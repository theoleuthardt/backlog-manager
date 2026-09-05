import { Suspense } from "react";
import { Navbar, Footer, CreationToolForm } from "components";
import { creationToolNavLinks } from "~/constants";

export default function CreationTool() {
  return (
    <>
      <div className="relative min-h-screen overflow-hidden">
        <div className={`relative z-10 flex flex-col bg-black text-white`}>
          <div className="flex min-h-screen flex-col">
            <Navbar navbarLinks={creationToolNavLinks} />
            <main className="drop-in flex-grow px-4 py-8">
              <Suspense fallback={<div>Loading...</div>}>
                <CreationToolForm />
              </Suspense>
            </main>
            <Footer />
          </div>
        </div>
      </div>
    </>
  );
}
