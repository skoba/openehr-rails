# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

describe OpenehrRails::Rm::DataValue do
  let(:composition) do
    OpenehrRails::Rm::Composition.create!(uid: 'uid-1', archetype_node_id: 'arch')
  end
  let(:element) do
    OpenehrRails::Rm::Element.create!(
      composition: composition, rm_attribute_name: 'items', path: '/x/items[at0004]'
    )
  end

  def build_dv(klass, attrs)
    klass.create!(
      { node: element, composition: composition, path: "#{element.path}/value" }.merge(attrs)
    )
  end

  it 'round-trips STI through DV type names' do
    dv = build_dv(OpenehrRails::Rm::DvQuantity, magnitude: 170.0, units: 'cm')
    expect(dv.rm_type).to eq('DV_QUANTITY')
    expect(OpenehrRails::Rm::DataValue.find(dv.id)).to be_a(OpenehrRails::Rm::DvQuantity)
  end

  describe '#value' do
    it 'reads the typed column per DV class' do
      expect(build_dv(OpenehrRails::Rm::DvQuantity, magnitude: 1.5, units: 'kg').value).to eq(1.5)
      expect(build_dv(OpenehrRails::Rm::DvText, text_value: 'hello').value).to eq('hello')
      expect(build_dv(OpenehrRails::Rm::DvCodedText,
                      text_value: 'Sitting', code_string: 'at1001').value).to eq('Sitting')
      expect(build_dv(OpenehrRails::Rm::DvCount, integer_value: 3).value).to eq(3)
      expect(build_dv(OpenehrRails::Rm::DvBoolean, boolean_value: false).value).to be(false)
    end
  end

  describe '#to_canonical_hash' do
    it 'emits the Storable-compatible shape for DV_QUANTITY' do
      dv = build_dv(OpenehrRails::Rm::DvQuantity, magnitude: 170.0, units: 'cm')
      expect(dv.to_canonical_hash).to eq(
        '_type' => 'DV_QUANTITY', 'magnitude' => 170.0, 'units' => 'cm'
      )
    end

    it 'emits defining_code for DV_CODED_TEXT' do
      dv = build_dv(OpenehrRails::Rm::DvCodedText,
                    text_value: 'Sitting', code_string: 'at1001', terminology_id: 'local')
      expect(dv.to_canonical_hash).to eq(
        '_type' => 'DV_CODED_TEXT', 'value' => 'Sitting',
        'defining_code' => {
          '_type' => 'CODE_PHRASE',
          'terminology_id' => { 'value' => 'local' },
          'code_string' => 'at1001'
        }
      )
    end
  end

  describe '.matching' do
    before do
      build_dv(OpenehrRails::Rm::DvQuantity, magnitude: 170.0, units: 'cm')
      build_dv(OpenehrRails::Rm::DvText, text_value: 'note', path: '/x/items[at0005]/value')
      build_dv(OpenehrRails::Rm::DvCodedText, text_value: 'Sitting', code_string: 'at1001',
                                              path: '/x/items[at0006]/value')
    end

    it 'matches numerics against magnitude columns' do
      expect(OpenehrRails::Rm::DataValue.matching(170.0).count).to eq(1)
    end

    it 'matches strings against text and code columns' do
      expect(OpenehrRails::Rm::DataValue.matching('note').count).to eq(1)
      expect(OpenehrRails::Rm::DataValue.matching('at1001').count).to eq(1)
    end
  end

  it 'validates required typed columns per class' do
    expect(OpenehrRails::Rm::DvQuantity.new(node: element, composition: composition,
                                            path: '/p')).not_to be_valid
    expect(OpenehrRails::Rm::DvText.new(node: element, composition: composition,
                                        path: '/p')).not_to be_valid
  end
end
