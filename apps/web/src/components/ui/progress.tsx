"use client"

import * as React from "react"
import { cn } from "@/lib/utils"

type ProgressProps = React.ComponentProps<"div"> & {
  value?: number
  max?: number
  indicatorClassName?: string
}

function Progress({
  className,
  value = 0,
  max = 100,
  indicatorClassName,
  ...props
}: ProgressProps) {
  const percentage = Math.min(Math.max((value / max) * 100, 0), 100)

  return (
    <div
      className={cn(
        "bg-secondary relative h-2 w-full overflow-hidden rounded-full",
        className
      )}
      {...props}
    >
      <div
        className={cn(
          "bg-primary h-full rounded-full transition-all duration-500 ease-out",
          indicatorClassName
        )}
        style={{ width: `${percentage}%` }}
      />
    </div>
  )
}

export { Progress }
