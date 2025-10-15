import Image from "next/image";
import { type JSX } from "react";

export interface NavbarLink {
  id: number;
  href: string;
  content: JSX.Element;
  action?: string;
  target?: string;
}

export const landingPageNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "#features",
    content: <Image src="/features.png" alt="account" width={32} height={32} />,
    action: "scroll",
    target: "features",
  },
  {
    id: 2,
    href: "#future-updates",
    content: <Image src="/updates.png" alt="account" width={32} height={32} />,
    action: "scroll",
    target: "future-updates",
  },
  {
    id: 3,
    href: "/login",
    content: <Image src="/account.png" alt="account" width={32} height={32} />,
    action: "navigate",
  },
];

export const dashboardNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/account",
    content: <Image src="/account.png" alt="account" width={32} height={32} />,
    action: "navigate",
  },
  {
    id: 2,
    href: "/",
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
  },
];
