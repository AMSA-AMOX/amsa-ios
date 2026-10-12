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

// GET /api/places/reviews?stateAbbr=CA
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const stateAbbr = searchParams.get("stateAbbr")?.toUpperCase();
  const userId = optionalUserId(request);

  if (!stateAbbr) {
    return NextResponse.json({ message: "stateAbbr is required." }, { status: 400 });
  }

  try {
    const hiddenPromise = hiddenUserIds(userId);
    const { data, error } = await supabase
      .from("place_reviews")
      .select("id, state_abbr, content, images, created_at, user_id, helpful_user_ids, Users(id, firstName, lastName, profilePic)")
      .eq("state_abbr", stateAbbr)
      .order("created_at", { ascending: false });

    if (error) {
      console.error("GET /api/places/reviews failed:", error);
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
    console.error("GET /api/places/reviews exception:", e);
    return NextResponse.json({ message: "Failed to load reviews." }, { status: 500 });
  }
}

// POST /api/places/reviews
export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const body = await request.json();
    const stateAbbr = typeof body?.stateAbbr === "string" ? body.stateAbbr.trim().toUpperCase() : "";
    const content = typeof body?.content === "string" ? body.content.trim() : "";
    const images: string[] = Array.isArray(body?.images)
      ? body.images.filter((u: unknown) => typeof u === "string").slice(0, 4)
      : [];

    if (!stateAbbr || stateAbbr.length > 3) {
      return NextResponse.json({ message: "Invalid stateAbbr." }, { status: 400 });
    }
    if (!content || content.length < 10 || content.length > 2000) {
      return NextResponse.json({ message: "Review must be 10–2000 characters." }, { status: 400 });
    }

    const { data: inserted, error } = await supabase
      .from("place_reviews")
      .insert({ state_abbr: stateAbbr, user_id: payload.id, content, images })
      .select("id, state_abbr, content, images, created_at, user_id")
      .single();

    if (error) {
      console.error("POST /api/places/reviews failed:", error);
      return NextResponse.json({ message: "Failed to submit review." }, { status: 500 });
    }

    const { data: user } = await supabase
      .from("Users")
      .select("id, firstName, lastName, profilePic")
      .eq("id", payload.id)
      .single();

    return NextResponse.json({ review: { ...inserted, Users: user ?? null } }, { status: 201 });
  } catch (e) {
    console.error("POST /api/places/reviews exception:", e);
    return NextResponse.json({ message: "Failed to submit review." }, { status: 500 });
  }
}
