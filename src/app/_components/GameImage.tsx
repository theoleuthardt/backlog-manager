"use client";
import Image from "next/image";
import React, { useState } from "react";
import type { GameImageProps } from "~/app/types";
import { Spinner } from "~/components/ui/spinner";

export function GameImage(props: GameImageProps) {
  const [isLoading, setIsLoading] = useState(true);
  const proxyUrl = `/api/image-proxy?url=${encodeURIComponent(props.src)}`;

  const handleError = (e: React.SyntheticEvent<HTMLImageElement, Event>) => {
    const target = e.target as HTMLImageElement;
    target.src = "/entryPlaceholder.jpg";
    setIsLoading(false);
  };

  const handleLoadingComplete = () => {
    setIsLoading(false);
  };

  return (
    <div
      className="relative overflow-hidden rounded-xl"
      style={{ width: `${props.width}px`, height: `${props.height}px` }}
    >
      {isLoading && (
        <div className="absolute inset-0 z-10 flex items-center justify-center bg-gray-800/50 backdrop-blur-sm">
          <Spinner className="h-8 w-8 text-white" />
        </div>
      )}
      <Image
        src={proxyUrl}
        alt={props.alt}
        fill
        onError={handleError}
        onLoad={handleLoadingComplete}
        className={`pointer-events-none object-cover ${props.className}`}
      />
    </div>
  );
}
