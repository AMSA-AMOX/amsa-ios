import { NextResponse } from "next/server";
import { verifyToken } from "@/lib/auth";
import { rpc } from "@/lib/rpc";

export type NotificationItem = {
  id: string;
  type: "follow" | "event" | "thread_question" | "thread_answered" | "welcome" | "post_report" | "content_report";
  title: string;
  description: string;
  happenedAt: string;
  href?: string;
  avatarUrl?: string | null;
};

/**
 * One round trip: `get_notifications` (supabase/migrations/*_rpc.sql) builds
 * the merged, sorted feed in SQL. It used to take 8–10 sequential queries.
 */
export async function GET(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const data = await rpc<{ notifications: NotificationItem[] }>("get_notifications", {
      p_user_id: payload.id,
      p_role: payload.role ?? "member",
    });
    return NextResponse.json({ notifications: data?.notifications ?? [] });
  } catch (e: any) {
    console.error("GET /api/user/notifications failed:", e);
    return NextResponse.json({ notifications: [] }, { status: 500 });
  }
}
