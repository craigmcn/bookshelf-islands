import { useState } from "react"

export interface RatingOption {
  key: string
  value: number
  label: string
}

interface RatingPickerProps {
  options: RatingOption[]
  initialValue?: string
  onChange: (key: string) => void
}

export default function RatingPicker({ options, initialValue, onChange }: RatingPickerProps) {
  const [selectedKey, setSelectedKey] = useState(initialValue ?? "")
  const [hoverKey, setHoverKey] = useState<string | null>(null)

  const selected = options.find((option) => option.key === selectedKey) ?? null
  const displayKey = hoverKey ?? selectedKey
  const displayValue = options.find((option) => option.key === displayKey)?.value ?? 0

  const selectOption = (option: RatingOption) => {
    const nextKey = option.key === selectedKey ? "" : option.key
    setSelectedKey(nextKey)
    onChange(nextKey)
  }

  return (
    <div className="d-flex align-items-center gap-2">
      <div role="radiogroup" aria-label="Rating" className="d-flex gap-1">
        {options.map((option) => (
          <button
            key={option.key}
            type="button"
            role="radio"
            aria-checked={option.key === selectedKey}
            aria-label={option.label}
            className="btn btn-link p-0 border-0"
            style={{ fontSize: "1.5rem", lineHeight: 1 }}
            onMouseEnter={() => setHoverKey(option.key)}
            onMouseLeave={() => setHoverKey(null)}
            onClick={() => selectOption(option)}
          >
            <i
              className={option.value <= displayValue ? "fas fa-star text-warning" : "far fa-star text-secondary"}
              aria-hidden="true"
            />
          </button>
        ))}
      </div>
      <span className="text-muted small">{selected ? selected.label : "No rating"}</span>
    </div>
  )
}
