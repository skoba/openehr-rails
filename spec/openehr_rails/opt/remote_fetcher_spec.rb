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

  describe 'SSRF protection' do
    # No stub_request for any of these: a correctly-blocked URL must never
    # reach Net::HTTP at all (WebMock would raise its own "real requests
    # are not allowed" error if it did, which -- being a different error
    # class -- would also fail these expectations).
    [
      '127.0.0.1',        # loopback
      '169.254.169.254',  # link-local, incl. cloud metadata endpoints
      '10.1.2.3',         # private
      '172.16.0.5',       # private
      '192.168.1.1',      # private
      '[::1]' # IPv6 loopback
    ].each do |host|
      it "rejects a URL targeting the blocked address #{host}" do
        expect { described_class.fetch("http://#{host}/x.opt") }
          .to raise_error(described_class::FetchError, /internal|private|blocked/i)
      end
    end

    it 'rejects a redirect to a blocked address, not just the initial URL' do
      stub_request(:get, 'https://example.com/external.opt')
        .to_return(status: 302, headers: { 'Location' => 'http://127.0.0.1/internal.opt' })

      expect { described_class.fetch('https://example.com/external.opt') }
        .to raise_error(described_class::FetchError, /internal|private|blocked/i)
    end

    it 'still allows a normal public host' do
      stub_request(:get, 'https://example.com/bmi_calculation.opt')
        .to_return(status: 200, body: opt_body)

      expect(described_class.fetch('https://example.com/bmi_calculation.opt')).to eq(opt_body)
    end
  end
end
