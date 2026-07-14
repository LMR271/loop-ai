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

  private

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
