require 'spec_helper'
require 'openehr/rails/ckm_accessor'

describe OpenEHR::Rails::CKMAccessor do
  describe 'retrieve archetype ADL by ID' do
    before do
      @adl = OpenEHR::Rails::CKMAccessor.retrieve('openEHR-EHR-OBSERVATION.blood_pressure.v1') 
    end

    it 'is match archetype' do
      @adl.should match /archetype \(adl_version=1\.4\)/
    end
  end

  it 'raise exception when it could not retrieve archetype' do
    expect { OpenEHR::Rails::CKMAccessor.retrieve('invalid_id') }.to raise_error
  end
end
