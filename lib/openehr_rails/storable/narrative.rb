# frozen_string_literal: true

module OpenehrRails
  # The part of Storable that fills an INSTRUCTION's mandatory attributes that
  # no input field carries (skoba/openehr-rails#69; plan docs/design/0.9.x-plan.md
  # 3.4, 3.4a). The rule is the one anlage uses for form-built compositions
  # (its docs/design/rm-attributes-without-inputs.md section 6).
  module Storable
    # The RM's "any ACTION archetype" pattern, for an ACTIVITY whose OPT does
    # not constrain action_archetype_id (or a FIELD_MAP generated before #69).
    ANY_ACTION_ARCHETYPE = '/.*/'

    # DV_TEXT cannot hold a line break (an RM invariant), so the parts are
    # joined by a full-width semicolon.
    NARRATIVE_SEPARATOR = '；'

    private

    # +filled+ maps each entry hash to the [field, value] pairs written into
    # it, in FIELD_MAP (template document) order.
    def write_narratives(filled)
      filled.each do |entry, pairs|
        next unless entry['_type'] == 'INSTRUCTION'

        text = pairs.map { |field, value| "#{narrative_label(field)}: #{narrative_value(field, value)}" }
        entry['narrative'] = { '_type' => 'DV_TEXT', 'value' => text.join(NARRATIVE_SEPARATOR) }
      end
    end

    # "root name／label" under an embedded root, else the label.
    def narrative_label(field)
      field[:root_label] ? "#{field[:root_label]}／#{field[:label]}" : field[:label]
    end

    # The value as a form shows it.
    def narrative_value(field, value)
      case field[:rm_type]
      when 'DV_CODED_TEXT' then field[:code_labels]&.fetch(value.to_s, nil) || value.to_s
      when 'DV_ORDINAL', 'DV_SCALE' then narrative_symbol(field, value)
      when 'DV_QUANTITY' then [value, narrative_units(field)].compact.join(' ')
      when 'DV_DATE_TIME' then value.respond_to?(:strftime) ? value.strftime('%Y-%m-%d %H:%M') : value.to_s
      when 'DV_DATE' then value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
      else value.to_s
      end
    end

    def narrative_symbol(field, value)
      magnitude = field[:rm_type] == 'DV_ORDINAL' ? value.to_i : value.to_f
      code = field[:value_code_map]&.fetch(magnitude, nil)
      (code && field[:code_labels]&.fetch(code, nil)) || value.to_s
    end

    def narrative_units(field)
      units_attribute = "#{field[:name]}_units"
      (respond_to?(units_attribute) ? public_send(units_attribute) : nil) || field[:units]
    end
  end
end
