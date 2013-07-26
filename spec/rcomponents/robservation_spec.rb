require 'spec_helper'
require 'rcomponents'

describe OpenEHR::RComponents::RObservation do
  before(:each) do
    @robservation =
      OpenEHR::RComponents::RObservation.new(node_id: double('node_id'),
                                             path: double('path'),
                                             rm_type_name: 'OBSERVATION',
                                             protocol: 'dummy protocol',
                                             state: 'dummy state')
  end

  it 'protocol is properly assigned' do
    @robservation.protocol.should eq 'dummy protocol'
  end

  it 'state is properly assigned' do
    @robservation.state.should eq 'dummy state'
  end
end
