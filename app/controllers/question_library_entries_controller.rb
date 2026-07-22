class QuestionLibraryEntriesController < ApplicationController
  before_action :set_question_library_entry, only: %i[edit update destroy use]

  def index
    @question_library_entries = current_user.question_library_entries.alphabetical
    @question_library_categories = current_user.question_library_categories.order(:name)
    @question_library_category = current_user.question_library_categories.build
  end

  def create
    attributes = question_library_entry_params.to_h

    attributes["category"] = params[:new_category].presence if attributes["category"] == "__create_new_category__"

    @question_library_entry = current_user.question_library_entries.build(attributes)

    if @question_library_entry.save
      respond_to do |format|
        format.turbo_stream
        format.html do
          redirect_back fallback_location: question_library_entries_path,
                        notice: "Question saved to your library."
        end
        format.json { render json: @question_library_entry, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          redirect_back fallback_location: question_library_entries_path,
                        alert: @question_library_entry.errors.full_messages.to_sentence
        end
        format.json do
          render json: { errors: @question_library_entry.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    @categories = current_user.question_library_categories.where.not(name: @question_library_entry.category).order(:name).pluck(:name)
  end

  def update
    attributes = question_library_entry_params.to_h

    attributes["category"] = params[:new_category].presence if attributes["category"] == "__create_new_category__"

    if @question_library_entry.update(attributes)
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
