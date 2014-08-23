require 'spec_helper'
require 'rcomponents'

describe OpenEHR::RComponents::RElement do
  before(:each) do
    @relement =
      OpenEHR::RComponents::RElement.new(:node_id => 'at0004', :path => '/data[at0004]', :rm_type_name => "ELEMENT")
  end

  it 'should be an instance of RElement' do
    expect(@relement).to be_an_instance_of OpenEHR::RComponents::RElement
  end

  it 'node_id is at0004' do
    expect(@relement.node_id).to eq 'at0004'
  end

  it 'path is /data[at0004]' do
    expect(@relement.path).to eq '/data[at0004]'
  end
end
