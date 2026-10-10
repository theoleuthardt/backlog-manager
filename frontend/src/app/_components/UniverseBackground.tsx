import React, { useEffect, useRef } from "react";
import { useTheme } from "~/app/context/ThemeContext";
import {
  advanceStars,
  createStars,
  rescaleStars,
  starCountFor,
  type Star,
} from "~/lib/starfield";

export const UniverseBackground = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const { theme } = useTheme();
  const starColor = theme.colors.foreground;

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let w = 0;
    let h = 0;
    let stars: Star[] = [];

    const fit = () => {
      const nextW = canvas.clientWidth;
      const nextH = canvas.clientHeight;
      if (nextW === w && nextH === h) return;
      const count = starCountFor(nextW, nextH);
      const scaled = rescaleStars(stars, w, h, nextW, nextH);
      stars =
        scaled.length >= count
          ? scaled.slice(0, count)
          : [...scaled, ...createStars(count - scaled.length, nextW, nextH)];
      w = canvas.width = nextW;
      h = canvas.height = nextH;
    };

    fit();

    let animationId = 0;

    function animate() {
      if (!ctx) return;
      ctx.clearRect(0, 0, w, h);
      ctx.fillStyle = starColor;
      advanceStars(stars, h);
      stars.forEach((star) => {
        ctx.beginPath();
        ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
        ctx.fill();
      });

      animationId = requestAnimationFrame(animate);
    }

    animate();

    const observer = new ResizeObserver(fit);
    observer.observe(canvas);
    return () => {
      cancelAnimationFrame(animationId);
      observer.disconnect();
    };
  }, [starColor]);

  return (
    <canvas
      ref={canvasRef}
      className="pointer-events-none absolute inset-0 h-full w-full bg-black"
    />
  );
};
