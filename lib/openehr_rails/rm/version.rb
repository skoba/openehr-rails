# frozen_string_literal: true

module OpenehrRails
  module Rm
    # One version of a VERSIONED_COMPOSITION (immutable-append): points at
    # the immutable composition graph snapshot for that version.
    class Version < ActiveRecord::Base
      self.table_name = 'openehr_rm_versions'

      LIFECYCLE_COMPLETE = '532'
      LIFECYCLE_INCOMPLETE = '553'
      LIFECYCLE_DELETED = '523'

      belongs_to :composition, class_name: 'OpenehrRails::Rm::Composition',
                               inverse_of: :version
      belongs_to :contribution, class_name: 'OpenehrRails::Rm::Contribution',
                                optional: true, inverse_of: :versions

      validates :versioned_object_uid, presence: true
      validates :version_tree_id, presence: true,
                                  uniqueness: { scope: :versioned_object_uid }
      validates :lifecycle_state_code,
                inclusion: { in: [LIFECYCLE_COMPLETE, LIFECYCLE_INCOMPLETE, LIFECYCLE_DELETED] }

      before_validation { self.system_id ||= OpenehrRails.system_id }

      scope :of_object, ->(uid) { where(versioned_object_uid: uid).order(Arel.sql('CAST(version_tree_id AS INTEGER)')) }

      def object_version_id
        "#{versioned_object_uid}::#{system_id}::#{version_tree_id}"
      end
    end
  end
end
