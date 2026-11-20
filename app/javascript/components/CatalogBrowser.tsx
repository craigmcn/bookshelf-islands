import { useEffect, useRef, useState } from "react"

interface CatalogBook {
  id: number
  title: string
  author: string
  cover_url: string | null
  added_by_name: string
  path: string
}

interface GenreTag {
  name: string
}

export interface CatalogPage {
  books: CatalogBook[]
  sort: string
  tag: string | null
  genre_tags: GenreTag[]
  mood_tags: GenreTag[]
  pace_tags: GenreTag[]
  pagy: { page: number; pages: number; count: number }
}

const SORT_OPTIONS: Array<{ value: string; label: string }> = [
  { value: "title", label: "Title" },
  { value: "author", label: "Author" },
  { value: "newest", label: "Recently Added" },
  { value: "published", label: "Publication Date" },
]

const DEBOUNCE_MS = 300

interface CatalogBrowserProps {
  initial: CatalogPage
  initialQuery: string
  initialTag: string
}

export default function CatalogBrowser({ initial, initialQuery, initialTag }: CatalogBrowserProps) {
  const [query, setQuery] = useState(initialQuery)
  const [sort, setSort] = useState(initial.sort)
  // the server's normalized tag when it recognised one, else the raw param, so an unknown
  // ?tag= stays applied (and clearable) rather than silently dropping to an unfiltered catalog
  const tag = initial.tag ?? initialTag
  const [page, setPage] = useState(initial.pagy.page)
  const [data, setData] = useState<CatalogPage>(initial)
  const [loading, setLoading] = useState(false)
  const isFirstRender = useRef(true)

  // One builder for both the JSON fetch and the tag links, so the two can't drift apart.
  const buildParams = (tagValue: string) => {
    const params = new URLSearchParams()
    if (query.trim()) params.set("q", query.trim())
    if (tagValue) params.set("tag", tagValue)
    params.set("sort", sort)
    return params
  }

  useEffect(() => {
    if (isFirstRender.current) {
      isFirstRender.current = false
      return
    }

    const controller = new AbortController()
    const timeout = setTimeout(() => {
      setLoading(true)
      const params = buildParams(tag)
      params.set("page", String(page))

      fetch(`/books.json?${params.toString()}`, {
        signal: controller.signal,
        headers: { Accept: "application/json" },
      })
        .then((response) => {
          if (!response.ok) throw new Error(`Catalog search failed: ${response.status}`)
          return response.json()
        })
        .then((result: CatalogPage) => setData(result))
        .catch((error: unknown) => {
          if ((error as { name?: string }).name !== "AbortError") {
            setData((current) => ({
              books: [],
              sort,
              tag: current.tag,
              genre_tags: current.genre_tags,
              mood_tags: current.mood_tags,
              pace_tags: current.pace_tags,
              pagy: { page: 1, pages: 1, count: 0 },
            }))
          }
        })
        .finally(() => setLoading(false))
    }, DEBOUNCE_MS)

    return () => {
      clearTimeout(timeout)
      controller.abort()
    }
  }, [query, sort, page])

  const handleQueryChange = (value: string) => {
    setQuery(value)
    setPage(1)
  }

  const handleSortChange = (value: string) => {
    setSort(value)
    setPage(1)
  }

  // Tag filters are real links that navigate (community_bookshelf#224 #12), so the
  // filtered view has a shareable URL; the island re-hydrates from these params.
  const tagHref = (value: string) => `/books?${buildParams(value).toString()}`

  return (
    <div>
      <div className="row g-2 mb-4">
        <div className="col-sm-8 col-md-6">
          <label className="visually-hidden" htmlFor="catalog_q">
            Search
          </label>
          <input
            type="text"
            id="catalog_q"
            className="form-control"
            placeholder="Search by title or author..."
            autoComplete="off"
            value={query}
            onChange={(event) => handleQueryChange(event.target.value)}
          />
        </div>
        <div className="col-sm-4 col-md-3">
          <label className="visually-hidden" htmlFor="catalog_sort">
            Sort by
          </label>
          <select
            id="catalog_sort"
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

      {([
        ["Genre", data.genre_tags],
        ["Mood", data.mood_tags],
        ["Pace", data.pace_tags],
      ] as const).map(
        ([label, tags]) =>
          tags.length > 0 && (
            <div key={label} className="d-flex flex-wrap align-items-center gap-1 mb-2">
              <span className="text-muted small me-1">Browse by {label.toLowerCase()}:</span>
              {tags.map((chipTag) => (
                <a
                  key={chipTag.name}
                  href={tagHref(tag === chipTag.name ? "" : chipTag.name)}
                  className={`badge text-decoration-none ${tag === chipTag.name ? "text-bg-primary" : "text-bg-secondary"}`}
                  aria-current={tag === chipTag.name ? "true" : undefined}
                >
                  {chipTag.name}
                </a>
              ))}
            </div>
          )
      )}
      {tag && (
        <a href={tagHref("")} className="d-inline-block small mb-3">
          Clear tag filter
        </a>
      )}

      {data.books.length === 0 ? (
        <div className="text-center text-muted py-5">
          <p className="fs-5">No books found.</p>
        </div>
      ) : (
        <div className="row row-cols-1 row-cols-sm-2 row-cols-md-3 row-cols-lg-4 g-4">
          {data.books.map((book) => (
            <div className="col" key={book.id}>
              <a href={book.path} className="text-decoration-none text-dark">
                <div className="card h-100">
                  {book.cover_url ? (
                    <img
                      src={book.cover_url}
                      className="card-img-top"
                      style={{ objectFit: "cover", height: 200 }}
                      alt={book.title}
                      loading="lazy"
                    />
                  ) : (
                    <div
                      className="book-placeholder d-flex align-items-center justify-content-center"
                      style={{ height: 200 }}
                    >
                      <i className="fasl fa-book-open-cover fa-3x text-white opacity-50" />
                    </div>
                  )}
                  <div className="card-body">
                    <h5 className="card-title">{book.title}</h5>
                    <p className="card-text text-muted mb-1">{book.author}</p>
                    <p className="card-text">
                      <small className="text-muted">Added by {book.added_by_name}</small>
                    </p>
                  </div>
                </div>
              </a>
            </div>
          ))}
        </div>
      )}

      {data.pagy.pages > 1 && (
        <nav aria-label="Book catalog pagination" className="mt-4 d-flex justify-content-center gap-2">
          <button
            type="button"
            className="btn btn-outline-secondary btn-sm"
            disabled={data.pagy.page <= 1}
            onClick={() => setPage(data.pagy.page - 1)}
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
            onClick={() => setPage(data.pagy.page + 1)}
          >
            Next
          </button>
        </nav>
      )}
    </div>
  )
}
