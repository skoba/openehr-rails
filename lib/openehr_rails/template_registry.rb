# frozen_string_literal: true

require 'active_support/concern'

module OpenehrRails
  # Behaviour of the OpenehrTemplate registry model that stores every
  # template (OPT or ADL) known to the host application. The install
  # generator emits a thin ActiveRecord model including this module.
  module TemplateRegistry
    extend ActiveSupport::Concern

    TEMPLATE_TYPES = %w[operational_template archetype_template].freeze

    included do
      validates :template_id, presence: true, uniqueness: true
      validates :template_type, inclusion: { in: TEMPLATE_TYPES }

      scope :operational, -> { where(template_type: 'operational_template') }
      scope :archetype_based, -> { where(template_type: 'archetype_template') }
    end

    class_methods do
      def from_opt_file(opt_file)
        template = OpenehrRails::Opt.parse(opt_file)
        template_id = template.template_id.value
        find_by(template_id: template_id) ||
          create!(
            template_id: template_id,
            name: template.concept || template_id,
            content: File.read(opt_file),
            template_type: 'operational_template'
          )
      end

      def from_adl_file(adl_file)
        archetype = OpenEHR::Parser::ADLParser.new(adl_file).parse
        archetype_id = archetype.archetype_id.value
        find_by(template_id: archetype_id) ||
          create!(
            template_id: archetype_id,
            name: archetype.concept,
            content: File.read(adl_file),
            template_type: 'archetype_template'
          )
      end
    end

    def generate_model_name
      template_id.underscore.tr('.', '_')
    end

    def operational?
      template_type == 'operational_template'
    end

    def form_fields
      raise 'form_fields is only available for operational templates' unless operational?

      template = OpenehrRails::Opt.parse(content)
      OpenehrRails::Opt::FieldExtractor.new(template).fields
    end
  end
end
