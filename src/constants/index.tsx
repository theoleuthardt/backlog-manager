import Image from "next/image";

export const navbarLinks = [
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
      document.getElementById("features")?.scrollIntoView({
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
