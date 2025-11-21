"use client";
import React, { useRef } from "react";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import { parse } from "csv-parse";

export const ImportCSVContent = () => {
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleButtonClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      processCSVFile(file);
    }
  };

  const processCSVFile = async (file: File) => {
    try {
      const fileContent = await file.text();
      const records: Record<string, unknown>[] = [];

      const parser = parse(fileContent, {
        columns: false,
        skip_empty_lines: true,
      });

      parser.on("readable", function () {
        let record;
        while ((record = parser.read()) !== null) {
          records.push(record);
        }
      });

      parser.on("error", function (err) {
        console.error("CSV parsing error:", err);
      });

      parser.on("end", function () {
        // Transform records to fixed structure [A, B, C, ...]
        const transformedData = records.map((row: any) => {
          const keys = [
            "A",
            "B",
            "C",
            "D",
            "E",
            "F",
            "G",
            "H",
            "I",
            "J",
            "K",
            "L",
            "M",
            "N",
            "O",
            "P",
            "Q",
            "R",
            "S",
            "T",
            "U",
            "V",
            "W",
            "X",
            "Y",
            "Z",
          ];
          const transformedRow: Record<string, unknown> = {};

          row.forEach((value: unknown, index: number) => {
              const key = keys[index];
              if (key !== undefined) {
                  transformedRow[key] = value;
              }
          });

          return transformedRow;
        });

        console.log("CSV parsed successfully!");
        console.log("Imported data:", transformedData);
      });
    } catch (error) {
      console.error("Error processing CSV file:", error);
    }
  };

  return (
    <div className="flex flex-col items-center justify-center gap-8 py-12">
      <div className="flex flex-col items-center gap-4">
        <Image
          src="/csv_import.png"
          alt="import CSV"
          width={64}
          height={64}
        />
        <h1 className="text-3xl font-bold">Import Backlog from CSV</h1>
        <p className="max-w-md text-center text-gray-400">
          Select a CSV file to import your game backlog entries
        </p>
      </div>

      <Button
        className="border-2 border-white font-bold text-white bg-black hover:bg-white hover:text-black"
        variant="outline"
        onClick={handleButtonClick}
        size="lg"
      >
        Select CSV File
      </Button>

      <input
        ref={fileInputRef}
        type="file"
        accept=".csv"
        className="hidden"
        onChange={handleFileChange}
      />
    </div>
  );
};

