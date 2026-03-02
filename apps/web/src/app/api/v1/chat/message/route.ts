import { NextResponse } from "next/server"
import { createClient } from "@/lib/supabase/server"
import { prisma } from "@harukoto/database"
import { generateText } from "ai"
import { getAIProvider } from "@harukoto/ai"

type MessageRole = "system" | "user" | "assistant"

interface StoredMessage {
  role: MessageRole
  content: string
}

interface AIResponse {
  messageJa: string
  messageKo: string
  feedback: {
    type: string
    original: string
    correction: string
    explanationKo: string
  }[]
  hint: string
  newVocabulary: {
    word: string
    reading: string
    meaningKo: string
  }[]
}

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
    const { conversationId, message } = body

    if (!conversationId || !message) {
      return NextResponse.json(
        { error: "conversationId and message are required" },
        { status: 400 }
      )
    }

    const conversation = await prisma.conversation.findUnique({
      where: { id: conversationId },
    })
    if (!conversation) {
      return NextResponse.json(
        { error: "Conversation not found" },
        { status: 404 }
      )
    }
    if (conversation.userId !== user.id) {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 })
    }
    if (conversation.endedAt) {
      return NextResponse.json(
        { error: "Conversation has ended" },
        { status: 400 }
      )
    }

    // Load existing messages
    const storedMessages = conversation.messages as unknown as StoredMessage[]

    // Separate system prompt from conversation history
    const systemMessage = storedMessages.find((m) => m.role === "system")
    const conversationHistory = storedMessages
      .filter((m) => m.role !== "system")
      .map((m) => ({
        role: m.role as "user" | "assistant",
        content: m.content,
      }))

    // Add user's new message
    conversationHistory.push({ role: "user", content: message })

    // Call AI
    const { text } = await generateText({
      model: getAIProvider(),
      system: systemMessage?.content || "",
      messages: conversationHistory,
    })

    // Parse AI response
    let parsed: AIResponse
    try {
      const jsonMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/) || [
        null,
        text,
      ]
      parsed = JSON.parse(jsonMatch[1]!.trim())
    } catch {
      parsed = {
        messageJa: text,
        messageKo: "(번역을 불러올 수 없습니다)",
        feedback: [],
        hint: "",
        newVocabulary: [],
      }
    }

    // Update conversation with new messages
    const updatedMessages: StoredMessage[] = [
      ...storedMessages,
      { role: "user", content: message },
      { role: "assistant", content: text },
    ]

    await prisma.conversation.update({
      where: { id: conversationId },
      data: {
        messages: JSON.parse(JSON.stringify(updatedMessages)),
        messageCount: { increment: 1 },
      },
    })

    return NextResponse.json({
      messageJa: parsed.messageJa,
      messageKo: parsed.messageKo,
      feedback: parsed.feedback || [],
      hint: parsed.hint || "",
      newVocabulary: parsed.newVocabulary || [],
    })
  } catch (err) {
    console.error("Chat message error:", err)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
