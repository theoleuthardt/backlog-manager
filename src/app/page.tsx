"use client";
import { useEffect, useRef } from "react";
import { Navbar } from "./_components/Navbar";
import { Footer } from "./_components/Footer";

export default function Home() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
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
      // clear canvas to reveal gradient background
      ctx.clearRect(0, 0, w, h);
      // draw stars
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
        <canvas ref={canvasRef} className="absolute inset-0 h-full w-full" />
        <div className="relative z-10 flex min-h-screen flex-col text-white">
          <Navbar />
          <main className="drop-in flex flex-grow items-center justify-center px-4">
            <div className="max-w-xl rounded-lg p-6 text-center">
              <h1 className="drop-in mb-18 text-5xl font-extrabold text-indigo-500 shadow-indigo-500 text-shadow-md md:text-6xl lg:text-7xl">
                Manage your gaming backlog!
              </h1>
              <a
                href="/login"
                className="inline-block rounded-lg border bg-black px-6 py-2 text-indigo-600 transition-colors duration-300 hover:text-white hover:shadow-md hover:shadow-white"
              >
                Get Started today!
              </a>
            </div>
          </main>
          <Footer />
        </div>
      </div>
      <style jsx>{`
        .drop-in {
          opacity: 0;
          transform: translateY(100px);
          animation: dropIn 1s ease-out forwards;
        }
        @keyframes dropIn {
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }
      `}</style>
    </>
  );
}
