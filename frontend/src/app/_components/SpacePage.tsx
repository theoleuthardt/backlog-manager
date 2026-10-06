import { useRef, useState } from "react";
import { Loader2, LogOut, Users } from "lucide-react";
import { toast } from "sonner";
import { Button } from "shadcn_components/ui/button";
import { Input } from "shadcn_components/ui/input";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "shadcn_components/ui/alert-dialog";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "shadcn_components/ui/popover";
import { DashboardContent } from "components/DashboardContent";
import { DashboardSearch } from "components/DashboardSearch";
import { Footer } from "components/Footer";
import { Navbar } from "components/Navbar";
import { BacklogScopeProvider } from "~/app/context/BacklogScopeContext";
import { DashboardProvider } from "~/app/context/DashboardContext";
import { spaceNavLinks } from "~/constants";
import {
  useAcceptSpaceInvitation,
  useInviteToSpace,
  useLeaveSpace,
  useSpace,
} from "~/hooks/useSpace";
import type { SpaceData } from "~/lib/api/space";

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof Error ? error.message : fallback;
}

function InviteForm() {
  const [username, setUsername] = useState("");
  const invite = useInviteToSpace();

  const submit = async (event: React.FormEvent) => {
    event.preventDefault();
    const trimmed = username.trim();
    if (!trimmed) return;
    try {
      await invite.mutateAsync(trimmed);
      setUsername("");
      toast.success(`Invitation sent to ${trimmed}`);
    } catch (error) {
      toast.error(errorMessage(error, "Failed to send invitation"));
    }
  };

  return (
    <form onSubmit={(event) => void submit(event)} className="flex gap-2">
      <Input
        value={username}
        onChange={(event) => setUsername(event.target.value)}
        placeholder="Username of your co-op partner"
        aria-label="Username to invite"
        className="max-w-xs"
      />
      <Button type="submit" disabled={invite.isPending || !username.trim()}>
        {invite.isPending ? (
          <Loader2 className="h-4 w-4 animate-spin" />
        ) : (
          "Invite"
        )}
      </Button>
    </form>
  );
}

/**
 * Inline notice shown only while the space has no active partner: the
 * invite form when nobody is invited, or the pending invitation. Those
 * need an action or explain why the grid is empty, so they stay visible.
 */
function SpaceNotice({ space }: { space: SpaceData }) {
  const partner = space.members.find((member) => !member.isMe);
  if (partner?.status === "active") return null;

  return (
    <div className="mb-3 flex flex-wrap items-center justify-end gap-3">
      {partner === undefined ? (
        <InviteForm />
      ) : (
        <span className="text-foreground/70 text-sm">
          Waiting for {partner.username} to accept your invitation.
        </span>
      )}
    </div>
  );
}

/**
 * Unobtrusive space controls, placed left of the Steam sync button: a
 * small button whose hover (or click, on touch) popover explains how the
 * space works and holds the leave action, which still asks for
 * confirmation.
 */
function SpaceControls({ space }: { space: SpaceData }) {
  const leave = useLeaveSpace();
  const partner = space.members.find((member) => !member.isMe);
  const [infoOpen, setInfoOpen] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const closeTimer = useRef<ReturnType<typeof setTimeout> | undefined>(
    undefined,
  );

  const showInfo = () => {
    clearTimeout(closeTimer.current);
    setInfoOpen(true);
  };
  const hideInfo = () => {
    closeTimer.current = setTimeout(() => setInfoOpen(false), 150);
  };

  const confirmLeave = async () => {
    try {
      await leave.mutateAsync();
      toast.success("You left the shared space");
    } catch (error) {
      toast.error(errorMessage(error, "Failed to leave the space"));
    }
  };

  const leaveLabel =
    partner?.status === "invited" ? "Cancel invitation" : "Leave space";

  return (
    <>
      <Popover open={infoOpen} onOpenChange={setInfoOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="ghost"
            size="sm"
            className="text-foreground/60 hover:text-foreground gap-1.5 text-xs"
            aria-label="Shared space info"
            onMouseEnter={showInfo}
            onMouseLeave={hideInfo}
          >
            <Users className="h-4 w-4" />
            {partner?.status === "active" ? partner.username : "Shared space"}
          </Button>
        </PopoverTrigger>
        <PopoverContent
          align="end"
          className="flex flex-col gap-3"
          onMouseEnter={showInfo}
          onMouseLeave={hideInfo}
          onOpenAutoFocus={(event) => event.preventDefault()}
        >
          <p className="text-foreground/80 text-sm">
            {partner?.status === "active"
              ? `Shared with ${partner.username}. Status and categories are shared; rating and playtime stay your own.`
              : "A shared co-op backlog for two. Status and categories are shared; rating and playtime stay your own."}
          </p>
          <Button
            variant="outline"
            size="sm"
            className="gap-2 self-start"
            disabled={leave.isPending}
            onClick={() => {
              setInfoOpen(false);
              setConfirmOpen(true);
            }}
          >
            <LogOut className="h-4 w-4" />
            {leaveLabel}
          </Button>
        </PopoverContent>
      </Popover>
      <AlertDialog open={confirmOpen} onOpenChange={setConfirmOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Leave the shared space?</AlertDialogTitle>
            <AlertDialogDescription>
              You lose access to its entries. They stay with your partner; once
              nobody is left in the space they are deleted.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Stay</AlertDialogCancel>
            <AlertDialogAction onClick={() => void confirmLeave()}>
              Leave
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </>
  );
}

function InvitationCard({ space }: { space: SpaceData }) {
  const accept = useAcceptSpaceInvitation();
  const decline = useLeaveSpace();
  const inviter = space.members.find((member) => !member.isMe);

  const run = async (action: () => Promise<unknown>, failure: string) => {
    try {
      await action();
    } catch (error) {
      toast.error(errorMessage(error, failure));
    }
  };

  return (
    <div className="surface-glow bg-surface border-border mx-auto mt-12 flex max-w-lg flex-col items-center gap-4 rounded-xl border p-8 text-center">
      <Users className="h-10 w-10" />
      <h1 className="text-xl font-bold">
        {inviter?.username ?? "Someone"} invited you to a shared space
      </h1>
      <p className="text-foreground/70 text-sm">
        A shared backlog for games you play together. Your ratings and playtime
        stay your own.
      </p>
      <div className="flex gap-3">
        <Button
          disabled={accept.isPending || decline.isPending}
          onClick={() =>
            void run(() => accept.mutateAsync(), "Failed to accept invitation")
          }
        >
          Accept
        </Button>
        <Button
          variant="outline"
          disabled={accept.isPending || decline.isPending}
          onClick={() =>
            void run(
              () => decline.mutateAsync(),
              "Failed to decline invitation",
            )
          }
        >
          Decline
        </Button>
      </div>
    </div>
  );
}

function NoSpaceCard() {
  return (
    <div className="surface-glow bg-surface border-border mx-auto mt-12 flex max-w-lg flex-col items-center gap-4 rounded-xl border p-8 text-center">
      <Users className="h-10 w-10" />
      <h1 className="text-xl font-bold">Start a shared space</h1>
      <p className="text-foreground/70 text-sm">
        Invite a friend by username to keep a co-op backlog together. Status and
        categories are shared, ratings and playtime stay your own, and only
        Steam games can be added.
      </p>
      <InviteForm />
    </div>
  );
}

/**
 * The shared space page: invitation handling, and for an active member
 * the regular dashboard pointed at the space through
 * BacklogScopeProvider, so grouping, filtering, drag and drop and the
 * entry dialog behave exactly as on the personal dashboard.
 */
export function SpacePage() {
  const { data: space, isLoading, error } = useSpace();
  const activeSpaceId = space?.myStatus === "active" ? space.spaceId : null;

  let content: React.ReactNode;
  if (isLoading) {
    content = (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Loader2 className="text-primary h-12 w-12 animate-spin" />
      </div>
    );
  } else if (error || !space) {
    content = (
      <p className="mt-12 text-center text-red-500">
        {errorMessage(error, "Failed to load the shared space")}
      </p>
    );
  } else if (space.myStatus === "invited") {
    content = <InvitationCard space={space} />;
  } else if (space.myStatus === null) {
    content = <NoSpaceCard />;
  } else {
    content = (
      <>
        <SpaceNotice space={space} />
        <DashboardContent toolbarStart={<SpaceControls space={space} />} />
      </>
    );
  }

  const page = (
    <DashboardProvider>
      <div className="relative min-h-screen overflow-x-clip">
        <div className="relative z-10 flex flex-col text-white">
          <div className="flex min-h-screen flex-col">
            <Navbar
              navbarLinks={spaceNavLinks}
              center={activeSpaceId !== null ? <DashboardSearch /> : undefined}
            />
            <main className="drop-in flex-grow px-3 md:px-4">
              <div className="mx-auto max-w-[100rem]">{content}</div>
            </main>
            <Footer />
          </div>
        </div>
      </div>
    </DashboardProvider>
  );

  return activeSpaceId !== null ? (
    <BacklogScopeProvider spaceId={activeSpaceId}>{page}</BacklogScopeProvider>
  ) : (
    page
  );
}
