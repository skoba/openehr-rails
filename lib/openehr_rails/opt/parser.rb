require 'openehr/parser'

module OpenehrRails
  module Opt
    # OPT parser tolerant of templates without a <uid> element.
    #
    # OpenEHR::Parser::OPTParser#parse unconditionally builds a UIDBasedID,
    # which raises ArgumentError when the template has no uid. Real-world
    # OPT exports frequently omit it, so #parse is overridden here with the
    # only change being optional uid handling.
    class Parser < OpenEHR::Parser::OPTParser
      def parse
        source = if @filename.to_s.lstrip.start_with?('<')
                   @filename # raw OPT XML content
                 else
                   File.open(@filename)
                 end
        @opt = Nokogiri::XML::Document.parse(source)
        @opt.remove_namespaces!

        uid_value = text_on_path(@opt, UID_PATH)
        uid = if uid_value.nil? || uid_value.empty?
                nil
              else
                OpenEHR::RM::Support::Identification::UIDBasedID.new(value: uid_value)
              end
        defs = definition

        OpenEHR::AM::Template::OperationalTemplate.new(
          uid: uid,
          concept: concept,
          original_language: language,
          description: description,
          template_id: template_id,
          archetype_id: template_id,
          definition: defs,
          ontology: create_template_ontology,
          component_terminologies: @component_terminologies || {},
          terminology_extracts: @component_terminologies || {},
          adl_version: '1.4'
        )
      end

      private

      # The upstream parser builds an Interval even when an occurrences or
      # existence element has neither bound, which Interval rejects. Treat
      # such intervals as "unconstrained".
      def occurrences(occurrence_xml)
        super
      rescue ArgumentError
        nil
      end
    end
  end
end
