"use client"

import * as React from "react"
import { Star } from "lucide-react"

import { cn } from "~/lib/utils"

interface StarRatingProps {
  value: number
  onValueChange: (value: number) => void
  disabled?: boolean
  max?: number
  className?: string
}

function StarRating({
  value,
  onValueChange,
  disabled = false,
  max = 5,
  className,
}: StarRatingProps) {
  const [hovered, setHovered] = React.useState<number | null>(null)
  const filled = hovered ?? value

  return (
    <div
      data-slot="star-rating"
      className={cn("flex flex-wrap items-center gap-0.5", className)}
      onMouseLeave={() => setHovered(null)}
    >
      {Array.from({ length: max }, (_, index) => index + 1).map((star) => (
        <button
          key={star}
          type="button"
          aria-pressed={value >= star}
          aria-label={`${star} of ${max} stars`}
          disabled={disabled}
          onClick={() => onValueChange(value === star ? 0 : star)}
          onMouseEnter={() => setHovered(star)}
          className={cn(
            "cursor-pointer rounded-sm p-0.5 transition-colors disabled:cursor-not-allowed disabled:opacity-50",
            filled >= star ? "text-yellow-400" : "text-gray-600 hover:text-yellow-400"
          )}
        >
          <Star
            className="h-5 w-5 sm:h-6 sm:w-6"
            fill={filled >= star ? "currentColor" : "none"}
            strokeWidth={1.5}
          />
        </button>
      ))}
      <span className="ml-2 text-sm text-gray-400">
        {value > 0 ? `${value} / ${max}` : "Not rated"}
      </span>
    </div>
  )
}

export { StarRating }