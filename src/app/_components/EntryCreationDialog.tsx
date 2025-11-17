"use client";
import * as React from "react";
import Image from "next/image";
import {
  Dialog,
  DialogHeader,
  DialogPortal,
  DialogTitle,
  DialogTrigger,
} from "~/components/ui/dialog";
import { SearchBar } from "components";
import * as DialogPrimitive from "@radix-ui/react-dialog";
import { cn } from "~/lib/utils";
import { Button } from "~/components/ui/button";

export const EntryCreationDialog = () => {
  return (
    <div>
      <Dialog>
        <DialogTrigger asChild>
          <Button
            id={"add-entry-button"}
            className={`relative mb-4 h-[2.5rem] w-[10rem] rounded-3xl border-0 bg-blue-700 p-4 font-bold text-white hover:bg-blue-800 hover:text-white`}
            variant="outline"
            disabled={false}
          >
            <Image src="/add.png" alt="add" width={24} height={24} />
            Add Entry
          </Button>
        </DialogTrigger>
        <DialogPortal>
          <DialogPrimitive.Overlay
            className={cn(
              "data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 fixed inset-0 z-50 bg-black/50 backdrop-blur-md",
            )}
          />
          <DialogPrimitive.Content
            className={cn(
              "bg-background data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-lg p-6 shadow-lg duration-200 sm:max-w-lg",
              "h-[10rem] w-full justify-center-safe bg-transparent md:w-[80rem] lg:w-[100rem]",
            )}
            onOpenAutoFocus={(e) => e.preventDefault()}
          >
            <DialogHeader>
              <DialogTitle className="text-center text-3xl text-white">
                Search for a game 🎮:
              </DialogTitle>
            </DialogHeader>
            <SearchBar
              useIcon={false}
              placeholder="Type in a game name..."
              onInput={(e: React.ChangeEvent<HTMLInputElement>) => {
                console.log(`${{ e: e.target.value }}`);
              }}
              className="text-white"
            />
          </DialogPrimitive.Content>
        </DialogPortal>
      </Dialog>
    </div>
  );
};
