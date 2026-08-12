# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Serializes an Rm::Ehr row into canonical openEHR EHR / EHR_STATUS JSON
    # (openEHR REST API shape), the counterpart to CanonicalSerializer for
    # compositions.
    class EhrSerializer
      def initialize(ehr)
        @ehr = ehr
      end

      def call
        {
          '_type' => 'EHR',
          'system_id' => { '_type' => 'HIER_OBJECT_ID', 'value' => @ehr.system_id },
          'ehr_id' => { '_type' => 'HIER_OBJECT_ID', 'value' => @ehr.ehr_id },
          'time_created' => { '_type' => 'DV_DATE_TIME', 'value' => @ehr.time_created&.iso8601 },
          'ehr_status' => ehr_status
        }
      end

      def ehr_status
        {
          '_type' => 'EHR_STATUS',
          'archetype_node_id' => 'openEHR-EHR-EHR_STATUS.generic.v1',
          'name' => { '_type' => 'DV_TEXT', 'value' => 'EHR Status' },
          'subject' => {
            '_type' => 'PARTY_SELF',
            'external_ref' => subject_ref
          },
          'is_queryable' => @ehr.is_queryable,
          'is_modifiable' => @ehr.is_modifiable,
          'other_details' => @ehr.other_details
        }.compact
      end

      private

      def subject_ref
        return nil if @ehr.subject_id.blank?

        {
          '_type' => 'PARTY_REF',
          'id' => { '_type' => 'GENERIC_ID', 'value' => @ehr.subject_id, 'scheme' => 'id_scheme' },
          'namespace' => @ehr.subject_namespace,
          'type' => 'PERSON'
        }
      end
    end
  end
end
