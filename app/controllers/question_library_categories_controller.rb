class QuestionLibraryCategoriesController < ApplicationController
  before_action :set_category, only: %i[destroy]

  def create
    @category = current_user.question_library_categories.build(category_params)

    if @category.save
      redirect_to question_library_entries_path, notice: "Category created."
    else
      redirect_to question_library_entries_path, alert: @category.errors.full_messages.to_sentence
    end
  end

  def destroy
    current_user.question_library_entries.where(category: @category.name).destroy_all
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
end
