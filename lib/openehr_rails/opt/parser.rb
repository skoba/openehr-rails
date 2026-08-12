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
      def parse
        source = if @filename.to_s.lstrip.start_with?('<')
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
    end
  end
end
