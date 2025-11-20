"use client";
import Image from "next/image";
import React from "react";
import type { GameImageProps } from "~/types";

export function GameImage(props: GameImageProps) {
  const proxyUrl = `/api/image-proxy?url=${encodeURIComponent(props.src)}`;
  const handleError = (e: React.SyntheticEvent<HTMLImageElement, Event>) => {
    const target = e.target as HTMLImageElement;
    target.src = "/entryPlaceholder.jpg";
  };

  return (
    <div
      className="relative overflow-hidden rounded-xl"
      style={{ width: `${props.width}px`, height: `${props.height}px` }}
    >
      <Image
        src={proxyUrl}
        alt={props.alt}
        fill
        onError={handleError}
        className={`pointer-events-none object-cover ${props.className}`}
      />
    </div>
  );
}
