# frozen_string_literal: true

require 'spec_helper'
require 'openehr_rails'

# #94 (R-20261127-2): GET /query takes q and query_parameters from the URL
# and puts them into the console's inputs, without running the query.
describe OpenehrRails::QueryConsolePrefill do
  let(:limit) { described_class::MAX_LENGTH }

  it 'takes q and query_parameters when given as strings' do # enhancement
    prefill = described_class.new(q: 'SELECT e/ehr_id/value FROM EHR e', query_parameters: '{"min": 100}')

    expect([prefill.query, prefill.query_parameters]).to eq(['SELECT e/ehr_id/value FROM EHR e', '{"min": 100}'])
  end

  it 'falls back to the example query and empty parameters when nothing is given' do # regression pin
    prefill = described_class.new({})

    expect([prefill.query, prefill.query_parameters, prefill.notice]).to eq([described_class::EXAMPLE_QUERY, '', nil])
  end

  it 'ignores a non-string value (e.g. query_parameters[min]=1)' do # enhancement
    prefill = described_class.new(q: { 'a' => 'b' }, query_parameters: { 'min' => '1' })

    expect([prefill.query, prefill.query_parameters]).to eq([described_class::EXAMPLE_QUERY, ''])
  end

  it 'caps each value at MAX_LENGTH characters and says so' do # enhancement
    prefill = described_class.new(q: 'x' * (limit + 1), query_parameters: 'y' * (limit + 1))

    expect([prefill.query, prefill.query_parameters]).to eq([described_class::EXAMPLE_QUERY, ''])
    expect(prefill.notice).to include(limit.to_s)
  end

  it 'accepts a value of exactly MAX_LENGTH characters' do # enhancement
    expect(described_class.new(q: 'x' * limit).query.length).to eq(limit)
  end
end
