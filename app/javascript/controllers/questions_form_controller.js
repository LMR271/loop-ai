import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "question", "template", "number", "position"]

  add() {
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, Date.now())
    this.listTarget.insertAdjacentHTML("beforeend", content)
    this.updateOrder()
  }

  remove(event) {
    const question = event.target.closest("[data-questions-form-target='question']")
    const destroyField = question.querySelector("input[name$='[_destroy]']")

    if (destroyField) {
      destroyField.value = "1"
      question.hidden = true
    } else {
      question.remove()
    }

    this.updateOrder()
  }

  moveUp(event) {
    const question = event.target.closest("[data-questions-form-target='question']")
    const previousQuestion = this.visibleQuestions().at(this.visibleQuestions().indexOf(question) - 1)

    if (previousQuestion) question.before(previousQuestion)
    this.updateOrder()
  }

  moveDown(event) {
    const question = event.target.closest("[data-questions-form-target='question']")
    const questions = this.visibleQuestions()
    const nextQuestion = questions.at(questions.indexOf(question) + 1)

    if (nextQuestion) nextQuestion.after(question)
    this.updateOrder()
  }

  updateOrder() {
    this.visibleQuestions().forEach((question, index) => {
      question.querySelector("[data-questions-form-target='number']").textContent = `Question ${index + 1}`
      question.querySelector("[data-questions-form-target='position']").value = index + 1
    })
  }

  visibleQuestions() {
    return this.questionTargets.filter((question) => !question.hidden)
  }
}
