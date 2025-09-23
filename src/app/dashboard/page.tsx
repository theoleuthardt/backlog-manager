"use client";
import { Navbar, Footer, BacklogEntry } from "components";
import { BacklogEntryDummyData, dashboardNavLinks } from "~/constants";
import Image from "next/image";
import { Input } from "shadcn_components/ui/input";

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
            <main className="drop-in flex-grow px-4">
              <div className="mx-auto grid h-full max-w-[100rem] grid-rows-[1fr_auto] gap-6">
                <div id="upperSection" className="flex min-h-30 gap-12 p-8">
                  <div
                    id="leftBar"
                    className="h-[20rem] w-48 flex-shrink-0 border-2 border-white p-4"
                  >
                    <div id="searchBar" className="relative mb-4 h-[2rem]">
                      <Input
                        className="rounded-3xl"
                        type="search"
                        placeholder="Backlog Entry"
                      />
                    </div>
                    <div
                      id="filterOptions"
                      className="mb-4 h-32 border-2 border-white p-4 text-center"
                    >
                      Dropdown Dropdown Dropdown
                    </div>
                    <div
                      id="slider"
                      className="mb-4 h-[2rem] border-2 border-white text-center"
                    >
                      Slider
                    </div>
                    <div
                      id="slider"
                      className="mb-4 h-[2rem] border-2 border-white text-center"
                    >
                      Slider
                    </div>
                  </div>

                  <div
                    id="entryList"
                    className="h-[30rem] flex-1 overflow-hidden border-2 border-white p-4"
                  >
                    <div className="grid h-full grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-2 overflow-y-auto">
                      {BacklogEntryDummyData.map((entry) => (
                        <BacklogEntry
                          key={entry.id}
                          imageLink={entry.imageLink}
                        />
                      ))}
                    </div>
                  </div>
                </div>

                <div
                  id="csv-import"
                  className="pointer-events-auto flex h-24 cursor-pointer place-items-center-safe justify-center-safe border-2"
                >
                  <div className="flex flex-row">
                    <Image
                      src={"/csv_import.png"}
                      alt={"csv_import"}
                      width={50}
                      height={50}
                    />
                    <div className="mx-4 flex place-items-center-safe justify-center-safe">
                      <p className="text-center text-2xl font-bold text-white">
                        Import your Backlog
                      </p>
                    </div>
                    <Image
                      className=""
                      src={"/csv_import.png"}
                      alt={"csv_import"}
                      width={50}
                      height={50}
                    />
                  </div>
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
