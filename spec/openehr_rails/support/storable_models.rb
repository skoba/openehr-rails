# frozen_string_literal: true

# Throwaway models like the ones openehr:scaffold generates, backed by
# temporary tables with one string column per field.
module StorableModels
  def field_map_for(path_under_spec)
    template = OpenehrRails::Opt.parse(File.expand_path("../../#{path_under_spec}", __dir__))
    OpenehrRails::Opt::FieldExtractor.new(template).fields.index_by { |field| field[:name] }.freeze
  end

  def storable_model(table, field_map)
    ActiveRecord::Base.connection.create_table(table, force: true, temporary: true) do |t|
      field_map.each_key { |name| t.string name }
      t.json :rm_composition
      t.string :template_id
      t.string :uid
      t.datetime :composed_at
    end
    Class.new(ActiveRecord::Base) do # rubocop:disable Rails/ApplicationRecord
      self.table_name = table
      define_singleton_method(:name) { table.to_s.classify }
      const_set(:TEMPLATE_ID, table.to_s)
      const_set(:ROOT_ARCHETYPE_ID, 'openEHR-EHR-COMPOSITION.report.v1')
      const_set(:FIELD_MAP, field_map)
      include OpenehrRails::Storable
    end
  end

  # A deterministic value per field, for pinning whole compositions.
  def sample_value(field)
    case field[:rm_type]
    when 'DV_CODED_TEXT' then field[:code_list]&.first || 'code'
    when 'DV_ORDINAL', 'DV_SCALE' then (field[:value_code_map] || { 1 => nil }).keys.first.to_s
    when 'DV_QUANTITY', 'DV_COUNT', 'DV_PROPORTION' then '12.5'
    when 'DV_BOOLEAN' then 'true'
    when 'DV_DATE_TIME' then '2026-11-26T10:00:00+09:00'
    when 'DV_DATE' then '2026-11-26'
    else "#{field[:name]} value"
    end
  end
end
