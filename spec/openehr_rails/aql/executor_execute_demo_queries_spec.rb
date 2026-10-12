# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'
require_relative '../storable_spec_model'

# Regression pin (skoba/openehr-rails#45, ruling condition (b)): the four AQL
# queries the anlage demo runs (anlage docs/demo/aql-queries.md 1-4) must keep
# returning the same rows after RmObjectBuilder started rebuilding `protocol`,
# SECTION, INSTRUCTION and ACTIVITY. Resolution shape (c): these results were
# already true before #45 and red is not achievable -- this file pins them.
#
# Data: query 1 and 3 run on the BmiCalculation model (real bmi_calculation.opt
# graph). Queries 2 and 4 need a problem_diagnosis EVALUATION, for which this
# repo has no model, so a **synthetic** canonical hash is committed directly:
# hand-authored, but its archetype id and at-codes are the real ones from
# spec/templates/problem_list.opt (at0002 diagnosis, at0073 certainty with the
# local code at0076, at0003 date/time recognised) so the demo queries run
# verbatim. Design authority: docs/design/rm-object-builder-section-instruction-plan.md
# section 3.
describe OpenehrRails::Aql::Executor, '.execute' do
  # anlage demo AQL queries (regression pin) -- see the file comment above.
  let(:problem_diagnosis_hash) do
    {
      '_type' => 'COMPOSITION',
      'archetype_node_id' => 'openEHR-EHR-COMPOSITION.problem_list.v1',
      'archetype_details' => {
        '_type' => 'ARCHETYPED',
        'archetype_id' => { 'value' => 'openEHR-EHR-COMPOSITION.problem_list.v1' },
        'template_id' => { 'value' => 'problem_list' }, 'rm_version' => '1.0.4'
      },
      'name' => { '_type' => 'DV_TEXT', 'value' => 'Problem list' },
      'content' => [
        {
          '_type' => 'EVALUATION', 'archetype_node_id' => 'openEHR-EHR-EVALUATION.problem_diagnosis.v1',
          'archetype_details' => { 'archetype_id' => { 'value' => 'openEHR-EHR-EVALUATION.problem_diagnosis.v1' } },
          'name' => { '_type' => 'DV_TEXT', 'value' => 'Problem/Diagnosis' },
          'data' => {
            '_type' => 'ITEM_TREE', 'archetype_node_id' => 'at0001',
            'items' => [
              { '_type' => 'ELEMENT', 'archetype_node_id' => 'at0002',
                'value' => { '_type' => 'DV_TEXT', 'value' => 'Hypertension' } },
              { '_type' => 'ELEMENT', 'archetype_node_id' => 'at0073',
                'value' => { '_type' => 'DV_CODED_TEXT', 'value' => 'Confirmed',
                             'defining_code' => { 'terminology_id' => { 'value' => 'local' }, 'code_string' => 'at0076' } } },
              { '_type' => 'ELEMENT', 'archetype_node_id' => 'at0003',
                'value' => { '_type' => 'DV_DATE_TIME', 'value' => '2026-02-01T00:00:00' } }
            ]
          }
        }
      ]
    }
  end

  before do
    BmiCalculation.create!(height: 170.0)
    BmiCalculation.create!(height: 180.0)
    OpenehrRails::Rm::CompositionCommitter.commit(problem_diagnosis_hash, uid: 'uid-demo-problem')
  end

  it '1. height inequality (alias in SELECT, path in WHERE)' do
    query = 'SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height ' \
            'FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2] ' \
            'WHERE o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude > 170'

    expect(OpenehrRails::Aql.execute(query).rows).to eq([[180.0]])
  end

  it '2. MATCHES against a literal value list on the certainty label' do
    query = 'SELECT c/name/value AS composition_name, o/data[at0001]/items[at0073]/value/value AS certainty ' \
            'FROM EHR e CONTAINS COMPOSITION c CONTAINS EVALUATION o[openEHR-EHR-EVALUATION.problem_diagnosis.v1] ' \
            "WHERE o/data[at0001]/items[at0073]/value/value MATCHES {'Confirmed', 'Suspected'}"

    expect(OpenehrRails::Aql.execute(query).rows).to eq([['Problem list', 'Confirmed']])
  end

  it '3. CONTAINS nodePredicate with WHERE EXISTS' do
    query = 'SELECT c/name/value AS composition_name ' \
            'FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2] ' \
            'CONTAINS ELEMENT el[at0004] WHERE EXISTS el/value/magnitude'

    expect(OpenehrRails::Aql.execute(query).rows)
      .to eq([['openEHR-EHR-COMPOSITION.report-result.v1'], ['openEHR-EHR-COMPOSITION.report-result.v1']])
  end

  it '4. date range WHERE on an ELEMENT-held date/time' do
    query = 'SELECT o/data[at0001]/items[at0003]/value/value AS recognized_at ' \
            'FROM EHR e CONTAINS COMPOSITION c CONTAINS EVALUATION o[openEHR-EHR-EVALUATION.problem_diagnosis.v1] ' \
            'WHERE o/data[at0001]/items[at0003]/value/value >= "2026-01-01T00:00:00"'

    rows = OpenehrRails::Aql.execute(query).rows

    # Measured: the naive input is parsed in the process's local zone and
    # comes back as UTC (`2026-01-31T15:00:00Z` under JST) -- pinned as the
    # same instant, not as the literal string.
    expect(rows.size).to eq(1)
    expect(Time.iso8601(rows.first.first)).to eq(Time.parse('2026-02-01T00:00:00').utc)
  end
end
