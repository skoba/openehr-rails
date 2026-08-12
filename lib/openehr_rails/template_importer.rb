# frozen_string_literal: true

require 'fileutils'

module OpenehrRails
  # Fetches an OPT from a URL, validates it, stores it under
  # app/templates/operational and registers it in the template registry.
  # Used by the admin engine's URL-import field (the URL counterpart to
  # TemplateUploader's drag & drop).
  class TemplateImporter
    class InvalidTemplate < StandardError; end

    def self.call(url:, root: ::Rails.root, registry: ::OpenehrTemplate)
      new(url: url, root: root, registry: registry).call
    end

    def initialize(url:, root:, registry:)
      @url = url
      @root = Pathname.new(root)
      @registry = registry
    end

    def call
      content = fetch_content
      template_id = OpenehrRails::Opt.parse(content).template_id.value

      path = storage_path(template_id)
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, content)
      @registry.from_opt_file(path.to_s)
    end

    private

    def fetch_content
      OpenehrRails::Opt::RemoteFetcher.fetch(@url)
    rescue OpenehrRails::Opt::RemoteFetcher::FetchError => e
      raise InvalidTemplate, e.message
    end

    def storage_path(template_id)
      @root.join(TemplateUploader::STORAGE_DIR, "#{template_id}.opt")
    end
  end
end
