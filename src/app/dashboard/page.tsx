"use client";
import { Navbar, Footer, BacklogEntry } from "components";
import { BacklogEntryDummyData, dashboardNavLinks } from "~/constants";
import Image from "next/image";
import { Input } from "shadcn_components/ui/input";
import { Button } from "shadcn_components/ui/button";

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
                    className="h-[23rem] w-48 flex-shrink-0 border-2 border-white p-4"
                  >
                    <Button
                      id="addEntryButton"
                      className="relative mb-4 h-[2rem] w-[10rem] rounded-3xl border-2 border-white bg-black p-4 font-bold text-white"
                      variant="outline"
                    >
                      Add Entry
                    </Button>
                    <div id="searchBar" className="relative mb-4 h-[2rem]">
                      <Input
                        className="rounded-3xl text-center"
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
                    <div className="grid h-full grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-3 overflow-y-auto">
                      {BacklogEntryDummyData.map((entry) => (
                        <BacklogEntry
                          key={entry.id}
                          title={entry.title}
                          imageLink={entry.imageLink}
                          imageAlt={entry.imageAlt}
                          genre={entry.genre}
                          platform={entry.platform}
                          status={entry.status}
                          owned={entry.owned}
                          interest={entry.interest}
                          review={entry.review}
                          reviewStars={entry.reviewStars}
                          note={entry.note}
                          howLongToBeat={entry.howLongToBeat}
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
