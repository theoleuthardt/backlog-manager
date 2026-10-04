import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { BACKLOG_QUERY_KEYS } from "~/hooks/useBacklog";
import * as spaceApi from "~/lib/api/space";

const SPACE_KEY = ["space"] as const;

export function useSpace() {
  return useQuery({ queryKey: SPACE_KEY, queryFn: spaceApi.getSpace });
}

function useRefreshSpace() {
  const queryClient = useQueryClient();
  return async () => {
    await queryClient.invalidateQueries({ queryKey: SPACE_KEY });
  };
}

export function useInviteToSpace() {
  const refresh = useRefreshSpace();
  return useMutation({
    mutationFn: spaceApi.inviteToSpace,
    onSuccess: refresh,
  });
}

export function useAcceptSpaceInvitation() {
  const refresh = useRefreshSpace();
  return useMutation({
    mutationFn: spaceApi.acceptSpaceInvitation,
    onSuccess: refresh,
  });
}

/**
 * Leaves the space or declines a pending invitation. Every cached
 * backlog query is dropped afterwards, since the space's entries must
 * not linger in the cache once access is gone.
 */
export function useLeaveSpace() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: spaceApi.leaveSpace,
    onSuccess: async () => {
      for (const queryKey of BACKLOG_QUERY_KEYS) {
        queryClient.removeQueries({ queryKey });
      }
      await queryClient.invalidateQueries({ queryKey: SPACE_KEY });
    },
  });
}
