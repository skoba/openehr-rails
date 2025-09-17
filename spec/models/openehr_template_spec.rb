require 'spec_helper'

describe 'OpenehrTemplate model' do
  let(:opt_file) { File.expand_path('../generators/templates/bmi_calculation.opt', __FILE__) }
  let(:adl_file) { File.expand_path('../generators/templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl', __FILE__) }

  describe 'validations' do
    it 'requires template_id' do
      template = OpenehrTemplate.new(name: 'Test', content: 'content', template_type: 'operational_template')
      expect(template).not_to be_valid
      expect(template.errors[:template_id]).to include("can't be blank")
    end

    it 'requires unique template_id' do
      OpenehrTemplate.create!(
        template_id: 'test_template',
        name: 'Test',
        content: 'content',
        template_type: 'operational_template'
      )
      
      duplicate = OpenehrTemplate.new(
        template_id: 'test_template',
        name: 'Test 2',
        content: 'content2',
        template_type: 'operational_template'
      )
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:template_id]).to include('has already been taken')
    end

    it 'requires valid template_type' do
      template = OpenehrTemplate.new(
        template_id: 'test',
        name: 'Test',
        content: 'content',
        template_type: 'invalid_type'
      )
      
      expect(template).not_to be_valid
      expect(template.errors[:template_type]).to include('is not included in the list')
    end
  end

  describe '.from_opt_file' do
    it 'creates template from OPT file' do
      template = OpenehrTemplate.from_opt_file(opt_file)
      
      expect(template).to be_persisted
      expect(template.template_id).to eq('bmi_calculation')
      expect(template.template_type).to eq('operational_template')
      expect(template.content).to include('<?xml')
    end
  end

  describe '.from_adl_file' do
    it 'creates template from ADL file' do
      template = OpenehrTemplate.from_adl_file(adl_file)
      
      expect(template).to be_persisted
      expect(template.template_id).to include('blood_pressure')
      expect(template.template_type).to eq('archetype_template')
      expect(template.content).to include('archetype')
    end
  end

  describe '#generate_model_name' do
    it 'generates model name from template_id' do
      template = OpenehrTemplate.new(template_id: 'openEHR-EHR-OBSERVATION.blood_pressure.v1')
      expect(template.generate_model_name).to eq('open_ehr_ehr_observation_blood_pressure_v1')
    end
  end

  describe '#form_fields' do
    it 'extracts form fields from OPT template' do
      template = OpenehrTemplate.from_opt_file(opt_file)
      fields = template.form_fields
      
      expect(fields).to be_an(Array)
      expect(fields).not_to be_empty
      expect(fields.first).to have_key(:node_id)
      expect(fields.first).to have_key(:name)
    end
  end

  describe 'scopes' do
    before do
      OpenehrTemplate.create!(
        template_id: 'opt_template',
        name: 'OPT Template',
        content: 'content',
        template_type: 'operational_template'
      )
      
      OpenehrTemplate.create!(
        template_id: 'adl_template',
        name: 'ADL Template',
        content: 'content',
        template_type: 'archetype_template'
      )
    end

    it 'filters operational templates' do
      expect(OpenehrTemplate.operational.count).to eq(1)
      expect(OpenehrTemplate.operational.first.template_id).to eq('opt_template')
    end

    it 'filters archetype templates' do
      expect(OpenehrTemplate.archetype_based.count).to eq(1)
      expect(OpenehrTemplate.archetype_based.first.template_id).to eq('adl_template')
    end
  end
end