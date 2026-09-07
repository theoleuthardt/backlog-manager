"use client";
import React from "react";
import Link from "next/link";
import Image from "next/image";
import { motion } from "motion/react";
import { useRouter } from "next/navigation";
import type { NavbarLink, NavbarProps } from "~/app/types";
import { useAuth } from "~/app/context/AuthContext";
import { useIsTauriMacOS } from "~/hooks/useIsTauri";

export function Navbar(props: NavbarProps) {
  const router = useRouter();
  const { logout } = useAuth();
  const isTauriMacOS = useIsTauriMacOS();

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
        logout();
        router.push("/login");
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
    <nav
      {...(isTauriMacOS ? { "data-tauri-drag-region": true } : {})}
      className={`mx-auto flex w-full items-center justify-between rounded-4xl bg-transparent px-8 py-4 text-white ${isTauriMacOS ? "pt-8" : ""}`}
    >
      <div
        className={`flex items-center space-x-2 ${isTauriMacOS ? "ml-16" : ""}`}
      >
        <Link href={"/"}>
          <motion.div
            whileHover={{ scale: 1.08, rotate: -4 }}
            whileTap={{ scale: 0.95 }}
          >
            <Image
              src="/logo_mana.png"
              alt="Backlog-Manager"
              width={64}
              height={64}
            />
          </motion.div>
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
              <motion.div
                className="!h-8 !w-8 !border-0 !p-0"
                key={link.id}
                whileHover={{ scale: 1.2, y: -3 }}
                whileTap={{ scale: 0.92 }}
                transition={{ type: "spring", stiffness: 400, damping: 20 }}
              >
                {link.component}
              </motion.div>
            );
          }
          return (
            <Link
              key={link.id}
              href={link.href ?? "#"}
              onClick={(e) => handleClick(e, link)}
              className="bg-transparent"
            >
              <motion.div
                whileHover={{ scale: 1.2, y: -3 }}
                whileTap={{ scale: 0.92 }}
                transition={{ type: "spring", stiffness: 400, damping: 20 }}
              >
                {link.content}
              </motion.div>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
