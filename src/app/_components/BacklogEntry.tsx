import React from "react";
import Image from "next/image";

interface BacklogEntryProps {
  title?: string;
  imageLink?: string;
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
  return (
    <div className="h-12">
      <Image
        src={props.imageLink ?? ""}
        alt={props.imageAlt ?? ""}
        width={250}
        height={125}
      />
    </div>
  );
};