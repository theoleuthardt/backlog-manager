"use client";
import React, { useEffect, useRef } from "react";

export const UniverseBackground = () => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    let w = (canvas.width = window.innerWidth);
    let h = (canvas.height = window.innerHeight);

    const stars = Array.from({ length: 200 }).map(() => ({
      x: Math.random() * w,
      y: Math.random() * h,
      size: Math.random() * 1.5 + 0.5,
      speed: Math.random() * 2 + 0.1,
    }));

    function animate() {
      if (!ctx) return;
      ctx.clearRect(0, 0, w, h);
      ctx.fillStyle = "white";
      stars.forEach((star) => {
        star.y -= star.speed;
        if (star.y < 0) star.y = h;
        ctx.beginPath();
        ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
        ctx.fill();
      });

      requestAnimationFrame(animate);
    }

    animate();

    const handleResize = () => {
      w = canvas.width = window.innerWidth;
      h = canvas.height = window.innerHeight;
    };

    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  return (
    <canvas
      ref={canvasRef}
      className="pointer-events-none absolute inset-0 h-full w-full"
    />
  );
};
