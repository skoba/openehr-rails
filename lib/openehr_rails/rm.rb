# frozen_string_literal: true

# openEHR Reference Model persistence layer: ActiveRecord models that
# store compositions as a typed node graph (3 tables + STI) instead of an
# opaque JSON document. Required lazily — only when ActiveRecord is loaded
# (host apps via the engine, gem specs via spec/support/active_record.rb).
require 'openehr_rails/rm/type_map'
require 'openehr_rails/rm/ehr'
require 'openehr_rails/rm/composition'
require 'openehr_rails/rm/node'
require 'openehr_rails/rm/nodes'
require 'openehr_rails/rm/data_value'
require 'openehr_rails/rm/data_values'
require 'openehr_rails/rm/contribution'
require 'openehr_rails/rm/version'
require 'openehr_rails/rm/graph_builder'
require 'openehr_rails/rm/canonical_serializer'
require 'openehr_rails/rm/graph_persister'
require 'openehr_rails/rm/rm_object_builder'

module OpenehrRails
  module Rm
    # True when the host database has the RM tables (the install
    # migrations were run) and persistence is not explicitly disabled.
    def self.enabled?
      explicit = OpenehrRails.rm_persistence_enabled
      return explicit unless explicit.nil?

      tables_present?
    end

    def self.tables_present?
      return @tables_present unless @tables_present.nil?

      @tables_present = Composition.table_exists?
    rescue StandardError
      false
    end

    def self.reset_tables_cache!
      @tables_present = nil
    end
  end
end
