# frozen_string_literal: true

require 'fileutils'

module OpenehrRails
  # Validates an uploaded OPT file, stores it under
  # app/templates/operational and registers it in the template registry.
  # Used by the admin engine's drag & drop upload.
  class TemplateUploader
    class InvalidTemplate < StandardError; end

    STORAGE_DIR = 'app/templates/operational'

    def self.call(file:, root: ::Rails.root, registry: ::OpenehrTemplate)
      new(file: file, root: root, registry: registry).call
    end

    def initialize(file:, root:, registry:)
      @file = file
      @root = Pathname.new(root)
      @registry = registry
    end

    def call
      validate_filename!
      content = read_content
      validate_template!(content)

      path = storage_path
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, content)
      @registry.from_opt_file(path.to_s)
    end

    private

    def filename
      name = @file.respond_to?(:original_filename) ? @file.original_filename : @file.path
      File.basename(name.to_s)
    end

    def validate_filename!
      return if filename.end_with?('.opt')

      raise InvalidTemplate, 'only .opt files are supported'
    end

    def read_content
      return File.read(@file.to_s) unless @file.respond_to?(:read)

      @file.rewind if @file.respond_to?(:rewind)
      @file.read
    end

    def validate_template!(content)
      template = OpenehrRails::Opt.parse(content)
      raise InvalidTemplate, 'template has no template_id' if template.template_id.value.to_s.empty?
    rescue InvalidTemplate
      raise
    rescue StandardError => e
      raise InvalidTemplate, "not a valid operational template: #{e.message}"
    end

    def storage_path
      @root.join(STORAGE_DIR, filename)
    end
  end
end
