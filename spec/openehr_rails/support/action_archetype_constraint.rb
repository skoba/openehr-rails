# frozen_string_literal: true

# Adds an `action_archetype_id` C_STRING constraint to every ACTIVITY of a
# parsed template, in memory: no fixture OPT constrains it (plan
# docs/design/0.9.x-plan.md 3.4a).
module ActionArchetypeConstraint
  CONSTRAINT_MODEL = OpenEHR::AM::Archetype::ConstraintModel

  def constrain_action_archetype_id(template, pattern)
    activities(template.definition).each do |activity|
      item = CONSTRAINT_MODEL::Primitive::CString.new(pattern: pattern)
      object = CONSTRAINT_MODEL::CPrimitiveObject.new(rm_type_name: 'STRING', item: item, occurrences: once)
      activity.attributes << CONSTRAINT_MODEL::CSingleAttribute.new(rm_attribute_name: 'action_archetype_id',
                                                                    existence: once, children: [object])
    end
  end

  private

  def once
    OpenEHR::AssumedLibraryTypes::Interval.new(lower: 1, upper: 1)
  end

  def activities(node)
    return [] unless node.respond_to?(:attributes) && node.attributes

    own = node.respond_to?(:rm_type_name) && node.rm_type_name == 'ACTIVITY' ? [node] : []
    own + node.attributes.flat_map { |attribute| (attribute.children || []).flat_map { |child| activities(child) } }
  end
end
