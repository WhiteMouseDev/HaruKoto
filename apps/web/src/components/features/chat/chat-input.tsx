'use client';

import { useState, useRef, useEffect } from 'react';
import { Send, Lightbulb, Mic } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { VoiceInput } from '@/components/features/chat/voice-input';

type ChatInputProps = {
  onSend: (message: string) => void;
  onHint: () => void;
  hint: string | null;
  disabled: boolean;
  voiceEnabled?: boolean;
};

export function ChatInput({
  onSend,
  onHint,
  hint,
  disabled,
  voiceEnabled = false,
}: ChatInputProps) {
  const [message, setMessage] = useState('');
  const [voiceMode, setVoiceMode] = useState(false);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (!disabled && !voiceMode && inputRef.current) {
      inputRef.current.focus();
    }
  }, [disabled, voiceMode]);

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

  function handleVoiceSend(text: string) {
    onSend(text);
    setVoiceMode(false);
  }

  // Voice input mode
  if (voiceMode && voiceEnabled) {
    return (
      <VoiceInput
        onSend={handleVoiceSend}
        disabled={disabled}
        onCancel={() => setVoiceMode(false)}
      />
    );
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

        {voiceEnabled && (
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setVoiceMode(true)}
            disabled={disabled}
            className="text-muted-foreground shrink-0"
          >
            <Mic className="size-5" />
          </Button>
        )}

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
