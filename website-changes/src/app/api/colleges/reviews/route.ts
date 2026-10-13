import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import { hiddenUserIds, toUserId } from "@/lib/blocks";

function optionalUserId(request: Request): number | null {
  try {
    return verifyToken(request).id;
  } catch {
    return null;
  }
}

// GET /api/colleges/reviews?collegeId=123
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const collegeId = Number(searchParams.get("collegeId"));
  const userId = optionalUserId(request);

  if (!collegeId || !Number.isFinite(collegeId)) {
    return NextResponse.json({ message: "collegeId is required." }, { status: 400 });
  }

  try {
    const hiddenPromise = hiddenUserIds(userId);
    const { data, error } = await supabase
      .from("college_reviews")
      .select("id, college_id, content, images, created_at, user_id, helpful_user_ids, Users(id, firstName, lastName, profilePic)")
      .eq("college_id", collegeId)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("GET /api/colleges/reviews failed:", error);
      return NextResponse.json({ message: "Failed to load reviews." }, { status: 500 });
    }

    const hidden = await hiddenPromise;
    const enriched = (data ?? []).filter((r) => !hidden.has(toUserId(r.user_id) ?? -1)).map((r) => {
      const helpfulUserIds = (r.helpful_user_ids as number[] | null) ?? [];
      const { helpful_user_ids: _, ...rest } = r;
      return {
        ...rest,
        helpfulCount: helpfulUserIds.length,
        hasHelpful: userId !== null && helpfulUserIds.includes(userId),
      };
    });

    return NextResponse.json({ reviews: enriched });
  } catch (e) {
    console.error("GET /api/colleges/reviews exception:", e);
    return NextResponse.json({ message: "Failed to load reviews." }, { status: 500 });
  }
}

// POST /api/colleges/reviews
export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const body = await request.json();
    const collegeId = Number(body?.collegeId);
    const content = typeof body?.content === "string" ? body.content.trim() : "";
    const images: string[] = Array.isArray(body?.images)
      ? body.images.filter((u: unknown) => typeof u === "string").slice(0, 4)
      : [];

    if (!collegeId || !Number.isFinite(collegeId)) {
      return NextResponse.json({ message: "Invalid collegeId." }, { status: 400 });
    }
    if (!content || content.length < 10 || content.length > 2000) {
      return NextResponse.json({ message: "Review must be 10–2000 characters." }, { status: 400 });
    }

    const { data: inserted, error } = await supabase
      .from("college_reviews")
      .insert({ college_id: collegeId, user_id: payload.id, content, images })
      .select("id, college_id, content, images, created_at, user_id")
      .single();

    if (error) {
      console.error("POST /api/colleges/reviews failed:", error);
      return NextResponse.json({ message: "Failed to submit review." }, { status: 500 });
    }

    const { data: user } = await supabase
      .from("Users")
      .select("id, firstName, lastName, profilePic")
      .eq("id", payload.id)
      .single();

    return NextResponse.json({ review: { ...inserted, Users: user ?? null } }, { status: 201 });
  } catch (e) {
    console.error("POST /api/colleges/reviews exception:", e);
    return NextResponse.json({ message: "Failed to submit review." }, { status: 500 });
  }
}
