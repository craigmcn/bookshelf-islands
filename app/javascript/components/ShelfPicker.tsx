import { useState } from "react"

interface ShelfOption {
  id: number
  name: string
  shelf_book_id: number | null
}

interface ShelfPickerProps {
  bookId: number
  initialShelves: ShelfOption[]
}

function csrfToken() {
  return document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ""
}

export default function ShelfPicker({ bookId, initialShelves }: ShelfPickerProps) {
  const [shelves, setShelves] = useState(initialShelves)
  const [busyId, setBusyId] = useState<number | null>(null)

  const toggle = async (shelf: ShelfOption) => {
    setBusyId(shelf.id)

    try {
      if (shelf.shelf_book_id) {
        const response = await fetch(`/shelves/${shelf.id}/books/${shelf.shelf_book_id}`, {
          method: "DELETE",
          headers: { Accept: "application/json", "X-CSRF-Token": csrfToken() },
        })
        if (response.status !== 204) throw new Error(`Remove from shelf failed: ${response.status}`)
        setShelves((current) => current.map((s) => (s.id === shelf.id ? {...s, shelf_book_id: null} : s)))
      } else {
        const response = await fetch(`/shelves/${shelf.id}/books`, {
          method: "POST",
          headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": csrfToken() },
          body: JSON.stringify({book_id: bookId}),
        })
        if (response.status !== 201) throw new Error(`Add to shelf failed: ${response.status}`)
        const created: {id: number} = await response.json()
        setShelves((current) => current.map((s) => (s.id === shelf.id ? {...s, shelf_book_id: created.id} : s)))
      }
    } catch {
      // Leave shelf state as it was — the button just re-enables, ready to retry.
    } finally {
      setBusyId(null)
    }
  }

  if (shelves.length === 0) {
    return (
      <a href="/shelves/new" className="btn btn-outline-secondary">
        <i className="fasl fa-layer-group me-1" />
        Create a List
      </a>
    )
  }

  return (
    <div className="dropdown">
      <button
        className="btn btn-outline-secondary dropdown-toggle"
        type="button"
        data-bs-toggle="dropdown"
        data-bs-auto-close="outside"
        aria-expanded="false"
      >
        <i className="fasl fa-layer-group me-1" />
        Save to a List
      </button>
      <ul className="dropdown-menu">
        {shelves.map((shelf) => (
          <li key={shelf.id}>
            <button
              type="button"
              className="dropdown-item d-flex justify-content-between align-items-center gap-3"
              disabled={busyId === shelf.id}
              aria-pressed={!!shelf.shelf_book_id}
              onClick={() => toggle(shelf)}
            >
              {shelf.name}
              {shelf.shelf_book_id && <i className="fasl fa-check text-success" aria-hidden="true" />}
            </button>
          </li>
        ))}
        <li>
          <hr className="dropdown-divider" />
        </li>
        <li>
          <a className="dropdown-item" href="/shelves/new">
            <i className="fasl fa-plus me-2" />
            New List
          </a>
        </li>
      </ul>
    </div>
  )
}
