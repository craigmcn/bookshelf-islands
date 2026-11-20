import { useState } from "react"

interface DeleteReadingControlProps {
  readingUrl: string
  onDeleted: () => void
  // Set for an icon-only trigger (the shelf row); the admin table keeps its text "Delete" button.
  iconLabel?: string
}

type Status = "idle" | "confirming" | "deleting" | "error"

export default function DeleteReadingControl({ readingUrl, onDeleted, iconLabel }: DeleteReadingControlProps) {
  const [status, setStatus] = useState<Status>("idle")

  const confirmDelete = async () => {
    setStatus("deleting")
    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""

    try {
      const response = await fetch(readingUrl, {
        method: "DELETE",
        headers: { Accept: "application/json", "X-CSRF-Token": token },
      })
      // require the exact 204 our destroy action returns on success, not just response.ok —
      // fetch follows redirects, so an expired session bouncing to /sign_in would otherwise
      // resolve to a 200 HTML response and be mistaken for a successful delete
      if (response.status !== 204) throw new Error(`Delete failed: ${response.status}`)
      onDeleted()
    } catch {
      setStatus("error")
    }
  }

  if (status === "confirming" || status === "deleting") {
    return (
      <div className="d-flex align-items-center gap-1">
        <span className="text-muted small">Remove this reading?</span>
        <button
          type="button"
          className="btn btn-sm btn-danger"
          disabled={status === "deleting"}
          onClick={confirmDelete}
        >
          {status === "deleting" ? "Removing…" : "Yes"}
        </button>
        <button
          type="button"
          className="btn btn-sm btn-outline-secondary"
          disabled={status === "deleting"}
          onClick={() => setStatus("idle")}
        >
          Cancel
        </button>
      </div>
    )
  }

  if (status === "error") {
    return (
      <div className="d-flex align-items-center gap-2">
        <span className="text-danger small">Delete failed.</span>
        <button type="button" className="btn btn-sm btn-outline-danger" onClick={confirmDelete}>
          Retry
        </button>
      </div>
    )
  }

  return (
    <button type="button" className="btn btn-sm btn-outline-danger" onClick={() => setStatus("confirming")}>
      {iconLabel ? (
        <>
          <i className="fasl fa-trash-can" aria-hidden="true" />
          <span className="visually-hidden">{iconLabel}</span>
        </>
      ) : (
        "Delete"
      )}
    </button>
  )
}
