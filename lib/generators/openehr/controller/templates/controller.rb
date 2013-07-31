class <%= controller_class_name %>Controller < ApplicationController
  before_action :set_<%= controller_name %>, only: [:show, :edit, :update, :destroy]

  # GET /<%= controller_class_name %>
  # GET /<%= controller_class_name %>.json
  def index
    @<%= model_name %> = <%= model_class_name %>.all
  end

  # GET /<%= controller_name %>/1
  # GET /<%= controller_name %>/1.json
  def show
  end

  # GET /<%= controller_name %>/new
  def new
    @<%= model_name %> = <%= model_class_name %>.new
  end

  # GET /<%= controller_name %>/1/edit
  def edit
  end

  # POST /<%= controller_name %>
  # POST /<%= controller_name %>.json
  def create
    @<%= model_name %> = <%= model_class_name %>.new(<%= model_name %>_params)

    respond_to do |format|
      if <%= model_name %>.save
        format.html { redirect_to <%= model_name %>, notice: '<%= archetype_name %> was successfully created.' }
        format.json { render action: 'show', status: :created, location: @<%= controller_name %> }
      else
        format.html { render action: 'new' }
        format.json { render json: @<%= controller_name %>, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /<%= controller_name %>/1
  # PATCH/PUT /<%= controller_name %>/1.json
  def update
    respond_to do |format|
      if @<%= model_name %>.update(<%= model_name %>_params)
        format.html { redirect_to @open_ehr_ehr_observation_blood_pressure_v1, notice: '<%= archetype_name %> updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @<%= model_name %>.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /<%= controller_name %>/1
  # DELETE /<%= controller_name %>/1.json
  def destroy
    @<%= model_name %>.destroy
    respond_to do |format|
      format.html { redirect_to <%= controller_name %>_url }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_<%= controller_name %>
      @<%= model_name %> = <%= model_class_name %>.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def <%= model_name %>_params
      params[:<%= model_name %>]
    end
end
