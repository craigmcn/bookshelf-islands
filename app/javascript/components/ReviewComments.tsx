import { useState } from "react"

export interface ReviewCommentData {
  id: number
  body: string
  createdAt: string
  authorName: string
  authorPath: string
  canDestroy: boolean
  deletePath: string
}

interface ReviewCommentsProps {
  commentsUrl: string
  initialComments: ReviewCommentData[]
  canComment: boolean
}

class CommentError extends Error {}

function csrfToken() {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""
}

export default function ReviewComments({ commentsUrl, initialComments, canComment }: ReviewCommentsProps) {
  const [comments, setComments] = useState(initialComments)
  const [body, setBody] = useState("")
  const [posting, setPosting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const submit = async () => {
    if (!body.trim()) return
    setPosting(true)
    setError(null)

    try {
      const response = await fetch(commentsUrl, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken(),
        },
        body: JSON.stringify({ review_comment: { body } }),
      })
      // only a 201 is a created comment. Error bodies may be HTML (500, NullByteGuard's 400), empty
      // (Clearance's 401) or JSON with a single `error` (Pundit's 403), so parse leniently.
      const data = await response.json().catch(() => null)
      if (response.status !== 201 || !data) {
        const message = Array.isArray(data?.errors) ? data.errors.join(", ") : data?.error
        throw new CommentError(typeof message === "string" && message ? message : "Comment failed")
      }

      setComments((previous) => [
        ...previous,
        {
          id: data.id,
          body: data.body,
          createdAt: data.created_at,
          authorName: data.author_name,
          authorPath: data.author_path,
          canDestroy: data.can_destroy,
          deletePath: data.delete_path,
        },
      ])
      setBody("")
    } catch (err) {
      // only our own messages reach the user, never a raw fetch/parse exception
      setError(err instanceof CommentError ? err.message : "Comment failed")
    } finally {
      setPosting(false)
    }
  }

  const remove = async (comment: ReviewCommentData) => {
    try {
      const response = await fetch(comment.deletePath, {
        method: "DELETE",
        headers: { Accept: "application/json", "X-CSRF-Token": csrfToken() },
      })
      if (response.status !== 204) throw new Error(`Delete failed: ${response.status}`)
      setComments((previous) => previous.filter((c) => c.id !== comment.id))
    } catch {
      setError("Couldn't remove that comment.")
    }
  }

  return (
    <div>
      {comments.length === 0 && <p className="text-muted small">No comments yet.</p>}
      <ul className="list-unstyled">
        {comments.map((comment) => (
          <li key={comment.id} className="mb-3">
            <div className="d-flex justify-content-between align-items-start">
              <div>
                <a href={comment.authorPath} className="fw-semibold text-decoration-none">
                  {comment.authorName}
                </a>
                <span className="text-muted small ms-2">{new Date(comment.createdAt).toLocaleString()}</span>
                <p className="mb-0">{comment.body}</p>
              </div>
              {comment.canDestroy && (
                <button
                  type="button"
                  className="btn btn-sm btn-link text-danger"
                  onClick={() => remove(comment)}
                >
                  Delete
                </button>
              )}
            </div>
          </li>
        ))}
      </ul>

      {canComment && (
        <div className="mt-2">
          <textarea
            className="form-control"
            rows={3}
            value={body}
            maxLength={1000}
            placeholder="Add a comment…"
            onChange={(event) => setBody(event.target.value)}
          />
          {error && <p className="text-danger small mt-1">{error}</p>}
          <button
            type="button"
            className="btn btn-primary btn-sm mt-2"
            disabled={posting || !body.trim()}
            onClick={submit}
          >
            {posting ? "Posting…" : "Post Comment"}
          </button>
        </div>
      )}
    </div>
  )
}
