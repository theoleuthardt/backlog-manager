import { Navbar, Footer, Features, UniverseBackground } from "components";
import { Button } from "shadcn_components/ui/button";
import Link from "next/link";
import { landingPageNavLinks } from "~/constants";

export default function Home() {
  return (
    <>
      <div className="relative min-h-screen overflow-hidden">
        <UniverseBackground />
        <div className="relative z-10 flex flex-col text-white">
          <div className="flex min-h-screen flex-col">
            <Navbar navbarLinks={landingPageNavLinks} />
            <main className="drop-in flex flex-grow items-center justify-center px-4">
              <div className="max-w-xl rounded-lg p-6 text-center">
                <h1 className="drop-in mb-8 text-5xl font-extrabold text-white shadow-white text-shadow-md md:text-6xl lg:text-7xl">
                  Manage your gaming backlog!
                </h1>
                <p className="text- mb-8 text-lg text-gray-300">
                  Organize your games and track your progress with ease.
                </p>
                <div className="flex flex-col items-center justify-center gap-5 sm:flex-row">
                  <Link href="/login">
                    <Button
                      variant="outline"
                      className="border-black text-black transition-colors duration-300 hover:cursor-pointer hover:border-white hover:bg-transparent hover:text-white"
                    >
                      Get Started today!
                    </Button>
                  </Link>
                </div>
              </div>
            </main>
          </div>

          <div id="features">
            <Features />
          </div>

          <Footer />
        </div>
      </div>
    </>
  );
}
