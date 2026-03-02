import { BottomNav } from "@/components/layout/bottom-nav"

export default function AppLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="flex min-h-dvh flex-col">
      <main className="mx-auto w-full max-w-lg flex-1 pb-20">{children}</main>
      <BottomNav />
    </div>
  )
}
