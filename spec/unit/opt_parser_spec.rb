require 'spec_helper'
require 'openehr_rails'

describe 'OPT parsing functionality' do
  let(:opt_file) do
    File.expand_path('../../generators/templates/bmi_calculation.opt', __FILE__)
  end

  it 'can parse OPT file' do
    template = OpenehrRails::Opt.parse(opt_file)

    expect(template).not_to be_nil
    expect(template.template_id.value).to eq('bmi_calculation')
    expect(template.concept).to eq('bmi_calculation')
  end

  it 'parses the definition into a constraint tree' do
    template = OpenehrRails::Opt.parse(opt_file)

    definition = template.definition
    expect(definition).not_to be_nil
    expect(definition.rm_type_name).to eq('COMPOSITION')
    expect(definition.archetype_id.value).to eq('openEHR-EHR-COMPOSITION.report-result.v1')
  end

  it 'parses templates without a uid element' do
    uidless = File.expand_path('../../templates/bmi_calculation_without_uid.opt', __FILE__)
    template = OpenehrRails::Opt.parse(uidless)

    expect(template.uid).to be_nil
    expect(template.template_id.value).to eq('bmi_calculation')
  end
end
