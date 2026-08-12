# frozen_string_literal: true

module OpenehrRails
  # Patient timeline (HTML admin UI): a cross-template view of everything
  # recorded against one EHR, independent of which scaffolded model owns
  # each composition. Distinct from OpenehrApi::EhrsController, which is
  # the JSON openEHR REST API resource.
  EhrSummary = Struct.new(:ehr, :composition_count, :last_activity_at)

  class EhrsController < ApplicationController
    def index
      @summaries = ::OpenehrRails::Rm::Ehr.order(created_at: :desc).map do |ehr|
        compositions = ::OpenehrRails::Rm::Composition.latest.where(ehr: ehr)
        EhrSummary.new(ehr, compositions.count, compositions.maximum(:context_start_time))
      end
    end

    def show
      @ehr = ::OpenehrRails::Rm::Ehr.find_by!(ehr_id: params[:id])

      scope = ::OpenehrRails::Rm::Composition.latest.where(ehr: @ehr)
      @template_ids = scope.distinct.order(:template_id).pluck(:template_id).compact
      scope = scope.where(template_id: params[:template_id]) if params[:template_id].present?

      @compositions = scope.to_a.sort_by { |c| c.context_start_time || c.created_at }.reverse
      @days = @compositions.group_by { |c| (c.context_start_time || c.created_at).to_date }
    end
  end
end
