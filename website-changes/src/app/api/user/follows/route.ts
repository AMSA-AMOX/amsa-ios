import { NextResponse, after } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import { isBlockedEitherWay } from "@/lib/blocks";
import { pushNewFollower } from "@/lib/push";
import { FOLLOWS_TABLE_CANDIDATES, getFollowsTableName } from "@/lib/follows-table";

export async function GET(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    // Table name is resolved once per process (see follows-table.ts), so this
    // is exactly two parallel queries per call.
    const followsTable = await getFollowsTableName();
    const [followersRes, followingRes] = await Promise.all([
      supabase.from(followsTable).select("id", { count: "exact", head: true }).eq("followingId", payload.id),
      supabase.from(followsTable).select("followingId").eq("followerId", payload.id),
    ]);

    if (followersRes.error) throw followersRes.error;
    if (followingRes.error) throw followingRes.error;

    const followingIds = (followingRes.data ?? []).map((r) => r.followingId as number);
    return NextResponse.json({
      followersCount: followersRes.count ?? 0,
      followingCount: followingIds.length,
      followingIds,
    });
  } catch (e: any) {
    if (e?.code !== "PGRST205") console.error(e);
    return NextResponse.json({ followersCount: 0, followingCount: 0, followingIds: [] });
  }
}

export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const { followingId } = await request.json();
    if (!followingId || followingId === payload.id) {
      return NextResponse.json({ message: "Invalid followingId" }, { status: 400 });
    }
    if (await isBlockedEitherWay(payload.id, Number(followingId))) {
      return NextResponse.json({ message: "You can't follow this member." }, { status: 403 });
    }

    let lastError: any = null;
    for (const followsTable of FOLLOWS_TABLE_CANDIDATES) {
      const { error } = await supabase
        .from(followsTable)
        .insert({ followerId: payload.id, followingId });

      if (!error || error.code === "23505") {
        // 23505: already following, so nothing new to tell them.
        if (!error) after(() => pushNewFollower(payload.id, Number(followingId)));
        return NextResponse.json({ message: "Followed" });
      }

      lastError = error;
      if (error.code !== "PGRST205") {
        throw error;
      }
    }

    if (lastError?.code === "PGRST205") {
      return NextResponse.json(
        { message: "Follow system is not configured yet. Please apply the follow-table migration." },
        { status: 503 }
      );
    }

    throw lastError ?? new Error("Failed to resolve follows table");
  } catch (e: any) {
    console.error(e);
    return NextResponse.json({ message: "Failed to follow" }, { status: 500 });
  }
}
