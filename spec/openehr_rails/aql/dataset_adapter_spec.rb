# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

describe OpenehrRails::Aql::DatasetAdapter do
  it 'yields one EHR record per Rm::Ehr, with Pathable compositions' do
    record = BmiCalculation.create!(height: 170.0, ehr_id: 'ehr-1') # materializes Rm::Ehr(ehr_id: 'ehr-1')

    dataset = described_class.build

    records = dataset.each_ehr.to_a
    matching = records.find { |r| r.ehr_id == 'ehr-1' }

    expect(matching).not_to be_nil
    expect(matching.compositions.map { |c| c.uid.value }).to include(record.rm_graph.uid)
    expect(matching.compositions).to all(be_a(OpenEHR::RM::Common::Archetyped::Pathable))
  end

  it 'groups EHR-less compositions (ehr_id nil) under a single nil-ehr_id record' do
    BmiCalculation.create!(height: 158.0) # no ehr_id

    dataset = described_class.build
    records = dataset.each_ehr.to_a
    unlinked = records.find { |r| r.ehr_id.nil? }

    expect(unlinked).not_to be_nil
    expect(unlinked.compositions).not_to be_empty
  end

  it 'only includes head (latest_version) compositions' do
    record = BmiCalculation.create!(height: 170.0, ehr_id: 'ehr-2')
    record.update!(height: 168.0) # appends a new graph version; same uid, old head becomes latest_version: false
    expect(OpenehrRails::Rm::Composition.where(owner_type: 'BmiCalculation', owner_id: record.id).count)
      .to eq(2) # sanity: both graph versions persisted

    dataset = described_class.build
    matching = dataset.each_ehr.find { |r| r.ehr_id == 'ehr-2' }

    expect(matching.compositions.size).to eq(1)
    expect(matching.compositions.first.uid.value).to eq(record.rm_graph.uid)
  end

  it 'is lazy: building the dataset does not query the database' do
    query_count = 0
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') { query_count += 1 }

    described_class.build

    expect(query_count).to eq(0)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
