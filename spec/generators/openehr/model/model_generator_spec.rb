require 'spec_helper'
require 'generators/openehr/model/model_generator'
require 'generator_helper'

module Openehr
  module Generators
    xdescribe ModelGenerator do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before(:each) do
        prepare_destination
        run_generator [archetype]
      end

      context 'rm.rb generation' do
        subject { file('app/models/rm.rb') }

        it { is_expected.to exist }
        it { is_expected.to contain 'class Rm < ActiveRecord::Base' }
        it { is_expected.to contain 'belongs_to :archetype' }
      end

      context 'archetype.rb generation' do
        subject { file('app/models/archetype.rb') }

        it { is_expected.to exist }
        it { is_expected.to contain 'class Archetype < ActiveRecord::Base' }
        it { is_expected.to contain 'has_many :rms, dependent: :destroy' }
      end

      context 'interim model generation' do
        subject { file('app/models/open_ehr_ehr_observation_blood_pressure_v1.rb') }

        it { is_expected.to exist }
        it { is_expected.to contain 'class OpenEhrEhrObservationBloodPressureV1' }
        it { is_expected.to contain 'OpenEhrEhrObservationBloodPressureV1.new(archetype: archetype)' }
        it { is_expected.to contain  'OpenEhrEhrObservationBloodPressureV1.new(archetype: Archetype.find(id))' }
        it { is_expected.to contain "def self.build(params)\n    OpenEhrEhrObservationBloodPressureV1.new(params)"}
        it { is_expected.to contain 'archetype.rms.inject(archetype.save, :&) {|rm| rm.save' }
        it { is_expected.to contain "def update(attributes)\n    self.attributes=attributes" }
        it { is_expected.to contain "@archetype ||= Archetype.new(archetypeid: 'openEHR-EHR-OBSERVATION.blood_pressure.v1', uid: SecureRandom.uuid)" }
        it { is_expected.to contain /def at0004$/ }
        it { is_expected.to contain /at0004model.num_value$/}
        it { is_expected.to contain 'def at0004=(at0004)' }
        it { is_expected.to contain 'at0004model.num_value = at0004'}
        it { is_expected.to contain 'at0004model.save'}
        it { is_expected.to contain 'translate(at0008model.text_value)'}
        it { is_expected.to contain 'def confat(node_id, path)'}
        it { is_expected.to contain 'archetype.rms.build(:node_id => node_id, :path => path)' }
        it { is_expected.to contain 'I18n.translate("open_ehr_ehr_observation_blood_pressure_v1.index.#{term}")'}
        it { is_expected.to contain "def persisted?\n    archetype.persisted?"}
      end
    end
  end
end
