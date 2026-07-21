class QuestionLibraryEntriesController < ApplicationController
  before_action :set_question_library_entry, only: %i[edit update destroy use]

  def index
    @question_library_entries = current_user.question_library_entries.alphabetical
    @question_library_categories = current_user.question_library_categories.order(:name)
    @question_library_category = current_user.question_library_categories.build
  end

  def create
    @question_library_entry = current_user.question_library_entries.build(question_library_entry_params)

    if @question_library_entry.save
      respond_to do |format|
        format.html { redirect_back fallback_location: question_library_entries_path, notice: "Question saved to your library." }
        format.json { render json: @question_library_entry, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: question_library_entries_path, alert: @question_library_entry.errors.full_messages.to_sentence }
        format.json { render json: { errors: @question_library_entry.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @categories = current_user.question_library_categories.where.not(name: @question_library_entry.category).order(:name).pluck(:name)
  end

  def update
    if @question_library_entry.update(question_library_entry_params)
      redirect_to question_library_entries_path, notice: "Library question updated."
    else
      @categories = current_user.question_library_categories.where.not(name: @question_library_entry.category).order(:name).pluck(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @question_library_entry.destroy!
    redirect_to question_library_entries_path, notice: "Library question deleted."
  end

  def use
    @question_library_entry.increment!(:times_used)
    head :no_content
  end

  private

  def set_question_library_entry
    @question_library_entry = current_user.question_library_entries.find(params[:id])
  end

  def question_library_entry_params
    params.require(:question_library_entry).permit(:category, :content)
  end
end
