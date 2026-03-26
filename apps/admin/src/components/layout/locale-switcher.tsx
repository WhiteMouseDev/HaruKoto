'use client';

import { Globe } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

type LocaleSwitcherProps = {
  currentLocale: string;
};

const LOCALES = [
  { code: 'ja', nativeLabel: '日本語' },
  { code: 'ko', nativeLabel: '한국어' },
  { code: 'en', nativeLabel: 'English' },
];

export function LocaleSwitcher({ currentLocale }: LocaleSwitcherProps) {
  const router = useRouter();

  const currentLocaleEntry = LOCALES.find((l) => l.code === currentLocale);
  const currentLabel = currentLocaleEntry?.nativeLabel ?? currentLocale;

  async function switchLocale(locale: string) {
    await fetch('/api/locale', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ locale }),
    });
    router.refresh();
  }

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="sm" className="min-w-[80px] gap-2">
          <Globe className="size-4" />
          <span>{currentLabel}</span>
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {LOCALES.map((locale) => (
          <DropdownMenuItem
            key={locale.code}
            onClick={() => switchLocale(locale.code)}
            className={
              locale.code === currentLocale
                ? 'font-semibold text-primary'
                : undefined
            }
          >
            {locale.nativeLabel}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
