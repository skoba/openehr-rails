# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'openehr_rails'
require 'tmpdir'

describe OpenehrRails::TemplateImporter do
  let(:opt_body) do
    File.read(File.expand_path('../generators/templates/bmi_calculation.opt', __dir__))
  end
  let(:url) { 'https://example.com/templates/bmi_calculation.opt' }

  around do |example|
    Dir.mktmpdir { |dir| @root = Pathname.new(dir); example.run }
  end

  it 'fetches the OPT, stores it under app/templates/operational and registers it' do
    stub_request(:get, url).to_return(status: 200, body: opt_body)

    record = described_class.call(url: url, root: @root)

    expect(@root.join('app/templates/operational/bmi_calculation.opt')).to exist
    expect(record.template_id).to eq('bmi_calculation')
    expect(record.template_type).to eq('operational_template')
    expect(OpenehrTemplate.where(template_id: 'bmi_calculation').count).to eq(1)
  end

  it 'is idempotent for the same template' do
    stub_request(:get, url).to_return(status: 200, body: opt_body)
    described_class.call(url: url, root: @root)

    expect { described_class.call(url: url, root: @root) }
      .not_to change(OpenehrTemplate, :count)
  end

  it 'raises InvalidTemplate when the URL cannot be fetched' do
    stub_request(:get, url).to_return(status: 404)

    expect { described_class.call(url: url, root: @root) }
      .to raise_error(described_class::InvalidTemplate, /404/)
  end

  it 'raises InvalidTemplate when the response is not a valid OPT' do
    stub_request(:get, url).to_return(status: 200, body: '<not-an-opt/>')

    expect { described_class.call(url: url, root: @root) }
      .to raise_error(described_class::InvalidTemplate)
  end
end
