import Image from 'next/image';
import { cn } from '@/lib/utils';

type FoxMascotProps = {
  size?: number;
  className?: string;
};

export function FoxMascot({ size = 40, className }: FoxMascotProps) {
  return (
    <Image
      src="/images/fox.svg"
      alt="하루코토 여우"
      width={size}
      height={size}
      className={cn('inline-block', className)}
    />
  );
}
