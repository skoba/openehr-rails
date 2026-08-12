# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'openehr_rails'

describe OpenehrRails::Opt::RemoteFetcher do
  let(:opt_body) do
    File.read(File.expand_path('../../generators/templates/bmi_calculation.opt', __dir__))
  end

  it 'fetches the body from a plain http(s) URL' do
    stub_request(:get, 'https://example.com/bmi_calculation.opt')
      .to_return(status: 200, body: opt_body)

    expect(described_class.fetch('https://example.com/bmi_calculation.opt')).to eq(opt_body)
  end

  it 'follows redirects' do
    stub_request(:get, 'https://example.com/old.opt')
      .to_return(status: 302, headers: { 'Location' => 'https://example.com/new.opt' })
    stub_request(:get, 'https://example.com/new.opt')
      .to_return(status: 200, body: opt_body)

    expect(described_class.fetch('https://example.com/old.opt')).to eq(opt_body)
  end

  it 'gives up after too many redirects' do
    6.times do |n|
      stub_request(:get, "https://example.com/hop#{n}")
        .to_return(status: 302, headers: { 'Location' => "https://example.com/hop#{n + 1}" })
    end

    expect { described_class.fetch('https://example.com/hop0') }
      .to raise_error(described_class::FetchError, /too many redirects/)
  end

  it 'raises FetchError on a non-2xx response' do
    stub_request(:get, 'https://example.com/missing.opt').to_return(status: 404)

    expect { described_class.fetch('https://example.com/missing.opt') }
      .to raise_error(described_class::FetchError, /404/)
  end

  it 'raises FetchError when the response is not parseable as an OPT' do
    stub_request(:get, 'https://example.com/not-xml.opt').to_return(status: 200, body: '{"not":"xml"}')

    expect { described_class.fetch('https://example.com/not-xml.opt') }
      .to raise_error(described_class::FetchError, /not a valid operational template/)
  end

  it 'raises FetchError on a response over the size limit' do
    stub_request(:get, 'https://example.com/huge.opt')
      .to_return(status: 200, body: 'x' * (described_class::MAX_BODY_BYTES + 1))

    expect { described_class.fetch('https://example.com/huge.opt') }
      .to raise_error(described_class::FetchError, /too large/)
  end

  it 'raises FetchError for an unsupported URL scheme' do
    expect { described_class.fetch('ftp://example.com/x.opt') }
      .to raise_error(described_class::FetchError, /scheme/)
  end

  it 'raises FetchError on a connection timeout' do
    stub_request(:get, 'https://example.com/slow.opt').to_timeout

    expect { described_class.fetch('https://example.com/slow.opt') }
      .to raise_error(described_class::FetchError)
  end
end
