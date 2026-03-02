import { toast } from 'sonner';

type GameEvent = {
  type: 'level_up' | 'streak' | 'achievement';
  data: Record<string, unknown>;
};

export function showGameEvents(events?: GameEvent[]) {
  if (!events?.length) return;
  events.forEach((event, i) => {
    setTimeout(() => {
      switch (event.type) {
        case 'level_up':
          toast.success(`🎉 레벨 업! 레벨 ${event.data.newLevel} 도달!`);
          break;
        case 'streak':
          toast.success(`🔥 ${event.data.streakCount}일째 연속 학습 중!`);
          break;
        case 'achievement':
          toast.success(`🏆 업적 달성! ${event.data.emoji} ${event.data.label}`);
          break;
      }
    }, i * 800);
  });
}
