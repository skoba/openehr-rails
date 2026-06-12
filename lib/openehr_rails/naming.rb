# frozen_string_literal: true

module OpenehrRails
  # Derives Rails model names from openEHR template ids. Shared by the
  # scaffold generator and the admin engine (to detect/generate UIs).
  module Naming
    RM_TYPES = %w[COMPOSITION OBSERVATION EVALUATION ACTION INSTRUCTION ADMIN_ENTRY].freeze

    module_function

    # "openEHR-EHR-COMPOSITION.vital_signs.v1" => "vital_signs"
    def model_name(template_id)
      name = template_id.dup
      name.gsub!(/^openEHR-EHR-/, '')
      name.gsub!(/^openEHR-/, '')
      name.gsub!(/^IDCR-/, '')
      name.gsub!(/^EHRN-/, '')
      RM_TYPES.each { |rm_type| name.gsub!(/^#{rm_type}\./, '') }
      name.gsub!(/\.v\d+(\.\d+)?$/, '')
      name.downcase.gsub(/[.\s-]/, '_')
    end
  end
end
