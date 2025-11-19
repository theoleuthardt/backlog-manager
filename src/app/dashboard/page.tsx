import { Navbar, Footer, DashboardContent } from "components";
import { BacklogEntryDummyData, dashboardNavLinks } from "~/constants";

export default function Dashboard() {
  return (
    <>
      <div className="relative min-h-screen overflow-hidden">
        <div className={`relative z-10 flex flex-col bg-black text-white`}>
          <div className="flex min-h-screen flex-col">
            <Navbar navbarLinks={dashboardNavLinks} />
            <main className="drop-in flex-grow px-4">
              <div className="mx-auto grid h-full max-w-[100rem] grid-rows-[1fr_auto] gap-6">
                <DashboardContent initialData={BacklogEntryDummyData} />
              </div>
            </main>
            <Footer />
          </div>
        </div>
      </div>
    </>
  );
}
