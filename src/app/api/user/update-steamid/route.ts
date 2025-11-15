import { NextRequest, NextResponse } from "next/server";
import { auth } from "~/server/auth";
import pool from "~/server/db";
import { getUserByEmail } from "~/server/db/CRUD/read";
import { updateUserByEmail } from "~/server/db/CRUD/update";

export async function POST(request: NextRequest) {
    const session = await auth();
    if (!session?.user) {
      return NextResponse.json({ message: "Unauthorized" }, { status: 401 });
    }
  
    const { steamId } = await request.json();
    const email = session.user.email;
    if (!steamId || !email) {
      return NextResponse.json({ message: "Missing steamId or email" }, { status: 400 });
    }
  
    try {
      const userFromDb = await getUserByEmail(pool, email);
  
      const updatedUser = await updateUserByEmail(
        pool,
        email,
        userFromDb.Username,
        userFromDb.PasswordHash,
        steamId
      );
  
      return NextResponse.json({ message: "Steam ID updated", user: updatedUser });
    } catch (e) {
      return NextResponse.json({ message: "Update failed", error: (e as Error).message }, { status: 500 });
    }
  }
  