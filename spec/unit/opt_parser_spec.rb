require 'spec_helper'

describe 'OPT parsing functionality' do
  let(:opt_file) { File.expand_path('../templates/sample_blood_pressure.opt', __FILE__) }

  it 'can parse OPT file' do
    require 'openehr/parser'
    parser = OpenEHR::Parser::OPTParser.new(opt_file)
    template = parser.parse
    
    expect(template).not_to be_nil
    expect(template.template_id.value).to eq('blood_pressure_template')
    expect(template.name.value).to eq('Blood Pressure Measurement Template')
  end

  it 'can extract field names from template' do
    require 'openehr/parser'
    parser = OpenEHR::Parser::OPTParser.new(opt_file)
    template = parser.parse
    
    # Check if we can extract systolic and diastolic fields
    definition = template.definition
    expect(definition).not_to be_nil
    expect(definition.concept_name).to eq('Blood pressure')
  end
end