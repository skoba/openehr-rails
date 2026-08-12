# frozen_string_literal: true

require 'openehr/aql'

module OpenehrRails
  module Aql
    # Public entry point: validate -> build the Dataset from the RM graph ->
    # execute -> translate any engine error into OpenehrRails::Aql::Error.
    class Executor
      def self.execute(aql_string, params: {}, ehr_scope: OpenehrRails::Rm::Ehr.all,
                        composition_scope: OpenehrRails::Rm::Composition.latest)
        query = QueryValidator.validate!(aql_string)
        dataset = DatasetAdapter.build(ehr_scope: ehr_scope, composition_scope: composition_scope)

        begin
          query.execute(dataset, params: params)
        rescue OpenEHR::AQL::UnboundParameterError => e
          raise InvalidQuery, e.message
        rescue OpenEHR::AQL::DatasetError, OpenEHR::AQL::ExecutionError => e
          raise UnsupportedFeature, e.message
        end
      end
    end

    def self.execute(aql_string, params: {}, **scope_options)
      Executor.execute(aql_string, params: params, **scope_options)
    end
  end
end
