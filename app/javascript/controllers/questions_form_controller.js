import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "list",
    "question",
    "template",
    "number",
    "position",
    "saveContent",
    "savePreview"
  ]

  add() {
    this.addQuestion()
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

  openSaveModal(event) {
    const question = event.target.closest("[data-questions-form-target='question']")
    const content = question.querySelector("textarea").value.trim()

    if (!content) {
      question.querySelector("textarea").focus()
      return
    }

    this.saveContentTarget.value = content
    this.savePreviewTarget.textContent = content
    this.modal("saveQuestionToLibraryModal").show()
  }

  insertFromLibrary(event) {
    const { content, useUrl } = event.params
    this.addQuestion(content)
    this.modal("insertQuestionFromLibraryModal").hide()

    fetch(useUrl, {
      method: "POST",
      headers: { "X-CSRF-Token": this.csrfToken() }
    })
  }

  updateOrder() {
    this.visibleQuestions().forEach((question, index) => {
      question.querySelector("[data-questions-form-target='number']").textContent = `Question ${index + 1}`
      question.querySelector("[data-questions-form-target='position']").value = index + 1
    })
  }

  addQuestion(content = "") {
    const timestamp = Date.now()
    const question = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, timestamp)
    this.listTarget.insertAdjacentHTML("beforeend", question)
    const field = this.visibleQuestions().at(-1).querySelector("textarea")
    field.value = content
    this.updateOrder()
    field.focus()
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }

  modal(id) {
    return window.bootstrap.Modal.getOrCreateInstance(document.getElementById(id))
  }

  visibleQuestions() {
    return this.questionTargets.filter((question) => !question.hidden)
  }
}
