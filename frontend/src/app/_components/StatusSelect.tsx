"use client";
import { useState } from "react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "shadcn_components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "shadcn_components/ui/dialog";
import { Button } from "shadcn_components/ui/button";
import { Input } from "shadcn_components/ui/input";
import { Label } from "shadcn_components/ui/label";
import { PlusCircle, Trash2, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { DEFAULT_STATUSES } from "~/lib/api/backlog";
import {
  useCustomStatuses,
  useCreateCustomStatus,
  useDeleteCustomStatus,
} from "~/hooks/useBacklog";

const STATUS_NAME_MAX_LENGTH = 20;

interface StatusSelectProps {
  value: string;
  onValueChange: (value: string) => void;
  className?: string;
  placeholder?: string;
}

export function StatusSelect({
  value,
  onValueChange,
  className,
  placeholder = "Select status",
}: StatusSelectProps) {
  const [addDialogOpen, setAddDialogOpen] = useState(false);
  const [newStatusName, setNewStatusName] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const { data: customStatuses = [] } = useCustomStatuses();
  const createStatusMutation = useCreateCustomStatus();
  const deleteStatusMutation = useDeleteCustomStatus();

  const isKnownStatus =
    (DEFAULT_STATUSES as readonly string[]).includes(value) ||
    customStatuses.some((status) => status.name === value);

  const trimmedName = newStatusName.trim();
  const nameError =
    trimmedName.length === 0
      ? ""
      : trimmedName.length > STATUS_NAME_MAX_LENGTH
        ? `Max ${STATUS_NAME_MAX_LENGTH} characters`
        : DEFAULT_STATUSES.includes(
              trimmedName as (typeof DEFAULT_STATUSES)[number],
            )
          ? "That's already a default status"
          : customStatuses.some((status) => status.name === trimmedName)
            ? "You already have a status with that name"
            : "";

  const handleCreate = async () => {
    if (trimmedName.length === 0 || nameError) return;
    setIsCreating(true);
    try {
      const created = await createStatusMutation.mutateAsync(trimmedName);
      onValueChange(created.name);
      setNewStatusName("");
      setAddDialogOpen(false);
      toast.success(`Status "${created.name}" created`);
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to create status. Please try again.",
      );
    } finally {
      setIsCreating(false);
    }
  };

  const handleDelete = async (
    event: React.MouseEvent,
    statusId: number,
    statusName: string,
  ) => {
    event.stopPropagation();
    try {
      await deleteStatusMutation.mutateAsync(statusId);
      if (value === statusName) onValueChange("");
      toast.success(`Status "${statusName}" deleted`);
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to delete status. Please try again.",
      );
    }
  };

  return (
    <>
      <Select value={value} onValueChange={onValueChange}>
        <SelectTrigger className={className}>
          <SelectValue placeholder={placeholder} />
        </SelectTrigger>
        <SelectContent>
          {DEFAULT_STATUSES.map((status) => (
            <SelectItem key={status} value={status}>
              {status}
            </SelectItem>
          ))}
          {value && !isKnownStatus && (
            <SelectItem key={value} value={value}>
              {value}
            </SelectItem>
          )}
          {customStatuses.map((status) => (
            <div key={status.id} className="relative flex items-center">
              <SelectItem value={status.name} className="flex-1 pr-14">
                {status.name}
              </SelectItem>
              <button
                type="button"
                onClick={(e) => void handleDelete(e, status.id, status.name)}
                aria-label={`Delete status ${status.name}`}
                className="absolute right-8 text-gray-400 opacity-70 transition-opacity hover:text-red-400 hover:opacity-100"
              >
                <Trash2 className="h-3.5 w-3.5" />
              </button>
            </div>
          ))}
          <div className="border-t pt-1" onSelect={(e) => e.preventDefault()}>
            <button
              type="button"
              onClick={() => setAddDialogOpen(true)}
              className="flex w-full cursor-pointer items-center gap-2 rounded-sm px-2 py-1.5 text-sm hover:bg-black/10"
            >
              <PlusCircle className="h-4 w-4" />
              Add Status
            </button>
          </div>
        </SelectContent>
      </Select>

      <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
        <DialogContent className="border-2 border-white bg-black p-6">
          <DialogHeader>
            <DialogTitle className="text-white">Add Custom Status</DialogTitle>
          </DialogHeader>
          <div className="space-y-2">
            <Label htmlFor="new-status-name" className="text-white">
              Status name
            </Label>
            <Input
              id="new-status-name"
              value={newStatusName}
              onChange={(e) => setNewStatusName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") void handleCreate();
              }}
              maxLength={STATUS_NAME_MAX_LENGTH}
              placeholder='e.g. "Playing in Co-Op"'
              className="bg-black text-white"
            />
            {nameError && <p className="text-sm text-red-400">{nameError}</p>}
            <Button
              onClick={() => void handleCreate()}
              disabled={isCreating || trimmedName.length === 0 || !!nameError}
              className="w-full gap-2 bg-white text-black hover:bg-gray-200"
            >
              {isCreating && <Loader2 className="h-4 w-4 animate-spin" />}
              Create Status
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
