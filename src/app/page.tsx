"use client";
import { useEffect, useRef } from "react";
import { Navbar, Footer, Features } from "components";
import { Button } from "shadcn_components/ui/button";
import Link from "next/link";

export default function Home() {
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
    <>
      <div
        className="relative min-h-screen overflow-hidden"
        style={{
          backgroundImage:
            "linear-gradient(to bottom, black 60%, #1e3a8a 100%)",
        }}
      >
        <canvas
          ref={canvasRef}
          className="pointer-events-none absolute inset-0 h-full w-full"
        />

        <div className="relative z-10 flex flex-col text-white">
          <div className="flex min-h-screen flex-col">
            <Navbar />
            <main className="drop-in flex flex-grow items-center justify-center px-4">
              <div className="max-w-xl rounded-lg p-6 text-center">
                <h1 className="drop-in mb-8 text-5xl font-extrabold text-white shadow-white text-shadow-md md:text-6xl lg:text-7xl">
                  Manage your gaming backlog!
                </h1>
                <p className="text- mb-8 text-lg text-gray-300">
                  Organize your games and track your progress with ease.
                </p>
                <div className="flex flex-col items-center justify-center gap-5 sm:flex-row">
                  {/* Korrigierte Button-Link-Struktur */}
                  <Link href="/login">
                    <Button
                      variant="outline"
                      className="border-black text-black transition-colors duration-300 hover:cursor-pointer hover:border-white hover:bg-transparent hover:text-white"
                    >
                      Get Started today!
                    </Button>
                  </Link>
                </div>
              </div>
            </main>
          </div>

          <div id="features">
            <Features />
          </div>

          <Footer />
        </div>
      </div>
    </>
  );
}
