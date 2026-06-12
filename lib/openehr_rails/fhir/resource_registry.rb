# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Tracks which ActiveRecord models (those including Storable) expose
    # which openEHR archetypes as FHIR resources. Populated automatically
    # by Storable's `included` hook, so no generated registration code is
    # needed. Model names are stored as strings to survive code reloading
    # in development.
    module ResourceRegistry
      ARCHETYPE_SYSTEM = 'http://openehr.org/ckm/archetypes'

      Entry = Struct.new(:model, :archetype_id, :rm_type, :resource_type, :fields,
                         keyword_init: true) do
        def slug
          "openehr-#{archetype_id.delete_prefix('openEHR-EHR-').parameterize.dasherize}"
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
        models.flat_map { |model| entries_for(model) }
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
            fields: fields
          )
        end
      end

      def find_by_code(archetype_id)
        entries.find { |entry| entry.archetype_id == archetype_id }
      end

      def find_by_slug(slug)
        entries.find { |entry| entry.slug == slug }
      end
    end
  end
end
