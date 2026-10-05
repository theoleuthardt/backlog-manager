export function Footer() {
  return (
    <footer className="white mt-4 justify-center bg-transparent px-8 py-4 text-white shadow">
      <div className="flex flex-row items-center justify-between gap-2">
        <p className="text-sm">
          &copy; {new Date().getFullYear()} Backlog Manager
        </p>
        <div className="flex flex-row">
          <p className="text-sm">Icons by </p>
          <a
            className="ml-1 text-sm font-bold hover:underline"
            href="https://icons8.com/"
            target="_blank"
            rel="noopener noreferrer"
          >
            Icons8
          </a>
        </div>
      </div>
    </footer>
  );
}
