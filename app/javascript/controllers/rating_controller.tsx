import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import RatingPicker, { type RatingOption } from "../components/RatingPicker"

export default class extends Controller<HTMLElement> {
  static targets = ["root", "input"]
  static values = { options: Array }

  declare readonly rootTarget: HTMLElement
  declare readonly inputTarget: HTMLInputElement
  declare readonly optionsValue: RatingOption[]

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
      <RatingPicker
        options={this.optionsValue}
        initialValue={this.inputTarget.value}
        onChange={(key) => this.#handleChange(key)}
      />
    )
  }

  #handleChange(key: string) {
    this.inputTarget.value = key
  }
}
