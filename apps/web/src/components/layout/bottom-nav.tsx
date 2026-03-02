"use client"

import Link from "next/link"
import { usePathname } from "next/navigation"
import {
  Home,
  BarChart3,
  BookOpen,
  MessageCircle,
  User,
  Crown,
} from "lucide-react"
import { cn } from "@/lib/utils"

type Tab = {
  href: string
  label: string
  icon: typeof Home
  premium?: boolean
}

const tabs: Tab[] = [
  { href: "/home", label: "홈", icon: Home },
  { href: "/stats", label: "학습통계", icon: BarChart3 },
  { href: "/study", label: "학습", icon: BookOpen },
  { href: "/chat", label: "회화", icon: MessageCircle, premium: true },
  { href: "/my", label: "MY", icon: User },
]

export function BottomNav() {
  const pathname = usePathname()

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 border-t bg-background/95 backdrop-blur-sm safe-area-bottom">
      <div className="mx-auto flex h-16 max-w-lg items-center justify-around px-2">
        {tabs.map((tab) => {
          const isActive = pathname.startsWith(tab.href)
          const Icon = tab.icon

          return (
            <Link
              key={tab.href}
              href={tab.href}
              className={cn(
                "relative flex flex-1 flex-col items-center gap-0.5 py-1.5 text-[10px] transition-colors",
                isActive
                  ? "text-primary font-semibold"
                  : "text-muted-foreground hover:text-foreground"
              )}
            >
              <div className="relative">
                <Icon
                  className={cn(
                    "size-5 transition-all",
                    isActive && "fill-primary/20"
                  )}
                  strokeWidth={isActive ? 2.5 : 2}
                />
                {tab.premium && (
                  <Crown className="absolute -top-1.5 -right-2 size-2.5 fill-hk-yellow text-hk-yellow" />
                )}
              </div>
              <span>{tab.label}</span>
              {isActive && (
                <span className="absolute -top-px left-1/2 h-0.5 w-8 -translate-x-1/2 rounded-full bg-primary" />
              )}
            </Link>
          )
        })}
      </div>
    </nav>
  )
}
