import { useState } from "react"

interface DeleteReadingControlProps {
  readingUrl: string
  onDeleted: () => void
}

type Status = "idle" | "confirming" | "deleting" | "error"

export default function DeleteReadingControl({ readingUrl, onDeleted }: DeleteReadingControlProps) {
  const [status, setStatus] = useState<Status>("idle")

  const confirmDelete = async () => {
    setStatus("deleting")
    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""

    try {
      const response = await fetch(readingUrl, {
        method: "DELETE",
        headers: { Accept: "application/json", "X-CSRF-Token": token },
      })
      if (!response.ok) throw new Error(`Delete failed: ${response.status}`)
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
      Delete
    </button>
  )
}
