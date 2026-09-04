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
        populate_term_bindings!

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

      # 撤去条件: openehr-ruby#31（OPTParser drops term_bindings）の上流解消後。
      # 上流OPTParserがcomponent_terminologiesの各ArchetypeTerminologyへ
      # term_bindingsを投入するようになれば、下のnilガードで本メソッドは
      # no-opになるため、このメソッド群と#parseからの呼び出しを削除する。
      # #31の迂回保有者は本メソッド群（このnilガード1箇所）のみ（2026-09-04現在）。
      # もう一方の迂回だったanlage側の生XML再解析
      # （Opt::PathcardExtractor#extract_code_bindings、skoba/anlage#19）は
      # 撤去済みで、上流解消時はここの2メソッド削除だけで撤去が完了する。
      # それまでは、OPT文書のterm_bindings（items/valueの入れ子構造。ADL/XML
      # アーキタイプのterm_bindings ── 属性+単一テキストの平坦構造 ──とは
      # XML構造が異なる点に注意）を@optから直接読み、上流ArchetypeOntology#
      # term_bindingsと同じ正規形 { terminology => { code => [CodePhrase] } }
      # へ投入する暫定バイパス。
      def populate_term_bindings!
        raw_term_bindings_by_archetype.each do |archetype_id, bindings|
          terminology = (@component_terminologies || {})[archetype_id]
          next unless terminology
          next if terminology.term_bindings

          terminology.term_bindings = bindings
        end
      end

      def raw_term_bindings_by_archetype
        @opt.xpath('//term_bindings').each_with_object({}) do |term_binding, by_archetype|
          archetype_id = nearest_archetype_id(term_binding)
          next unless archetype_id

          system_uri = term_binding['terminology']
          term_binding.xpath('./items').each do |item|
            code_phrase = binding_code_phrase(item, system_uri)
            next unless code_phrase

            systems = (by_archetype[archetype_id] ||= {})
            codes = (systems[system_uri] ||= {})
            (codes[item['code']] ||= []) << code_phrase
          end
        end
      end

      def binding_code_phrase(item, fallback_terminology)
        code_string = item.at_xpath('./value/code_string')&.text
        return if code_string.to_s.empty?

        terminology_text = item.at_xpath('./value/terminology_id/value')&.text
        terminology_text = fallback_terminology if terminology_text.to_s.empty?

        OpenEHR::RM::DataTypes::Text::CodePhrase.new(
          terminology_id: OpenEHR::RM::Support::Identification::TerminologyID.new(value: terminology_text),
          code_string: code_string
        )
      end

      def nearest_archetype_id(node)
        node.ancestors.each do |ancestor|
          value = ancestor.at_xpath('./archetype_id/value')
          return value.text if value
        end
        nil
      end

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
