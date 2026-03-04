import { useEffect, useState } from 'react';
import { useMotionValue, animate } from 'framer-motion';

export function useCountUp(target: number, duration = 0.8, delay = 0) {
  const motionValue = useMotionValue(0);
  const [display, setDisplay] = useState(0);

  useEffect(() => {
    const timeout = setTimeout(() => {
      const controls = animate(motionValue, target, {
        duration,
        ease: 'easeOut',
        onUpdate: (v) => setDisplay(Math.round(v)),
      });
      return () => controls.stop();
    }, delay * 1000);

    return () => clearTimeout(timeout);
  }, [motionValue, target, duration, delay]);

  return display;
}
