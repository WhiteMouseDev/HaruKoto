import { Crown } from 'lucide-react';

export default function ChatPage() {
  return (
    <div className="flex flex-col gap-4 p-4">
      <div className="flex items-center gap-2 pt-2">
        <h1 className="text-2xl font-bold">AI 회화</h1>
        <span className="bg-hk-yellow/20 text-hk-yellow inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium">
          <Crown className="size-3" />
          Premium
        </span>
      </div>
      <p className="text-muted-foreground">
        AI와 함께하는 일본어 상황극 회화 연습이 곧 추가됩니다.
      </p>
    </div>
  );
}
