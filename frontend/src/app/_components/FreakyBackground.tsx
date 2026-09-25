"use client";
import { useEffect, useRef } from "react";

interface Orb {
  x: number;
  y: number;
  radius: number;
  speedX: number;
  speedY: number;
  phase: number;
  useGlow: boolean;
}

const ORB_COUNT = 28;

/**
 * Drifting, pulsing neon orbs behind the whole app for the "freaky"
 * theme, tinted with the theme's accent and glow colours. Renders
 * nothing for users who prefer reduced motion, in which case the
 * theme falls back to its plain colours.
 */
export const FreakyBackground = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const styles = getComputedStyle(document.documentElement);
    const accent = styles.getPropertyValue("--t-accent").trim() || "#a3ff12";
    const glow = styles.getPropertyValue("--t-glow").trim() || "#ff00e5";

    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    const orbs: Orb[] = Array.from({ length: ORB_COUNT }, (_, index) => ({
      x: Math.random() * width,
      y: Math.random() * height,
      radius: 40 + Math.random() * 120,
      speedX: (Math.random() - 0.5) * 0.6,
      speedY: (Math.random() - 0.5) * 0.6,
      phase: Math.random() * Math.PI * 2,
      useGlow: index % 2 === 0,
    }));

    let frame = 0;
    let animationId = 0;

    const draw = () => {
      frame += 1;
      ctx.clearRect(0, 0, width, height);
      ctx.globalCompositeOperation = "lighter";
      for (const orb of orbs) {
        orb.x += orb.speedX;
        orb.y += orb.speedY;
        if (orb.x < -orb.radius) orb.x = width + orb.radius;
        if (orb.x > width + orb.radius) orb.x = -orb.radius;
        if (orb.y < -orb.radius) orb.y = height + orb.radius;
        if (orb.y > height + orb.radius) orb.y = -orb.radius;

        const pulse = 0.75 + 0.25 * Math.sin(frame / 40 + orb.phase);
        const radius = orb.radius * pulse;
        const gradient = ctx.createRadialGradient(
          orb.x,
          orb.y,
          0,
          orb.x,
          orb.y,
          radius,
        );
        gradient.addColorStop(0, orb.useGlow ? glow : accent);
        gradient.addColorStop(1, "transparent");
        ctx.globalAlpha = 0.14;
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.arc(orb.x, orb.y, radius, 0, Math.PI * 2);
        ctx.fill();
      }
      animationId = requestAnimationFrame(draw);
    };
    animationId = requestAnimationFrame(draw);

    const handleResize = () => {
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    };
    window.addEventListener("resize", handleResize);

    return () => {
      cancelAnimationFrame(animationId);
      window.removeEventListener("resize", handleResize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      className="pointer-events-none fixed inset-0 -z-10 h-full w-full"
    />
  );
};
