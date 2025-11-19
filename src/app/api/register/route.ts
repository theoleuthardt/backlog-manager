import { NextRequest, NextResponse } from "next/server";
import argon2 from "argon2";
import { createUser } from "~/server/db/CRUD/create";
import pool from "~/server/db"; 

export async function POST(req: NextRequest) {
  try {
    const { username, email, password, steamId } = await req.json();

    if (!username || !email || !password) {
      return NextResponse.json({ message: "Missing fields" }, { status: 400 });
    }

    const passwordHash = await argon2.hash(password);

    const user = await createUser(pool, username, email, passwordHash, steamId);

    return NextResponse.json({ user }, { status: 201 });
  } catch (error: any) {
    if (error.code === "23505") {
      return NextResponse.json({ message: "Email or username already in use" }, { status: 400 });
    }
    return NextResponse.json({ message: "Internal server error" }, { status: 500 });
  }
}
