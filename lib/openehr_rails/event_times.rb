# frozen_string_literal: true

module OpenehrRails
  # Writes a scaffold record's save time into the HISTORY.origin and
  # EVENT.time of its composition (#121; plan
  # docs/design/121-122-structural-date-times-plan.md section 4.1). The
  # scaffolded form has no input for the event time, so the record's own
  # `composed_at` -- a value the record holds -- is what it records; reads no
  # longer fill these in from the clock. A time already present is kept.
  # Written in UTC, as the context's start_time reads back from the same
  # composed_at (GraphPersister passes it as a Time).
  module EventTimes
    module_function

    def stamp!(content, time)
      value = time.respond_to?(:getutc) ? time.getutc.iso8601 : time.to_s
      Array(content).each { |node| walk(node, nil, value) }
      content
    end

    def walk(node, attribute, value)
      return unless node.is_a?(Hash)

      stamp_node(node, attribute, value)
      node.each { |key, child| Array.wrap(child).each { |item| walk(item, key, value) } unless key == 'value' }
    end

    def stamp_node(node, attribute, value)
      if node['_type'] == 'HISTORY'
        node['origin'] ||= { '_type' => 'DV_DATE_TIME', 'value' => value }
      elsif attribute == 'events'
        node['time'] ||= { '_type' => 'DV_DATE_TIME', 'value' => value }
      end
    end
  end
end
