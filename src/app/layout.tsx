import "./styles/globals.css";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
        <head>
            <meta charSet="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <title>Backlog Manager</title>
            <link rel="icon" href="/vercel.svg" />
        </head>
      <body className="font-spaceMono">
        {children}
      </body>
    </html>
  );
}
