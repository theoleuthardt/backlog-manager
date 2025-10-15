"use client";
import React, { useRef, useState, useEffect } from "react";

interface ScrollSectionProps {
  children: React.ReactNode;
  className?: string;
  delay?: number;
}

export const ScrollSection = (Props: ScrollSectionProps) => {
  const [isVisible, setIsVisible] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry?.isIntersecting) {
          setTimeout(() => setIsVisible(true), Props.delay);
        }
      },
      {
        threshold: 0.1,
        rootMargin: "-50px",
      },
    );

    const currentRef = ref.current;
    if (currentRef) {
      observer.observe(currentRef);
    }

    return () => {
      if (currentRef) {
        observer.unobserve(currentRef);
      }
    };
  }, [Props.delay]);

  return (
    <div
      ref={ref}
      className={`transform transition-all duration-700 ease-out ${
        isVisible ? "translate-y-0 opacity-100" : "translate-y-10 opacity-0"
      } ${Props.className}`}
    >
      {Props.children}
    </div>
  );
};
