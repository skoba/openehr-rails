# frozen_string_literal: true

require 'spec_helper'
require 'openehr'
require 'openehr/aql'
require 'openehr_rails'

describe OpenehrRails::Aql::QueryValidator do
  def validate(query)
    described_class.validate!(query)
  end

  describe 'accepted queries (happy paths)' do
    it 'accepts a plain SELECT/FROM/WHERE/ORDER BY query' do
      query = 'SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height ' \
              'FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2] ' \
              'WHERE o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude > 100 ' \
              'ORDER BY height'
      expect(validate(query)).to be_a(OpenEHR::AQL::Model::Query)
    end

    it 'accepts aggregate-only SELECT columns' do
      query = 'SELECT COUNT(o) FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]'
      expect(validate(query)).to be_a(OpenEHR::AQL::Model::Query)
    end

    it 'accepts an archetype predicate on CONTAINS' do
      query = 'SELECT c FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]'
      expect(validate(query)).to be_a(OpenEHR::AQL::Model::Query)
    end
  end

  describe 'rejected queries (parse-time)' do
    it 'wraps a ParseError as InvalidQuery' do
      expect { validate('SELECT FROM') }.to raise_error(OpenehrRails::Aql::InvalidQuery)
    end
  end

  describe 'rejected queries (unsupported constructs)' do
    it 'rejects LIKE in WHERE' do
      query = "SELECT c FROM EHR e CONTAINS COMPOSITION c WHERE c/archetype_node_id LIKE 'foo%'"
      expect { validate(query) }.to raise_error(OpenehrRails::Aql::UnsupportedFeature, /LIKE/)
    end

    it 'rejects MATCHES in WHERE' do
      query = "SELECT c FROM EHR e CONTAINS COMPOSITION c WHERE c/archetype_node_id MATCHES {'a', 'b'}"
      expect { validate(query) }.to raise_error(OpenehrRails::Aql::UnsupportedFeature, /MATCHES/)
    end

    it 'rejects mixing aggregate and non-aggregate SELECT columns' do
      query = 'SELECT c/archetype_node_id, COUNT(c) ' \
              'FROM EHR e CONTAINS COMPOSITION c'
      expect { validate(query) }.to raise_error(OpenehrRails::Aql::UnsupportedFeature, /aggregate/)
    end

    it 'rejects a nodePredicate inside CONTAINS' do
      query = 'SELECT c FROM EHR e CONTAINS COMPOSITION c CONTAINS ELEMENT e2[at0004]'
      expect { validate(query) }.to raise_error(OpenehrRails::Aql::UnsupportedFeature, /predicate/)
    end

    it 'rejects VERSIONED_COMPOSITION-based FROM classes' do
      query = 'SELECT v FROM EHR e CONTAINS VERSIONED_COMPOSITION v'
      expect { validate(query) }.to raise_error(OpenehrRails::Aql::UnsupportedFeature, /VERSIONED_COMPOSITION/)
    end

    # VERSION/LATEST_VERSION/ALL_VERSIONS are reserved lexer keywords in the
    # grammar itself and can't even parse as a class name -- they surface as
    # InvalidQuery (a ParseError), never reaching the UnsupportedFeature
    # check above. Still a caught, friendly error either way.
    it 'rejects VERSION/LATEST_VERSION/ALL_VERSIONS as a parse error' do
      %w[VERSION LATEST_VERSION ALL_VERSIONS].each do |keyword|
        query = "SELECT v FROM EHR e CONTAINS #{keyword} v"
        expect { validate(query) }.to raise_error(OpenehrRails::Aql::InvalidQuery)
      end
    end
  end
end
