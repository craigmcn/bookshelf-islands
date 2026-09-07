import { useState } from "react"

interface ProgressPickerProps {
  initialValue: string
  onChange: (value: string) => void
}

const QUICK_VALUES = [25, 50, 75, 100]

export default function ProgressPicker({ initialValue, onChange }: ProgressPickerProps) {
  const [percent, setPercent] = useState<number | null>(initialValue === "" ? null : Number(initialValue))

  const setValue = (value: number | null) => {
    setPercent(value)
    onChange(value === null ? "" : String(value))
  }

  const displayPercent = percent ?? 0

  return (
    <div>
      <div className="d-flex align-items-center gap-2 mb-2">
        <div className="progress flex-grow-1" style={{ height: "0.5rem" }}>
          <div
            className="progress-bar"
            role="progressbar"
            style={{ width: `${displayPercent}%` }}
            aria-valuenow={displayPercent}
            aria-valuemin={0}
            aria-valuemax={100}
          />
        </div>
        <span className="text-muted small" style={{ minWidth: "3ch" }}>
          {percent === null ? "—" : `${percent}%`}
        </span>
      </div>
      <input
        type="range"
        className="form-range"
        min={0}
        max={100}
        value={displayPercent}
        aria-label="Progress percent"
        onChange={(event) => setValue(Number(event.target.value))}
      />
      <div className="d-flex gap-1 flex-wrap">
        {QUICK_VALUES.map((value) => (
          <button
            key={value}
            type="button"
            className={`btn btn-sm ${percent === value ? "btn-primary" : "btn-outline-secondary"}`}
            onClick={() => setValue(value)}
          >
            {value}%
          </button>
        ))}
        <button type="button" className="btn btn-sm btn-outline-secondary" onClick={() => setValue(null)}>
          Clear
        </button>
      </div>
    </div>
  )
}
