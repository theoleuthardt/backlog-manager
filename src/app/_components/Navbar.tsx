import Link from "next/link";
import Image from "next/image";
import { navbarLinks } from "~/constants";

export function Navbar() {
  return (
    <nav className="mx-auto mb-8 flex w-full items-center justify-between rounded-4xl bg-transparent px-8 py-4 pr-20 text-white">
      <div className="flex items-center space-x-2">
        <Image
          src="/logo_mana.png"
          alt="Backlog-Manager"
          width={64}
          height={64}
        />
        <span className="text-xl font-bold">Backlog-Manager</span>
      </div>
      <div className="space-x-6">
        {navbarLinks.map((link) => (
          <Link href={link.href} className="hover:underline">
            {link.content}
          </Link>
        ))}
      </div>
    </nav>
  );
}
