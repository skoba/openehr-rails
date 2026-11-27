# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Resolves StructureDefinition profiles for the FHIR endpoint. Prefers
    # files written by `--fhir` under app/fhir/profiles, and otherwise
    # builds them on the fly from the operational templates of
    # Fhir.template_source (default: the OpenehrTemplate registry).
    module ProfileRepository
      module_function

      def all(root: ::Rails.root)
        from_files(root).presence || from_registry
      end

      def find(id, root: ::Rails.root)
        file = profiles_dir(root).join("#{id}.json")
        return JSON.parse(File.read(file)) if File.exist?(file)

        matches = ->(profile) { profile['id'] == id || profile[:id] == id }
        # A template without a file (e.g. registered at runtime, #101) is
        # still found among the generated profiles.
        from_files(root).find(&matches) || from_registry.find(&matches)
      end

      def from_files(root)
        Dir.glob(profiles_dir(root).join('*.json')).map { |path| JSON.parse(File.read(path)) }
      end

      # Templates from Fhir.template_source, which defaults to the gem's
      # OpenehrTemplate registry (#101).
      def from_registry
        TemplateSource.templates.flat_map do |template|
          ProfileGenerator.new(TemplateSource.parsed(template.opt)).profiles
        end
      end

      def profiles_dir(root)
        Pathname.new(root).join('app/fhir/profiles')
      end
    end
  end
end
