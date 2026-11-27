# frozen_string_literal: true

require 'digest'

module OpenehrRails
  # HL7 FHIR R5 facade (profiles, serialization, resource registry).
  module Fhir
    # Raised when OpenehrRails::Fhir.template_source breaks its contract
    # (one template per template_id, R-20261127-15 answer 3).
    class TemplateSourceError < StandardError; end

    class << self
      # Where the FHIR facade finds the operational templates of records it
      # reads from the RM graph (#101). A callable returning an enumerable of
      # { template_id:, opt: } (opt = the OPT XML), one per template_id: the
      # version current records should be read with. nil (the default) reads
      # the gem's own registry, OpenehrTemplate.operational.
      #
      #   OpenehrRails::Fhir.template_source = lambda do
      #     Template.where(status: 'active').map { |t| { template_id: t.template_id, opt: t.source_xml } }
      #   end
      attr_accessor :template_source
    end

    # Reads OpenehrRails::Fhir.template_source and parses each template once
    # (cached by the OPT's digest).
    module TemplateSource
      Template = Struct.new(:template_id, :opt, :fields, keyword_init: true)

      module_function

      def templates
        raw = raw_templates
        repeated = raw.map { |t| t[:template_id] }.tally.select { |_, count| count > 1 }.keys
        if repeated.any?
          raise TemplateSourceError,
                "template_source returned template_id #{repeated.join(', ')} more than once; " \
                'return one template (the current version) per template_id'
        end

        raw.map { |t| Template.new(template_id: t[:template_id], opt: t[:opt], fields: fields_for(t[:opt])) }
      end

      def raw_templates
        source = Fhir.template_source
        list = source ? source.call : registry_templates
        Array(list).map do |t|
          t = t.to_h.transform_keys(&:to_sym)
          { template_id: t[:template_id].to_s, opt: t[:opt].to_s }
        end
      end

      def registry_templates
        registry = 'OpenehrTemplate'.safe_constantize
        return [] unless registry.respond_to?(:operational)

        registry.operational.map { |t| { template_id: t.template_id, opt: t.content } }
      rescue ActiveRecord::ActiveRecordError
        []
      end

      def fields_for(opt)
        cache[Digest::SHA256.hexdigest(opt)] ||= Opt::FieldExtractor.new(parsed(opt)).fields.freeze
      end

      def parsed(opt)
        parsed_cache[Digest::SHA256.hexdigest(opt)] ||= Opt.parse(opt)
      end

      def cache
        @cache ||= {}
      end

      def parsed_cache
        @parsed_cache ||= {}
      end
    end
  end
end
