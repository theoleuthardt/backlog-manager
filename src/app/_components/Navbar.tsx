"use client";
import React from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { type NavbarLink } from "~/constants";

interface NavbarProps {
  navbarLinks: NavbarLink[];
}

export function Navbar(props: NavbarProps) {
  const router = useRouter();

  const handleClick = (e: React.MouseEvent, link: NavbarLink) => {
    e.preventDefault();

    switch (link.action) {
      case "scroll":
        if (link.target) {
          document.getElementById(link.target)?.scrollIntoView({
            behavior: "smooth",
          });
        }
        break;

      case "logout":
        router.push("/logout");
        break;

      case "navigate":
      default:
        if (link.href != null) {
          router.push(link.href);
        }
        break;
    }
  };

  return (
    <nav className="mx-auto flex w-full items-center justify-between rounded-4xl bg-transparent px-8 py-4 text-white">
      <div className="flex items-center space-x-2">
        <Link href={"/"}>
          <Image
            src="/logo_mana.png"
            alt="Backlog-Manager"
            width={64}
            height={64}
          />
        </Link>
        <Link href={"/"}>
          <span className="hidden text-xl font-bold md:block">
            Backlog-Manager
          </span>
        </Link>
      </div>
      <div className="flex flex-row items-center space-x-8">
        {props.navbarLinks.map((link) => {
          if (link.type === "component") {
            return (
              <div className="!h-8 !w-8 !border-0 !p-0" key={link.id}>
                {link.component}
              </div>
            );
          }
          return (
            <Link
              key={link.id}
              href={link.href || "#"}
              onClick={(e) => handleClick(e, link)}
              className="bg-transparent hover:underline"
            >
              {link.content}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
