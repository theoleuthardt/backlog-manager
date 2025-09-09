export function Footer() {
  return (
    <footer className="white bg-transparent px-8 py-4 text-white shadow shadow-inner">
      <div className="text-center text-sm">
        &copy; {new Date().getFullYear()} Backlog Manager. Alle Rechte
        vorbehalten.
      </div>
    </footer>
  );
}
