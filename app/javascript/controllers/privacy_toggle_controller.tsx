import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import PrivacyToggle from "../components/PrivacyToggle"

export default class extends Controller<HTMLElement> {
  static targets = ["root", "input"]

  declare readonly rootTarget: HTMLElement
  declare readonly inputTarget: HTMLInputElement

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(
      <PrivacyToggle
        initialValue={this.inputTarget.value === "true"}
        onChange={(isPublic) => this.#handleChange(isPublic)}
      />
    )
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }

  #handleChange(isPublic: boolean) {
    this.inputTarget.value = String(isPublic)
  }
}
