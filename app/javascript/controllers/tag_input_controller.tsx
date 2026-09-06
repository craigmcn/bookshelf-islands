import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import TagInput from "../components/TagInput"

export default class extends Controller<HTMLElement> {
  static targets = ["root", "tagList"]

  declare readonly rootTarget: HTMLElement
  declare readonly tagListTarget: HTMLInputElement

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(
      <TagInput initialTags={this.tagListTarget.value} onChange={(tagList) => this.#handleChange(tagList)} />
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
