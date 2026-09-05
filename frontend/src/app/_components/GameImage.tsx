"use client";
import Image from "next/image";
import React, { useState } from "react";
import type { GameImageProps } from "~/app/types";
import { Spinner } from "~/components/ui/spinner";

export function GameImage(props: GameImageProps) {
  const [isLoading, setIsLoading] = useState(true);
  const [hasError, setHasError] = useState(false);

  const hasValidSrc = Boolean(props.src?.trim());
  const getImageSrc = () => {
    if (hasError || !hasValidSrc) {
      return "/entryPlaceholder.png";
    }
    return `/api/image-proxy?url=${encodeURIComponent(props.src)}`;
  };

  const imageSrc = getImageSrc();

  const handleError = () => {
    setHasError(true);
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
      {isLoading && hasValidSrc && !hasError && (
        <div className="absolute inset-0 z-10 flex items-center justify-center bg-gray-800/50 backdrop-blur-sm">
          <Spinner className="h-8 w-8 text-white" />
        </div>
      )}
      <Image
        src={imageSrc}
        alt={props.alt || "Game cover"}
        fill
        unoptimized
        onError={handleError}
        onLoad={handleLoadingComplete}
        className={`pointer-events-none object-cover ${props.className ?? ""}`}
      />
    </div>
  );
}
