# frozen_string_literal: true

module OpenehrRails
  # Template management UI: lists registered templates, accepts drag &
  # drop OPT uploads and triggers runtime scaffolding ("Generate UI").
  class TemplatesController < ApplicationController
    before_action :require_runtime_scaffolding, only: %i[create generate]

    def index
      @templates = ::OpenehrTemplate.order(:template_id)
    end

    def create
      record = params[:url].present? ? TemplateImporter.call(url: params[:url]) : upload_template
      return unless record

      render json: { template_id: record.template_id, name: record.name }, status: :created
    rescue TemplateUploader::InvalidTemplate, TemplateImporter::InvalidTemplate, ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def generate
      template = ::OpenehrTemplate.find(params[:id])
      scaffolder = RuntimeScaffolder.new(template, root: ::Rails.root)

      if scaffolder.scaffolded?
        redirect_to root_path, notice: "UI already exists at /#{scaffolder.model_name.pluralize}"
      else
        result = scaffolder.call
        redirect_to root_path, notice: "Generated UI at /#{result.route_path}"
      end
    rescue StandardError => e
      log_openehr_error(e)
      redirect_to root_path, alert: "Generation failed: #{e.message}"
    end

    def destroy
      template = ::OpenehrTemplate.find(params[:id])
      remove_stored_opt(template)
      template.destroy
      redirect_to root_path,
                  notice: "Removed template #{template.template_id} (generated code is kept).",
                  status: :see_other
    end

    private

    def upload_template
      file = params[:file]
      unless file
        render json: { error: 'no file or url given' }, status: :unprocessable_entity
        return nil
      end

      TemplateUploader.call(file: file)
    end

    def require_runtime_scaffolding
      return if OpenehrRails.runtime_scaffolding_allowed?

      respond_to do |format|
        format.html { redirect_to root_path, alert: 'Runtime scaffolding is disabled in this environment.' }
        format.json { render json: { error: 'runtime scaffolding is disabled' }, status: :forbidden }
        format.any { head :forbidden }
      end
    end

    def remove_stored_opt(template)
      model_name = OpenehrRails::Naming.model_name(template.template_id)
      Dir.glob(::Rails.root.join(TemplateUploader::STORAGE_DIR, '*.opt')).each do |path|
        File.delete(path) if OpenehrRails::Naming.model_name(File.basename(path, '.opt')) == model_name
      end
    end
  end
end
