# frozen_string_literal: true

require 'digest'
require 'erb'

module OpenehrRails
  module Fhir
    # The one place a StructureDefinition's id, url, name and title come from
    # (skoba/openehr-rails#55). Both ProfileGenerator (JSON) and FshGenerator
    # use it, so the two outputs cannot disagree, and every value is qualified
    # by the template: two templates that use the same archetype with different
    # constraints get different profiles. Plain Ruby, like FshGenerator (no
    # ActiveSupport string extensions; see 0181f7f).
    module ProfileIdentity
      MAX_ID_LENGTH = 64 # FHIR id: [A-Za-z0-9\-\.]{1,64}
      HASH_LENGTH = 8
      CANONICAL_SCHEME = 'urn:openehr'

      module_function

      # template_id may be the parsed template's TemplateID or a String.
      def for(template_id, archetype_id)
        template_id = template_id.value if template_id.respond_to?(:value)
        id = profile_id(template_id, archetype_id)
        {
          id: id,
          url: "#{CANONICAL_SCHEME}:#{ERB::Util.url_encode(template_id)}:#{archetype_id}",
          name: id.split('-').map { |word| word[0].upcase + word[1..] }.join,
          title: "openEHR #{humanize(concept(archetype_id))} (#{template_id}: #{archetype_id})"
        }
      end

      # "openehr-<template slug>-<archetype slug>". Longer than a FHIR id may
      # be, it keeps a prefix and ends in the first characters of the full
      # id's sha256, so it stays unique and stable.
      def profile_id(template_id, archetype_id)
        full = ['openehr', slug(template_id), slug(archetype_id.delete_prefix('openEHR-EHR-'))].join('-')
        return full if full.length <= MAX_ID_LENGTH

        prefix = full[0, MAX_ID_LENGTH - HASH_LENGTH - 1].sub(/-+\z/, '')
        "#{prefix}-#{Digest::SHA256.hexdigest(full)[0, HASH_LENGTH]}"
      end

      # ActiveSupport's parameterize.dasherize on ASCII input: downcase,
      # collapse every run of non-alphanumerics to "-", strip edge dashes.
      def slug(text)
        text.to_s.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
      end

      # Same rule as Opt::FieldExtractor's entry concept ("problem_diagnosis").
      def concept(archetype_id)
        archetype_id.split('.')[1].to_s.gsub(/[^A-Za-z0-9]+/, '_').gsub(/\A_+|_+\z/, '').downcase
      end

      def humanize(concept)
        spaced = concept.tr('_', ' ')
        spaced.empty? ? spaced : spaced[0].upcase + spaced[1..]
      end
    end
  end
end
