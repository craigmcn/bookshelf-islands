import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import ReviewLikeButton from "../components/ReviewLikeButton"

export default class extends Controller<HTMLElement> {
  static targets = ["root"]
  static values = { url: String, liked: Boolean, count: Number, canLike: Boolean }

  declare readonly rootTarget: HTMLElement
  declare readonly urlValue: string
  declare readonly likedValue: boolean
  declare readonly countValue: number
  declare readonly canLikeValue: boolean

  #reactRoot: Root | null = null

  connect() {
    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(
      <ReviewLikeButton
        likeUrl={this.urlValue}
        initialLiked={this.likedValue}
        initialCount={this.countValue}
        canLike={this.canLikeValue}
      />
    )
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }
}
