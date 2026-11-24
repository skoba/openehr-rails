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

  describe 'a model whose template embeds an archetype root (lab_result_report_reduced)' do
    let(:field_map) { field_map_for('../templates/lab_result_report_reduced.opt') }
    let(:model) { storable_model(:guard_lab_results, field_map) }
    let(:embedded_name) { field_map.find { |_name, field| field[:node_id] == 'at0024' }.first }
    let(:own_name) { field_map.find { |_name, field| field[:archetype_id].include?('OBSERVATION') }.first }

    # bug: red before #60 (saved a second, bogus OBSERVATION entry).
    it 'refuses to save a value under the embedded root, naming the shape and the field' do
      record = model.new(embedded_name => 'Na')

      expect { record.save! }.to raise_error(
        OpenehrRails::Storable::UnsupportedTemplateShape,
        %r{embedded archetype root.*#{embedded_name}.*skoba/openehr-rails#61}m
      )
    end

    # bug: red before #60.
    it 'persists nothing when it refuses' do
      record = model.new(embedded_name => 'Na')

      compositions_before = OpenehrRails::Rm::Composition.count

      expect { record.save }.to raise_error(OpenehrRails::Storable::UnsupportedTemplateShape)
      expect(model.count).to eq(0)
      expect(OpenehrRails::Rm::Composition.count).to eq(compositions_before)
    end

    # regression pin: values owned by the entry itself still save.
    it 'still saves a record that only fills entry-owned fields' do
      record = model.create!(own_name => 'final')

      expect(record.rm_composition['content'].size).to eq(1)
    end
  end

  describe 'a model whose entries are nested in a SECTION (jp_referral)' do
    let(:model) { storable_model(:guard_jp_referrals, field_map_for('../templates/jp_referral.opt')) }

    # bug: red before #60 (saved an entry with an untyped items level, no SECTION).
    it 'refuses to save, naming the SECTION shape and the field' do
      record = model.new('story' => '現病歴')

      expect { record.save! }.to raise_error(
        OpenehrRails::Storable::UnsupportedTemplateShape, %r{nested in a SECTION.*story.*skoba/openehr-rails#62}m
      )
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

    # bug: red before #60 (no such method).
    it 'reports an INSTRUCTION field' do
      expect(described_class.unsupported_shape(field({}))).to eq(:instruction)
    end

    it 'reports a field nested in a SECTION before anything else' do
      path = "/content[openEHR-EHR-SECTION.synthetic_guard_test.v1]/items#{entry_path.delete_prefix('/content')}/x[at1]/value"

      expect(described_class.unsupported_shape(field(path: path))).to eq(:section)
    end

    it 'reports a field whose archetype is not the entry, whatever form the root segment has' do
      observation = { entry_rm_type: 'OBSERVATION', archetype_id: 'openEHR-EHR-CLUSTER.synthetic_guard_test.v1' }
      old_form = '/content[openEHR-EHR-OBSERVATION.synthetic_guard_test.v1]/data[at0001]/items[at0000]/items[at0002]/value'
      new_form = old_form.sub('[at0000]', '[openEHR-EHR-CLUSTER.synthetic_guard_test.v1]')

      expect(described_class.unsupported_shape(field(observation.merge(path: old_form)))).to eq(:embedded_root)
      expect(described_class.unsupported_shape(field(observation.merge(path: new_form)))).to eq(:embedded_root)
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
