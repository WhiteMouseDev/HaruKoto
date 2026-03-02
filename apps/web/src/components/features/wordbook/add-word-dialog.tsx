'use client';

import { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Button } from '@/components/ui/button';

type AddWordData = {
  word: string;
  reading: string;
  meaningKo: string;
  note?: string;
};

type AddWordDialogProps = {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onAdd: (data: AddWordData) => void;
};

export function AddWordDialog({ open, onOpenChange, onAdd }: AddWordDialogProps) {
  const [word, setWord] = useState('');
  const [reading, setReading] = useState('');
  const [meaningKo, setMeaningKo] = useState('');
  const [note, setNote] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});

  function resetForm() {
    setWord('');
    setReading('');
    setMeaningKo('');
    setNote('');
    setErrors({});
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();

    const newErrors: Record<string, string> = {};
    if (!word.trim()) newErrors.word = '단어를 입력해주세요';
    if (!reading.trim()) newErrors.reading = '읽기를 입력해주세요';
    if (!meaningKo.trim()) newErrors.meaningKo = '뜻을 입력해주세요';

    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      return;
    }

    onAdd({
      word: word.trim(),
      reading: reading.trim(),
      meaningKo: meaningKo.trim(),
      note: note.trim() || undefined,
    });
    resetForm();
    onOpenChange(false);
  }

  return (
    <Dialog
      open={open}
      onOpenChange={(v) => {
        if (!v) resetForm();
        onOpenChange(v);
      }}
    >
      <DialogContent>
        <DialogHeader>
          <DialogTitle>단어 추가</DialogTitle>
          <DialogDescription>단어장에 새로운 단어를 추가합니다.</DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="flex flex-col gap-2">
            <Label htmlFor="word">단어 *</Label>
            <Input
              id="word"
              placeholder="例: 食べる"
              value={word}
              onChange={(e) => {
                setWord(e.target.value);
                setErrors((prev) => ({ ...prev, word: '' }));
              }}
              aria-invalid={!!errors.word}
            />
            {errors.word && (
              <p className="text-destructive text-xs">{errors.word}</p>
            )}
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor="reading">읽기 *</Label>
            <Input
              id="reading"
              placeholder="例: たべる"
              value={reading}
              onChange={(e) => {
                setReading(e.target.value);
                setErrors((prev) => ({ ...prev, reading: '' }));
              }}
              aria-invalid={!!errors.reading}
            />
            {errors.reading && (
              <p className="text-destructive text-xs">{errors.reading}</p>
            )}
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor="meaningKo">뜻 (한국어) *</Label>
            <Input
              id="meaningKo"
              placeholder="例: 먹다"
              value={meaningKo}
              onChange={(e) => {
                setMeaningKo(e.target.value);
                setErrors((prev) => ({ ...prev, meaningKo: '' }));
              }}
              aria-invalid={!!errors.meaningKo}
            />
            {errors.meaningKo && (
              <p className="text-destructive text-xs">{errors.meaningKo}</p>
            )}
          </div>

          <div className="flex flex-col gap-2">
            <Label htmlFor="note">메모</Label>
            <Input
              id="note"
              placeholder="선택 사항"
              value={note}
              onChange={(e) => setNote(e.target.value)}
            />
          </div>

          <DialogFooter>
            <Button type="submit" className="w-full h-10 rounded-xl">
              추가하기
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
