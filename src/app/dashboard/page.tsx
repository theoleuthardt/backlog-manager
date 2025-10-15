import Image from "next/image";
import {
  Navbar,
  Footer,
  BacklogEntry,
  CustomDropdownMenu,
  UniSlider,
  SearchBar,
} from "components";
import { BacklogEntryDummyData, dashboardNavLinks } from "~/constants";
import { Button } from "shadcn_components/ui/button";
import { dropdownData } from "~/constants/dropdownData";

export default function Dashboard() {
  return (
    <>
      <div className="relative min-h-screen overflow-hidden">
        <div className={`relative z-10 flex flex-col bg-black text-white`}>
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
                      <CustomDropdownMenu
                        items={dropdownData}
                        triggerText={"Dropdown 1"}
                      />
                      <CustomDropdownMenu
                        items={dropdownData}
                        triggerText={"Dropdown 2"}
                      />
                      <CustomDropdownMenu
                        items={dropdownData}
                        triggerText={"Dropdown 3"}
                        className="mb-10"
                      />
                      <UniSlider defaultValue={50} step={1} maxvalue={100} />
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
            <Footer />
          </div>
        </div>
      </div>
    </>
  );
}
