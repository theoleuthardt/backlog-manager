import { apiClient, apiErrorMessage } from "./client";
import type { components } from "./schema";

export interface SpaceMember {
  username: string;
  status: "active" | "invited";
  isMe: boolean;
}

export interface SpaceData {
  spaceId: number | null;
  myStatus: "active" | "invited" | null;
  members: SpaceMember[];
}

function toSpaceData(space: components["schemas"]["SpaceResponse"]): SpaceData {
  return {
    spaceId: space.space_id ?? null,
    myStatus: (space.my_status as SpaceData["myStatus"]) ?? null,
    members: space.members.map((member) => ({
      username: member.username,
      status: member.status as SpaceMember["status"],
      isMe: member.is_me,
    })),
  };
}

export async function getSpace(): Promise<SpaceData> {
  const { data, error } = await apiClient.GET("/api/space");
  if (error) throw new Error(apiErrorMessage(error, "Failed to load space"));
  return toSpaceData(data);
}

export async function inviteToSpace(username: string): Promise<void> {
  const { error } = await apiClient.POST("/api/space/invitations", {
    body: { username },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to send invitation"));
}

export async function acceptSpaceInvitation(): Promise<SpaceData> {
  const { data, error } = await apiClient.POST("/api/space/invitations/accept");
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to accept invitation"));
  return toSpaceData(data);
}

export async function leaveSpace(): Promise<void> {
  const { error } = await apiClient.DELETE("/api/space/membership");
  if (error) throw new Error(apiErrorMessage(error, "Failed to leave space"));
}
