"use client";
import { useState } from "react";
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
  AlertDialogTrigger,
} from "shadcn_components/ui/alert-dialog";
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

function SpaceHeader({ space }: { space: SpaceData }) {
  const leave = useLeaveSpace();
  const partner = space.members.find((member) => !member.isMe);

  const confirmLeave = async () => {
    try {
      await leave.mutateAsync();
      toast.success("You left the shared space");
    } catch (error) {
      toast.error(errorMessage(error, "Failed to leave the space"));
    }
  };

  return (
    <div className="surface-glow bg-surface mb-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-white/30 p-4">
      <div className="flex flex-col gap-1">
        <h1 className="flex items-center gap-2 text-xl font-bold">
          <Users className="h-5 w-5" />
          Shared space
        </h1>
        <p className="text-sm text-white/70">
          {partner === undefined
            ? "Invite a friend to share a co-op backlog."
            : partner.status === "invited"
              ? `Waiting for ${partner.username} to accept your invitation.`
              : `Shared with ${partner.username}. Status and categories are shared; rating and playtime stay your own.`}
        </p>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        {partner === undefined && <InviteForm />}
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button
              variant="outline"
              size="sm"
              className="gap-2"
              disabled={leave.isPending}
            >
              <LogOut className="h-4 w-4" />
              {partner?.status === "invited" ? "Cancel invitation" : "Leave space"}
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Leave the shared space?</AlertDialogTitle>
              <AlertDialogDescription>
                You lose access to its entries. They stay with your partner;
                once nobody is left in the space they are deleted.
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
      </div>
    </div>
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
    <div className="surface-glow bg-surface mx-auto mt-12 flex max-w-lg flex-col items-center gap-4 rounded-xl border border-white/30 p-8 text-center">
      <Users className="h-10 w-10" />
      <h1 className="text-xl font-bold">
        {inviter?.username ?? "Someone"} invited you to a shared space
      </h1>
      <p className="text-sm text-white/70">
        A shared backlog for games you play together. Your ratings and
        playtime stay your own.
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
            void run(() => decline.mutateAsync(), "Failed to decline invitation")
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
    <div className="surface-glow bg-surface mx-auto mt-12 flex max-w-lg flex-col items-center gap-4 rounded-xl border border-white/30 p-8 text-center">
      <Users className="h-10 w-10" />
      <h1 className="text-xl font-bold">Start a shared space</h1>
      <p className="text-sm text-white/70">
        Invite a friend by username to keep a co-op backlog together. Status
        and categories are shared, ratings and playtime stay your own, and
        only Steam games can be added.
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
        <SpaceHeader space={space} />
        <DashboardContent />
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
