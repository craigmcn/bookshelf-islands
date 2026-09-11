import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import ProgressPicker from "../components/ProgressPicker"

export default class extends Controller<HTMLElement> {
  static targets = ["root", "input"]

  declare readonly rootTarget: HTMLElement
  declare readonly inputTarget: HTMLInputElement

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(
      <ProgressPicker initialValue={this.inputTarget.value} onChange={(value) => this.#handleChange(value)} />
    )
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }

  #handleChange(value: string) {
    this.inputTarget.value = value
  }
}
