# frozen_string_literal: true

module OpenehrRails
  # The part of Storable that refuses template shapes #rm_content cannot
  # assemble into a valid composition yet (skoba/openehr-rails#60).
  module Storable
    # Template shapes #rm_content cannot assemble into a valid composition yet.
    # Each maps to what the error says and the issue that tracks the real fix.
    UNSUPPORTED_SHAPES = {
      section: ['an entry nested in a SECTION', 'skoba/openehr-rails#62'],
      instruction: ['an INSTRUCTION entry (its narrative and ACTIVITY attributes have no source)',
                    'skoba/openehr-rails#69'],
      embedded_root: ['an embedded archetype root', 'skoba/openehr-rails#61']
    }.freeze

    # Raised on save when a record holds a value for a field whose template
    # shape Storable cannot assemble: a malformed composition is never written
    # (skoba/openehr-rails#60).
    class UnsupportedTemplateShape < StandardError
      attr_reader :shape, :field_names

      def initialize(model_name, shape, field_names)
        @shape = shape
        @field_names = field_names
        description, issue = UNSUPPORTED_SHAPES.fetch(shape)
        super(
          "#{model_name}: cannot build an RM composition for #{description} " \
          "(fields with a value: #{field_names.join(', ')}). OpenehrRails::Storable does not " \
          "support this template shape yet (#{issue}); nothing was saved."
        )
      end
    end

    # The UNSUPPORTED_SHAPES key a field description falls under, or nil.
    # Works on FIELD_MAPs generated before 0.9.0 too: an embedded root is
    # recognised by the field's archetype differing from its entry's, not by
    # how the root segment is written in the path.
    def self.unsupported_shape(field)
      _attribute, entry_id = path_segments(field[:path]).first
      return :section if entry_id.to_s.include?('-SECTION.')
      return :instruction if field[:entry_rm_type] == 'INSTRUCTION'

      :embedded_root if field[:archetype_id] && field[:archetype_id] != entry_id
    end

    # One generation-time warning per unsupported shape among +fields+
    # (Opt::FieldExtractor output), for openehr:scaffold.
    def self.shape_warnings(fields)
      fields.group_by { |field| unsupported_shape(field) }.except(nil).map do |shape, shape_fields|
        description, issue = UNSUPPORTED_SHAPES.fetch(shape)
        "Warning: #{shape_fields.size} field(s) belong to #{description}; the generated model " \
          "cannot save a value for them yet (#{issue}): #{shape_fields.pluck(:name).join(', ')}"
      end
    end

    private

    # Called by #rm_content before anything is assembled.
    def assert_supported_shapes!
      unsupported = self.class::FIELD_MAP.filter_map do |name, field|
        shape = OpenehrRails::Storable.unsupported_shape(field)
        [shape, name.to_s] if shape && !public_send(name).nil?
      end
      return if unsupported.empty?

      shape = unsupported.first.first
      names = unsupported.select { |candidate, _name| candidate == shape }.map(&:last)
      raise UnsupportedTemplateShape.new(self.class.name, shape, names)
    end
  end
end
