# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Resolves StructureDefinition profiles for the FHIR endpoint. Prefers
    # files written by `--fhir` under app/fhir/profiles, and otherwise
    # builds them on the fly from the registered operational templates.
    module ProfileRepository
      module_function

      def all(root: ::Rails.root)
        from_files(root).presence || from_registry
      end

      def find(id, root: ::Rails.root)
        file = profiles_dir(root).join("#{id}.json")
        return JSON.parse(File.read(file)) if File.exist?(file)

        all(root: root).find { |profile| profile['id'] == id || profile[:id] == id }
      end

      def from_files(root)
        Dir.glob(profiles_dir(root).join('*.json')).map { |path| JSON.parse(File.read(path)) }
      end

      def from_registry
        return [] unless defined?(::OpenehrTemplate)

        ::OpenehrTemplate.operational.flat_map do |template|
          opt = OpenehrRails::Opt.parse(template.content)
          ProfileGenerator.new(opt).profiles
        end
      end

      def profiles_dir(root)
        Pathname.new(root).join('app/fhir/profiles')
      end
    end
  end
end
