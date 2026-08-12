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
        source = remote_url? ? fetch_remote_opt : opt_file
        template = OpenehrRails::Opt.parse(source)
        OpenehrRails::Fhir::ProfileGenerator.new(template).to_json_files.each do |id, json|
          create_file "app/fhir/profiles/#{id}.json", json
        end
      end

      private

      def remote_url?
        opt_file.to_s.match?(%r{\Ahttps?://})
      end

      def fetch_remote_opt
        say "Fetching OPT from #{opt_file}"
        OpenehrRails::Opt::RemoteFetcher.fetch(opt_file)
      rescue OpenehrRails::Opt::RemoteFetcher::FetchError => e
        raise Thor::Error, "Could not fetch OPT from #{opt_file}: #{e.message}"
      end
    end
  end
end
