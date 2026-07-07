import { useEffect, useState } from "react"

export interface BookSelection {
  title: string
  author: string
  coverUrl: string
}

interface SearchResult {
  title: string
  author: string
  cover_url: string | null
}

interface BookSearchProps {
  initialTitle?: string
  initialAuthor?: string
  initialCoverUrl?: string
  onChange: (selection: BookSelection | null) => void
}

const DEBOUNCE_MS = 300

export default function BookSearch({ initialTitle, initialAuthor, initialCoverUrl, onChange }: BookSearchProps) {
  const [query, setQuery] = useState("")
  const [results, setResults] = useState<SearchResult[]>([])
  const [loading, setLoading] = useState(false)
  const [selected, setSelected] = useState<BookSelection | null>(
    initialTitle ? { title: initialTitle, author: initialAuthor ?? "", coverUrl: initialCoverUrl ?? "" } : null
  )

  useEffect(() => {
    if (selected || query.trim().length < 2) {
      setResults([])
      return
    }

    const controller = new AbortController()
    const timeout = setTimeout(() => {
      setLoading(true)
      fetch(`/book_search.json?q=${encodeURIComponent(query.trim())}`, { signal: controller.signal })
        .then((response) => response.json())
        .then((data: SearchResult[]) => setResults(data))
        .catch((error: unknown) => {
          if ((error as { name?: string }).name !== "AbortError") setResults([])
        })
        .finally(() => setLoading(false))
    }, DEBOUNCE_MS)

    return () => {
      clearTimeout(timeout)
      controller.abort()
    }
  }, [query, selected])

  const selectBook = (result: SearchResult) => {
    const selection: BookSelection = { title: result.title, author: result.author, coverUrl: result.cover_url ?? "" }
    setSelected(selection)
    setQuery("")
    setResults([])
    onChange(selection)
  }

  const clearSelection = () => {
    setSelected(null)
    onChange(null)
  }

  if (selected) {
    return (
      <div className="mb-3">
        <label className="form-label">Selected Book</label>
        <div className="d-flex align-items-center gap-3 p-3 border rounded">
          {selected.coverUrl && (
            <img
              src={selected.coverUrl}
              style={{ height: 70, width: 50, objectFit: "cover", borderRadius: 3, flexShrink: 0 }}
              alt=""
            />
          )}
          <div className="overflow-hidden flex-grow-1">
            <div className="fw-semibold text-truncate">{selected.title}</div>
            <div className="text-muted small text-truncate">{selected.author}</div>
          </div>
          <button type="button" className="btn btn-sm btn-outline-secondary flex-shrink-0" onClick={clearSelection}>
            Change
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="mb-3">
      <label className="form-label d-flex align-items-center gap-2" htmlFor="book_query">
        Search for a Book
        {loading && (
          <div className="spinner-border spinner-border-sm text-secondary" role="status">
            <span className="visually-hidden">Loading…</span>
          </div>
        )}
      </label>
      <input
        type="text"
        id="book_query"
        className="form-control"
        placeholder="Search by title or author..."
        autoComplete="off"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
      />
      {results.length === 0 && !loading && query.trim().length >= 2 && (
        <p className="text-muted small mt-2 mb-0">No results found.</p>
      )}
      {results.length > 0 && (
        <div className="list-group mt-2">
          {results.map((result, index) => (
            <button
              key={`${result.title}-${result.author}-${index}`}
              type="button"
              className="list-group-item list-group-item-action d-flex align-items-center gap-3 py-2"
              onClick={() => selectBook(result)}
            >
              {result.cover_url ? (
                <img
                  src={result.cover_url}
                  style={{ height: 50, width: 35, objectFit: "cover", flexShrink: 0 }}
                  alt=""
                />
              ) : (
                <div
                  style={{ height: 50, width: 35, flexShrink: 0 }}
                  className="bg-secondary rounded d-flex align-items-center justify-content-center"
                >
                  <small className="text-white">📚</small>
                </div>
              )}
              <div className="text-start overflow-hidden">
                <div className="fw-semibold text-truncate">{result.title}</div>
                <div className="text-muted small text-truncate">{result.author}</div>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
