# frozen_string_literal: true

module OpenehrRails
  module Rm
    # Raised when a canonical composition lacks an attribute the RM makes
    # mandatory and that openEHR-Rails will not make up (#121). The message
    # names each missing path; /v1 answers it with 422.
    class MissingRequiredAttributes < StandardError
      attr_reader :paths

      def initialize(paths)
        @paths = paths
        super("required attributes missing: #{paths.join(', ')}")
      end
    end

    # The commit-time check for #121 (plan
    # docs/design/121-122-structural-date-times-plan.md section 4.2,
    # R-20261128-6 answer 2): EVENT.time, HISTORY.origin, and, when a context
    # is given, its start_time and setting. Reads used to fill these in (the
    # clock, `other`); a commit without them is refused instead.
    class RequiredAttributes
      EVENT_TYPES = %w[POINT_EVENT INTERVAL_EVENT].freeze

      # +context_start_time+: the committer's keyword, which supplies the
      # context's start_time when the hash has none.
      def self.check!(canonical_hash, context_start_time: nil)
        missing = new(canonical_hash, context_start_time).missing
        raise MissingRequiredAttributes, missing if missing.any?
      end

      def initialize(canonical_hash, context_start_time)
        @hash = canonical_hash
        @context_start_time = context_start_time
      end

      def missing
        missing = context_missing
        Array(@hash['content']).each do |entry|
          walk(entry, nil, "/content[#{entry['archetype_node_id']}]", missing) if entry.is_a?(Hash)
        end
        missing
      end

      private

      def context_missing
        context = @hash['context']
        return [] unless context.is_a?(Hash)

        missing = []
        missing << '/context/start_time' unless value?(context['start_time']) || @context_start_time.present?
        missing << '/context/setting' if context.dig('setting', 'defining_code', 'code_string').blank?
        missing
      end

      def walk(node, attribute, path, missing)
        type = node_type(node, attribute)
        missing << "#{path}/origin" if type == 'HISTORY' && !value?(node['origin'])
        missing << "#{path}/time" if EVENT_TYPES.include?(type) && !value?(node['time'])
        node.each do |key, child|
          next if key == '_type'

          Array.wrap(child).each do |item|
            walk(item, key, "#{path}/#{key}#{"[#{item['archetype_node_id']}]" if item['archetype_node_id']}", missing) if
              structural?(item)
          end
        end
      end

      # Hashes below the entry that are nodes, not data values.
      def structural?(item)
        item.is_a?(Hash) && (item.key?('archetype_node_id') || item.key?('events'))
      end

      # GraphBuilder#infer_type's rule for hashes without a _type.
      def node_type(node, attribute)
        return node['_type'] if node['_type']
        return 'POINT_EVENT' if attribute == 'events'

        'HISTORY' if node.key?('events')
      end

      def value?(data_value)
        data_value.is_a?(Hash) && data_value['value'].present?
      end
    end
  end
end
