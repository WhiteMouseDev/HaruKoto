'use client';

import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const COLORS = ['#FFB7C5', '#87CEEB', '#98D8C8', '#FFD93D', '#FF6B6B', '#A78BFA'];
const PARTICLE_COUNT = 40;

function randomBetween(min: number, max: number) {
  return Math.random() * (max - min) + min;
}

type Particle = {
  id: number;
  x: number;
  y: number;
  color: string;
  rotation: number;
  size: number;
};

export function Confetti({ duration = 2000 }: { duration?: number }) {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setVisible(false), duration);
    return () => clearTimeout(timer);
  }, [duration]);

  const particles: Particle[] = Array.from({ length: PARTICLE_COUNT }, (_, i) => ({
    id: i,
    x: randomBetween(-20, 120),
    y: randomBetween(-20, -60),
    color: COLORS[i % COLORS.length],
    rotation: randomBetween(0, 360),
    size: randomBetween(6, 10),
  }));

  return (
    <AnimatePresence>
      {visible && (
        <div className="pointer-events-none fixed inset-0 z-50 overflow-hidden">
          {particles.map((p) => (
            <motion.div
              key={p.id}
              className="absolute rounded-sm"
              style={{
                left: `${p.x}%`,
                width: p.size,
                height: p.size,
                backgroundColor: p.color,
              }}
              initial={{ y: '-10vh', rotate: 0, opacity: 1 }}
              animate={{
                y: '110vh',
                rotate: p.rotation + 720,
                opacity: [1, 1, 0],
              }}
              transition={{
                duration: randomBetween(1, 1.8),
                delay: randomBetween(0, 0.3),
                ease: 'easeIn',
              }}
              exit={{ opacity: 0 }}
            />
          ))}
        </div>
      )}
    </AnimatePresence>
  );
}
