import { useState } from "react"
import type { ShelfReading } from "./ShelfBrowser"

interface RereadControlProps {
  bookId: number
  onCreated: (reading: ShelfReading) => void
}

type Status = "idle" | "creating" | "error"

export default function RereadControl({ bookId, onCreated }: RereadControlProps) {
  const [status, setStatus] = useState<Status>("idle")

  const startReread = async () => {
    setStatus("creating")
    const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""

    try {
      const response = await fetch("/readings", {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": token },
        body: JSON.stringify({reading: {book_id: bookId, status: "want_to_read"}}),
      })
      if (response.status !== 201) throw new Error(`Start a re-read failed: ${response.status}`)
      const reading: ShelfReading = await response.json()
      onCreated(reading)
      setStatus("idle")
    } catch {
      setStatus("error")
    }
  }

  if (status === "error") {
    return (
      <button type="button" className="btn btn-sm btn-outline-danger" onClick={startReread}>
        Retry
      </button>
    )
  }

  return (
    <button type="button" className="btn btn-sm btn-outline-secondary" disabled={status === "creating"} onClick={startReread}>
      {status === "creating" ? "Starting…" : "Start a re-read"}
    </button>
  )
}
