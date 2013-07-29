require 'spec_helper'
require 'generators/openehr'

describe Openehr::Generators::ArchetypedBase do
  before (:each) do
    adl_file = File.expand_path '../../templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl', __FILE__
    @archetyped_base = Openehr::Generators::ArchetypedBase.new([adl_file])
  end

  context 'archtype path' do
    it 'archetype_path is app/archetypes' do
      @archetyped_base.archetype_path.should == 'app/archetypes'
    end
  end

  context 'data_tree' do
    it 'rm_attribute_name.should data' do
      @archetyped_base.data_tree.rm_attribute_name.should == 'data'
    end
  end

  context 'index data' do
    it 'includes value data' do
      @archetyped_base.index_data.should include 'at0004'
    end

    it 'includes at0005, too' do
      @archetyped_base.index_data.should include 'at0005'
    end

    it 'does not include at0006' do
      @archetyped_base.index_data.should_not include 'at0006'
    end
  end

  # context 'show data' do
  #   subject { @archetyped_base. }

  #   it { should have_key :protocol }
  # end

  context 'model name' do
    it 'is origined form archetype id' do
      expect(@archetyped_base.model_name).to eq 'open_ehr_ehr_observation_blood_pressure_v1'
    end
  end
end
