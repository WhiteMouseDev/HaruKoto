import type { SVGProps } from 'react';

type LogoVariant = 'symbol' | 'full';
type LogoSize = 'sm' | 'md' | 'lg' | 'xl';

const sizeMap: Record<LogoSize, number> = {
  sm: 32,
  md: 48,
  lg: 64,
  xl: 96,
};

type LogoProps = SVGProps<SVGSVGElement> & {
  variant?: LogoVariant;
  size?: LogoSize | number;
};

/**
 * 하루코토 로고 컴포넌트
 *
 * MVP placeholder: 벚꽃 심볼 + "ハル" 텍스트
 * 추후 Adobe Illustrator SVG로 교체 시 이 컴포넌트의 JSX만 업데이트하면
 * 앱 전체에 반영됩니다.
 *
 * @example
 * <Logo size="lg" />
 * <Logo variant="full" size={80} />
 * <Logo className="drop-shadow-md" />
 */
export function Logo({ variant = 'symbol', size = 'md', ...props }: LogoProps) {
  const px = typeof size === 'number' ? size : sizeMap[size];

  if (variant === 'full') {
    return <LogoFull width={px * 2.5} height={px} {...props} />;
  }

  return <LogoSymbol width={px} height={px} {...props} />;
}

/** 심볼 로고 (아이콘용) - 벚꽃 + ハル */
function LogoSymbol(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 192 192"
      fill="none"
      {...props}
    >
      <rect width="192" height="192" rx="32" fill="#FFB7C5" />
      {/* Cherry blossom petals */}
      <g transform="translate(96, 60)">
        {[0, 72, 144, 216, 288].map((deg) => (
          <ellipse
            key={deg}
            cx="0"
            cy="-18"
            rx="10"
            ry="18"
            fill="rgba(255,255,255,0.6)"
            transform={`rotate(${deg})`}
          />
        ))}
        <circle cx="0" cy="0" r="6" fill="rgba(255,255,255,0.9)" />
      </g>
      {/* ハル text */}
      <text
        x="96"
        y="140"
        textAnchor="middle"
        fontFamily="sans-serif"
        fontWeight="700"
        fontSize="48"
        fill="white"
      >
        ハル
      </text>
    </svg>
  );
}

/** 풀 로고 (텍스트 포함) - 심볼 + 하루코토 */
function LogoFull(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 400 120"
      fill="none"
      {...props}
    >
      {/* Symbol part */}
      <rect width="120" height="120" rx="24" fill="#FFB7C5" />
      <g transform="translate(60, 36)">
        {[0, 72, 144, 216, 288].map((deg) => (
          <ellipse
            key={deg}
            cx="0"
            cy="-12"
            rx="7"
            ry="12"
            fill="rgba(255,255,255,0.6)"
            transform={`rotate(${deg})`}
          />
        ))}
        <circle cx="0" cy="0" r="4" fill="rgba(255,255,255,0.9)" />
      </g>
      <text
        x="60"
        y="90"
        textAnchor="middle"
        fontFamily="sans-serif"
        fontWeight="700"
        fontSize="30"
        fill="white"
      >
        ハル
      </text>
      {/* Text part */}
      <text
        x="145"
        y="62"
        fontFamily="sans-serif"
        fontWeight="700"
        fontSize="36"
        fill="currentColor"
      >
        하루코토
      </text>
      <text
        x="145"
        y="95"
        fontFamily="sans-serif"
        fontWeight="400"
        fontSize="20"
        fill="currentColor"
        opacity="0.5"
      >
        ハルコト
      </text>
    </svg>
  );
}
