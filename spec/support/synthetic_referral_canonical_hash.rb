# frozen_string_literal: true

# Fixture kind: **synthetic** (hand-authored, not derived from any real
# artifact). Design authority: docs/design/rm-object-builder-section-instruction-plan.md
# section 3 (skoba/openehr-rails#45). Every archetype id is self-evidently
# invented (`synthetic_*_test`); the at-codes mirror the *shape* of
# jp_referral's service_request (activities[at0001]/description[at0009],
# protocol[at0008]) so the AQL paths in the specs read like the real ones,
# but no real canonical JSON with SECTION/INSTRUCTION exists in this repo --
# anlage's hand-mapped composition lives outside it.
#
# Shape: COMPOSITION whose content is a SECTION holding one EVALUATION, and
# an INSTRUCTION with a narrative, a protocol ITEM_TREE and one ACTIVITY
# (description ITEM_TREE + DV_PARSABLE timing). Everything GraphBuilder
# accepts today; before #45 RmObjectBuilder could rebuild none of it.
module SyntheticReferralCanonicalHash
  COMPOSITION_ID = 'openEHR-EHR-COMPOSITION.synthetic_referral_test.v1'
  SECTION_ID = 'openEHR-EHR-SECTION.synthetic_details_test.v1'
  EVALUATION_ID = 'openEHR-EHR-EVALUATION.synthetic_summary_test.v1'
  INSTRUCTION_ID = 'openEHR-EHR-INSTRUCTION.synthetic_request_test.v1'

  module_function

  def dv_text(value)
    { '_type' => 'DV_TEXT', 'value' => value }
  end

  def element(node_id, value)
    { '_type' => 'ELEMENT', 'archetype_node_id' => node_id, 'name' => dv_text(node_id), 'value' => value }
  end

  def item_tree(node_id, items)
    { '_type' => 'ITEM_TREE', 'archetype_node_id' => node_id, 'name' => dv_text(node_id), 'items' => items }
  end

  def archetyped(id)
    { '_type' => 'ARCHETYPED', 'archetype_id' => { 'value' => id }, 'rm_version' => '1.0.4' }
  end

  def evaluation
    {
      '_type' => 'EVALUATION', 'archetype_node_id' => EVALUATION_ID,
      'archetype_details' => archetyped(EVALUATION_ID), 'name' => dv_text('Summary'),
      'data' => item_tree('at0001', [element('at0002', dv_text('stable'))])
    }
  end

  def activity
    {
      '_type' => 'ACTIVITY', 'archetype_node_id' => 'at0001', 'name' => dv_text('Request'),
      'description' => item_tree('at0009', [element('at0121', dv_text('Chest pain work-up'))]),
      'timing' => { '_type' => 'DV_PARSABLE', 'value' => 'R1', 'formalism' => 'timing' }
    }
  end

  # narrative: pass false to omit the narrative (the injected-default case).
  def instruction(narrative: 'Refer to cardiology')
    hash = {
      '_type' => 'INSTRUCTION', 'archetype_node_id' => INSTRUCTION_ID,
      'archetype_details' => archetyped(INSTRUCTION_ID), 'name' => dv_text('Request'),
      'protocol' => item_tree('at0008', [element('at0010', dv_text('Synthetic Hospital'))]),
      'activities' => [activity]
    }
    hash['narrative'] = dv_text(narrative) if narrative
    hash
  end

  def section(items = [evaluation])
    { '_type' => 'SECTION', 'archetype_node_id' => SECTION_ID, 'name' => dv_text('Details'), 'items' => items }
  end

  def composition(content: [section, instruction])
    {
      '_type' => 'COMPOSITION', 'archetype_node_id' => COMPOSITION_ID,
      'archetype_details' => archetyped(COMPOSITION_ID).merge('template_id' => { 'value' => 'synthetic_referral_test' }),
      'name' => dv_text('Synthetic referral'),
      'content' => content
    }
  end
end
