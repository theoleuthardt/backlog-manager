"use client";
import React from "react";
import { ScrollSection } from "components/ScrollSection";
import Image from "next/image";

export const Features = () => {
  return (
    <div className="min-h-screen">
      <ScrollSection className="px-4 py-20">
        <div className="mx-auto max-w-7xl">
          <div className="mb-16 text-center">
            <h2 className="mb-6 text-4xl font-bold text-white md:text-5xl">
              Features
            </h2>
          </div>

          <div className="grid gap-8 md:grid-cols-3">
            <ScrollSection
              delay={0}
              className="rounded-xl border-2 border-white bg-transparent p-8 text-center transition-all duration-300 hover:shadow-lg"
            >
              <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-transparent">
                <Image
                  src="/backlog.png"
                  alt="backlog"
                  width={64}
                  height={64}
                />
              </div>
              <h3 className="mb-4 text-2xl font-semibold text-white">
                Backlog Management
              </h3>
              <p className="text-white">
                Add games to your backlog, update the status or remove games.
              </p>
            </ScrollSection>

            <ScrollSection
              delay={200}
              className="rounded-xl border-2 border-white bg-transparent p-8 text-center transition-all duration-300 hover:shadow-lg"
            >
              <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-transparent">
                <Image src="/filter.png" alt="filter" width={64} height={64} />
              </div>
              <h3 className="mb-4 text-2xl font-semibold text-white">
                Organization & Filtering
              </h3>
              <p className="text-white">
                Add own categories to organize your games, filter through a
                search bar or use the inbuild filter and sort methods.
              </p>
            </ScrollSection>

            <ScrollSection
              delay={400}
              className="rounded-xl border-2 border-white bg-transparent p-8 text-center transition-all duration-300 hover:shadow-lg"
            >
              <div className="mx-auto mb-6 flex h-16 w-16 items-center justify-center rounded-full bg-transparent">
                <Image
                  src="/csv_import.png"
                  alt="csv_import"
                  width={64}
                  height={64}
                />
              </div>
              <h3 className="mb-4 text-2xl font-semibold text-white">
                External Import
              </h3>
              <p className="text-white">
                Import an existing backlog from a sheet file or from an external
                service like Steam.
              </p>
            </ScrollSection>
          </div>
        </div>
      </ScrollSection>
    </div>
  );
};
