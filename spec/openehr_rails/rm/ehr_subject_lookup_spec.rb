# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# #95 (R-20261127-2, R-20261127-6): GET /v1/ehr?subject_id=&subject_namespace=
# -- openEHR ITS-REST EHR API "Get EHR by subject id": 200 with the EHR, 404
# when none matches. Two outcomes are this implementation's own, because the
# specification does not cover them (R-20261127-6):
#   - several EHRs for one subject -> 409 with the matching ehr_ids; never
#     pick one silently (it could hand back another patient's record);
#   - a missing or blank parameter -> 400 with { "error": ... }.
describe OpenehrRails::Rm::EhrSubjectLookup do
  def ehr(ehr_id, subject_id, namespace, created: Time.utc(2026, 11, 1))
    OpenehrRails::Rm::Ehr.create!(ehr_id: ehr_id, subject_id: subject_id, subject_namespace: namespace,
                                  time_created: created)
  end

  def lookup(subject_id, namespace)
    described_class.new(subject_id: subject_id, subject_namespace: namespace).call
  end

  it 'finds the one EHR whose subject id and namespace both match (200)' do # enhancement
    ehr('e-1', 'p-1', 'hospital-a')
    ehr('e-2', 'p-1', 'hospital-b')
    ehr('e-3', 'p-2', 'hospital-a')

    result = lookup('p-1', 'hospital-a')

    expect([result.status, result.ehr&.ehr_id]).to eq([:ok, 'e-1'])
  end

  it 'reports not found when no EHR matches (404)' do # enhancement
    ehr('e-1', 'p-1', 'hospital-a')

    result = lookup('p-1', 'hospital-z')

    expect([result.status, result.ehr]).to eq([:not_found, nil])
    expect(result.error).to include('p-1', 'hospital-z')
  end

  # Not in the specification: this implementation's handling (R-20261127-6 answer 1).
  it 'reports a conflict with every matching ehr_id, oldest first, when several match (409)' do # enhancement
    ehr('e-new', 'p-1', 'hospital-a', created: Time.utc(2026, 11, 20))
    ehr('e-old', 'p-1', 'hospital-a', created: Time.utc(2026, 11, 2))

    result = lookup('p-1', 'hospital-a')

    expect([result.status, result.ehr, result.ehr_ids]).to eq([:conflict, nil, %w[e-old e-new]])
  end

  # Not in the specification: this implementation's handling (R-20261127-6 answer 2).
  [[nil, 'hospital-a'], ['p-1', nil], ['', 'hospital-a'], ['p-1', '  '], [{ 'x' => 'y' }, 'hospital-a']].each do |id, ns|
    it "rejects subject_id=#{id.inspect} subject_namespace=#{ns.inspect} as a bad request (400)" do # enhancement
      ehr('e-1', 'p-1', 'hospital-a')

      result = lookup(id, ns)

      expect([result.status, result.ehr]).to eq([:bad_request, nil])
      expect(result.error).to include('subject_id and subject_namespace are required')
    end
  end
end
