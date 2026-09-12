import { Navbar, Footer, SteamContent } from "components";
import { steamNavLinks } from "~/constants";

export default function Steam() {
  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="relative z-10 flex flex-col bg-black text-white">
        <div className="flex min-h-screen flex-col">
          <Navbar navbarLinks={steamNavLinks} />
          <main className="drop-in flex-grow px-4">
            <div className="mx-auto max-w-4xl py-12">
              <SteamContent />
            </div>
          </main>
          <Footer />
        </div>
      </div>
    </div>
  );
}