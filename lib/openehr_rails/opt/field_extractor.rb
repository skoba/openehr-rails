module OpenehrRails
  module Opt
    # Walks the constraint tree of an OperationalTemplate and extracts the
    # data ELEMENTs as flat field descriptions. This is the single source of
    # truth that drives model/migration/view generation and, later, the
    # openEHR RM <-> FHIR mapping.
    #
    # Each field is a Hash:
    #   name:            Ruby attribute / DB column name (ASCII, unique)
    #   label:           display text from the template terminology (any language)
    #   path:            RM path from the COMPOSITION content
    #   rm_type:         openEHR data value type (e.g. 'DV_QUANTITY')
    #   node_id:         at-code of the ELEMENT
    #   archetype_id:    id of the nearest enclosing archetype root (entry or embedded C_ARCHETYPE_ROOT)
    #   column_type:     ActiveRecord column type symbol
    #   units:           unit string for DV_QUANTITY
    #   magnitude_range: [lower, upper] for DV_QUANTITY
    #   code_list:       allowed codes for DV_CODED_TEXT
    #   code_labels:     {code => text} resolved from the terminology
    #   terminology_id:  terminology of the code list
    #   value_set_uri:   external value-set URI for DV_CODED_TEXT
    #   code_bindings:   [{system_uri:, code:}] ontology bindings for the node
    #   required:        true when the entry and element are both mandatory
    # rubocop:disable Metrics/ClassLength
    class FieldExtractor
      ENTRY_TYPES = %w[OBSERVATION EVALUATION INSTRUCTION ACTION ADMIN_ENTRY].freeze
      SECTION_TYPE = 'SECTION'.freeze

      COLUMN_TYPES = {
        'DV_QUANTITY' => :float,
        'DV_PROPORTION' => :float,
        'DV_COUNT' => :integer,
        'DV_ORDINAL' => :integer,
        'DV_SCALE' => :float,
        'DV_TEXT' => :string,
        'DV_CODED_TEXT' => :string,
        'DV_IDENTIFIER' => :string,
        'DV_URI' => :string,
        'DV_BOOLEAN' => :boolean,
        'DV_DATE' => :date,
        'DV_TIME' => :time,
        'DV_DATE_TIME' => :datetime,
        'DV_DURATION' => :string
      }.freeze

      # ELEMENT containers we descend into; protocol/state are skipped for now.
      DESCENDABLE_ATTRIBUTES = %w[data events items value].freeze

      def initialize(template)
        @template = template
      end

      def entries
        @entries ||= content_roots.map { |root, path| build_entry(root, path) }
      end

      def fields
        @fields ||= begin
          used = {}
          entries.flat_map { |entry| entry[:fields] }.each do |field|
            field[:name] = uniquify(field[:name], used)
          end
        end
      end

      private

      def content_roots
        attrs = @template.definition.attributes || []
        content = attrs.find { |a| a.rm_attribute_name == 'content' }
        return [] unless content

        entry_roots(content.children || [], '/content')
      end

      # Collects [entry_root, rm_path] pairs from a list of content children,
      # descending through SECTION containers (which nest their entries under
      # the `items` attribute) so vitals/exam templates organised into sections
      # still expose their ENTRYs.
      def entry_roots(children, prefix)
        children.flat_map do |child|
          next [] unless child.respond_to?(:rm_type_name)

          if entry_root?(child)
            [[child, "#{prefix}[#{child.archetype_id.value}]"]]
          elsif child.rm_type_name == SECTION_TYPE
            section_path = prefix
            if child.respond_to?(:archetype_id) && child.archetype_id
              section_path += "[#{child.archetype_id.value}]"
            end
            (child.respond_to?(:attributes) ? child.attributes : []).to_a.flat_map do |attr|
              next [] unless attr.rm_attribute_name == 'items'

              entry_roots(attr.children || [], "#{section_path}/items")
            end
          else
            []
          end
        end
      end

      def entry_root?(child)
        ENTRY_TYPES.include?(child.rm_type_name) &&
          child.respond_to?(:archetype_id) && child.archetype_id
      end

      def build_entry(root, path_prefix)
        archetype_id = root.archetype_id.value
        concept = concept_of(archetype_id)
        elements = collect_elements(root, path_prefix, archetype_id)
        entry = {
          archetype_id: archetype_id,
          rm_type: root.rm_type_name,
          concept: concept,
          node_id: root.node_id,
          occurrences: root.occurrences,
          required: mandatory?(root)
        }
        entry[:fields] = elements.map do |element, path, element_archetype_id|
          build_field(element, path, element_archetype_id, entry, elements.size)
        end
        entry
      end

      # Depth-first walk collecting [ELEMENT, rm_path, archetype_id] tuples under an entry.
      def collect_elements(node, path, archetype_id)
        return [] unless node.respond_to?(:attributes) && node.attributes

        node.attributes.flat_map do |attribute|
          next [] unless DESCENDABLE_ATTRIBUTES.include?(attribute.rm_attribute_name)
          next [] unless attribute.respond_to?(:children) && attribute.children

          child_path = "#{path}/#{attribute.rm_attribute_name}"
          attribute.children.flat_map do |child|
            next [] unless child.respond_to?(:rm_type_name)

            node_path = child_path
            node_path += "[#{child.node_id}]" if child.respond_to?(:node_id) && child.node_id

            if child.rm_type_name == 'ELEMENT'
              [[child, node_path, archetype_id]]
            else
              # rm_type_name is the constrained RM type, not "C_ARCHETYPE_ROOT".
              child_archetype_id = if child.respond_to?(:archetype_id) && child.archetype_id
                                     child.archetype_id.value
                                   else
                                     archetype_id
                                   end
              collect_elements(child, node_path, child_archetype_id)
            end
          end
        end
      end

      def build_field(element, path, archetype_id, entry, sibling_count)
        constraint = value_constraint(element)
        rm_type = constraint&.rm_type_name || 'DV_TEXT'
        label = term_text(archetype_id, element.node_id)

        field = {
          name: field_name(entry[:concept], label, element.node_id, sibling_count),
          label: label || element.node_id,
          path: "#{path}/value",
          rm_type: rm_type,
          node_id: element.node_id,
          archetype_id: archetype_id,
          entry_rm_type: entry[:rm_type],
          column_type: COLUMN_TYPES.fetch(rm_type, :string),
          value_set_uri: nil,
          code_bindings: code_bindings_for(archetype_id, element.node_id),
          required: entry[:required] && mandatory?(element)
        }
        field.merge!(quantity_constraints(constraint)) if rm_type == 'DV_QUANTITY'
        field.merge!(coded_text_constraints(constraint, archetype_id)) if rm_type == 'DV_CODED_TEXT'
        field.merge!(symbol_constraints(constraint, archetype_id)) if %w[DV_ORDINAL DV_SCALE].include?(rm_type)
        field
      end

      def value_constraint(element)
        attrs = element.attributes || []
        value = attrs.find { |a| a.rm_attribute_name == 'value' }
        children = value&.children || []
        return children.first if children.size <= 1

        code_reference_class = OpenEHR::AM::OpenEHRProfile::DataTypes::Text::CCodeReference
        children.find { |child| defining_code_of(child).is_a?(code_reference_class) } || children.first
      end

      def quantity_constraints(constraint)
        item = constraint.list&.first
        return {} unless item

        range = item.magnitude
        {
          units: item.units,
          magnitude_range: range && [range.lower, range.upper]
        }
      end

      def coded_text_constraints(constraint, archetype_id)
        code_phrase = defining_code_of(constraint)
        return {} unless code_phrase

        codes = (code_phrase.code_list || []).reject { |c| c.nil? || c.empty? }
        {
          code_list: codes,
          code_labels: codes.to_h { |code| [code, term_text(archetype_id, code) || code] },
          terminology_id: code_phrase.terminology_id&.value,
          value_set_uri: value_set_uri(code_phrase)
        }
      end

      def defining_code_of(constraint)
        defining_code = (constraint.attributes || [])
                        .find { |attribute| attribute.rm_attribute_name == 'defining_code' }
        defining_code&.children&.first
      end

      def value_set_uri(code_phrase)
        code_reference_class = OpenEHR::AM::OpenEHRProfile::DataTypes::Text::CCodeReference
        code_phrase.reference_set_uri if code_phrase.is_a?(code_reference_class)
      end

      def code_bindings_for(archetype_id, node_id)
        terminology = @template.component_terminologies[archetype_id]
        bindings = terminology.respond_to?(:term_bindings) ? terminology.term_bindings : nil
        return [] unless bindings

        bindings.flat_map do |system_uri, codes|
          Array(codes[node_id]).map do |code_phrase|
            { system_uri: system_uri, code: code_phrase.code_string }
          end
        end
      end

      # DV_ORDINAL/DV_SCALE constrain their value to a fixed list of
      # (numeric value, symbol) pairs; the symbol's defining_code is the
      # only identifier the OPT carries, so it doubles as both the stored
      # code and the label fallback when the ontology has no term for it.
      def symbol_constraints(constraint, archetype_id)
        items = (constraint.list || []).select { |item| item.symbol&.defining_code&.code_string }
        return {} if items.empty?

        codes = items.map { |item| item.symbol.defining_code.code_string }
        {
          code_list: codes,
          code_labels: codes.to_h { |code| [code, term_text(archetype_id, code) || code] },
          # DV_ORDINAL/DV_SCALE store a numeric magnitude, not the symbol
          # code, so the write path needs this to reconstruct the symbol.
          value_code_map: items.to_h { |item| [item.value, item.symbol.defining_code.code_string] }
        }
      end

      # Single-element entries take the archetype concept name. Extra
      # elements get a label-derived suffix; non-ASCII labels (which the
      # terminology often holds) fall back to the at-code.
      def field_name(concept, label, node_id, sibling_count)
        return concept if sibling_count == 1

        slug = ascii_slug(label)
        return concept if slug == concept
        return "#{concept}_#{slug}" unless slug.empty?

        "#{concept}_#{node_id}"
      end

      def ascii_slug(text)
        text.to_s.gsub(/[^A-Za-z0-9]+/, '_').gsub(/\A_+|_+\z/, '').downcase
      end

      def uniquify(name, used)
        candidate = name
        serial = 1
        while used[candidate]
          serial += 1
          candidate = "#{name}_#{serial}"
        end
        used[candidate] = true
        candidate
      end

      # The middle segment of an archetype id is the concept (e.g.
      # "openEHR-EHR-OBSERVATION.heart_rate-pulse.v1" => "heart_rate-pulse").
      # Concepts can contain hyphens, which are illegal in column/attribute
      # names, so slug it to a valid identifier ("heart_rate_pulse").
      def concept_of(archetype_id)
        ascii_slug(archetype_id.split('.')[1].to_s)
      end

      def mandatory?(node)
        occurrences = node.respond_to?(:occurrences) ? node.occurrences : nil
        !occurrences.nil? && occurrences.lower.to_i >= 1
      end

      def term_text(archetype_id, code)
        terminology = @template.component_terminologies[archetype_id]
        return nil unless terminology

        terminology.term_definitions.each_value do |terms|
          term = terms.find { |t| t.code == code }
          return term.items['text'] if term
        end
        nil
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
