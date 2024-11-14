import { eq } from 'drizzle-orm';
import { db } from '@/db';
import { SelectUser, usersTable } from '../schema';

export async function deleteUser(id: SelectUser['id']) {
    await db.delete(usersTable).where(eq(usersTable.id, id));
}