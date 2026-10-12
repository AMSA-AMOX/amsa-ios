import { NextRequest, NextResponse } from "next/server";
import { verifyToken } from "@/lib/auth";
import { rpc } from "@/lib/rpc";

export type ShellData = {
  /** null = no US Member application on file */
  membershipStatus: "pending" | "approved" | "rejected" | null;
  /** notifications newer than ?seenAfter= (the client's amsa_notif_seen) */
  unseenNotifications: number;
  /** moderation queue sizes; zero for roles that can't see them */
  pending: { posts: number; threads: number; verification: number; reports: number };
};

/**
 * GET /api/me/shell?seenAfter=<ISO>
 * Everything the persistent dashboard chrome (sidebar badges, membership
 * banner) needs, computed by one SQL function. Replaces four list fetches
 * that were only used for `.length`.
 */
export async function GET(request: NextRequest) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  const seenAfterRaw = request.nextUrl.searchParams.get("seenAfter");
  const seenAfter = seenAfterRaw && !Number.isNaN(Date.parse(seenAfterRaw)) ? new Date(seenAfterRaw).toISOString() : null;

  try {
    const shell = await rpc<ShellData>("get_shell", {
      p_user_id: payload.id,
      p_role: payload.role ?? "member",
      p_seen_after: seenAfter,
    });
    return NextResponse.json(shell, { headers: { "Cache-Control": "private, no-store" } });
  } catch (e) {
    console.error("GET /api/me/shell failed:", e);
    return NextResponse.json(
      { membershipStatus: null, unseenNotifications: 0, pending: { posts: 0, threads: 0, verification: 0, reports: 0 } },
      { status: 500 },
    );
  }
}
