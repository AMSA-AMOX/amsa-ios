import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { ROLES, verifyToken } from "@/lib/auth";
import { hiddenUserIds } from "@/lib/blocks";

type RawPostRow = {
  id: number;
  userId: number | string | null;
  body: string;
  images: string[] | null;
  helpfulCount: number | null;
  createdAt: string;
  reviewStatus: "pending" | "approved" | "rejected";
  reviewedAt: string | null;
  reviewNote: string | null;
  topic: string | null;
  tagged_college_id: number | null;
};

type RawUserRow = {
  id: number;
  firstName: string;
  lastName: string;
  headline: string | null;
  profilePic: string | null;
};

type RawCollegeRow = {
  unitid: number;
  name: string;
  school_url: string | null;
};

const normalizeImages = (value: unknown): string[] => {
  if (!Array.isArray(value)) return [];
  return value.filter((entry): entry is string => typeof entry === "string" && entry.trim().length > 0);
};

const parseLimit = (value: string | null) => {
  const parsed = Number(value ?? "25");
  if (!Number.isFinite(parsed)) return 25;
  return Math.min(100, Math.max(1, Math.floor(parsed)));
};

const normalizeId = (value: unknown): number | null => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
};

const canModerate = (role: string | null | undefined) =>
  role === ROLES.ADMIN || role === ROLES.BOARD_MEMBER;

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

export async function GET(request: Request) {
  const url = new URL(request.url);
  const limit = parseLimit(url.searchParams.get("limit"));
  const creatorIdParam = url.searchParams.get("creatorId");
  const creatorId = creatorIdParam ? Number(creatorIdParam) : null;
  const includeModeration = url.searchParams.get("includeModeration") === "true";
  const reviewStatusParam = url.searchParams.get("reviewStatus");

  let viewerId: number | null = null;
  let viewerRole: string | null = null;
  try {
    const payload = verifyToken(request);
    viewerId = payload.id;
    viewerRole = payload.role;
  } catch {
    viewerId = null;
    viewerRole = null;
  }

  try {
    let query = supabase
      .from("Posts")
      .select("id, userId, body, images, helpfulCount, createdAt, reviewStatus, reviewedAt, reviewNote, topic, tagged_college_id")
      .order("createdAt", { ascending: false })
      .limit(limit);

    if (creatorId && Number.isFinite(creatorId)) {
      query = query.eq("userId", creatorId);
    }
    if (reviewStatusParam && ["pending", "approved", "rejected"].includes(reviewStatusParam)) {
      query = query.eq("reviewStatus", reviewStatusParam);
    }

    const canViewModeration =
      includeModeration &&
      !!viewerId &&
      (canModerate(viewerRole) || (creatorId !== null && creatorId === viewerId));

    if (!canViewModeration) {
      query = query.eq("reviewStatus", "approved");
    }

    // Blocked members (either way) are hidden from the feed, but never from moderation views.
    const [{ data: posts, error }, hidden] = await Promise.all([
      query,
      canViewModeration ? Promise.resolve(new Set<number>()) : hiddenUserIds(viewerId),
    ]);
    if (error) {
      console.error("List posts failed:", error);
      return NextResponse.json({ message: "Failed to load posts" }, { status: 500 });
    }

    const safePosts = ((posts ?? []) as RawPostRow[]).filter((post) => !hidden.has(normalizeId(post.userId) ?? -1));
    if (safePosts.length === 0) return NextResponse.json({ posts: [] });

    const userIds = Array.from(
      new Set(
        safePosts
          .map((post) => normalizeId(post.userId))
          .filter((id): id is number => id !== null)
      )
    );

    const collegeIds = Array.from(
      new Set(
        safePosts
          .map((p) => p.tagged_college_id)
          .filter((id): id is number => id !== null)
      )
    );

    // Authors, tagged colleges and the viewer's appreciations only depend on
    // the post list — fetch all three in one wave.
    const [usersRes, collegesRes, helpfulRes] = await Promise.all([
      userIds.length > 0
        ? supabase.from("Users").select("id, firstName, lastName, headline, profilePic").in("id", userIds)
        : Promise.resolve({ data: [] as RawUserRow[], error: null }),
      collegeIds.length > 0
        ? supabase.from("colleges_base").select("unitid, name, school_url").in("unitid", collegeIds)
        : Promise.resolve({ data: [] as RawCollegeRow[], error: null }),
      viewerId
        ? supabase
            .from("PostHelpfuls")
            .select("postId")
            .eq("userId", viewerId)
            .in("postId", safePosts.map((post) => post.id))
        : Promise.resolve({ data: [] as Array<{ postId: number }>, error: null }),
    ]);

    if (usersRes.error) {
      console.error("List post users failed:", usersRes.error);
      return NextResponse.json({ message: "Failed to load posts" }, { status: 500 });
    }

    const usersById = new Map<number, RawUserRow>(
      ((usersRes.data ?? []) as RawUserRow[]).map((user) => [user.id, user])
    );
    const collegesById = new Map<number, RawCollegeRow>(
      ((collegesRes.data ?? []) as RawCollegeRow[]).map((c) => [c.unitid, c])
    );
    const appreciationSet = new Set(
      (helpfulRes.error ? [] : ((helpfulRes.data ?? []) as Array<{ postId: number }>)).map((row) => row.postId)
    );

    return NextResponse.json({
      posts: safePosts.map((post) => {
        const normalizedUserId = normalizeId(post.userId);
        const collegeRow = post.tagged_college_id ? collegesById.get(post.tagged_college_id) : undefined;
        return {
          id: post.id,
          body: post.body,
          images: normalizeImages(post.images),
          createdAt: post.createdAt,
          appreciationCount: post.helpfulCount ?? 0,
          hasAppreciated: appreciationSet.has(post.id),
          reviewStatus: post.reviewStatus,
          reviewedAt: post.reviewedAt,
          reviewNote: post.reviewNote,
          topic: post.topic ?? null,
          author: normalizedUserId !== null ? usersById.get(normalizedUserId) ?? null : null,
          college: collegeRow
            ? { id: collegeRow.unitid, name: collegeRow.name, logoUrl: deriveLogoUrl(collegeRow.school_url) }
            : null,
        };
      }),
    });
  } catch (e) {
    console.error("List posts exception:", e);
    return NextResponse.json({ message: "Failed to load posts" }, { status: 500 });
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
    if (
      payload.role !== ROLES.US_MEMBER &&
      payload.role !== ROLES.ADMIN &&
      payload.role !== ROLES.BOARD_MEMBER
    ) {
      return NextResponse.json(
        { message: "Only US members, board members, and admins can post." },
        { status: 403 }
      );
    }

    const body = await request.json();
    const text = typeof body?.body === "string" ? body.body.trim() : "";
    const images = normalizeImages(body?.images).slice(0, 6);

    // Accept topics array (new) or legacy single topic string
    let topic: string | null = null;
    if (Array.isArray(body?.topics) && body.topics.length > 0) {
      const validTopics = body.topics
        .filter((t: unknown): t is string => typeof t === "string" && t.trim().length > 0)
        .slice(0, 3);
      topic = validTopics.length > 0 ? validTopics.join(",") : null;
    } else if (typeof body?.topic === "string" && body.topic.trim().length > 0) {
      topic = body.topic.trim();
    }
    const reviewStatus = payload.role === ROLES.US_MEMBER ? "pending" : "approved";
    const nowIso = new Date().toISOString();
    const startOfUtcDay = new Date();
    startOfUtcDay.setUTCHours(0, 0, 0, 0);

    // Validate and resolve collegeId
    const rawCollegeId = body?.collegeId;
    let taggedCollegeId: number | null = null;
    if (rawCollegeId != null) {
      const parsed = Number(rawCollegeId);
      if (Number.isFinite(parsed) && parsed > 0) {
        const { count } = await supabase
          .from("colleges_base")
          .select("unitid", { count: "exact", head: true })
          .eq("unitid", parsed);
        if ((count ?? 0) > 0) taggedCollegeId = parsed;
      }
    }

    const { count: todayCount, error: countError } = await supabase
      .from("Posts")
      .select("*", { count: "exact", head: true })
      .eq("userId", payload.id)
      .gte("createdAt", startOfUtcDay.toISOString());

    if (countError) {
      console.error("Daily post count failed:", countError);
      return NextResponse.json({ message: "Failed to create post" }, { status: 500 });
    }
    if ((todayCount ?? 0) >= 2) {
      return NextResponse.json(
        { message: "You can submit up to 2 post requests per day." },
        { status: 429 }
      );
    }

    if (!text) {
      return NextResponse.json(
        { message: "Body is required." },
        { status: 400 }
      );
    }
    if (text.length > 4000) {
      return NextResponse.json(
        { message: "Body exceeds allowed length." },
        { status: 400 }
      );
    }

    const { data: insertedPost, error } = await supabase
      .from("Posts")
      .insert({
        userId: payload.id,
        body: text,
        images,
        topic,
        tagged_college_id: taggedCollegeId,
        reviewStatus,
        createdAt: nowIso,
        updatedAt: nowIso,
      })
      .select("id, userId, body, images, helpfulCount, createdAt, reviewStatus, reviewedAt, reviewNote, topic, tagged_college_id")
      .single();

    if (error || !insertedPost) {
      console.error("Create post failed:", error);
      return NextResponse.json({ message: "Failed to create post" }, { status: 500 });
    }

    const { data: author } = await supabase
      .from("Users")
      .select("id, firstName, lastName, headline, profilePic")
      .eq("id", payload.id)
      .single();

    let college = null;
    const raw = insertedPost as RawPostRow;
    if (raw.tagged_college_id) {
      const { data: collegeRow } = await supabase
        .from("colleges_base")
        .select("unitid, name, school_url")
        .eq("unitid", raw.tagged_college_id)
        .maybeSingle();
      if (collegeRow) {
        college = {
          id: (collegeRow as RawCollegeRow).unitid,
          name: (collegeRow as RawCollegeRow).name,
          logoUrl: deriveLogoUrl((collegeRow as RawCollegeRow).school_url),
        };
      }
    }

    return NextResponse.json({
      post: {
        id: raw.id,
        body: raw.body,
        images: normalizeImages(raw.images),
        createdAt: raw.createdAt,
        appreciationCount: raw.helpfulCount ?? 0,
        hasAppreciated: false,
        reviewStatus: raw.reviewStatus,
        reviewedAt: raw.reviewedAt,
        reviewNote: raw.reviewNote,
        topic: raw.topic ?? null,
        author: author ?? null,
        college,
      },
      requiresApproval: reviewStatus === "pending",
    });
  } catch (e) {
    console.error("Create post exception:", e);
    return NextResponse.json({ message: "Failed to create post" }, { status: 500 });
  }
}
