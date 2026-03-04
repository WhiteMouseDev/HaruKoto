import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { prisma } from '@harukoto/database';

type MissionDef = {
  missionType: string;
  label: string;
  description: string;
  targetCount: number;
  xpReward: number;
  progressField: keyof DailyProgressFields;
};

type DailyProgressFields = {
  wordsStudied: number;
  quizzesCompleted: number;
  correctAnswers: number;
  conversationCount: number;
  kanaLearned: number;
};

const MISSION_POOL: MissionDef[] = [
  { missionType: 'words_5', label: '단어 학습 5개', description: '오늘 단어 5개를 학습하세요', targetCount: 5, xpReward: 10, progressField: 'wordsStudied' },
  { missionType: 'words_10', label: '단어 학습 10개', description: '오늘 단어 10개를 학습하세요', targetCount: 10, xpReward: 20, progressField: 'wordsStudied' },
  { missionType: 'quiz_1', label: '퀴즈 1회 완료', description: '퀴즈를 1번 완료하세요', targetCount: 1, xpReward: 10, progressField: 'quizzesCompleted' },
  { missionType: 'quiz_3', label: '퀴즈 3회 완료', description: '퀴즈를 3번 완료하세요', targetCount: 3, xpReward: 25, progressField: 'quizzesCompleted' },
  { missionType: 'correct_10', label: '정답 10개', description: '문제를 10개 맞추세요', targetCount: 10, xpReward: 15, progressField: 'correctAnswers' },
  { missionType: 'correct_20', label: '정답 20개', description: '문제를 20개 맞추세요', targetCount: 20, xpReward: 30, progressField: 'correctAnswers' },
  { missionType: 'chat_1', label: 'AI 회화 1회', description: 'AI와 대화를 1번 완료하세요', targetCount: 1, xpReward: 15, progressField: 'conversationCount' },
  { missionType: 'chat_2', label: 'AI 회화 2회', description: 'AI와 대화를 2번 완료하세요', targetCount: 2, xpReward: 30, progressField: 'conversationCount' },
  { missionType: 'kana_learn_5', label: '가나 5자 학습', description: '오늘 가나 5자를 배우세요', targetCount: 5, xpReward: 15, progressField: 'kanaLearned' },
];

/**
 * 날짜 + userId를 시드로 사용해 매일 결정적으로 3개 미션 선택
 */
function selectDailyMissions(userId: string, date: Date): MissionDef[] {
  const dateStr = `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`;
  let hash = 0;
  const seed = dateStr + userId;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) | 0;
  }

  // 카테고리별 그룹화 (같은 progressField 중복 방지)
  const byCategory = new Map<string, MissionDef[]>();
  for (const m of MISSION_POOL) {
    const arr = byCategory.get(m.progressField) ?? [];
    arr.push(m);
    byCategory.set(m.progressField, arr);
  }

  const categories = Array.from(byCategory.keys());
  const selected: MissionDef[] = [];
  let h = Math.abs(hash);

  // 카테고리 셔플 후 3개 선택
  const shuffled = categories.sort(() => {
    const ha = ((h = (h * 1103515245 + 12345) | 0), Math.abs(h));
    const hb = ((h = (h * 1103515245 + 12345) | 0), Math.abs(h));
    return (ha % 100) - (hb % 100);
  });

  for (const cat of shuffled) {
    if (selected.length >= 3) break;
    const pool = byCategory.get(cat)!;
    h = (h * 1103515245 + 12345) | 0;
    selected.push(pool[Math.abs(h) % pool.length]);
  }

  return selected;
}

export async function GET() {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: '인증이 필요합니다' }, { status: 401 });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // 오늘 미션이 있는지 확인
    let missions = await prisma.dailyMission.findMany({
      where: { userId: user.id, date: today },
      orderBy: { missionType: 'asc' },
    });

    // 없으면 자동 생성
    if (missions.length === 0) {
      const selected = selectDailyMissions(user.id, today);
      await prisma.dailyMission.createMany({
        data: selected.map((m) => ({
          userId: user.id,
          date: today,
          missionType: m.missionType,
          targetCount: m.targetCount,
          currentCount: 0,
        })),
      });
      missions = await prisma.dailyMission.findMany({
        where: { userId: user.id, date: today },
        orderBy: { missionType: 'asc' },
      });
    }

    // DailyProgress로 현재 진행 상황 동기화
    const progress = await prisma.dailyProgress.findUnique({
      where: { userId_date: { userId: user.id, date: today } },
    });

    const defs = new Map(MISSION_POOL.map((m) => [m.missionType, m]));

    const result = missions.map((m) => {
      const def = defs.get(m.missionType);
      if (!def) {
        return {
          id: m.id,
          missionType: m.missionType,
          label: m.missionType,
          description: '',
          targetCount: m.targetCount,
          currentCount: m.currentCount,
          isCompleted: m.isCompleted,
          rewardClaimed: m.rewardClaimed,
          xpReward: 10,
        };
      }

      // DailyProgress에서 실제 진행량 반영
      const actualCount = progress
        ? Math.min(progress[def.progressField] as number, m.targetCount)
        : m.currentCount;
      const isCompleted = actualCount >= m.targetCount;

      return {
        id: m.id,
        missionType: m.missionType,
        label: def.label,
        description: def.description,
        targetCount: m.targetCount,
        currentCount: actualCount,
        isCompleted,
        rewardClaimed: m.rewardClaimed,
        xpReward: def.xpReward,
      };
    });

    // DB 진행 상황도 업데이트 (변경된 미션만 병렬 업데이트)
    if (progress) {
      const updates = missions
        .map((m) => {
          const def = defs.get(m.missionType);
          if (!def) return null;
          const actual = Math.min(
            progress[def.progressField] as number,
            m.targetCount
          );
          const completed = actual >= m.targetCount;
          if (actual !== m.currentCount || completed !== m.isCompleted) {
            return prisma.dailyMission.update({
              where: { id: m.id },
              data: { currentCount: actual, isCompleted: completed },
            });
          }
          return null;
        })
        .filter(Boolean);
      if (updates.length > 0) {
        await Promise.all(updates);
      }
    }

    const completedCount = result.filter((m) => m.isCompleted).length;

    return NextResponse.json(
      {
        missions: result,
        completedCount,
        totalCount: result.length,
      },
      { headers: { 'Cache-Control': 'private, no-cache' } }
    );
  } catch (err) {
    console.error('Daily missions GET error:', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
