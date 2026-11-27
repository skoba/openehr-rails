# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# #99 (R-20261127-8): creating an EHR -- POST /v1/ehr (server-generated
# ehr_id) and PUT /v1/ehr/:ehr_id (client-supplied ehr_id).
#
# - POST: openEHR ITS-REST EHR API "Create EHR" answers 409 when an EHR with
#   the same subject id, namespace pair already exists. Before #99 a second
#   EHR was created (201): a bug.
# - PUT: the specification's 409 covers only an ehr_id already in use. Also
#   refusing a second EHR for the subject is this implementation's own
#   handling (R-20261127-8 answer 1), so that the result does not depend on
#   which endpoint was used.
# - The 409 carries the existing ehr_ids, as #95's GET by subject does
#   (R-20261127-8 answer 3).
# - No unique index backs this (R-20261127-8 answer 2): two concurrent
#   requests can still both pass the check.
describe OpenehrRails::Rm::EhrCreation do
  def existing(ehr_id, subject_id, namespace, created: Time.utc(2026, 11, 1))
    OpenehrRails::Rm::Ehr.create!(ehr_id: ehr_id, subject_id: subject_id, subject_namespace: namespace,
                                  time_created: created)
  end

  def create(ehr_id: nil, subject_id: nil, subject_namespace: nil)
    attributes = { subject_id: subject_id, subject_namespace: subject_namespace }.compact
    described_class.new(attributes, ehr_id: ehr_id).call
  end

  context 'with a server-generated ehr_id (POST)' do
    it 'creates the EHR when no EHR has the subject (201)' do # bug (control)
      result = create(subject_id: 'p-1', subject_namespace: 'hospital-a')

      expect(result.status).to eq(:created)
      expect(result.ehr).to be_persisted
      expect(result.ehr.subject_id).to eq('p-1')
    end

    it 'refuses a second EHR for the same subject id and namespace (409), creating nothing' do # bug
      existing('e-1', 'p-1', 'hospital-a')

      result = nil
      expect { result = create(subject_id: 'p-1', subject_namespace: 'hospital-a') }
        .not_to change(OpenehrRails::Rm::Ehr, :count)
      expect([result.status, result.ehr, result.ehr_ids]).to eq([:conflict, nil, ['e-1']])
      expect(result.error).to include('p-1', 'hospital-a')
    end

    it 'lists every existing ehr_id for the subject, oldest first (409)' do # bug
      existing('e-new', 'p-1', 'hospital-a', created: Time.utc(2026, 11, 20))
      existing('e-old', 'p-1', 'hospital-a', created: Time.utc(2026, 11, 2))

      expect(create(subject_id: 'p-1', subject_namespace: 'hospital-a').ehr_ids).to eq(%w[e-old e-new])
    end

    it 'creates an EHR for the same subject id in another namespace (201)' do # regression pin
      existing('e-1', 'p-1', 'hospital-a')

      expect(create(subject_id: 'p-1', subject_namespace: 'hospital-b').status).to eq(:created)
    end

    # Anonymous subjects (no id/namespace pair) are not compared: the
    # specification's conflict is about the pair.
    [{}, { subject_id: 'p-1' }, { subject_namespace: 'hospital-a' }].each do |subject|
      it "creates an EHR again and again without a full subject pair #{subject.inspect} (201)" do # regression pin
        existing('e-1', subject[:subject_id], subject[:subject_namespace])

        expect(create(**subject).status).to eq(:created)
        expect(create(**subject).status).to eq(:created)
      end
    end
  end

  context 'with a client-supplied ehr_id (PUT)' do
    it 'creates the EHR under the given ehr_id (201)' do # regression pin
      result = create(ehr_id: 'ehr-x', subject_id: 'p-1', subject_namespace: 'hospital-a')

      expect([result.status, result.ehr.ehr_id]).to eq([:created, 'ehr-x'])
    end

    it 'refuses an ehr_id already in use (409), as before' do # regression pin
      existing('ehr-x', 'p-9', 'hospital-z')

      result = create(ehr_id: 'ehr-x', subject_id: 'p-1', subject_namespace: 'hospital-a')

      expect([result.status, result.ehr, result.ehr_ids]).to eq([:conflict, nil, []])
      expect(result.error).to eq('EHR ehr-x already exists')
    end

    # Not in the specification: this implementation's handling (R-20261127-8 answer 1).
    it 'refuses a second EHR for the same subject under a new ehr_id (409)' do # enhancement
      existing('e-1', 'p-1', 'hospital-a')

      result = nil
      expect { result = create(ehr_id: 'ehr-x', subject_id: 'p-1', subject_namespace: 'hospital-a') }
        .not_to change(OpenehrRails::Rm::Ehr, :count)
      expect([result.status, result.ehr_ids]).to eq([:conflict, ['e-1']])
    end
  end
end
