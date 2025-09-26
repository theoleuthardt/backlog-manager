import Image from "next/image";
import { type JSX } from "react";

export interface NavbarLink {
  id: number;
  href: string;
  content: JSX.Element;
  onClick?: () => void;
}

export const landingPageNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "#features",
    content: <Image src="/features.png" alt="account" width={32} height={32} />,
    onClick: () => {
      document.getElementById("features")?.scrollIntoView({
        behavior: "smooth",
      });
    },
  },
  {
    id: 2,
    href: "#future-updates",
    content: <Image src="/updates.png" alt="account" width={32} height={32} />,
    onClick: () => {
      document.getElementById("future-updates")?.scrollIntoView({
        behavior: "smooth",
      });
    },
  },
  {
    id: 3,
    href: "/login",
    content: <Image src="/account.png" alt="account" width={32} height={32} />,
  },
];

export const dashboardNavLinks: NavbarLink[] = [
  {
    id: 1,
    href: "/account",
    content: <Image src="/account.png" alt="account" width={32} height={32} />,
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
    onClick: () => {},
  },
];
