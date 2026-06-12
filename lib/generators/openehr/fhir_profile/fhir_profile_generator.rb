# frozen_string_literal: true

require 'rails/generators'
require 'openehr_rails'

module Openehr
  module Generators
    # Writes HL7 FHIR R5 StructureDefinition profiles (one per OPT entry)
    # into app/fhir/profiles/<id>.json. Also invoked from openehr:scaffold
    # with --fhir.
    class FhirProfileGenerator < ::Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      argument :opt_file, type: :string, desc: 'Path to OPT file'

      def generate_profiles
        template = OpenehrRails::Opt.parse(opt_file)
        OpenehrRails::Fhir::ProfileGenerator.new(template).to_json_files.each do |id, json|
          create_file "app/fhir/profiles/#{id}.json", json
        end
      end
    end
  end
end
