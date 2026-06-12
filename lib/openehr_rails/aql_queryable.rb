# frozen_string_literal: true

require 'active_support/concern'

module OpenehrRails
  # Minimal AQL-style querying for scaffolded models: resolves an openEHR
  # RM path to the backing column through FIELD_MAP. Full AQL parsing is
  # planned to build on this same path-to-column resolution.
  module AqlQueryable
    extend ActiveSupport::Concern

    class_methods do
      def find_by_path(path, value)
        name = column_for_path(path)
        raise ArgumentError, "no field maps to path #{path}" unless name

        where(name => value)
      end

      def column_for_path(path)
        name, = const_get(:FIELD_MAP).find { |_name, field| field[:path] == path }
        name
      end
    end
  end
end
