# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'
require_relative 'support/storable_models'

# #122 (plan docs/design/121-122-structural-date-times-plan.md section 5, option A;
# R-20261128-6 answer 5): a scaffolded model's date, datetime and time columns
# cannot hold every value openEHR allows. Active Record's cast turned `2026-11`
# into nil and `2026-11-05T09` into midnight, and `valid?` stayed true. Storable
# now refuses such a value with a validation error naming the field and the value.
describe OpenehrRails::Storable do
  include StorableModels

  let(:problem_fields) { field_map_for('templates/problem_list.opt') }
  let(:onset) { 'problem_diagnosis_at0077' }

  # Like StorableModels#storable_model, but with the column types openehr:scaffold
  # generates (FieldExtractor's column_type) instead of one string column per field.
  def typed_model(table, field_map)
    ActiveRecord::Base.connection.create_table(table, force: true, temporary: true) do |t|
      field_map.each { |name, field| t.column name, field[:column_type] || :string }
      t.json :rm_composition
      t.string :template_id
      t.string :uid
      t.datetime :composed_at
    end
    storable_class(table, field_map)
  end

  def storable_class(table, field_map)
    Class.new(ActiveRecord::Base) do # rubocop:disable Rails/ApplicationRecord
      self.table_name = table
      define_singleton_method(:name) { table.to_s.classify }
      const_set(:TEMPLATE_ID, table.to_s)
      const_set(:ROOT_ARCHETYPE_ID, 'openEHR-EHR-COMPOSITION.problem_list.v2')
      const_set(:FIELD_MAP, field_map)
      include OpenehrRails::Storable
    end
  end

  # The onset field, retyped: DV_DATE and DV_TIME have no fixture leaf of their own.
  def retyped(rm_type, column_type)
    { onset => problem_fields[onset].merge(rm_type: rm_type, column_type: column_type) }.freeze
  end

  def errors_for(model, value)
    record = model.new(onset => value)
    record.valid?
    record.errors[onset]
  end

  describe 'a datetime column (DV_DATE_TIME)' do
    let(:model) { typed_model(:partial_problems, problem_fields) }

    # bug: red before #122 (cast to nil, valid? true).
    it 'refuses a year or a year-month, naming the value' do
      expect(errors_for(model, '2026')).to contain_exactly(include('2026'))
      expect(errors_for(model, '2026-11')).to contain_exactly(include('2026-11'))
    end

    # bug: red before #122 (cast to midnight; the hour was lost).
    it 'refuses a value to the hour' do
      expect(errors_for(model, '2026-11-05T09')).to contain_exactly(include('2026-11-05T09'))
      expect(errors_for(model, '2026-11-05T09+09:00')).not_to be_empty
    end

    # regression pin: a date with no time still saves (as midnight). The plan
    # (section 5) does not list it; whether to refuse it is raised in the gate
    # report (docs/reports/0.14.x-log.md R6), not decided here.
    it 'accepts a date with no time, as before' do
      expect(errors_for(model, '2026-11-05')).to be_empty
    end

    # bug: red before #122 (cast to nil, so the value just disappeared).
    it 'refuses a value the column cannot read at all' do
      expect(errors_for(model, 'not a date')).not_to be_empty
    end

    # regression pin: values the column holds save as before.
    it 'accepts a value to the minute or second, with or without an offset, and a Time' do
      ['2026-11-05T09:30', '2026-11-05T09:30:15+09:00', '2026-11-05T00:30:15Z',
       Time.utc(2026, 11, 5, 0, 30)].each do |value|
        expect(errors_for(model, value)).to be_empty, value.inspect
      end
    end

    # regression pin: an empty field stays empty and valid.
    it 'accepts no value' do
      expect(errors_for(model, nil)).to be_empty
      expect(errors_for(model, '')).to be_empty
    end

    # regression pin: a full value still reaches the composition.
    it 'saves a full value into the composition' do
      record = model.create!(onset => '2026-11-05T09:30:00+09:00')

      expect(record.rm_composition.to_json).to include('2026-11-05T09:30:00+09:00')
    end

    # bug: red before #122 (create! succeeded and the value was gone).
    it 'makes create! raise instead of saving a record without the value' do
      expect { model.create!(onset => '2026-11') }.to raise_error(ActiveRecord::RecordInvalid, /2026-11/)
    end
  end

  describe 'a date column (DV_DATE)' do
    let(:model) { typed_model(:partial_dates, retyped('DV_DATE', :date)) }

    # bug: red before #122 (cast to nil, valid? true).
    it 'refuses a year or a year-month' do
      expect(errors_for(model, '2026')).not_to be_empty
      expect(errors_for(model, '2026-11')).not_to be_empty
    end

    # regression pin.
    it 'accepts a full date and a Date' do
      expect(errors_for(model, '2026-11-05')).to be_empty
      expect(errors_for(model, Date.new(2026, 11, 5))).to be_empty
    end
  end

  describe 'a time column (DV_TIME)' do
    let(:model) { typed_model(:partial_times, retyped('DV_TIME', :time)) }

    # bug: red before #122 (cast to 09:00:00; minutes and seconds were added).
    it 'refuses a value to the hour' do
      expect(errors_for(model, '09')).not_to be_empty
      expect(errors_for(model, '09+09:00')).not_to be_empty
    end

    # regression pin.
    it 'accepts a value to the minute or second, with or without an offset' do
      %w[09:30 09:30:15 09:30:15+09:00].each do |value|
        expect(errors_for(model, value)).to be_empty, value
      end
    end
  end

  # regression pin: a string column (a host's own choice, and these specs'
  # StorableModels) holds the value as written, so nothing is refused.
  it 'leaves a string column alone' do
    model = storable_model(:partial_strings, problem_fields)

    expect(errors_for(model, '2026-11')).to be_empty
  end
end
