# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative 'storable_spec_model'

# Issue #60: Storable refuses the template shapes it cannot assemble instead of
# writing a malformed composition (the fixes themselves are #61 / #62).
describe OpenehrRails::Storable do
  def field_map_for(relative_path)
    template = OpenehrRails::Opt.parse(File.expand_path(relative_path, __dir__))
    OpenehrRails::Opt::FieldExtractor.new(template).fields.index_by { |field| field[:name] }.freeze
  end

  # A throwaway model like the one openehr:scaffold generates, backed by a
  # temporary table with one string column per field.
  def storable_model(table, field_map)
    ActiveRecord::Base.connection.create_table(table, force: true, temporary: true) do |t|
      field_map.each_key { |name| t.string name }
      t.json :rm_composition
      t.string :template_id
      t.string :uid
      t.datetime :composed_at
    end
    Class.new(ActiveRecord::Base) do # rubocop:disable Rails/ApplicationRecord
      self.table_name = table
      define_singleton_method(:name) { table.to_s.classify }
      const_set(:TEMPLATE_ID, table.to_s)
      const_set(:ROOT_ARCHETYPE_ID, 'openEHR-EHR-COMPOSITION.report.v1')
      const_set(:FIELD_MAP, field_map)
      include OpenehrRails::Storable
    end
  end

  # The embedded-root guard of #60 is lifted by #61: those records now save
  # (spec/openehr_rails/storable_embedded_root_spec.rb). Only FIELD_MAPs that
  # cannot place the root are still refused (:embedded_root).

  describe 'a model whose entries are nested in a SECTION (jp_referral)' do
    let(:model) { storable_model(:guard_jp_referrals, field_map_for('../templates/jp_referral.opt')) }

    # enhancement (#62, #69): the SECTION and INSTRUCTION guards of #60 are
    # lifted (spec/openehr_rails/storable_section_spec.rb,
    # spec/openehr_rails/storable_instruction_spec.rb).
    it 'saves a value for the INSTRUCTION in the SECTION' do
      expect(model.create!('service_request_at0121' => '紹介').rm_composition['content'].sole['_type']).to eq('SECTION')
    end

    # regression pin: a record with no values builds an empty composition as before.
    it 'still saves a record with no values' do
      expect(model.create!.rm_composition['content']).to eq([])
    end
  end

  describe '.unsupported_shape' do
    # Hand-written field descriptions (invented ids), not from any template.
    let(:entry_path) { '/content[openEHR-EHR-INSTRUCTION.synthetic_guard_test.v1]' }

    def field(overrides)
      { archetype_id: 'openEHR-EHR-INSTRUCTION.synthetic_guard_test.v1', entry_rm_type: 'INSTRUCTION',
        path: "#{entry_path}/activities[at0001]/description[at0002]/items[at0003]/value" }.merge(overrides)
    end

    # enhancement (#69): an INSTRUCTION is no longer a shape of its own (#60 reported :instruction).
    it 'reports nothing for an INSTRUCTION field, in a SECTION or not' do
      path = "/content[openEHR-EHR-SECTION.synthetic_guard_test.v1]/items#{entry_path.delete_prefix('/content')}/x[at1]/value"

      expect(described_class.unsupported_shape(field({}))).to be_nil
      expect(described_class.unsupported_shape(field(path: path))).to be_nil
    end

    # enhancement (#61): only the pre-0.9.0 [at-code] root segment is still refused.
    it 'reports an embedded-root field only when its root segment is not [archetype_id]' do
      observation = { entry_rm_type: 'OBSERVATION', archetype_id: 'openEHR-EHR-CLUSTER.synthetic_guard_test.v1' }
      old_form = '/content[openEHR-EHR-OBSERVATION.synthetic_guard_test.v1]/data[at0001]/items[at0000]/items[at0002]/value'
      new_form = old_form.sub('[at0000]', '[openEHR-EHR-CLUSTER.synthetic_guard_test.v1]')

      expect(described_class.unsupported_shape(field(observation.merge(path: old_form)))).to eq(:embedded_root)
      expect(described_class.unsupported_shape(field(observation.merge(path: new_form)))).to be_nil
    end

    # enhancement (#61): without root_chain, a root that repeats cannot be placed.
    it 'reports an embedded-root field without root_chain when a root on its path repeats' do
      root = '/content[openEHR-EHR-OBSERVATION.synthetic_guard_test.v1]/data[at0001]/items[openEHR-EHR-CLUSTER.synthetic_guard_test.v1]'
      first = field(entry_rm_type: 'OBSERVATION', archetype_id: 'openEHR-EHR-CLUSTER.synthetic_guard_test.v1',
                    path: "#{root}/items[at0002]/value", instance_index: 0)
      second = first.merge(instance_index: 1)
      field_map = { 'first' => first, 'second' => second }

      expect(described_class.unsupported_shape(first, field_map)).to eq(:embedded_root)
      expect(described_class.unsupported_shape(first.merge(root_chain: [[root, 0]]), field_map)).to be_nil
    end

    # regression pin
    it 'reports nothing for the fields of bmi_calculation' do
      expect(BmiCalculation::FIELD_MAP.values.map { |f| described_class.unsupported_shape(f) }.uniq).to eq([nil])
    end
  end

  # regression pin: the supported shape is untouched.
  it 'saves a bmi_calculation record as before' do
    expect(BmiCalculation.create!(height: 170.0).rm_composition['content'].size).to eq(1)
  end
end
