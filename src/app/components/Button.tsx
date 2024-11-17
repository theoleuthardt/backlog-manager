import React from "react";
import Image from "next/image";
import { ImageType } from "@lib/types";

export interface ButtonProps {
  className?: string;
  content: string | ImageType | undefined;
  link: string;
}

export const Button = (props: ButtonProps) => {
  return (
    <div
      className={`${props.className} h-10 border-2 border-white rounded-full flex 
            justify-center items-center hover:bg-white hover:text-black group transition duration-300`}
    >
      {typeof props.content === "string" ? (
        <a href={`${props.link}`}>{props.content}</a>
      ) : (
        props.content && (
          <a href={`${props.link}`}>
            <Image
              className="filter invert group-hover:invert-0 transition duration-200"
              src={props.content?.src}
              alt={props.content?.alt}
              width={props.content?.width}
              height={props.content?.height}
            />
          </a>
        )
      )}
    </div>
  );
};
