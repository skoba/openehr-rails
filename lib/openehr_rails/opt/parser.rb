require 'openehr/parser'

module OpenehrRails
  module Opt
    # OPT parser accepting raw OPT XML content, not just a file path.
    #
    # OpenEHR::Parser::OPTParser#parse unconditionally does File.open(@filename);
    # callers here (TemplateUploader, TemplateRegistry, Fhir::ProfileRepository)
    # need to parse XML already held in memory, so #parse is overridden with
    # that as the only change — uid/occurrences tolerance now lives upstream.
    class Parser < OpenEHR::Parser::OPTParser
      UTF8_BOM = "\xEF\xBB\xBF".freeze

      def parse
        source = if raw_xml_content?(@filename)
                   @filename # raw OPT XML content
                 else
                   File.open(@filename)
                 end
        @opt = Nokogiri::XML::Document.parse(source)
        @opt.remove_namespaces!

        defs = definition

        OpenEHR::AM::Template::OperationalTemplate.new(
          uid: build_uid,
          concept: concept,
          original_language: language,
          description: description,
          template_id: template_id,
          archetype_id: template_id,
          definition: defs,
          ontology: (@component_terminologies || {})[defs.archetype_id.value] || create_template_ontology,
          component_terminologies: @component_terminologies || {},
          terminology_extracts: @component_terminologies || {},
          adl_version: '1.4'
        )
      end

      private

      # A leading UTF-8 BOM (common in OPT exports from Windows-authored
      # tools) survives #lstrip, since it's not whitespace, so it has to be
      # stripped before checking whether this is raw content vs. a path.
      def raw_xml_content?(filename)
        # .b avoids Encoding::CompatibilityError when filename is a
        # BINARY-encoded String (e.g. read from an uploaded Rack file).
        filename.to_s.b.delete_prefix(UTF8_BOM.b).lstrip.start_with?('<')
      end
    end
  end
end
