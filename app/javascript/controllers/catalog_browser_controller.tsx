import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import CatalogBrowser, { type CatalogPage } from "../components/CatalogBrowser"

export default class extends Controller<HTMLElement> {
  static targets = ["root"]
  static values = { initial: Object, query: String }

  declare readonly rootTarget: HTMLElement
  declare readonly initialValue: CatalogPage
  declare readonly queryValue: string

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(<CatalogBrowser initial={this.initialValue} initialQuery={this.queryValue} />)
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }
}
