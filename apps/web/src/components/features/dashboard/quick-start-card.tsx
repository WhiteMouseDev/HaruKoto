"use client"

import Link from "next/link"
import { motion } from "framer-motion"
import { Card, CardContent } from "@/components/ui/card"

type QuickStartCardProps = {
  jlptLevel: string
}

export function QuickStartCard({ jlptLevel }: QuickStartCardProps) {
  return (
    <Link href="/study">
      <motion.div whileTap={{ scale: 0.98 }}>
        <Card className="border-primary/30 bg-gradient-to-r from-primary/10 to-accent">
          <CardContent className="flex items-center gap-4 p-4">
            <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-primary text-2xl">
              🌸
            </div>
            <div className="flex-1">
              <h3 className="font-semibold">학습 시작하기</h3>
              <p className="text-sm text-muted-foreground">
                JLPT {jlptLevel} 단어부터 시작해보세요!
              </p>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </Link>
  )
}
