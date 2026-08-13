# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'ipaddr'
require 'resolv'
require 'openehr_rails/opt'

module OpenehrRails
  module Opt
    # Fetches an OPT file over HTTP(S) (used for URL arguments to the
    # scaffold/fhir_profile generators and the admin UI's URL-import field).
    # Validates that the response actually parses as an operational
    # template before handing it back, so callers never write garbage into
    # app/templates/operational.
    class RemoteFetcher
      class FetchError < StandardError; end

      MAX_REDIRECTS = 5
      MAX_BODY_BYTES = 10 * 1024 * 1024
      OPEN_TIMEOUT = 10
      READ_TIMEOUT = 20
      ALLOWED_SCHEMES = %w[http https].freeze

      # Loopback, private, and link-local ranges (the latter includes the
      # 169.254.169.254 cloud-metadata endpoint AWS/GCP/Azure all use).
      # Checked against every hop (initial URL and every redirect target,
      # since parse_uri runs on each via #get), not just the first.
      BLOCKED_IP_RANGES = [
        IPAddr.new('127.0.0.0/8'),
        IPAddr.new('10.0.0.0/8'),
        IPAddr.new('172.16.0.0/12'),
        IPAddr.new('192.168.0.0/16'),
        IPAddr.new('169.254.0.0/16'),
        IPAddr.new('::1/128'),
        IPAddr.new('fc00::/7'),
        IPAddr.new('fe80::/10')
      ].freeze

      def self.fetch(url)
        new(url).fetch
      end

      def initialize(url)
        @url = url
      end

      def fetch
        body = get(@url, MAX_REDIRECTS)
        validate_size!(body)
        validate_opt!(body)
        body
      end

      private

      def get(url, redirects_left)
        uri = parse_uri(url)
        response = request(uri)

        case response
        when Net::HTTPSuccess
          response.body.to_s
        when Net::HTTPRedirection
          follow_redirect(url, response, redirects_left)
        else
          raise FetchError, "failed to fetch #{url}: #{response.code} #{response.message}"
        end
      rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
        raise FetchError, "failed to fetch #{url}: #{e.class}: #{e.message}"
      end

      def parse_uri(url)
        uri = URI.parse(url)
        unless ALLOWED_SCHEMES.include?(uri.scheme)
          raise FetchError, "unsupported URL scheme: #{uri.scheme.inspect} (must be http/https)"
        end
        if blocked_host?(uri.host)
          raise FetchError, "refusing to fetch #{url}: host resolves to a private/internal/link-local address"
        end

        uri
      end

      # True if `host` (a literal IP, a bracketed IPv6 literal, or a
      # hostname to resolve) is, or resolves to, a loopback/private/
      # link-local address. Fails open on an unresolvable hostname --
      # Net::HTTP will then fail on its own DNS lookup, converted to a
      # FetchError by #get's rescue clause.
      def blocked_host?(host)
        literal = literal_ip(host)
        addresses = literal ? [literal] : Resolv.getaddresses(host).filter_map { |ip| literal_ip(ip) }
        addresses.any? { |address| BLOCKED_IP_RANGES.any? { |range| range.include?(address) } }
      end

      def literal_ip(host)
        IPAddr.new(host)
      rescue IPAddr::Error
        nil
      end

      def request(uri)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                            open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.get(uri.request_uri)
        end
      end

      def follow_redirect(url, response, redirects_left)
        raise FetchError, "too many redirects for #{@url}" if redirects_left <= 0

        location = response['location']
        raise FetchError, "redirect from #{url} had no Location header" unless location

        get(URI.join(url, location).to_s, redirects_left - 1)
      end

      def validate_size!(body)
        return if body.bytesize <= MAX_BODY_BYTES

        raise FetchError, "response from #{@url} is too large (> #{MAX_BODY_BYTES} bytes)"
      end

      def validate_opt!(body)
        template = OpenehrRails::Opt.parse(body)
        return unless template.template_id.value.to_s.empty?

        raise FetchError, "response from #{@url} is not a valid operational template (no template_id)"
      rescue FetchError
        raise
      rescue StandardError => e
        raise FetchError, "response from #{@url} is not a valid operational template: #{e.message}"
      end
    end
  end
end
