"use client";
import React, { useRef, useState } from "react";
import { Button } from "shadcn_components/ui/button";
import Image from "next/image";
import { api } from "~/trpc/react";

export const ImportCSVContent = () => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const parseCSV = api.csv.parse.useMutation({
    onSuccess: (result) => {
      if (result.success) {
        console.log("CSV parsed successfully!");
        console.log("Imported data:", result.data);
      } else {
        setError(result.error);
      }
      setIsLoading(false);
    },
    onError: (err) => {
      setError(err.message || "Failed to parse CSV");
      setIsLoading(false);
    },
  });

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
      setIsLoading(true);
      setError(null);
      const fileContent = await file.text();
      await parseCSV.mutateAsync({ content: fileContent });
    } catch (error) {
      setError(error instanceof Error ? error.message : "Error processing CSV file");
      setIsLoading(false);
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

