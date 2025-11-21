"use client";
import Image from "next/image";
import { EntryCreationDialog } from "~/app/_components/EntryCreationDialog";
import { ImportCSVButton } from "~/app/_components/ImportCSVButton";
import { ExportCSVButton } from "~/app/_components/ExportCSVButton";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "~/components/ui/tooltip";
import type { NavbarLink } from "~/types";

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
            className="!h-8 !w-8 cursor-pointer !border-0 !bg-transparent !p-0 hover:!bg-transparent"
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
            className="!h-8 !w-8 cursor-pointer !border-0 !bg-transparent !p-0 hover:!bg-transparent"
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

export const creationToolNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/dashboard",
    content: <Image src="/go-back.png" alt="go-back" width={32} height={32} />,
    action: "navigate",
    type: "link",
  },
  {
    id: 2,
    href: "/account",
    content: <Image src="/account.png" alt="account" width={32} height={32} />,
    action: "navigate",
    type: "link",
  },
  {
    id: 3,
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

export const importCSVNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/dashboard",
    content: <Image src="/go-back.png" alt="go-back" width={32} height={32} />,
    action: "navigate",
    type: "link",
  },
  {
    id: 2,
    href: "/account",
    content: <Image src="/account.png" alt="account" width={32} height={32} />,
    action: "navigate",
    type: "link",
  },
  {
    id: 3,
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

