# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Generates one FHIR Shorthand profile per openEHR ENTRY.
    class FshGenerator
      ARCHETYPE_SYSTEM = 'http://openehr.org/ckm/archetypes'
      TERMINOLOGY_ALIASES = {
        'SNOMED-CT' => ['SNOMEDCT', 'http://snomed.info/sct'],
        'LOINC' => ['LOINC', 'http://loinc.org']
      }.freeze

      def initialize(template)
        @entries = OpenehrRails::Opt::FieldExtractor.new(template).entries
      end

      def to_fsh_files
        @entries.to_h do |entry|
          id = profile_id(entry[:archetype_id])
          [id, build_profile(entry, id)]
        end
      end

      private

      def build_profile(entry, id)
        resource_type = TypeMap.resource_for_entry(entry[:rm_type])
        lines = alias_rules(entry[:fields])
        lines << '' unless lines.empty?
        lines.concat(metadata(entry, id, resource_type))
        element_map = TypeMap.element_map_for(entry[:archetype_id])
        if element_map
          lines.concat(mapped_rules(entry, element_map))
        elsif entry[:fields].one?
          field = entry[:fields].first
          lines.concat(code_rules(entry[:archetype_id], 'code', field[:code_bindings]))
          lines.concat(value_rules('value[x]', field))
        else
          lines.concat(code_rules(entry[:archetype_id]))
          lines.concat(component_rules(entry[:fields]))
        end
        "#{lines.join("\n")}\n"
      end

      # Leaves land on real elements of the base resource, per TypeMap's mapping
      # table -- the same table ProfileGenerator generates from, so the FSH and
      # the JSON facade cannot disagree about where a leaf goes (#33).
      def mapped_rules(entry, element_map)
        anchor = element_map[:anchor]
        rules = [
          "* #{anchor}.coding.system = \"#{ARCHETYPE_SYSTEM}\"",
          "* #{anchor}.coding.code = ##{entry[:archetype_id]}"
        ]
        entry[:fields].each do |field|
          leaf = element_map[:leaves][field[:node_id]]
          next unless leaf

          path = leaf[:element]
          rules << "* #{path} #{field[:required] ? 1 : 0}..1"
          rules << "* #{path} only #{TypeMap.datatype_for(field[:rm_type])}"
          next unless leaf[:bind_value_set] && field[:value_set_uri]

          rules << "* #{path} from #{value_set_uri(field[:value_set_uri])} (required)"
        end
        rules
      end

      def alias_rules(fields)
        bindings = fields.flat_map { |field| field[:code_bindings] }
        return [] if bindings.empty?

        aliases = [['CKM', ARCHETYPE_SYSTEM]]
        aliases.concat(bindings.filter_map { |binding| TERMINOLOGY_ALIASES[binding[:system_uri]] })
        aliases.uniq.map { |name, uri| "Alias: #{name} = #{uri}" }
      end

      def metadata(entry, id, resource_type)
        [
          "Profile: #{camelize(id.tr('-', '_'))}",
          "Parent: #{resource_type}",
          "Id: #{id}",
          "Title: \"openEHR #{humanize(entry[:concept])} (#{entry[:archetype_id]})\"",
          ''
        ]
      end

      # Plain-Ruby equivalent of ActiveSupport's String#camelize on an
      # underscore-separated input: "foo_bar" -> "FooBar".
      def camelize(str)
        str.split('_').map { |word| word[0].upcase + word[1..].to_s }.join
      end

      # Plain-Ruby equivalent of ActiveSupport's String#humanize on an
      # already-lowercase, underscore-separated input: "foo_bar" -> "Foo bar".
      def humanize(str)
        spaced = str.tr('_', ' ')
        spaced[0] ? spaced[0].upcase + spaced[1..].to_s.downcase : spaced
      end

      def code_rules(archetype_id, path = 'code', bindings = [])
        return simple_code_rules(archetype_id, path) if bindings.empty?

        coding_path = "#{path}.coding"
        slices = ['ckm 1..1', *binding_slices(bindings).map { |slice, _| "#{slice} 0..1" }]
        [
          "* #{coding_path} ^slicing.discriminator.type = #value",
          "* #{coding_path} ^slicing.discriminator.path = \"system\"",
          "* #{coding_path} ^slicing.rules = #open",
          "* #{coding_path} contains #{slices.join(' and ')}",
          "* #{coding_path}[ckm] = CKM##{archetype_id}",
          *binding_slices(bindings).map do |slice, binding|
            alias_name = TERMINOLOGY_ALIASES.fetch(binding[:system_uri]).first
            "* #{coding_path}[#{slice}] = #{alias_name}##{bare_code(binding[:code])}"
          end
        ]
      end

      def simple_code_rules(archetype_id, path)
        [
          "* #{path}.coding.system = \"#{ARCHETYPE_SYSTEM}\"",
          "* #{path}.coding.code = ##{archetype_id}"
        ]
      end

      def component_rules(fields)
        rules = [
          '* component ^slicing.discriminator.type = #pattern',
          '* component ^slicing.discriminator.path = "code"',
          '* component ^slicing.rules = #open'
        ]
        fields.each do |field|
          slice_name = field[:name].downcase.gsub(/[^a-z0-9]/, '')
          path = "component[#{slice_name}]"
          rules << "* component contains #{slice_name} #{field[:required] ? 1 : 0}..1"
          rules.concat(
            code_rules(
              "#{field[:archetype_id]}##{field[:node_id]}",
              "#{path}.code",
              field[:code_bindings]
            )
          )
          rules.concat(value_rules("#{path}.value[x]", field))
        end
        rules
      end

      def binding_slices(bindings)
        bindings.filter_map do |binding|
          terminology = TERMINOLOGY_ALIASES[binding[:system_uri]]
          next unless terminology

          [terminology.first.downcase, binding]
        end
      end

      # OPT term bindings wrap codes as `[TERMINOLOGY(version)::code]` (the
      # version is optional). FSH needs only the code after the final `::`.
      def bare_code(raw_code)
        raw_code.to_s.sub(/\A\[.*::/, '').delete_suffix(']')
      end

      def value_rules(path, field)
        rules = [
          "* #{path} only #{TypeMap.datatype_for(field[:rm_type])}"
        ]
        rules.unshift("* #{path} #{field[:required] ? 1 : 0}..1") if path == 'value[x]'
        rules << "* #{path}.unit = \"#{field[:units]}\"" if field[:rm_type] == 'DV_QUANTITY' && field[:units]
        rules << "* #{path} from #{value_set_uri(field[:value_set_uri])} (required)" if field[:value_set_uri]
        rules
      end

      def value_set_uri(uri)
        TypeMap.value_set_canonical(uri)
      end

      def profile_id(archetype_id)
        "openehr-#{parameterize(archetype_id.delete_prefix('openEHR-EHR-'))}"
      end

      # Plain-Ruby equivalent of ActiveSupport's String#parameterize.dasherize:
      # downcase, collapse every run of non-alphanumeric characters to a
      # single "-", and strip any leading/trailing "-".
      def parameterize(str)
        str.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
      end
    end
  end
end
