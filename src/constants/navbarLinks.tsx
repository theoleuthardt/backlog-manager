"use client";
import Image from "next/image";
import { type JSX, type ReactNode } from "react";
import { EntryCreationDialog } from "~/app/_components/EntryCreationDialog";
import { ImportCSVButton } from "~/app/_components/ImportCSVButton";
import { ExportCSVButton } from "~/app/_components/ExportCSVButton";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "~/components/ui/tooltip";

export interface NavbarLink {
  id: number;
  href?: string;
  content?: JSX.Element;
  component?: ReactNode;
  action?: string;
  target?: string;
  type: "link" | "component";
}

export const landingPageNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "#features",
    content: <Image src="/features.png" alt="account" width={32} height={32} />,
    action: "scroll",
    target: "features",
    type: "link",
  },
  {
    id: 2,
    href: "#future-updates",
    content: <Image src="/updates.png" alt="account" width={32} height={32} />,
    action: "scroll",
    target: "future-updates",
    type: "link",
  },
  {
    id: 3,
    href: "/login",
    content: <Image src="/account.png" alt="account" width={32} height={32} />,
    action: "navigate",
    type: "link",
  },
];

export const dashboardNavLinks: NavbarLink[] = [
  {
    id: 1,
    component: (
      <Tooltip>
        <TooltipTrigger asChild>
          <EntryCreationDialog
            triggerIcon="/search.png"
            triggerAlt="search"
            triggerClassName="!h-8 !w-8 !p-0 !border-0 !bg-transparent hover:!bg-transparent cursor-pointer"
            showText={false}
          />
        </TooltipTrigger>
        <TooltipContent>
          <p>Add Backlog Entry</p>
        </TooltipContent>
      </Tooltip>
    ),
    type: "component",
  },
  {
    id: 2,
    component: (
      <Tooltip>
        <TooltipTrigger asChild>
          <ImportCSVButton
            iconOnly
            className="!h-8 !w-8 !p-0 !border-0 !bg-transparent hover:!bg-transparent cursor-pointer"
          />
        </TooltipTrigger>
        <TooltipContent>
          <p>Import from CSV-file</p>
        </TooltipContent>
      </Tooltip>
    ),
    type: "component",
  },
  {
    id: 3,
    component: (
      <Tooltip>
        <TooltipTrigger asChild>
          <ExportCSVButton
            iconOnly
            className="!h-8 !w-8 !p-0 !border-0 !bg-transparent hover:!bg-transparent cursor-pointer"
          />
        </TooltipTrigger>
        <TooltipContent>
          <p>Export as CSV-file</p>
        </TooltipContent>
      </Tooltip>
    ),
    type: "component",
  },
  {
    id: 4,
    href: "/account",
    content: <Image src="/account.png" alt="account" width={32} height={32} />,
    action: "navigate",
    type: "link",
  },
  {
    id: 5,
    href: "/logout",
    content: (
      <Image
        className="scale-125"
        src="/logout.png"
        alt="logout"
        width={32}
        height={32}
      />
    ),
    action: "logout",
    type: "link",
  },
];
