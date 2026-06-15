# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Root of a stored openEHR COMPOSITION graph. Composition metadata
    # (language, territory, category, composer, context) lives in explicit
    # columns; the structure is in rm_nodes / rm_data_values. Versioning is
    # immutable-append: rows are never mutated, superseded heads get
    # latest_version: false (see GraphPersister).
    class Composition < ActiveRecord::Base
      self.table_name = 'openehr_rm_compositions'

      belongs_to :ehr, class_name: 'OpenehrRails::Rm::Ehr', optional: true,
                       inverse_of: :compositions
      belongs_to :owner, polymorphic: true, optional: true

      has_many :nodes, class_name: 'OpenehrRails::Rm::Node',
                       foreign_key: :composition_id, inverse_of: :composition,
                       dependent: :delete_all
      has_many :data_values, class_name: 'OpenehrRails::Rm::DataValue',
                             foreign_key: :composition_id, inverse_of: :composition,
                             dependent: :delete_all
      has_many :content_nodes, -> { where(parent_id: nil, rm_attribute_name: 'content').order(:position) },
               class_name: 'OpenehrRails::Rm::Node', foreign_key: :composition_id,
               inverse_of: :composition
      has_one :version, class_name: 'OpenehrRails::Rm::Version',
                        foreign_key: :composition_id, inverse_of: :composition,
                        dependent: :destroy

      validates :uid, presence: true
      validates :archetype_node_id, presence: true

      scope :latest, -> { where(latest_version: true) }

      def to_canonical_hash
        CanonicalSerializer.new(self).call
      end

      def to_rm
        RmObjectBuilder.new(self).call
      end

      def purge_graph!
        DataValue.where(composition_id: id).delete_all
        Node.where(composition_id: id).delete_all
      end
    end
  end
end
