import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import TagInput from "../components/TagInput"

export default class extends Controller<HTMLElement> {
  static targets = ["root", "tagList"]
  static values = { category: { type: String, default: "genre" }, label: { type: String, default: "Genres" } }

  declare readonly rootTarget: HTMLElement
  declare readonly tagListTarget: HTMLInputElement
  declare readonly categoryValue: string
  declare readonly labelValue: string

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(
      <TagInput
        category={this.categoryValue}
        label={this.labelValue}
        initialTags={this.tagListTarget.value}
        onChange={(tagList) => this.#handleChange(tagList)}
      />
    )
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }

  #handleChange(tagList: string) {
    this.tagListTarget.value = tagList
  }
}
