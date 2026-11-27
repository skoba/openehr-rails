# frozen_string_literal: true

module OpenehrRails
  # Values the AQL console (GET /query) starts with (#94). `q` and
  # `query_parameters` come from the URL so another page can link to the
  # console with a query filled in; the page never runs it on load. Only
  # strings up to MAX_LENGTH characters are taken. JSON validity of
  # query_parameters is left to the console's own check at run time.
  class QueryConsolePrefill
    MAX_LENGTH = 10_000

    EXAMPLE_QUERY = <<~AQL.chomp
      SELECT o/data[at0001]/events[at0002]/data[at0003]/items[at0004]/value/magnitude AS height
      FROM EHR e CONTAINS COMPOSITION c CONTAINS OBSERVATION o[openEHR-EHR-OBSERVATION.height.v2]
    AQL

    attr_reader :query, :query_parameters, :notice

    def initialize(params)
      params = params.to_h.transform_keys(&:to_s)
      @too_long = []
      @query = accept('q', params['q']) || EXAMPLE_QUERY
      @query_parameters = accept('query_parameters', params['query_parameters']) || ''
      @notice = ("#{@too_long.join(' and ')} not filled in: over #{MAX_LENGTH} characters" if @too_long.any?)
    end

    private

    def accept(name, value)
      return nil unless value.is_a?(String) && !value.empty?
      return value if value.length <= MAX_LENGTH

      @too_long << name
      nil
    end
  end
end
