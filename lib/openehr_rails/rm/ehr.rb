# frozen_string_literal: true

module OpenehrRails
  module Rm
    # openEHR EHR object with EHR_STATUS inlined (subject, queryable and
    # modifiable flags). Materialized from the scaffolded records' ehr_id.
    class Ehr < ActiveRecord::Base
      self.table_name = 'openehr_ehrs'

      has_many :compositions, class_name: 'OpenehrRails::Rm::Composition',
                              foreign_key: :ehr_id, inverse_of: :ehr,
                              dependent: nil

      validates :ehr_id, presence: true, uniqueness: true

      before_validation { self.time_created ||= Time.current }
      before_validation { self.system_id ||= OpenehrRails.system_id }
    end
  end
end
