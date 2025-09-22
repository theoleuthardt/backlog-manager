"use client"
import { Navbar, Footer } from "components";
import { BacklogEntryDummyData, dashboardNavLinks } from "~/constants";
import { BacklogEntry } from "components/BacklogEntry";

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
        <div className="relative z-10 flex flex-col text-white">
          <div className="flex min-h-screen flex-col">
            <Navbar navbarLinks={dashboardNavLinks} />
            <main className="drop-in flex-grow px-4 py-8">
              <div className="grid grid-rows-[1fr_auto] gap-6 h-full max-w-[100rem] mx-auto">
                <div id="upperSection" className="flex min-h-30 border-2 border-white p-8 gap-12">

                  <div id="leftBar" className="w-48 flex-shrink-0 border-2 border-white p-4">
                    <div id="searchBar" className="border-2 border-white rounded-xl h-[2rem] mb-4 text-center">Search</div>
                    <div id="filterOptions" className="border-2 border-white h-32 text-center p-4">
                      Dropdown
                      Dropdown
                      Dropdown
                    </div>
                  </div>

                  <div id="entryList" className="flex-1 border-2 border-white p-4 overflow-hidden">
                    <div className="h-full overflow-y-auto">
                      {BacklogEntryDummyData.map((entry) => (
                        <BacklogEntry key={entry.id} imageLink={entry.imageLink} />
                      ))}
                    </div>
                  </div>

                </div>

                <div id="importSection" className="border-2 border-white h-24 font-bold text-center content-center">
                  Import your Backlog
                </div>

              </div>
            </main>

          </div>
          <Footer />
        </div>
      </div>
    </>
  );
}