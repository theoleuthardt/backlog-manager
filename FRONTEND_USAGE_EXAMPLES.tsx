/**
 * FRONTEND USAGE EXAMPLES FOR TRPC BACKLOG ROUTER
 *
 * This file shows you how to use the backlog tRPC router in your React components.
 */

import { api } from "~/trpc/react";

/**
 * EXAMPLE 1: Create a new backlog entry
 */
export function CreateBacklogEntryExample() {
  const createEntry = api.backlog.createEntry.useMutation({
    onSuccess: () => {
      console.log("Backlog entry created successfully!");
    },
  });

  const handleCreate = async () => {
    await createEntry.mutateAsync({
      title: "The Legend of Zelda: Breath of the Wild",
      genre: "Action-Adventure",
      platform: "Nintendo Switch",
      status: "Playing",
      owned: true,
      interest: 9,
      imageLink: "https://example.com/image.jpg",
      reviewStars: 5,
      review: "Amazing game!",
    });
  };

  return <button onClick={handleCreate}>Create Entry</button>;
}

/**
 * EXAMPLE 2: Get all backlog entries for current user
 */
export function GetBacklogEntriesExample() {
  const { data: entries, isLoading } = api.backlog.getEntries.useQuery();

  if (isLoading) return <div>Loading...</div>;

  return (
    <ul>
      {entries?.map((entry) => (
        <li key={entry.backlogEntryID}>{entry.title}</li>
      ))}
    </ul>
  );
}

/**
 * EXAMPLE 3: Get entries by status
 */
export function GetEntriesByStatusExample() {
  const { data: completedEntries } = api.backlog.getEntriesByStatus.useQuery({
    status: "Completed",
  });

  return <div>Completed games: {completedEntries?.length}</div>;
}

/**
 * EXAMPLE 4: Create a category
 */
export function CreateCategoryExample() {
  const createCategory = api.backlog.createCategory.useMutation();

  const handleCreate = async () => {
    await createCategory.mutateAsync({
      categoryName: "Platformers",
      color: "#FF0000",
      description: "Platformer games",
    });
  };

  return <button onClick={handleCreate}>Create Category</button>;
}

/**
 * EXAMPLE 5: Get all categories
 */
export function GetCategoriesExample() {
  const { data: categories } = api.backlog.getCategories.useQuery();

  return (
    <ul>
      {categories?.map((cat) => (
        <li key={cat.categoryID}>{cat.name}</li>
      ))}
    </ul>
  );
}

/**
 * EXAMPLE 6: Add category to entry
 */
export function AddCategoryToEntryExample() {
  const addCategory = api.backlog.addCategoryToEntry.useMutation();

  const handleAddCategory = async () => {
    await addCategory.mutateAsync({
      categoryId: 1,
      backlogEntryId: 5,
    });
  };

  return <button onClick={handleAddCategory}>Add Category</button>;
}

/**
 * EXAMPLE 7: Update a backlog entry
 */
export function UpdateBacklogEntryExample() {
  const updateEntry = api.backlog.updateEntry.useMutation();

  const handleUpdate = async () => {
    await updateEntry.mutateAsync({
      backlogEntryId: 1,
      title: "Updated Title",
      genre: "Action-Adventure",
      platform: "Nintendo Switch",
      status: "Completed",
      owned: true,
      interest: 8,
      reviewStars: 4,
      review: "Great game",
    });
  };

  return <button onClick={handleUpdate}>Update Entry</button>;
}

/**
 * EXAMPLE 8: Delete an entry
 */
export function DeleteBacklogEntryExample() {
  const deleteEntry = api.backlog.deleteEntry.useMutation();

  const handleDelete = async () => {
    await deleteEntry.mutateAsync({
      backlogEntryId: 1,
    });
  };

  return <button onClick={handleDelete}>Delete Entry</button>;
}

/**
 * COMPLETE COMPONENT EXAMPLE
 */
export function CompleteBacklogComponent() {
  // Queries
  const { data: entries, refetch: refetchEntries } = api.backlog.getEntries.useQuery();
  const { data: categories } = api.backlog.getCategories.useQuery();

  // Mutations
  const createEntry = api.backlog.createEntry.useMutation({
    onSuccess: () => refetchEntries(),
  });

  const updateEntry = api.backlog.updateEntry.useMutation({
    onSuccess: () => refetchEntries(),
  });

  const deleteEntry = api.backlog.deleteEntry.useMutation({
    onSuccess: () => refetchEntries(),
  });

  return (
    <div>
      <h1>Backlog Manager</h1>

      <button
        onClick={async () => {
          await createEntry.mutateAsync({
            title: "New Game",
            genre: "RPG",
            platform: "PC",
            status: "Backlog",
            owned: false,
            interest: 7,
          });
        }}
      >
        Add Entry
      </button>

      <div>
        {entries?.map((entry) => (
          <div key={entry.backlogEntryID}>
            <h3>{entry.title}</h3>
            <p>Genre: {entry.genre}</p>
            <p>Platform: {entry.platform}</p>
            <p>Status: {entry.status}</p>

            <button
              onClick={async () => {
                await updateEntry.mutateAsync({
                  backlogEntryId: entry.backlogEntryID,
                  title: entry.title,
                  genre: entry.genre,
                  platform: entry.platform,
                  status: "Playing",
                  owned: entry.owned,
                  interest: entry.interest,
                });
              }}
            >
              Mark as Playing
            </button>

            <button
              onClick={async () => {
                await deleteEntry.mutateAsync({
                  backlogEntryId: entry.backlogEntryID,
                });
              }}
            >
              Delete
            </button>
          </div>
        ))}
      </div>

      <div>
        <h2>Categories</h2>
        {categories?.map((cat) => (
          <div key={cat.categoryID}>{cat.name}</div>
        ))}
      </div>
    </div>
  );
}

