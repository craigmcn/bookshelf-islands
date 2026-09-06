import { useEffect, useRef, useState } from "react"

interface TagInputProps {
  initialTags: string
  onChange: (tagList: string) => void
}

const DEBOUNCE_MS = 300

function parseTags(value: string): string[] {
  return value
    .split(",")
    .map((tag) => tag.trim().toLowerCase())
    .filter(Boolean)
}

export default function TagInput({ initialTags, onChange }: TagInputProps) {
  const [tags, setTags] = useState<string[]>(() => parseTags(initialTags))
  const [query, setQuery] = useState("")
  const [suggestions, setSuggestions] = useState<string[]>([])
  const inputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    if (query.trim().length < 2) {
      setSuggestions([])
      return
    }

    const controller = new AbortController()
    const timeout = setTimeout(() => {
      fetch(`/tags.json?q=${encodeURIComponent(query.trim())}`, { signal: controller.signal })
        .then((response) => {
          if (!response.ok) throw new Error(`Tag search failed: ${response.status}`)
          return response.json()
        })
        .then((names: string[]) => setSuggestions(names.filter((name) => !tags.includes(name))))
        .catch((error: unknown) => {
          if ((error as { name?: string }).name !== "AbortError") setSuggestions([])
        })
    }, DEBOUNCE_MS)

    return () => {
      clearTimeout(timeout)
      controller.abort()
    }
  }, [query, tags])

  const addTag = (raw: string) => {
    const tag = raw.trim().toLowerCase()
    if (!tag) return
    setTags((current) => (current.includes(tag) ? current : [...current, tag]))
    setQuery("")
    setSuggestions([])
    inputRef.current?.focus()
  }

  const removeTag = (tag: string) => {
    setTags((current) => current.filter((t) => t !== tag))
  }

  useEffect(() => {
    onChange(tags.join(", "))
  }, [tags, onChange])

  const handleKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      addTag(query)
    } else if (event.key === "Backspace" && query === "" && tags.length > 0) {
      removeTag(tags[tags.length - 1])
    }
  }

  return (
    <div className="mb-3">
      <label className="form-label" htmlFor="tag_input">
        Genres
      </label>
      <div className="d-flex flex-wrap gap-2 mb-2">
        {tags.map((tag) => (
          <span key={tag} className="badge text-bg-secondary d-flex align-items-center gap-1">
            {tag}
            <button
              type="button"
              className="btn-close btn-close-white"
              style={{ fontSize: "0.55rem" }}
              aria-label={`Remove ${tag}`}
              onClick={() => removeTag(tag)}
            />
          </span>
        ))}
      </div>
      <input
        ref={inputRef}
        type="text"
        id="tag_input"
        className="form-control"
        placeholder="Type a genre and press Enter..."
        autoComplete="off"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        onKeyDown={handleKeyDown}
      />
      {suggestions.length > 0 && (
        <div className="list-group mt-2" aria-label="Genre suggestions">
          {suggestions.map((name) => (
            <button
              key={name}
              type="button"
              className="list-group-item list-group-item-action py-1"
              onClick={() => addTag(name)}
            >
              {name}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
