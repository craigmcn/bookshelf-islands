import { useState } from "react"

interface ReviewLikeButtonProps {
  likeUrl: string
  initialLiked: boolean
  initialCount: number
  canLike: boolean
}

export default function ReviewLikeButton({ likeUrl, initialLiked, initialCount, canLike }: ReviewLikeButtonProps) {
  const [liked, setLiked] = useState(initialLiked)
  const [count, setCount] = useState(initialCount)
  const [pending, setPending] = useState(false)

  const toggle = async () => {
    setPending(true)
    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""

    try {
      const response = await fetch(likeUrl, {
        method: liked ? "DELETE" : "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": token },
      })
      if (!response.ok) throw new Error(`Like toggle failed: ${response.status}`)
      const data = (await response.json()) as { liked: boolean; count: number }
      setLiked(data.liked)
      setCount(data.count)
    } catch {
      // leave the previous state in place — the button stays clickable so the user can retry
    } finally {
      setPending(false)
    }
  }

  if (!canLike && count === 0) return null

  if (!canLike) {
    return (
      <span className="text-muted small">
        <i className="fasl fa-heart me-1" aria-hidden="true" />
        {count} {count === 1 ? "like" : "likes"}
      </span>
    )
  }

  return (
    <button
      type="button"
      className={liked ? "btn btn-sm btn-danger" : "btn btn-sm btn-outline-danger"}
      disabled={pending}
      aria-pressed={liked}
      onClick={toggle}
    >
      <i className="fasl fa-heart me-1" aria-hidden="true" />
      {liked ? "Liked" : "Like"} ({count})
    </button>
  )
}
