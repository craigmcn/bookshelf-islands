import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import ShelfPicker from "../components/ShelfPicker"

export default class extends Controller<HTMLElement> {
  static targets = ["root"]
  static values = { bookId: Number, shelves: Array }

  declare readonly rootTarget: HTMLElement
  declare readonly bookIdValue: number
  declare readonly shelvesValue: Array<{id: number; name: string; shelf_book_id: number | null}>

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(<ShelfPicker bookId={this.bookIdValue} initialShelves={this.shelvesValue} />)
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }
}
