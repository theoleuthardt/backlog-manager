import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { auth } from "./server/auth";

export const runtime = "nodejs";

const protectedPaths = ["/dashboard", "/setup_steam"];

export default async function middleware(request: NextRequest) {
  const session = await auth();
  const { pathname } = request.nextUrl;


  const isProtectedPath = protectedPaths.some((route) =>
    pathname.startsWith(route)
  );

  if (isProtectedPath && !session?.user) {
    const loginUrl = new URL("/login", request.url);
    return NextResponse.redirect(loginUrl);
  }


  return NextResponse.next();
}