'use client';

import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';

const COLORS = ['#FFB7C5', '#87CEEB', '#98D8C8', '#FFD93D', '#FF6B6B', '#A78BFA'];
const PARTICLE_COUNT = 50;

function randomBetween(min: number, max: number) {
  return Math.random() * (max - min) + min;
}

type Particle = {
  id: number;
  angle: number;
  distance: number;
  color: string;
  rotation: number;
  size: number;
  delay: number;
};

export function Confetti({ duration = 2500 }: { duration?: number }) {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setVisible(false), duration);
    return () => clearTimeout(timer);
  }, [duration]);

  const particles: Particle[] = Array.from({ length: PARTICLE_COUNT }, (_, i) => ({
    id: i,
    angle: (i / PARTICLE_COUNT) * 360 + randomBetween(-15, 15),
    distance: randomBetween(120, 350),
    color: COLORS[i % COLORS.length],
    rotation: randomBetween(0, 360),
    size: randomBetween(6, 12),
    delay: randomBetween(0, 0.15),
  }));

  return (
    <AnimatePresence>
      {visible && (
        <div className="pointer-events-none fixed inset-0 z-50 overflow-hidden">
          {particles.map((p) => {
            const rad = (p.angle * Math.PI) / 180;
            const endX = Math.cos(rad) * p.distance;
            const endY = Math.sin(rad) * p.distance;

            return (
              <motion.div
                key={p.id}
                className="absolute rounded-sm"
                style={{
                  left: '50%',
                  top: '45%',
                  width: p.size,
                  height: p.size * randomBetween(0.6, 1),
                  backgroundColor: p.color,
                  marginLeft: -p.size / 2,
                  marginTop: -p.size / 2,
                }}
                initial={{ x: 0, y: 0, rotate: 0, opacity: 1, scale: 0 }}
                animate={{
                  x: endX,
                  y: endY + randomBetween(40, 120),
                  rotate: p.rotation + randomBetween(360, 720),
                  opacity: [0, 1, 1, 0],
                  scale: [0, 1.2, 1, 0.6],
                }}
                transition={{
                  duration: randomBetween(1.2, 2),
                  delay: p.delay,
                  ease: [0.2, 0.8, 0.4, 1],
                }}
                exit={{ opacity: 0 }}
              />
            );
          })}
        </div>
      )}
    </AnimatePresence>
  );
}
