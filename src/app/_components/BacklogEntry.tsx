"use client";
import React, { useState, useEffect } from "react";
import Image from "next/image";
import {
  Dialog,
  DialogContent,
  DialogTrigger,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogClose,
} from "shadcn_components/ui/dialog";
import { Button } from "shadcn_components/ui/button";

interface BacklogEntryProps {
  title?: string;
  imageLink: string;
  imageAlt?: string;
  genre?: string[];
  platform?: string[];
  status?: string;
  owned?: boolean;
  interest?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
  howLongToBeat?: number[];
}

export const BacklogEntry = (props: BacklogEntryProps) => {
  const [imgSrc, setImgSrc] = useState("/entryPlaceholder.png");

  useEffect(() => {
    const img = new window.Image();
    img.crossOrigin = "anonymous";
    img.onload = () => setImgSrc(props.imageLink ?? "/entryPlaceholder.png");
    img.onerror = () => setImgSrc("/entryPlaceholder.png");
    img.src = props.imageLink ?? "/entryPlaceholder.png";
  }, [props.imageLink]);

  return (
    <div className="h-[12.5rem] w-[9.375rem] cursor-pointer">
      <Dialog>
        <DialogTrigger asChild>
          <Image
            src={imgSrc}
            alt={props.imageAlt ?? ""}
            width={150}
            height={200}
          />
        </DialogTrigger>
        <DialogContent
          className="h-[40rem] w-[40rem] justify-center-safe border-2 border-white bg-black"
          onOpenAutoFocus={(e) => e.preventDefault()}
        >
          <DialogClose asChild>
            <Button
              variant="ghost"
              size="sm"
              className="absolute top-4 right-4 h-8 w-8 fill-white p-0 text-white"
            ></Button>
          </DialogClose>
          <DialogHeader>
            <DialogTitle className="text-center text-3xl text-white">
              {props.title ?? "Game"}
            </DialogTitle>
            <DialogDescription className="text-center text-white">
              MOIN MEISTER WIE GEHTS SO, COOL DAS DU HIER RAUF GEKLICKT HAST!!!
            </DialogDescription>
          </DialogHeader>
        </DialogContent>
      </Dialog>
    </div>
  );
};
