import { Navbar, Footer, ThemeCreator } from "components";
import { accountNavLinks } from "~/constants";

export default function Themes() {
  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="relative z-10 flex flex-col text-white">
        <div className="flex min-h-screen flex-col">
          <Navbar navbarLinks={accountNavLinks} />
          <main className="drop-in flex-grow px-4">
            <div className="mx-auto max-w-5xl py-12">
              <ThemeCreator />
            </div>
          </main>
          <Footer />
        </div>
      </div>
    </div>
  );
}
