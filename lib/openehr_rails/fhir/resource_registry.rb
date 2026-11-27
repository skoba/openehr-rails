# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Tracks which openEHR archetypes are exposed as FHIR resources, from two
    # sources:
    # - :model -- ActiveRecord models including Storable. Populated
    #   automatically by Storable's `included` hook, so no generated
    #   registration code is needed. Model names are stored as strings to
    #   survive code reloading in development.
    # - :rm_graph (#101) -- templates from Fhir.template_source that no
    #   scaffolded model covers; their records are read from the RM graph.
    module ResourceRegistry
      ARCHETYPE_SYSTEM = 'http://openehr.org/ckm/archetypes'

      # index: position of the entry among its template's entries (:rm_graph
      # only; part of the resource id).
      Entry = Struct.new(:model, :archetype_id, :rm_type, :resource_type, :fields,
                         :source, :template_id, :index, keyword_init: true) do
        def slug
          "openehr-#{archetype_id.delete_prefix('openEHR-EHR-').parameterize.dasherize}"
        end

        def runtime?
          source == :rm_graph
        end

        # Served only as the resource its profile describes (#104): an
        # Observation entry, or one with a TypeMap::ENTRY_ELEMENT_MAPS row
        # (the same rule as TypeMap.assert_supported!).
        def servable?
          resource_type == 'Observation' || !TypeMap.element_map_for(archetype_id).nil?
        end
      end

      module_function

      def model_names
        @model_names ||= []
      end

      def register_model(model)
        name = model.is_a?(Class) ? model.name : model.to_s
        return if name.nil? || name.empty?

        model_names << name unless model_names.include?(name)
      end

      def reset!
        @model_names = []
      end

      def models
        discover_from_templates
        model_names.filter_map { |name| name.safe_constantize }
      end

      # Models autoload lazily, so the Storable `included` hook may not
      # have run yet. Seed the model names from the operational templates
      # in the registry and let safe_constantize trigger autoloading.
      def discover_from_templates
        registry_model = 'OpenehrTemplate'.safe_constantize
        return unless registry_model.respond_to?(:operational)

        registry_model.operational.each do |template|
          register_model(OpenehrRails::Naming.model_name(template.template_id).camelize)
        end
      rescue StandardError
        nil
      end

      def entries
        model_entries + runtime_entries
      end

      def model_entries
        models.flat_map { |model| entries_for(model) }
      end

      # Entries of templates no scaffolded model covers (#101, R-20261127-15
      # answer 2: a template with a model is served by the model path only).
      def runtime_entries
        covered = models.filter_map { |model| model.const_get(:TEMPLATE_ID).to_s if model.const_defined?(:TEMPLATE_ID) }
        TemplateSource.templates.reject { |template| covered.include?(template.template_id) }
                      .flat_map { |template| runtime_entries_for(template) }
      end

      def runtime_entries_for(template)
        template.fields.group_by { |field| field[:archetype_id] }.each_with_index.filter_map do |(archetype_id, fields), index|
          entry = Entry.new(model: nil, archetype_id: archetype_id, rm_type: fields.first[:entry_rm_type],
                            resource_type: TypeMap.resource_for_entry(fields.first[:entry_rm_type]),
                            fields: fields, source: :rm_graph, template_id: template.template_id, index: index)
          entry if entry.servable?
        end
      end

      def entries_for(model)
        return [] unless model.const_defined?(:FIELD_MAP)

        # Generated FIELD_MAPs key fields by name without a :name entry;
        # normalize so every consumer can rely on field[:name].
        fields_with_names = model.const_get(:FIELD_MAP).map do |name, field|
          field.merge(name: name.to_s)
        end
        fields_with_names.group_by { |f| f[:archetype_id] }
                         .map do |archetype_id, fields|
          Entry.new(
            model: model,
            archetype_id: archetype_id,
            rm_type: fields.first[:entry_rm_type],
            resource_type: TypeMap.resource_for_entry(fields.first[:entry_rm_type]),
            fields: fields,
            source: :model,
            template_id: (model.const_get(:TEMPLATE_ID).to_s if model.const_defined?(:TEMPLATE_ID))
          )
        end
      end

      def find_by_code(archetype_id)
        entries.find { |entry| entry.archetype_id == archetype_id }
      end

      # Model entries only: "<record id>-<slug>" ids belong to the model path.
      def find_by_slug(slug)
        model_entries.find { |entry| entry.slug == slug }
      end
    end
  end
end
