class QuestionLibraryCategoriesController < ApplicationController
  before_action :set_category, only: %i[edit update destroy]

  def create
    @category = current_user.question_library_categories.build(category_params)

    if @category.save
      redirect_to question_library_entries_path, notice: "Category created."
    else
      redirect_to question_library_entries_path, alert: @category.errors.full_messages.to_sentence
    end
  end

  def edit
  end

  def update
    previous_name = @category.name

    QuestionLibraryCategory.transaction do
      @category.update!(category_params)
      current_user.question_library_entries.where(category: previous_name).update_all(category: @category.name)
    end

    redirect_to question_library_entries_path, notice: "Category renamed."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    entries = @category.entries

    if entries.exists?
      destination = destination_category
      unless params[:destination] == "no_category" || destination
        redirect_to question_library_entries_path, alert: "Choose where to move this category's questions."
        return
      end

      entries.update_all(category: destination&.name)
    end

    @category.destroy!
    redirect_to question_library_entries_path, notice: "Category deleted."
  end

  private

  def set_category
    @category = current_user.question_library_categories.find(params[:id])
  end

  def category_params
    params.require(:question_library_category).permit(:name)
  end

  def destination_category
    return unless params[:destination] == "move"

    current_user.question_library_categories.where.not(id: @category.id).find_by(id: params[:move_to])
  end
end
