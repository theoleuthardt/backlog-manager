import { Link } from "react-router";
import { Users } from "lucide-react";
import { useSpace } from "~/hooks/useSpace";

/**
 * Navbar entry for the shared space. A dot marks a pending invitation
 * so it is noticed without opening the page.
 */
export function SpaceNavLink({ showLabel = false }: { showLabel?: boolean }) {
  const { data: space } = useSpace();
  const hasInvitation = space?.myStatus === "invited";

  return (
    <Link
      to="/space"
      aria-label={
        hasInvitation ? "Shared space (new invitation)" : "Shared space"
      }
      className={
        showLabel
          ? "flex h-11 items-center gap-3 rounded-md px-3 text-base font-semibold hover:bg-white/10"
          : "relative flex h-8 w-8 items-center justify-center"
      }
    >
      <span className="relative flex h-8 w-8 items-center justify-center">
        <Users className="h-7 w-7 text-white" />
        {hasInvitation && (
          <span className="bg-primary absolute top-0 right-0 h-2.5 w-2.5 rounded-full" />
        )}
      </span>
      {showLabel && "Shared space"}
    </Link>
  );
}
