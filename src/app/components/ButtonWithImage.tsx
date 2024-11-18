import React from "react";
import Image from "next/image";
import { ImageType } from "@lib/types";

export interface ButtonWithImageProps {
  className?: string;
  text: string | undefined;
  image: ImageType | undefined;
  link: string;
}

export const ButtonWithImage = (props: ButtonWithImageProps) => {
  return (
    <div
      className={`${props.className} h-10 border-2 border-white rounded-full flex 
            flex-row items-center hover:bg-transparent hover:text-white group transition duration-300`}
    >
      {props.image && (
        <a href={`${props.link}`}>
          <Image
            className="pr-1 group-hover:filter group-hover:invert transition duration-200"
            src={props.image?.src}
            alt={props.image?.alt}
            width={props.image?.width}
            height={props.image?.height}
          />
        </a>
      )}
      {props.text && <a href={`${props.link}`}>{props.text}</a>}
    </div>
  );
};
