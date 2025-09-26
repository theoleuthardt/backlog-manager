"use client";
import { Navbar, Footer, BacklogEntry } from "components";
import { BacklogEntryDummyData, dashboardNavLinks } from "~/constants";
import Image from "next/image";
import { Button } from "shadcn_components/ui/button";
import { Slider } from "shadcn_components/ui/slider";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "shadcn_components/ui/dropdown-menu";
import { SearchBar } from "components/SearchBar";

export default function Dashboard() {
  return (
    <>
      <div
        className="relative min-h-screen overflow-hidden"
        style={{
          backgroundImage:
            "linear-gradient(to bottom, black 60%, #000000 100%)",
        }}
      >
        <div className="relative z-10 flex flex-col text-white">
          <div className="flex min-h-screen flex-col">
            <Navbar navbarLinks={dashboardNavLinks} />
            <main className="drop-in flex-grow px-4">
              <div className="mx-auto grid h-full max-w-[100rem] grid-rows-[1fr_auto] gap-6">
                <div id="upperSection" className="flex min-h-30 gap-8 p-4">
                  <div
                    id="leftBar"
                    className="h-[23rem] w-48 flex-shrink-0 p-4"
                  >
                    <SearchBar />
                    <Button
                      id="addEntryButton"
                      className="relative mb-4 h-[2.5rem] w-[10rem] rounded-3xl border-0 bg-blue-700 p-4 font-bold text-white hover:bg-blue-800 hover:text-white"
                      variant="outline"
                    >
                      <Image src="/add.png" alt="add" width={24} height={24} />
                      Add Entry
                    </Button>
                    <Button
                      id="csvImportButton"
                      className="relative mb-4 h-[2.5rem] w-[10rem] rounded-3xl border-0 bg-blue-700 p-4 font-bold text-white hover:bg-blue-800 hover:text-white"
                      variant="outline"
                    >
                      <Image
                        src="/csv_import.png"
                        alt="csv_import"
                        width={24}
                        height={24}
                      />
                      Import Backlog
                    </Button>
                    <Button
                      id="csvExportButton"
                      className="relative mb-4 h-[2.5rem] w-[10rem] rounded-3xl border-0 bg-blue-700 p-4 font-bold text-white hover:bg-blue-800 hover:text-white"
                      variant="outline"
                    >
                      <Image
                        src="/csv_export.png"
                        alt="csv_export"
                        width={24}
                        height={24}
                      />
                      Export Backlog
                    </Button>
                    <div
                      id="filterOptions"
                      className="mb-4 h-42 p-4 text-center"
                    >
                      <div className="mb-2 rounded-xl border-2 border-white hover:bg-white hover:text-black">
                        <DropdownMenu>
                          <DropdownMenuTrigger>Dropdown 1</DropdownMenuTrigger>
                          <DropdownMenuContent className="h-28 border-2 border-white bg-black">
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 1
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 2
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 3
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 4
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 5
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>
                      <div className="mb-2 rounded-xl border-2 border-white hover:bg-white hover:text-black">
                        <DropdownMenu>
                          <DropdownMenuTrigger>Dropdown 2</DropdownMenuTrigger>
                          <DropdownMenuContent className="h-28 border-2 border-white bg-black">
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 1
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 2
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 3
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 4
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>
                      <div className="mb-2 rounded-xl border-2 border-white hover:bg-white hover:text-black">
                        <DropdownMenu>
                          <DropdownMenuTrigger>Dropdown 3</DropdownMenuTrigger>
                          <DropdownMenuContent className="h-28 border-2 border-white bg-black">
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 1
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 2
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 3
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 4
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>
                      <div className="mb-10 rounded-xl border-2 border-white hover:bg-white hover:text-black">
                        <DropdownMenu>
                          <DropdownMenuTrigger>Dropdown 4</DropdownMenuTrigger>
                          <DropdownMenuContent className="h-28 border-2 border-white bg-black">
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 1
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 2
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 3
                            </DropdownMenuItem>
                            <DropdownMenuItem className="bg-black text-white hover:border-2 hover:border-white">
                              Option 4
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </div>
                    </div>
                    <div id="slider" className="mb-4 h-[2rem] text-center">
                      <Slider
                        className="invert"
                        defaultValue={[50]}
                        max={100}
                        step={1}
                      />
                    </div>
                    <div id="slider" className="mb-4 h-[2rem] text-center">
                      <Slider
                        className="invert"
                        defaultValue={[50]}
                        max={100}
                        step={1}
                      />
                    </div>
                  </div>

                  <div id="entryList" className="flex-1 overflow-hidden p-4">
                    <div className="grid h-full grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-2 overflow-y-auto">
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
              </div>
            </main>
          </div>
          <Footer />
        </div>
      </div>
    </>
  );
}
