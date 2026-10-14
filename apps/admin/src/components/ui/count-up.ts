'use client';

import { useEffect, useRef, useState } from 'react';

/**
 * Un nombre qui monte jusqu'à sa valeur en 600 ms (motion.duration.deliberate),
 * avec une décélération. Sans animation si le système demande moins de
 * mouvement : la valeur s'affiche d'emblée.
 */
function animates(): boolean {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia !== undefined &&
    !window.matchMedia('(prefers-reduced-motion: reduce)').matches
  );
}

const DURATION_MS = 600;

export function useCountUp(target: number): number {
  const [value, setValue] = useState(() => (animates() ? 0 : target));
  // Une relecture qui change le total part de la valeur affichée, pas de 0.
  const shown = useRef(value);

  useEffect(() => {
    if (!animates()) {
      return;
    }
    let frame = 0;
    const from = shown.current;
    const start = performance.now();
    const tick = (now: number) => {
      const progress = Math.min(1, (now - start) / DURATION_MS);
      const next = Math.round(from + (target - from) * (1 - (1 - progress) ** 3));
      shown.current = next;
      setValue(next);
      if (progress < 1) {
        frame = requestAnimationFrame(tick);
      }
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [target]);

  // Sans animation, la valeur cible fait foi telle quelle : aucun état à
  // recopier dans un effet.
  return animates() ? value : target;
}
