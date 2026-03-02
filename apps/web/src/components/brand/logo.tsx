import Image from 'next/image';

type LogoVariant = 'symbol' | 'full';
type LogoSize = 'sm' | 'md' | 'lg' | 'xl';

const sizeMap: Record<LogoSize, number> = {
  sm: 32,
  md: 48,
  lg: 64,
  xl: 96,
};

type LogoProps = {
  variant?: LogoVariant;
  size?: LogoSize | number;
  className?: string;
};

/**
 * 하루코토 로고 컴포넌트
 *
 * - variant="symbol": 심볼만 (정사각형)
 * - variant="full": 심볼 + 서비스명 (가로형)
 */
export function Logo({ variant = 'symbol', size = 'md', className }: LogoProps) {
  const px = typeof size === 'number' ? size : sizeMap[size];

  if (variant === 'full') {
    // 가로형 로고 (원본 비율 약 3.18:1)
    const width = Math.round(px * 3.18);
    return (
      <Image
        src="/images/logo-horizontal.svg"
        alt="하루코토"
        width={width}
        height={px}
        className={className}
        priority
      />
    );
  }

  return (
    <Image
      src="/images/logo-symbol.svg"
      alt="하루코토"
      width={px}
      height={px}
      className={className}
      priority
    />
  );
}
