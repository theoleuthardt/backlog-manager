"use client"
import { Navbar, Footer } from "components";
import { dashboardNavLinks } from "~/constants";

export default function Dashboard() {
  return (
    <>
      <div
        className="relative min-h-screen overflow-hidden"
        style={{
          backgroundImage:
            "linear-gradient(to bottom, black 60%, #1e3a8a 100%)",
        }}
      >
        <canvas className="pointer-events-none absolute inset-0 h-full w-full" />

        <div className="relative z-10 flex flex-col text-white">
          <div className="flex min-h-screen flex-col">
            <Navbar navbarLinks={dashboardNavLinks} />
            <main className="drop-in flex flex-grow items-center justify-center px-4">
              HI DOMI
            </main>
          </div>
          <Footer />
        </div>
      </div>
    </>
  );
}
