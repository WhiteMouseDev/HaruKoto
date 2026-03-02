import { createElement } from 'react';
import { toast } from 'sonner';
import { Flame, PartyPopper } from 'lucide-react';
import { GameIcon } from '@/components/ui/game-icon';

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
          toast.success(`레벨 업! 레벨 ${event.data.newLevel} 도달!`, {
            icon: createElement(PartyPopper, { className: 'size-4' }),
          });
          break;
        case 'streak':
          toast.success(`${event.data.streakCount}일째 연속 학습 중!`, {
            icon: createElement(Flame, { className: 'size-4' }),
          });
          break;
        case 'achievement':
          toast.success(`업적 달성! ${event.data.label}`, {
            icon: createElement(GameIcon, {
              name: (event.data.emoji as string) || 'trophy',
              className: 'size-4',
            }),
          });
          break;
      }
    }, i * 800);
  });
}
