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
    #   archetype_id:    id of the enclosing archetype root (entry)
    #   column_type:     ActiveRecord column type symbol
    #   units:           unit string for DV_QUANTITY
    #   magnitude_range: [lower, upper] for DV_QUANTITY
    #   code_list:       allowed codes for DV_CODED_TEXT
    #   code_labels:     {code => text} resolved from the terminology
    #   terminology_id:  terminology of the code list
    #   required:        true when the entry and element are both mandatory
    class FieldExtractor
      ENTRY_TYPES = %w[OBSERVATION EVALUATION INSTRUCTION ACTION ADMIN_ENTRY].freeze

      COLUMN_TYPES = {
        'DV_QUANTITY' => :float,
        'DV_PROPORTION' => :float,
        'DV_COUNT' => :integer,
        'DV_ORDINAL' => :integer,
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
        @entries ||= content_roots.map { |root| build_entry(root) }
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

        (content.children || []).select do |child|
          child.respond_to?(:archetype_id) && ENTRY_TYPES.include?(child.rm_type_name)
        end
      end

      def build_entry(root)
        archetype_id = root.archetype_id.value
        concept = concept_of(archetype_id)
        elements = collect_elements(root, "/content[#{archetype_id}]")
        entry = {
          archetype_id: archetype_id,
          rm_type: root.rm_type_name,
          concept: concept,
          node_id: root.node_id,
          occurrences: root.occurrences,
          required: mandatory?(root)
        }
        entry[:fields] = elements.map do |element, path|
          build_field(element, path, entry, elements.size)
        end
        entry
      end

      # Depth-first walk collecting [ELEMENT, rm_path] pairs under an entry.
      def collect_elements(node, path)
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
              [[child, node_path]]
            else
              collect_elements(child, node_path)
            end
          end
        end
      end

      def build_field(element, path, entry, sibling_count)
        constraint = value_constraint(element)
        rm_type = constraint&.rm_type_name || 'DV_TEXT'
        label = term_text(entry[:archetype_id], element.node_id)

        field = {
          name: field_name(entry[:concept], label, element.node_id, sibling_count),
          label: label || element.node_id,
          path: "#{path}/value",
          rm_type: rm_type,
          node_id: element.node_id,
          archetype_id: entry[:archetype_id],
          entry_rm_type: entry[:rm_type],
          column_type: COLUMN_TYPES.fetch(rm_type, :string),
          required: entry[:required] && mandatory?(element)
        }
        field.merge!(quantity_constraints(constraint)) if rm_type == 'DV_QUANTITY'
        field.merge!(coded_text_constraints(constraint, entry[:archetype_id])) if rm_type == 'DV_CODED_TEXT'
        field
      end

      def value_constraint(element)
        attrs = element.attributes || []
        value = attrs.find { |a| a.rm_attribute_name == 'value' }
        value&.children&.first
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
        defining_code = (constraint.attributes || [])
                        .find { |a| a.rm_attribute_name == 'defining_code' }
        code_phrase = defining_code&.children&.first
        return {} unless code_phrase

        codes = (code_phrase.code_list || []).reject { |c| c.nil? || c.empty? }
        {
          code_list: codes,
          code_labels: codes.to_h { |code| [code, term_text(archetype_id, code) || code] },
          terminology_id: code_phrase.terminology_id&.value
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

      def concept_of(archetype_id)
        archetype_id.split('.')[1].to_s.downcase
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
  end
end
