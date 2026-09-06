import { Navbar, Footer, AccountContent } from "components";
import { accountNavLinks } from "~/constants";

export default function Account() {
  return (
    <div className="relative min-h-screen overflow-hidden">
      <div className="relative z-10 flex flex-col bg-black text-white">
        <div className="flex min-h-screen flex-col">
          <Navbar navbarLinks={accountNavLinks} />
          <main className="drop-in flex-grow px-4">
            <div className="mx-auto max-w-2xl py-12">
              <AccountContent />
            </div>
          </main>
          <Footer />
        </div>
      </div>
    </div>
  );
}
