import { Controller } from "@hotwired/stimulus"
import { createRoot, type Root } from "react-dom/client"
import ReviewComments, { type ReviewCommentData } from "../components/ReviewComments"

interface RawComment {
  id: number
  body: string
  created_at: string
  author_name: string
  author_path: string
  can_destroy: boolean
  delete_path: string
}

export default class extends Controller<HTMLElement> {
  static targets = ["root"]
  static values = { url: String, comments: Array, canComment: Boolean }

  declare readonly rootTarget: HTMLElement
  declare readonly urlValue: string
  declare readonly commentsValue: RawComment[]
  declare readonly canCommentValue: boolean

  #reactRoot: Root | null = null

  connect() {
    const initialComments: ReviewCommentData[] = this.commentsValue.map((comment) => ({
      id: comment.id,
      body: comment.body,
      createdAt: comment.created_at,
      authorName: comment.author_name,
      authorPath: comment.author_path,
      canDestroy: comment.can_destroy,
      deletePath: comment.delete_path,
    }))

    this.#reactRoot = createRoot(this.rootTarget)
    this.#reactRoot.render(
      <ReviewComments commentsUrl={this.urlValue} initialComments={initialComments} canComment={this.canCommentValue} />
    )
  }

  disconnect() {
    this.#reactRoot?.unmount()
    this.#reactRoot = null
  }
}
