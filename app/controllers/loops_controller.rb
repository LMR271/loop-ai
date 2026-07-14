class LoopsController < ApplicationController
  before_action :set_loop, only: %i[edit update]

  def index
    @loops = current_user.loops.includes(:feedbacks).order(created_at: :desc)
  end

  def destroy
    loop = current_user.loops.find(params[:id])
    loop.destroy!

    redirect_to loops_path, notice: "Loop deleted."
  end

  def new
    @loop = current_user.loops.build
    @loop.questions.build
  end

  def create
    @loop = current_user.loops.build(loop_params)

    if @loop.save
      redirect_to edit_loop_path(@loop), notice: "Loop created. Add or refine its questions below."
    else
      ensure_question_field
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    ensure_question_field
  end

  def update
    if @loop.update(loop_params)
      redirect_to edit_loop_path(@loop), notice: "Loop updated."
    else
      ensure_question_field
      render :edit, status: :unprocessable_entity
    end
  end

  def activate
    loop = current_user.loops.find(params[:id])
    redirect_to edit_loop_path(loop), **activation_outcome(loop)
  end

  private

  # Provisions the ElevenLabs agent (once) and returns the flash to show.
  def activation_outcome(loop)
    return { notice: "This loop is already active." } if loop.active? || loop.agent_id.present?
    return { alert: "Add at least one question before activating." } if loop.questions.empty?

    loop.update!(agent_id: ElevenLabsAgentCreator.new(loop).call, status: :active)
    { notice: "Loop activated." }
  rescue ElevenLabsAgentCreator::Error => e
    { alert: "Couldn't create agent: #{e.message}" }
  end

  def set_loop
    @loop = current_user.loops.includes(:questions).find(params[:id])
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
