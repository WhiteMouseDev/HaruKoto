import type { Variants } from 'framer-motion';

export const shakeVariants: Variants = {
  idle: { x: 0 },
  shake: {
    x: [0, -8, 8, -6, 6, -3, 3, 0],
    transition: { duration: 0.4 },
  },
};

export const pulseVariants: Variants = {
  idle: { scale: 1 },
  pulse: {
    scale: [1, 1.04, 1],
    transition: { duration: 0.3 },
  },
};

export const cardHoverVariants: Variants = {
  rest: {
    scale: 1,
    boxShadow: '0 0 0 rgba(0,0,0,0)',
  },
  hover: {
    scale: 1.02,
    boxShadow: '0 8px 24px rgba(0,0,0,0.08)',
    transition: { duration: 0.2 },
  },
  tap: {
    scale: 0.98,
    transition: { duration: 0.1 },
  },
};
