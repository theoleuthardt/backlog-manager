import Link from "next/link";
import Image from "next/image";
import { type NavbarLink } from "~/constants";

interface NavbarProps {
  navbarLinks: NavbarLink[];
}

export function Navbar(props: NavbarProps) {
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
      <div className="flex flex-row space-x-8">
        {props.navbarLinks.map((link) => (
          <Link
            key={link.id}
            href={link.href}
            onClick={() => {
              if (link.onClick) {
                link.onClick();
              }
            }}
            className="hover:underline"
          >
            {link.content}
          </Link>
        ))}
      </div>
    </nav>
  );
}
