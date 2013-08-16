require 'spec_helper'
require 'generators/openehr/model/model_generator'
require 'generator_helper'

module Openehr
  module Generators
    describe ModelGenerator do
      destination File.expand_path('../../../../../tmp', __FILE__)

      before(:each) do
        prepare_destination
        run_generator [archetype]
      end

      context 'rm.rb generation' do
        subject { file('app/models/rm.rb') }

        it { should exist }
        it { should contain 'class Rm < ActiveRecord::Base' }
        it { should contain 'belongs_to :archetype' }
      end

      context 'archetype.rb generation' do
        subject { file('app/models/archetype.rb') }

        it { should exist }
        it { should contain 'class Archetype < ActiveRecord::Base' }
        it { should contain 'has_many :rms, dependent: :destroy' }
      end

      context 'interim model generation' do
        subject { file('app/models/open_ehr_ehr_observation_blood_pressure_v1.rb') }

        it { should exist }
        it { should contain 'class OpenEhrEhrObservationBloodPressureV1' }
        it { should contain 'OpenEhrEhrObservationBloodPressureV1.new(archetype: archetype, uid)' }
        it { should contain  'OpenEhrEhrObservationBloodPressureV1.new(archetype: Archetype.find(id))' }
        it { should contain "def self.build(params)\n    OpenEhrEhrObservationBloodPressureV1.new(params)"}
        it { should contain 'archetype.rms.inject(archetype.save, :&) {|rm| rm.save' }
        it { should contain "def update(attributes)\n    self.attributes=attributes" }
        it { should contain "@archetype ||= Archetype.new(archetypeid: 'openEHR-EHR-OBSERVATION.blood_pressure.v1', uid: SecureRandom.uuid)" }
        it { should contain /def at0004$/ }
        it { should contain /at0004model.num_value$/}
        it { should contain 'def at0004=(at0004)' }
        it { should contain 'at0004model.num_value = at0004'}
        it { should contain 'translate(at0008model.text_value)'}
        it { should contain 'def confat(node_id, path)'}
        it { should contain 'I18n.translate("open_ehr_ehr_observation_blood_pressure_v1.index.#{term}")'}
        it { should contain "def persisted?\n    archetype.persisted?"}
      end
    end
  end
end
