import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import DeleteReadingControl from "../components/DeleteReadingControl"

export default class extends Controller<HTMLElement> {
  static targets = ["root", "edit"]
  static values = { url: String }

  declare readonly rootTarget: HTMLElement
  declare readonly editTarget: HTMLElement
  declare readonly urlValue: string

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#render()
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }

  #render() {
    this.#reactRoot?.render(<DeleteReadingControl readingUrl={this.urlValue} onDeleted={() => this.#handleDeleted()} />)
  }

  #handleDeleted() {
    this.element.closest("tr")?.classList.add("opacity-50")
    this.editTarget.remove()
    this.#reactRoot?.render(<span className="badge bg-danger">Deleted</span>)
  }
}
