# frozen_string_literal: true

require 'active_support/concern'

module OpenehrRails
  # Minimal AQL-style querying for scaffolded models: resolves an openEHR
  # RM path to the backing column through FIELD_MAP. Full AQL parsing is
  # planned to build on this same path-to-column resolution.
  module AqlQueryable
    extend ActiveSupport::Concern

    class_methods do
      # Resolves an RM path to records: FIELD_MAP-backed paths hit the
      # typed column directly; any other path is searched on the head
      # version of the persisted RM graph (when available).
      def find_by_path(path, value)
        name = column_for_path(path)
        return where(name => value) if name

        unless rm_graph_queryable?
          raise ArgumentError, "no field maps to path #{path}"
        end

        data_values = OpenehrRails::Rm::DataValue.at_path(path).matching(value)
        compositions = OpenehrRails::Rm::Composition.latest
                                                    .where(owner_type: base_class.name)
                                                    .where(id: data_values.select(:composition_id))
        where(id: compositions.select(:owner_id))
      end

      def column_for_path(path)
        name, = const_get(:FIELD_MAP).find { |_name, field| field[:path] == path }
        name
      end

      def rm_graph_queryable?
        defined?(OpenehrRails::Rm) && OpenehrRails::Rm.enabled?
      end
    end
  end
end
