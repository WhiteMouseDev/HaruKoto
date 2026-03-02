import { NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"
import { prisma } from "@harukoto/database"

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
    const { sessionId } = body

    if (!sessionId) {
      return NextResponse.json(
        { error: "sessionId is required" },
        { status: 400 }
      )
    }

    // Complete session
    const session = await prisma.quizSession.update({
      where: { id: sessionId, userId: user.id },
      data: { completedAt: new Date() },
      include: {
        answers: true,
      },
    })

    // Update daily progress
    const today = new Date()
    today.setHours(0, 0, 0, 0)

    await prisma.dailyProgress.upsert({
      where: {
        userId_date: { userId: user.id, date: today },
      },
      update: {
        quizzesCompleted: { increment: 1 },
        correctAnswers: { increment: session.correctCount },
        totalAnswers: { increment: session.totalQuestions },
        wordsStudied: { increment: session.totalQuestions },
        xpEarned: { increment: session.correctCount * 10 },
      },
      create: {
        userId: user.id,
        date: today,
        quizzesCompleted: 1,
        correctAnswers: session.correctCount,
        totalAnswers: session.totalQuestions,
        wordsStudied: session.totalQuestions,
        xpEarned: session.correctCount * 10,
      },
    })

    // Update user XP
    await prisma.user.update({
      where: { id: user.id },
      data: {
        experiencePoints: { increment: session.correctCount * 10 },
        lastStudyDate: new Date(),
      },
    })

    return NextResponse.json({
      sessionId: session.id,
      totalQuestions: session.totalQuestions,
      correctCount: session.correctCount,
      accuracy: Math.round(
        (session.correctCount / session.totalQuestions) * 100
      ),
      xpEarned: session.correctCount * 10,
    })
  } catch (err) {
    console.error("Quiz complete error:", err)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
