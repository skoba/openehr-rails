# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Change-set audit record (openEHR CONTRIBUTION + AUDIT_DETAILS
    # flattened): who committed which kind of change, when.
    class Contribution < ActiveRecord::Base
      self.table_name = 'openehr_rm_contributions'

      CHANGE_TYPES = {
        'creation' => '249',
        'amendment' => '250',
        'modification' => '251',
        'deleted' => '523'
      }.freeze

      belongs_to :ehr, class_name: 'OpenehrRails::Rm::Ehr', optional: true
      has_many :versions, class_name: 'OpenehrRails::Rm::Version',
                          foreign_key: :contribution_id, inverse_of: :contribution,
                          dependent: nil

      validates :uid, presence: true
      validates :time_committed, presence: true
      validates :change_type_code, presence: true
      validates :change_type_value, inclusion: { in: CHANGE_TYPES.keys }

      def self.record!(change_type, ehr: nil, description: nil)
        create!(
          uid: SecureRandom.uuid,
          ehr: ehr,
          system_id: OpenehrRails.system_id,
          committer_name: OpenehrRails.default_composer_name,
          time_committed: Time.current,
          change_type_value: change_type,
          change_type_code: CHANGE_TYPES.fetch(change_type),
          description: description
        )
      end
    end
  end
end
