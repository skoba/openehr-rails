require 'spec_helper'
require 'openehr/rails/ckm_accessor'

describe OpenEHR::Rails::CKMAccessor do
  before do
    @adl = OpenEHR::Rails::CKMAccessor.retrieve('openEHR-EHR-OBSERVATION.blood_pressure.v1') 
  end

  it 'is match archetype' do
    @adl.should match /archetype \(adl_version=1\.4\)/
  end 
end
