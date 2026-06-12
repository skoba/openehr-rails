# frozen_string_literal: true

require 'openehr_rails'

# Mirrors the model that `rails g openehr:scaffold bmi_calculation.opt`
# generates; the backing table is defined in spec/support/active_record.rb.
class BmiCalculation < ActiveRecord::Base
  include OpenehrRails::Storable
  include OpenehrRails::AqlQueryable

  TEMPLATE_ID = 'bmi_calculation'
  ROOT_ARCHETYPE_ID = 'openEHR-EHR-COMPOSITION.report-result.v1'
  FIELD_MAP = OpenehrRails::Opt::FieldExtractor.new(
    OpenehrRails::Opt.parse(
      File.expand_path('../generators/templates/bmi_calculation.opt', __dir__)
    )
  ).fields.to_h { |field| [field[:name], field] }.freeze
end
