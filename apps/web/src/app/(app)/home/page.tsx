import { Flame, Target, BookOpen, Trophy } from "lucide-react"
import { Card, CardContent } from "@/components/ui/card"

export default function HomePage() {
  return (
    <div className="flex flex-col gap-6 p-4">
      {/* Header */}
      <div className="flex items-center justify-between pt-2">
        <div>
          <p className="text-sm text-muted-foreground">おはよう!</p>
          <h1 className="text-2xl font-bold">안녕하세요 👋</h1>
        </div>
        <div className="flex items-center gap-1 rounded-full bg-accent px-3 py-1.5">
          <Flame className="size-4 text-hk-red" />
          <span className="text-sm font-semibold">0일</span>
        </div>
      </div>

      {/* Today's Progress */}
      <Card>
        <CardContent className="flex flex-col gap-3 p-4">
          <h2 className="font-semibold">오늘의 학습</h2>
          <div className="grid grid-cols-3 gap-3">
            <div className="flex flex-col items-center gap-1 rounded-xl bg-secondary p-3">
              <Target className="size-5 text-primary" />
              <span className="text-xs text-muted-foreground">목표</span>
              <span className="text-lg font-bold">0/10</span>
            </div>
            <div className="flex flex-col items-center gap-1 rounded-xl bg-secondary p-3">
              <BookOpen className="size-5 text-hk-blue" />
              <span className="text-xs text-muted-foreground">단어</span>
              <span className="text-lg font-bold">0개</span>
            </div>
            <div className="flex flex-col items-center gap-1 rounded-xl bg-secondary p-3">
              <Trophy className="size-5 text-hk-yellow" />
              <span className="text-xs text-muted-foreground">정답률</span>
              <span className="text-lg font-bold">--%</span>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Quick Start */}
      <Card className="border-primary/30 bg-gradient-to-r from-primary/10 to-accent">
        <CardContent className="flex items-center gap-4 p-4">
          <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-primary text-2xl">
            🌸
          </div>
          <div className="flex-1">
            <h3 className="font-semibold">학습 시작하기</h3>
            <p className="text-sm text-muted-foreground">
              JLPT N5 단어부터 시작해보세요!
            </p>
          </div>
        </CardContent>
      </Card>

      {/* Level Progress */}
      <div>
        <h2 className="mb-3 font-semibold">JLPT 레벨</h2>
        <div className="grid grid-cols-5 gap-2">
          {(["N5", "N4", "N3", "N2", "N1"] as const).map((level, i) => (
            <div
              key={level}
              className={`flex flex-col items-center gap-1 rounded-xl border p-3 ${
                i === 0
                  ? "border-primary bg-primary/10"
                  : "border-border opacity-50"
              }`}
            >
              <span className="text-sm font-bold">{level}</span>
              <span className="text-[10px] text-muted-foreground">
                {i === 0 ? "학습중" : "잠금"}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
