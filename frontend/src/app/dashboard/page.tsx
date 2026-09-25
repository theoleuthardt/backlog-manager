import { Navbar, Footer, DashboardContent, DashboardSearch } from "components";
import { DashboardProvider } from "~/app/context/DashboardContext";
import { dashboardNavLinks } from "~/constants";

export default function Dashboard() {
  return (
    <DashboardProvider>
      <div className="relative min-h-screen overflow-x-clip">
        <div className="relative z-10 flex flex-col text-white">
          <div className="flex min-h-screen flex-col">
            <Navbar
              navbarLinks={dashboardNavLinks}
              center={<DashboardSearch />}
            />
            <main className="drop-in flex-grow px-3 md:px-4">
              <div className="mx-auto max-w-[100rem]">
                <DashboardContent />
              </div>
            </main>
            <Footer />
          </div>
        </div>
      </div>
    </DashboardProvider>
  );
}
