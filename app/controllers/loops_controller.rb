class LoopsController < ApplicationController
  def new
    @loop = current_user.loops.new
    # creates 3 blank, unsaved Question objects in memory, that's what makes 3 empty question fields appear on the new form
    3.times do
      @loop.questions.build
    end
  end

  def create
    @loop = current_user.loops.new(loop_params)
    if @loop.save
      redirect_to @loop, notice: "Loop created!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def loop_params
    params.require(:loop).permit(:name, :description, questions_attributes: %i[id body position _destroy]) # %i used for an array of symbols
  end
end
