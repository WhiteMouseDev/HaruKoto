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

export function Logo({ variant = 'symbol', size = 'md', ...props }: LogoProps) {
  const px = typeof size === 'number' ? size : sizeMap[size];

  if (variant === 'full') {
    return <LogoFull width={px * 2.5} height={px} {...props} />;
  }

  return <LogoSymbol width={px} height={px} {...props} />;
}

function LogoSymbol(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 192 192"
      fill="none"
      {...props}
    >
      <rect width="192" height="192" rx="32" fill="#FFB7C5" />
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

function LogoFull(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 400 120"
      fill="none"
      {...props}
    >
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
