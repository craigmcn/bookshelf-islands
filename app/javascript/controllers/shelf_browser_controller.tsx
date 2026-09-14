import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import ShelfBrowser, { type ShelfPage } from "../components/ShelfBrowser"

export default class extends Controller<HTMLElement> {
  static targets = ["root"]
  static values = { initial: Object, query: String, status: String, rating: String, tag: String }

  declare readonly rootTarget: HTMLElement
  declare readonly initialValue: ShelfPage
  declare readonly queryValue: string
  declare readonly statusValue: string
  declare readonly ratingValue: string
  declare readonly tagValue: string

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(
      <ShelfBrowser
        initial={this.initialValue}
        initialQuery={this.queryValue}
        initialStatus={this.statusValue}
        initialRating={this.ratingValue}
        initialTag={this.tagValue}
      />
    )
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }
}
