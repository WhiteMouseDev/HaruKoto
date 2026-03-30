'use client';

export function NavBadge({ count }: { count: number }) {
  if (count === 0) return null;
  return (
    <span className="ml-auto flex h-5 min-w-5 items-center justify-center rounded-full bg-primary/15 px-1 text-[10px] font-semibold text-primary">
      {count > 99 ? '99+' : count}
    </span>
  );
}
