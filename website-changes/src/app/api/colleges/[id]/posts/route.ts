import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import { hiddenUserIds } from "@/lib/blocks";

function optionalUserId(request: Request): number | null {
  try {
    return verifyToken(request).id;
  } catch {
    return null;
  }
}

function deriveLogoUrl(website: string | null): string | null {
  if (!website) return null;
  try {
    const host = new URL(website.startsWith("http") ? website : `https://${website}`).hostname;
    if (!host) return null;
    // Strip www. to match the root domain that img.logo.dev uses
    const rootHost = host.startsWith("www.") ? host.slice(4) : host;
    const token = process.env.NEXT_PUBLIC_LOGO_DEV_TOKEN;
    return token
      ? `https://img.logo.dev/${rootHost}?token=${encodeURIComponent(token)}`
      : `https://img.logo.dev/${rootHost}`;
  } catch {
    return null;
  }
}

const normalizeImages = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0);
};

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;
  const unitid = Number(id);
  if (!Number.isFinite(unitid) || unitid <= 0) {
    return NextResponse.json({ posts: [] });
  }

  const { data: collegeRow, error: collegeErr } = await supabase
    .from("colleges_base")
    .select("unitid, name, school_url")
    .eq("unitid", unitid)
    .maybeSingle();

  if (collegeErr || !collegeRow) {
    return NextResponse.json({ posts: [] });
  }

  const college = {
    id: collegeRow.unitid as number,
    name: collegeRow.name as string,
    logoUrl: deriveLogoUrl(collegeRow.school_url as string | null),
  };

  const hiddenPromise = hiddenUserIds(optionalUserId(request));
  const { data: allPosts, error } = await supabase
    .from("Posts")
    .select("id, userId, body, images, helpfulCount, createdAt, reviewStatus, reviewedAt, reviewNote, topic")
    .eq("tagged_college_id", unitid)
    .eq("reviewStatus", "approved")
    .order("createdAt", { ascending: false })
    .limit(20);

  if (error) {
    console.error("College posts fetch failed:", error);
    return NextResponse.json({ posts: [] });
  }

  // Hidden when either side blocked the other.
  const hidden = await hiddenPromise;
  const posts = (allPosts ?? []).filter((p) => p.userId == null || !hidden.has(Number(p.userId)));
  if (posts.length === 0) return NextResponse.json({ posts: [] });

  const userIds = Array.from(
    new Set(posts.map((p) => p.userId).filter((id): id is number => id != null))
  );

  let usersById = new Map<number, { id: number; firstName: string; lastName: string; headline: string | null; profilePic: string | null }>();
  if (userIds.length > 0) {
    const { data: users } = await supabase
      .from("Users")
      .select("id, firstName, lastName, headline, profilePic")
      .in("id", userIds);
    for (const u of users ?? []) usersById.set(u.id, u);
  }

  return NextResponse.json({
    posts: posts.map((post) => ({
      id: post.id,
      body: post.body,
      images: normalizeImages(post.images),
      createdAt: post.createdAt,
      appreciationCount: post.helpfulCount ?? 0,
      hasAppreciated: false,
      reviewStatus: post.reviewStatus,
      reviewedAt: post.reviewedAt,
      reviewNote: post.reviewNote,
      topic: post.topic ?? null,
      author: usersById.get(post.userId) ?? null,
      college,
    })),
  });
}
