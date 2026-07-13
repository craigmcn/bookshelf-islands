import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import BookSearch, { type BookSelection } from "../components/BookSearch"

export default class extends Controller<HTMLElement> {
  static targets = ["root", "title", "author", "coverUrl"]

  declare readonly rootTarget: HTMLElement
  declare readonly titleTarget: HTMLInputElement
  declare readonly authorTarget: HTMLInputElement
  declare readonly coverUrlTarget: HTMLInputElement

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
    this.#reactRoot?.render(
      <BookSearch
        initialTitle={this.titleTarget.value}
        initialAuthor={this.authorTarget.value}
        initialCoverUrl={this.coverUrlTarget.value}
        onChange={(selection) => this.#handleChange(selection)}
      />
    )
  }

  #handleChange(selection: BookSelection | null) {
    this.titleTarget.value = selection?.title ?? ""
    this.authorTarget.value = selection?.author ?? ""
    this.coverUrlTarget.value = selection?.coverUrl ?? ""
  }
}
