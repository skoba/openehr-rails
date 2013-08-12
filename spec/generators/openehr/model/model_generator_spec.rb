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
        it { should contain /class Rm \< ActiveRecord::Base/ }
        it { should contain /belongs_to :archetype/}
      end

      context 'archetype.rb generation' do
        subject { file('app/models/archetype.rb') }

        it { should exist }
        it { should contain /class Archetype \< ActiveRecord::Base/ }
        it { should contain /has_many :rms/ }
      end
    end
  end
end
