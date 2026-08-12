# frozen_string_literal: true

module OpenehrRails
  module OpenehrApi
    # openEHR REST API COMPOSITION resource
    # (base URL: <mount-point>/v1/ehr/:ehr_id/composition). Compositions
    # committed here are graph-only (no owning scaffolded record) via
    # OpenehrRails::Rm::CompositionCommitter -- the same versioning path
    # Storable uses on save, so a REST-created composition is a first-class
    # citizen of the RM graph (AQL-queryable, FHIR-exportable if mapped).
    class CompositionsController < ApplicationController
      class PreconditionFailed < StandardError; end

      skip_forgery_protection
      # rescue_from resolves multiple matches by most-recently-declared-wins,
      # so the generic StandardError catch-all must come first and the more
      # specific rescues after, or they'd never be reached.
      rescue_from StandardError, with: :render_error
      rescue_from ActiveRecord::RecordInvalid, with: :render_invalid
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from PreconditionFailed, with: :render_precondition_failed

      # POST /v1/ehr/:ehr_id/composition
      def create
        ehr = find_ehr!
        canonical = parsed_body
        uid = canonical.dig('uid', 'value').presence || SecureRandom.uuid
        canonical['uid'] = { '_type' => 'HIER_OBJECT_ID', 'value' => uid }

        composition = OpenehrRails::Rm::CompositionCommitter.commit(canonical, uid: uid, ehr: ehr)
        render_composition(composition, status: :created)
      end

      # GET /v1/ehr/:ehr_id/composition/:uid (versioned "uid::system::n" or bare uid; either resolves the head)
      def show
        find_ehr!
        composition = find_composition!
        render json: composition.to_canonical_hash
      end

      # PUT /v1/ehr/:ehr_id/composition/:uid  (requires If-Match: "<current object_version_id>")
      def update
        ehr = find_ehr!
        head_composition = find_composition!
        check_if_match!(head_composition)

        canonical = parsed_body
        canonical['uid'] = { '_type' => 'HIER_OBJECT_ID', 'value' => head_composition.uid }
        composition = OpenehrRails::Rm::CompositionCommitter.commit(canonical, uid: head_composition.uid, ehr: ehr)
        render_composition(composition)
      end

      # DELETE /v1/ehr/:ehr_id/composition/:uid  (logical delete: appends a LIFECYCLE_DELETED version)
      def destroy
        ehr = find_ehr!
        head_composition = find_composition!
        check_if_match!(head_composition) if request.headers['If-Match'].present?

        composition = OpenehrRails::Rm::CompositionCommitter.commit(head_composition.to_canonical_hash,
                                                                      uid: head_composition.uid, ehr: ehr)
        composition.version.update!(lifecycle_state_code: OpenehrRails::Rm::Version::LIFECYCLE_DELETED)
        head :no_content
      end

      private

      def find_ehr!
        OpenehrRails::Rm::Ehr.find_by!(ehr_id: params[:ehr_id])
      end

      # Accepts either a bare uid or a full "uid::system::version_tree_id"
      # object_version_id; both resolve to the current head graph row.
      def find_composition!
        object_uid = params[:uid].to_s.split('::').first
        OpenehrRails::Rm::Composition.latest.find_by!(uid: object_uid)
      end

      def check_if_match!(head_composition)
        expected = %("#{head_composition.version.object_version_id}")
        return if request.headers['If-Match'] == expected

        raise PreconditionFailed,
              "If-Match #{request.headers['If-Match'].inspect} does not match current version #{expected}"
      end

      def render_precondition_failed(error)
        render json: { error: error.message }, status: :precondition_failed
      end

      def render_composition(composition, status: :ok)
        version = composition.version
        response.headers['Location'] = composition_url(ehr_id: params[:ehr_id], uid: version.object_version_id)
        response.headers['ETag'] = %("#{version.object_version_id}")
        render json: composition.to_canonical_hash, status: status
      end

      def parsed_body
        @parsed_body ||= begin
          raw = request.body.read
          raw.blank? ? {} : JSON.parse(raw)
        end
      end

      def render_not_found(error)
        render json: { error: error.message }, status: :not_found
      end

      def render_invalid(error)
        render json: { error: error.message }, status: :unprocessable_entity
      end

      def render_error(error)
        render json: { error: error.message }, status: :bad_request
      end
    end
  end
end
