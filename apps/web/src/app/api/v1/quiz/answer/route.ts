import { NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"
import { prisma } from "@harukoto/database"
import { calculateSM2 } from "@/lib/spaced-repetition"

export async function POST(request: Request) {
  try {
    const supabase = await createClient()
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const body = await request.json()
    const {
      sessionId,
      questionId,
      selectedOptionId,
      isCorrect,
      timeSpentSeconds = 0,
      questionType = "VOCABULARY",
    } = body

    if (!sessionId || !questionId || !selectedOptionId) {
      return NextResponse.json(
        { error: "Missing required fields" },
        { status: 400 }
      )
    }

    // Save answer
    await prisma.quizAnswer.create({
      data: {
        sessionId,
        questionId,
        questionType,
        selectedOptionId,
        isCorrect,
        timeSpentSeconds,
      },
    })

    // Update correct count on session
    if (isCorrect) {
      await prisma.quizSession.update({
        where: { id: sessionId },
        data: { correctCount: { increment: 1 } },
      })
    }

    // Update spaced repetition progress
    if (questionType === "VOCABULARY") {
      const existing = await prisma.userVocabProgress.findUnique({
        where: {
          userId_vocabularyId: {
            userId: user.id,
            vocabularyId: questionId,
          },
        },
      })

      const sm2Result = calculateSM2({
        easeFactor: existing?.easeFactor ?? 2.5,
        interval: existing?.interval ?? 0,
        streak: existing?.streak ?? 0,
        isCorrect,
        timeSpentSeconds,
      })

      await prisma.userVocabProgress.upsert({
        where: {
          userId_vocabularyId: {
            userId: user.id,
            vocabularyId: questionId,
          },
        },
        update: {
          correctCount: isCorrect ? { increment: 1 } : undefined,
          incorrectCount: !isCorrect ? { increment: 1 } : undefined,
          streak: sm2Result.streak,
          easeFactor: sm2Result.easeFactor,
          interval: sm2Result.interval,
          nextReviewAt: sm2Result.nextReviewAt,
          lastReviewedAt: new Date(),
          mastered: sm2Result.interval >= 21,
        },
        create: {
          userId: user.id,
          vocabularyId: questionId,
          correctCount: isCorrect ? 1 : 0,
          incorrectCount: isCorrect ? 0 : 1,
          streak: sm2Result.streak,
          easeFactor: sm2Result.easeFactor,
          interval: sm2Result.interval,
          nextReviewAt: sm2Result.nextReviewAt,
          lastReviewedAt: new Date(),
        },
      })
    } else if (questionType === "GRAMMAR") {
      const existing = await prisma.userGrammarProgress.findUnique({
        where: {
          userId_grammarId: {
            userId: user.id,
            grammarId: questionId,
          },
        },
      })

      const sm2Result = calculateSM2({
        easeFactor: existing?.easeFactor ?? 2.5,
        interval: existing?.interval ?? 0,
        streak: existing?.streak ?? 0,
        isCorrect,
        timeSpentSeconds,
      })

      await prisma.userGrammarProgress.upsert({
        where: {
          userId_grammarId: {
            userId: user.id,
            grammarId: questionId,
          },
        },
        update: {
          correctCount: isCorrect ? { increment: 1 } : undefined,
          incorrectCount: !isCorrect ? { increment: 1 } : undefined,
          streak: sm2Result.streak,
          easeFactor: sm2Result.easeFactor,
          interval: sm2Result.interval,
          nextReviewAt: sm2Result.nextReviewAt,
          lastReviewedAt: new Date(),
          mastered: sm2Result.interval >= 21,
        },
        create: {
          userId: user.id,
          grammarId: questionId,
          correctCount: isCorrect ? 1 : 0,
          incorrectCount: isCorrect ? 0 : 1,
          streak: sm2Result.streak,
          easeFactor: sm2Result.easeFactor,
          interval: sm2Result.interval,
          nextReviewAt: sm2Result.nextReviewAt,
          lastReviewedAt: new Date(),
        },
      })
    }

    return NextResponse.json({ success: true })
  } catch (err) {
    console.error("Quiz answer error:", err)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
