require 'spec_helper'
require 'generators/openehr'
require 'generator_helper'

module Openehr
  module Generators
    describe ArchetypedBase do
      before (:each) do
        @archetyped_base = Openehr::Generators::ArchetypedBase.new([archetype])
      end

      context 'archetype file' do
        it 'archetype file is adl_file' do
          adl_file = File.expand_path '../../templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl', __FILE__
          archetyped_base = Openehr::Generators::ArchetypedBase.new([adl_file])
          archetyped_base.send(:archetype_file).should == File.expand_path('../../templates/openEHR-EHR-OBSERVATION.blood_pressure.v1.adl', __FILE__)
        end
      end

      context 'archetype path' do
        it 'archetype_path is app/archetypes' do
          @archetyped_base.send(:archetype_path).should == 'app/archetypes'
        end
      end

      context 'model name' do
        it 'is origined form archetype id' do
          expect(@archetyped_base.send(:model_name)).to eq 'open_ehr_ehr_observation_blood_pressure_v1'
        end
      end

      context 'controller_name' do
        it 'is originated from archtype id' do
          expect(@archetyped_base.send(:controller_name)).to eq 'open_ehr_ehr_observation_blood_pressure_v1'      
        end
      end
    end    
  end
end
