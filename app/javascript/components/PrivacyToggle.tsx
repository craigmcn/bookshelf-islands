import { useState } from "react"

interface PrivacyToggleProps {
  initialValue: boolean
  onChange: (isPublic: boolean) => void
}

export default function PrivacyToggle({ initialValue, onChange }: PrivacyToggleProps) {
  const [isPublic, setIsPublic] = useState(initialValue)

  const toggle = () => {
    const next = !isPublic
    setIsPublic(next)
    onChange(next)
  }

  return (
    <div className="form-check form-switch">
      <input
        type="checkbox"
        role="switch"
        id="review_public_toggle"
        className="form-check-input"
        checked={isPublic}
        onChange={toggle}
      />
      <label className="form-check-label" htmlFor="review_public_toggle">
        {isPublic ? "Review is public" : "Review is private"}
      </label>
    </div>
  )
}
