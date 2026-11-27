# frozen_string_literal: true

module OpenehrRails
  module Fhir
    # One composition in the RM graph that no scaffolded model owns (#101),
    # read as FHIR resources: values from its canonical JSON at each field's
    # path (the same walk Storable uses), built by ResourceBuilder.
    #
    # Resource id: "c<uuid hex>-<entry index>" (plan 3.2). FHIR ids allow
    # [A-Za-z0-9-.]{1,64}, so the composition uid ("<uuid>::<system>::<n>")
    # cannot be used as is; the version is left out (the latest is served).
    # A composition whose uid is not a UUID has no such id and is not served.
    class RuntimeRecord
      UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
      ID = /\Ac(\h{32})-(\d+)\z/

      def self.uuid_of(composition)
        object_id = composition.uid.to_s.split('::').first.to_s
        object_id.match?(UUID) ? object_id.downcase : nil
      end

      # [uuid, entry index] for a runtime resource id, or nil.
      def self.parse_id(id)
        match = ID.match(id.to_s)
        return nil unless match

        hex = match[1].downcase
        ["#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}", match[2].to_i]
      end

      def initialize(composition)
        @composition = composition
      end

      def resources(entries)
        uuid = self.class.uuid_of(@composition)
        return [] unless uuid

        canonical = @composition.to_canonical_hash.deep_stringify_keys
        entries.filter_map do |entry|
          read = read(canonical, entry)
          ResourceBuilder.new(entry, **read, id: "c#{uuid.delete('-')}-#{entry.index}",
                                             subject_ehr_id: @composition.ehr&.ehr_id,
                                             effective_at: @composition.context_start_time).build
        end
      end

      private

      # values, plus what the record itself says about them: DV_QUANTITY
      # units, and a coded value's text and terminology (#104).
      def read(canonical, entry)
        read = { values: {}, units: {}, displays: {}, terminologies: {} }
        entry.fields.each do |field|
          node = OpenehrRails::Storable.value_node(canonical, field)
          next if node.nil?

          name = field[:name]
          read[:values][name] = OpenehrRails::Storable.attribute_value(node, field)
          next unless node.is_a?(Hash)

          read[:units][name] = node['units'] if node['units']
          next unless node['defining_code']

          read[:displays][name] = node['value'] if node['value']
          terminology = node.dig('defining_code', 'terminology_id', 'value')
          read[:terminologies][name] = terminology if terminology
        end
        read
      end
    end
  end
end
