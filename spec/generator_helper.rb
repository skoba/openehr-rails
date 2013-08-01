def archetype
  @archetype ||= OpenEHR::Parser::ADLParser.new('spec/generators/templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl').parse
end
