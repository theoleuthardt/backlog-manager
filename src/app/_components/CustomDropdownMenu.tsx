"use client";
import React from "react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "~/components/ui/dropdown-menu";
import type { DropdownMenuProps } from "~/types";

export const CustomDropdownMenu = (props: DropdownMenuProps) => {
  return (
    <div
      className={`mb-2 rounded-xl border-2 border-white hover:bg-white hover:text-black ${props.className}`}
    >
      <DropdownMenu>
        <DropdownMenuTrigger>
          {props.triggerIcon && props.triggerIcon}
          {props.triggerText && props.triggerText}
        </DropdownMenuTrigger>
        <DropdownMenuContent className="h-28 border-2 border-white bg-black">
          {props.items.map((item, index) => {
            return (
              <DropdownMenuItem
                key={index}
                className="bg-black text-white hover:border-2 hover:border-white"
              >
                {item.text}
              </DropdownMenuItem>
            );
          })}
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
};
