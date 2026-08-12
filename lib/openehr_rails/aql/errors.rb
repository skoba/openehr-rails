# frozen_string_literal: true

module OpenehrRails
  module Aql
    # Base class for all errors this namespace raises. Wraps the openehr
    # gem's own AQL errors (ParseError/SemanticError/ExecutionError/
    # DatasetError/UnboundParameterError) so callers (REST controller, admin
    # UI) only need to rescue one hierarchy.
    class Error < StandardError; end

    # The query text itself is malformed (parse error) or references
    # something semantically invalid.
    class InvalidQuery < Error; end

    # The query parses but uses a construct the engine cannot execute yet
    # (see OpenehrRails::Aql::QueryValidator for the specific list).
    class UnsupportedFeature < Error; end
  end
end
