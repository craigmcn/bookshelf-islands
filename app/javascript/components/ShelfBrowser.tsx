import { useEffect, useRef, useState } from "react"
import DeleteReadingControl from "./DeleteReadingControl"
import RereadControl from "./RereadControl"

export interface ShelfReading {
  id: number
  book_id: number
  book_title: string
  book_author: string
  book_path: string
  status: string
  status_label: string
  rating: string | null
  rating_stars: number | null
  progress_percent: number | null
  review: string | null
  path: string
  edit_path: string
  can_edit: boolean
  can_destroy: boolean
}

interface ShelfTag {
  name: string
}

export interface ShelfPage {
  readings: ShelfReading[]
  sort: string
  tag: string | null
  shelf_tags: ShelfTag[]
  pagy: { page: number; pages: number; count: number }
}

const SORT_OPTIONS: Array<{ value: string; label: string }> = [
  { value: "recent", label: "Recently Updated" },
  { value: "title", label: "Book Title" },
  { value: "rating", label: "Rating (high to low)" },
]

const STATUS_OPTIONS: Array<{ value: string; label: string }> = [
  { value: "want_to_read", label: "Want To Read" },
  { value: "reading", label: "Reading" },
  { value: "finished", label: "Finished" },
  { value: "dnf", label: "DNF" },
]

const RATING_OPTIONS: Array<{ value: string; label: string }> = [
  { value: "one", label: "One" },
  { value: "two", label: "Two" },
  { value: "three", label: "Three" },
  { value: "four", label: "Four" },
  { value: "five", label: "Five" },
]

const DEBOUNCE_MS = 300

interface ShelfBrowserProps {
  initial: ShelfPage
  initialQuery: string
  initialStatus: string
  initialRating: string
  initialTag: string
}

export default function ShelfBrowser({
  initial,
  initialQuery,
  initialStatus,
  initialRating,
  initialTag,
}: ShelfBrowserProps) {
  const [query, setQuery] = useState(initialQuery)
  const [status, setStatus] = useState(initialStatus)
  const [rating, setRating] = useState(initialRating)
  // the server's normalized tag when it recognised one, else the raw param, so an unknown
  // ?tag= stays applied (and clearable) rather than silently dropping to an unfiltered shelf
  const tag = initial.tag ?? initialTag
  const [sort, setSort] = useState(initial.sort)
  const [page, setPage] = useState(initial.pagy.page)
  const [data, setData] = useState<ShelfPage>(initial)
  const [loading, setLoading] = useState(false)
  // keyed by a counter so a repeat "Reading was removed." remounts the alert and is re-announced
  const [notice, setNotice] = useState<{ text: string; key: number } | null>(null)
  const isFirstRender = useRef(true)

  // One builder for both the JSON fetch and the tag links, so the two can't drift apart.
  const buildParams = (tagValue: string) => {
    const params = new URLSearchParams()
    if (query.trim()) params.set("q", query.trim())
    if (status) params.set("status", status)
    if (rating) params.set("rating", rating)
    if (tagValue) params.set("tag", tagValue)
    params.set("sort", sort)
    return params
  }

  const fetchShelf = (signal?: AbortSignal) => {
    setLoading(true)
    const params = buildParams(tag)
    params.set("page", String(page))

    return fetch(`/readings.json?${params.toString()}`, {
      signal,
      headers: { Accept: "application/json" },
    })
      .then((response) => {
        if (!response.ok) throw new Error(`Shelf search failed: ${response.status}`)
        return response.json()
      })
      .then((result: ShelfPage) => setData(result))
      .catch((error: unknown) => {
        if ((error as { name?: string }).name !== "AbortError") {
          setData((current) => ({
            readings: [],
            sort,
            tag: current.tag,
            shelf_tags: current.shelf_tags,
            pagy: { page: 1, pages: 1, count: 0 },
          }))
        }
      })
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false
      return
    }

    const controller = new AbortController()
    const timeout = setTimeout(() => fetchShelf(controller.signal), DEBOUNCE_MS)

    return () => {
      clearTimeout(timeout)
      controller.abort()
    }
  }, [query, status, rating, sort, page])

  const goToPage = (value: number) => {
    setNotice(null)
    setPage(value)
  }

  const resetToFirstPage = <T,>(setter: (value: T) => void) => (value: T) => {
    setter(value)
    goToPage(1)
  }

  const handleQueryChange = resetToFirstPage(setQuery)
  const handleStatusChange = resetToFirstPage(setStatus)
  const handleRatingChange = resetToFirstPage(setRating)
  // Tag filters are real links that navigate (community_bookshelf#224 #12), so the
  // filtered view has a shareable URL; the island re-hydrates from these params.
  const tagHref = (value: string) => `/readings?${buildParams(value).toString()}`
  const hasFilters = Boolean(query.trim() || status || rating || tag)
  const handleSortChange = resetToFirstPage(setSort)

  const removeReading = (id: number) => {
    // same copy as the HTML destroy's flash, since the island deletes without a page load
    setNotice((current) => ({ text: "Reading was removed.", key: (current?.key ?? 0) + 1 }))
    const lastRowOnPage = data.readings.length === 1 && page > 1
    setData((current) => ({
      ...current,
      readings: current.readings.filter((reading) => reading.id !== id),
    }))
    // refetch so pagination and the next page's rows catch up; step back if this page is now empty
    if (lastRowOnPage) setPage(page - 1)
    else fetchShelf()
  }

  return (
    <div>
      {notice && (
        <div key={notice.key} className="alert alert-success alert-dismissible" role="alert">
          <i className="fasl fa-circle-check me-2" aria-hidden="true" />
          {notice.text}
          <button type="button" className="btn-close" aria-label="Close" onClick={() => setNotice(null)} />
        </div>
      )}
      <div className="row g-2 mb-4">
        <div className="col-sm-6 col-md-4">
          <label className="visually-hidden" htmlFor="shelf_q">
            Search
          </label>
          <input
            type="text"
            id="shelf_q"
            className="form-control"
            placeholder="Search by title or author..."
            autoComplete="off"
            value={query}
            onChange={(event) => handleQueryChange(event.target.value)}
          />
        </div>
        <div className="col-sm-3 col-md-2">
          <label className="visually-hidden" htmlFor="shelf_status">
            Status
          </label>
          <select
            id="shelf_status"
            className="form-select"
            value={status}
            onChange={(event) => handleStatusChange(event.target.value)}
          >
            <option value="">Any status</option>
            {STATUS_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
        <div className="col-sm-3 col-md-2">
          <label className="visually-hidden" htmlFor="shelf_rating">
            Rating
          </label>
          <select
            id="shelf_rating"
            className="form-select"
            value={rating}
            onChange={(event) => handleRatingChange(event.target.value)}
          >
            <option value="">Any rating</option>
            {RATING_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
        <div className="col-sm-4 col-md-3">
          <label className="visually-hidden" htmlFor="shelf_sort">
            Sort by
          </label>
          <select
            id="shelf_sort"
            className="form-select"
            value={sort}
            onChange={(event) => handleSortChange(event.target.value)}
          >
            {SORT_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
        {loading && (
          <div className="col-auto d-flex align-items-center">
            <div className="spinner-border spinner-border-sm text-secondary" role="status">
              <span className="visually-hidden">Loading…</span>
            </div>
          </div>
        )}
      </div>

      {data.shelf_tags.length > 0 && (
        <div className="d-flex flex-wrap align-items-center gap-1 mb-3">
          <span className="text-muted small me-1">Browse by genre:</span>
          {data.shelf_tags.map((shelfTag) => (
            <a
              key={shelfTag.name}
              href={tagHref(tag === shelfTag.name ? "" : shelfTag.name)}
              className={`badge text-decoration-none ${tag === shelfTag.name ? "text-bg-primary" : "text-bg-secondary"}`}
              aria-current={tag === shelfTag.name ? "true" : undefined}
            >
              {shelfTag.name}
            </a>
          ))}
          {tag && (
            <a href={tagHref("")} className="small ms-2">
              Clear tag filter
            </a>
          )}
        </div>
      )}

      {data.readings.length === 0 ? (
        hasFilters ? (
          <p className="text-muted">No readings match those filters.</p>
        ) : (
          <div className="text-center text-muted py-5">
            <p className="fs-5">Your shelf is empty.</p>
            <a href="/readings/new" className="btn btn-primary">
              <i className="fasl fa-plus me-1" aria-hidden="true" />
              Log your first reading
            </a>
          </div>
        )
      ) : (
        <div className="table-responsive">
          <table className="table table-hover align-middle">
            <thead className="table-dark">
              <tr>
                <th>Book</th>
                <th>Status</th>
                <th>Rating</th>
                <th>Progress</th>
                <th>Review</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {data.readings.map((reading) => (
                <tr key={reading.id}>
                  <td>
                    <a href={reading.book_path} className="text-decoration-none fw-semibold">
                      {reading.book_title}
                    </a>
                  </td>
                  <td>
                    <span className={`badge badge-status-${reading.status.replace(/_/g, "-")}`}>
                      {reading.status_label}
                    </span>
                  </td>
                  <td>
                    {reading.rating_stars ? (
                      <>
                        <span className="visually-hidden">{reading.rating}</span>
                        {Array.from({ length: reading.rating_stars }).map((_, index) => (
                          <i key={index} className="fasl fa-star text-warning" aria-hidden="true" />
                        ))}
                      </>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td>
                    {reading.progress_percent != null ? (
                      <span className="text-muted small">{reading.progress_percent}%</span>
                    ) : (
                      "—"
                    )}
                  </td>
                  <td className="text-muted">
                    {reading.review && reading.review.length > 80
                      ? `${reading.review.slice(0, 80)}...`
                      : reading.review}
                  </td>
                  <td className="d-flex align-items-center">
                    {reading.status === "finished" && (
                      <span className="me-1">
                        <RereadControl bookId={reading.book_id} onCreated={() => fetchShelf()} />
                      </span>
                    )}
                    {reading.can_edit && (
                      <a href={reading.edit_path} className="btn btn-sm btn-outline-secondary">
                        <i className="fasl fa-pen-to-square" aria-hidden="true" />
                        <span className="visually-hidden">Edit reading</span>
                      </a>
                    )}
                    {reading.can_destroy && (
                      <span className="ms-1">
                        <DeleteReadingControl
                          readingUrl={reading.path}
                          iconLabel="Remove reading"
                          onDeleted={() => removeReading(reading.id)}
                        />
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {data.pagy.pages > 1 && (
        <nav aria-label="My Shelf pagination" className="mt-4 d-flex justify-content-center gap-2">
          <button
            type="button"
            className="btn btn-outline-secondary btn-sm"
            disabled={data.pagy.page <= 1}
            onClick={() => goToPage(data.pagy.page - 1)}
          >
            Previous
          </button>
          <span className="align-self-center text-muted small">
            Page {data.pagy.page} of {data.pagy.pages}
          </span>
          <button
            type="button"
            className="btn btn-outline-secondary btn-sm"
            disabled={data.pagy.page >= data.pagy.pages}
            onClick={() => goToPage(data.pagy.page + 1)}
          >
            Next
          </button>
        </nav>
      )}
    </div>
  )
}
