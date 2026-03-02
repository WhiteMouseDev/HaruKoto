'use client';

import { useState, useRef, useEffect } from 'react';
import { Send, Lightbulb } from 'lucide-react';
import { Button } from '@/components/ui/button';

type ChatInputProps = {
  onSend: (message: string) => void;
  onHint: () => void;
  hint: string | null;
  disabled: boolean;
};

export function ChatInput({ onSend, onHint, hint, disabled }: ChatInputProps) {
  const [message, setMessage] = useState('');
  const inputRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (!disabled && inputRef.current) {
      inputRef.current.focus();
    }
  }, [disabled]);

  function handleSend() {
    const trimmed = message.trim();
    if (!trimmed || disabled) return;
    onSend(trimmed);
    setMessage('');
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  }

  return (
    <div className="border-t bg-background safe-area-bottom">
      {/* Hint display */}
      {hint && (
        <div className="bg-hk-yellow/10 border-hk-yellow/30 border-b px-4 py-2">
          <p className="text-xs">
            <span className="font-medium">💡 힌트:</span>{' '}
            <span className="font-jp">{hint}</span>
          </p>
        </div>
      )}

      <div className="flex items-end gap-2 p-3">
        <Button
          variant="ghost"
          size="icon"
          onClick={onHint}
          disabled={disabled}
          className="text-hk-yellow shrink-0"
        >
          <Lightbulb className="size-5" />
        </Button>

        <textarea
          ref={inputRef}
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="일본어로 입력하세요..."
          disabled={disabled}
          rows={1}
          className="font-jp border-input bg-secondary/50 max-h-24 min-h-[40px] flex-1 resize-none rounded-xl border px-3 py-2.5 text-sm outline-none focus:ring-2 focus:ring-primary/30 disabled:opacity-50"
        />

        <Button
          size="icon"
          onClick={handleSend}
          disabled={disabled || !message.trim()}
          className="shrink-0 rounded-full"
        >
          <Send className="size-4" />
        </Button>
      </div>
    </div>
  );
}
