"use client";
import React, { useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { AnimatePresence, motion } from "motion/react";
import { useRouter } from "next/navigation";
import type { NavbarLink, NavbarProps } from "~/app/types";
import { useAuth } from "~/app/context/AuthContext";
import { useIsTauriMacOS } from "~/hooks/useIsTauri";
import { ThemeMenu } from "./ThemeMenu";

export function Navbar(props: NavbarProps) {
  const router = useRouter();
  const { logout } = useAuth();
  const isTauriMacOS = useIsTauriMacOS();
  const [isMenuOpen, setIsMenuOpen] = useState(false);

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
      className={`mx-auto flex w-full flex-wrap items-center justify-between gap-x-2 gap-y-3 rounded-4xl bg-transparent px-3 py-3 text-white md:flex-nowrap md:gap-x-4 md:px-8 md:py-4 ${isTauriMacOS ? "pt-8" : ""}`}
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
              className="themed-icon h-12 w-12 md:h-16 md:w-16"
            />
          </motion.div>
        </Link>
        <Link href={"/"}>
          <span className="hidden text-xl font-bold md:block">
            Backlog-Manager
          </span>
        </Link>
      </div>
      {props.center && (
        <div className="order-last w-full md:order-none md:mx-4 md:w-auto md:max-w-2xl md:flex-1">
          {props.center}
        </div>
      )}
      <div className="flex items-center gap-1 md:hidden">
        <ThemeMenu />
        <button
          type="button"
          onClick={() => setIsMenuOpen(!isMenuOpen)}
          aria-label={isMenuOpen ? "Close menu" : "Open menu"}
          aria-expanded={isMenuOpen}
          aria-controls="mobile-nav-menu"
          className="flex h-10 w-10 cursor-pointer flex-col items-center justify-center gap-[5px] rounded-md"
        >
          <motion.span
            animate={isMenuOpen ? { rotate: 45, y: 7 } : { rotate: 0, y: 0 }}
            className="block h-0.5 w-6 rounded-full bg-white"
          />
          <motion.span
            animate={
              isMenuOpen ? { opacity: 0, scaleX: 0 } : { opacity: 1, scaleX: 1 }
            }
            className="block h-0.5 w-6 rounded-full bg-white"
          />
          <motion.span
            animate={isMenuOpen ? { rotate: -45, y: -7 } : { rotate: 0, y: 0 }}
            className="block h-0.5 w-6 rounded-full bg-white"
          />
        </button>
      </div>
      <AnimatePresence initial={false}>
        {isMenuOpen && (
          <motion.div
            id="mobile-nav-menu"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ type: "spring", stiffness: 300, damping: 32 }}
            className="order-1 w-full overflow-hidden md:hidden"
          >
            <ul className="surface-glow bg-surface flex flex-col gap-1 rounded-2xl border-2 border-white p-2">
              {props.navbarLinks.map((link, index) => (
                <motion.li
                  key={link.id}
                  initial={{ opacity: 0, x: -16 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: 0.04 * index }}
                >
                  {link.type === "component" ? (
                    (link.mobileComponent ?? link.component)
                  ) : (
                    <Link
                      href={link.href ?? "#"}
                      onClick={(e) => {
                        handleClick(e, link);
                        setIsMenuOpen(false);
                      }}
                      className="flex h-11 items-center gap-3 rounded-md px-3 text-base font-semibold hover:bg-white/10"
                    >
                      <span className="flex h-8 w-8 items-center justify-center">
                        {link.content}
                      </span>
                      {link.label}
                    </Link>
                  )}
                </motion.li>
              ))}
            </ul>
          </motion.div>
        )}
      </AnimatePresence>
      <div className="hidden flex-row items-center gap-8 md:flex">
        <motion.div
          whileHover={{ scale: 1.2, y: -3, rotate: -4 }}
          whileTap={{ scale: 0.92 }}
          transition={{ type: "spring", stiffness: 400, damping: 20 }}
        >
          <ThemeMenu />
        </motion.div>
        {props.navbarLinks.map((link) => {
          if (link.type === "component") {
            return (
              <motion.div
                className="!h-8 !w-8 !border-0 !p-0"
                key={link.id}
                whileHover={{ scale: 1.2, y: -3, rotate: -4 }}
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
                whileHover={{ scale: 1.2, y: -3, rotate: -4 }}
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
