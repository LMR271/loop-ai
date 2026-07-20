class LoopsController < ApplicationController
  before_action :set_loop, only: %i[edit update destroy activate deactivate approve]
  before_action :ensure_editable!, only: %i[edit update]
  before_action :require_workspace_admin!, only: %i[destroy activate deactivate approve]

  def index
    @query = params[:q].to_s.strip
    @loops = current_organization.loops.includes(:feedbacks).order(created_at: :desc)
    @loops = @loops.search_by_name_and_description(@query) if @query.present?
  end

  def destroy
    @loop.destroy!
    redirect_to loops_path, notice: "Loop deleted."
  end

  def new
    @loop = current_organization.loops.build(user: current_user)
    @loop.questions.build
  end

  def create
    @loop = current_organization.loops.build(loop_params)
    @loop.assign_attributes(user: current_user, pending_approval: !current_user_workspace_admin?)

    if @loop.save
      redirect_to dashboard_path, notice: "Loop created."
    else
      ensure_question_field
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    ensure_question_field
  end

  def update
    @loop.pending_approval = !current_user_workspace_admin?

    if @loop.update(loop_params)
      redirect_to edit_loop_path(@loop), notice: "Loop updated."
    else
      ensure_question_field
      render :edit, status: :unprocessable_entity
    end
  end

  def approve
    @loop.update!(pending_approval: false)
    redirect_to edit_loop_path(@loop), notice: "Loop approved."
  end

  def activate
    redirect_to activation_redirect_path(@loop), **activation_outcome(@loop)
  end

  def deactivate
    redirect_to deactivation_redirect_path(@loop), **deactivation_outcome(@loop)
  end

  private

  # Provisions the ElevenLabs agent (once) and returns the flash to show.
  def activation_outcome(loop)
    return { notice: "This loop is already active." } if loop.active?
    return { alert: "Add at least one question before activating." } if loop.questions.empty?
    return { alert: "Approve this loop before activating it." } if loop.pending_approval?

    activate_loop!(loop)
    { notice: "Loop activated." }
  rescue ElevenLabsAgentCreator::Error => e
    { alert: "Couldn't create agent: #{e.message}" }
  end

  # Reuses the existing agent when the loop was already provisioned (create-once);
  # otherwise provisions a new one before going active.
  def activate_loop!(loop)
    if loop.agent_id.present?
      loop.update!(
        status: :active,
        first_deployed_at: loop.first_deployed_at || Time.current
      )
    else
      loop.update!(
        agent_id: ElevenLabsAgentCreator.new(loop).call,
        status: :active,
        first_deployed_at: loop.first_deployed_at || Time.current
      )
    end
  end

  def activation_redirect_path(loop)
    return deploy_path if params[:return_to] == "deploy"

    edit_loop_path(loop)
  end

  def deactivation_redirect_path(loop)
    return deploy_path if params[:return_to] == "deploy"

    edit_loop_path(loop)
  end

  # Pauses an active loop. Keeps the agent so it can be re-activated without a new API call.
  def deactivation_outcome(loop)
    return { notice: "This loop is already inactive." } unless loop.active?

    loop.update!(status: :closed)

    { notice: "Loop deactivated. Respondents can no longer reach it." }
  end

  def ensure_editable!
    return unless @loop.locked?

    redirect_to deploy_path,
                alert: "This loop has already been deployed and can no longer be edited."
  end

  def set_loop
    @loop = current_organization.loops.includes(:questions).find(params[:id])
  end

  def loop_params
    params.require(:loop).permit(
      :name,
      :description,
      questions_attributes: %i[id body position _destroy]
    )
  end

  def ensure_question_field
    @loop.questions.build if @loop.questions.reject(&:marked_for_destruction?).empty?
  end
end
