import { parse } from "csv-parse";

export interface CSVRecord {
  [key: string]: unknown;
}

export async function parseCSVContent(fileContent: string): Promise<CSVRecord[]> {
  return new Promise((resolve, reject) => {
    const records: CSVRecord[] = [];

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
      reject(new Error(`CSV parsing error: ${err.message}`));
    });

    parser.on("end", function () {
      resolve(transformRecords(records));
    });
  });
}

function transformRecords(records: CSVRecord[]): CSVRecord[] {
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

  return records.map((row: any) => {
    const transformedRow: CSVRecord = {};

    row.forEach((value: unknown, index: number) => {
      const key = keys[index];
      if (key !== undefined) {
        transformedRow[key] = value;
      }
    });

    return transformedRow;
  });
}