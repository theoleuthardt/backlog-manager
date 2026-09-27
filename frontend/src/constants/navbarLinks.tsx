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
import type { NavbarLink } from "~/app/types";

export const landingPageNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "#features",
    content: (
      <Image
        src="/features.png"
        alt="account"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "scroll",
    target: "features",
    label: "Features",
    type: "link",
  },
  {
    id: 2,
    href: "#future-updates",
    content: (
      <Image
        src="/updates.png"
        alt="account"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "scroll",
    target: "future-updates",
    label: "Updates",
    type: "link",
  },
  {
    id: 3,
    href: "/login",
    content: (
      <Image
        src="/account.png"
        alt="account"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Log in",
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
            triggerClassName="!h-8 !w-8 !p-0 !border-0 !bg-transparent hover:!bg-transparent cursor-pointer"
            showText={false}
          />
        </TooltipTrigger>
        <TooltipContent>
          <p>Add Backlog Entry</p>
        </TooltipContent>
      </Tooltip>
    ),
    mobileComponent: (
      <EntryCreationDialog
        triggerClassName="!h-11 w-full !justify-start gap-3 !px-3 text-base font-semibold !bg-transparent hover:!bg-white/10"
        showText
      />
    ),
    label: "Add entry",
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
    mobileComponent: (
      <ImportCSVButton className="!h-11 w-full !justify-start gap-3 !px-3 text-base font-semibold !bg-transparent hover:!bg-white/10">
        <Image
          src="/csv_import.png"
          alt=""
          width={32}
          height={32}
          className="themed-icon"
        />
        Import from CSV
      </ImportCSVButton>
    ),
    label: "Import from CSV",
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
    mobileComponent: (
      <ExportCSVButton className="!h-11 w-full !justify-start gap-3 !px-3 text-base font-semibold !bg-transparent hover:!bg-white/10">
        <Image
          src="/csv_export.png"
          alt=""
          width={32}
          height={32}
          className="themed-icon"
        />
        Export as CSV
      </ExportCSVButton>
    ),
    label: "Export as CSV",
    type: "component",
  },
  {
    id: 4,
    href: "/steam",
    content: (
      <Image
        src="/steam-icon.png"
        alt="Steam"
        width={32}
        height={32}
        className="themed-icon-mono"
      />
    ),
    action: "navigate",
    label: "Steam sync",
    type: "link",
  },
  {
    id: 5,
    href: "/account",
    content: (
      <Image
        src="/account.png"
        alt="account"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Account",
    type: "link",
  },
  {
    id: 6,
    href: "/logout",
    content: (
      <Image
        className="themed-icon scale-125"
        src="/logout.png"
        alt="logout"
        width={32}
        height={32}
      />
    ),
    action: "logout",
    label: "Log out",
    type: "link",
  },
];

export const creationToolNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/dashboard",
    content: (
      <Image
        src="/go-back.png"
        alt="go-back"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Back to dashboard",
    type: "link",
  },
  {
    id: 2,
    href: "/account",
    content: (
      <Image
        src="/account.png"
        alt="account"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Account",
    type: "link",
  },
  {
    id: 3,
    href: "/logout",
    content: (
      <Image
        className="themed-icon scale-125"
        src="/logout.png"
        alt="logout"
        width={32}
        height={32}
      />
    ),
    action: "logout",
    label: "Log out",
    type: "link",
  },
];

export const accountNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/dashboard",
    content: (
      <Image
        src="/go-back.png"
        alt="go-back"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Back to dashboard",
    type: "link",
  },
  {
    id: 2,
    href: "/logout",
    content: (
      <Image
        className="themed-icon scale-125"
        src="/logout.png"
        alt="logout"
        width={32}
        height={32}
      />
    ),
    action: "logout",
    label: "Log out",
    type: "link",
  },
];

export const steamNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/dashboard",
    content: (
      <Image
        src="/go-back.png"
        alt="go-back"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Back to dashboard",
    type: "link",
  },
  {
    id: 2,
    href: "/account",
    content: (
      <Image
        src="/account.png"
        alt="account"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Account",
    type: "link",
  },
  {
    id: 3,
    href: "/logout",
    content: (
      <Image
        className="themed-icon scale-125"
        src="/logout.png"
        alt="logout"
        width={32}
        height={32}
      />
    ),
    action: "logout",
    label: "Log out",
    type: "link",
  },
];

export const importCSVNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/dashboard",
    content: (
      <Image
        src="/go-back.png"
        alt="go-back"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Back to dashboard",
    type: "link",
  },
  {
    id: 2,
    href: "/account",
    content: (
      <Image
        src="/account.png"
        alt="account"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Account",
    type: "link",
  },
  {
    id: 3,
    href: "/logout",
    content: (
      <Image
        className="themed-icon scale-125"
        src="/logout.png"
        alt="logout"
        width={32}
        height={32}
      />
    ),
    action: "logout",
    label: "Log out",
    type: "link",
  },
];

export const exportCSVNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/dashboard",
    content: (
      <Image
        src="/go-back.png"
        alt="go-back"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Back to dashboard",
    type: "link",
  },
  {
    id: 2,
    href: "/account",
    content: (
      <Image
        src="/account.png"
        alt="account"
        width={32}
        height={32}
        className="themed-icon"
      />
    ),
    action: "navigate",
    label: "Account",
    type: "link",
  },
  {
    id: 3,
    href: "/logout",
    content: (
      <Image
        className="themed-icon scale-125"
        src="/logout.png"
        alt="logout"
        width={32}
        height={32}
      />
    ),
    action: "logout",
    label: "Log out",
    type: "link",
  },
];
