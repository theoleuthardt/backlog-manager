"use client";
import Image from "next/image";
import React from "react";

export interface GameImageProps {
  src: string;
  alt: string;
  width: number;
  height: number;
}

export function GameImage(props: GameImageProps) {
  const proxyUrl = `/api/image-proxy?url=${encodeURIComponent(props.src)}`;
  const handleError = (e: React.SyntheticEvent<HTMLImageElement, Event>) => {
    const target = e.target as HTMLImageElement;
    target.src = "/entryPlaceholder.jpg";
  };

  return (
    <Image
      src={proxyUrl}
      alt={props.alt}
      width={props.width}
      height={props.height}
      onError={handleError}
      className="pointer-events-none rounded-xl"
    />
  );
}
