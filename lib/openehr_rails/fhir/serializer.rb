# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # Serializes a stored record of a scaffolded Storable model (one openEHR
    # COMPOSITION) into one HL7 FHIR R5 Observation per archetype entry that
    # has data. The resource itself is built by ResourceBuilder (#101); this
    # class only reads the record's attributes.
    class Serializer
      ARCHETYPE_SYSTEM = ResourceRegistry::ARCHETYPE_SYSTEM
      UCUM_SYSTEM = ResourceBuilder::UCUM_SYSTEM

      def initialize(record)
        @record = record
      end

      def observations
        ResourceRegistry.entries_for(@record.class).filter_map do |entry|
          ResourceBuilder.new(entry, values: values(entry), units: units(entry), id: "#{@record.id}-#{entry.slug}",
                                     subject_ehr_id: subject_ehr_id, effective_at: @record.composed_at).build
        end
      end

      private

      def values(entry)
        entry.fields.to_h { |field| [field[:name], @record.public_send(field[:name])] }
      end

      def units(entry)
        entry.fields.each_with_object({}) do |field, units|
          attribute = "#{field[:name]}_units"
          units[field[:name]] = @record.public_send(attribute) if @record.respond_to?(attribute)
        end
      end

      def subject_ehr_id
        @record.ehr_id if @record.respond_to?(:ehr_id)
      end
    end
  end
end
