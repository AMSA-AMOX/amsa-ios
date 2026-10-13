import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import { getFollowsTableName } from "@/lib/follows-table";

type BlockRow = { blockedId: number; createdAt: string };
type UserRow = { id: number; firstName: string | null; lastName: string | null; profilePic: string | null };

// GET /api/user/blocks — members the caller has blocked (Settings › Blocked members)
export async function GET(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const { data, error } = await supabase
      .from("UserBlocks")
      .select("blockedId, createdAt")
      .eq("blockerId", payload.id)
      .order("createdAt", { ascending: false });
    if (error) throw error;

    const rows = (data ?? []) as BlockRow[];
    const ids = rows.map((r) => r.blockedId);
    const { data: users } = ids.length > 0
      ? await supabase.from("Users").select("id, firstName, lastName, profilePic").in("id", ids)
      : { data: [] as UserRow[] };
    const byId = new Map(((users ?? []) as UserRow[]).map((u) => [u.id, u]));

    return NextResponse.json({
      blocks: rows
        .filter((r) => byId.has(r.blockedId))
        .map((r) => ({ ...byId.get(r.blockedId)!, blockedAt: r.createdAt })),
    });
  } catch (e) {
    console.error("GET /api/user/blocks failed:", e);
    return NextResponse.json({ message: "Failed to load blocked members." }, { status: 500 });
  }
}

// POST /api/user/blocks — { userId }
// Hides the member's content from the caller and the caller's from them,
// removes follows both ways and deletes unanswered direct questions between them.
export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const body = await request.json().catch(() => ({}));
    const userId = Number(body?.userId);
    if (!Number.isFinite(userId) || userId === payload.id) {
      return NextResponse.json({ message: "Invalid userId." }, { status: 400 });
    }

    const { data: target } = await supabase.from("Users").select("id").eq("id", userId).maybeSingle();
    if (!target) return NextResponse.json({ message: "Member not found." }, { status: 404 });

    const { error } = await supabase
      .from("UserBlocks")
      .upsert({ blockerId: payload.id, blockedId: userId }, { onConflict: "blockerId,blockedId", ignoreDuplicates: true });
    if (error) throw error;

    const followsTable = await getFollowsTableName().catch(() => null);
    await Promise.all([
      followsTable
        ? supabase
            .from(followsTable)
            .delete()
            .or(`and(followerId.eq.${payload.id},followingId.eq.${userId}),and(followerId.eq.${userId},followingId.eq.${payload.id})`)
        : Promise.resolve(),
      supabase
        .from("Threads")
        .delete()
        .is("answer", null)
        .or(`and(askerId.eq.${payload.id},recipientId.eq.${userId}),and(askerId.eq.${userId},recipientId.eq.${payload.id})`),
    ]);

    return NextResponse.json({ blocked: true });
  } catch (e) {
    console.error("POST /api/user/blocks failed:", e);
    return NextResponse.json({ message: "Failed to block member." }, { status: 500 });
  }
}
