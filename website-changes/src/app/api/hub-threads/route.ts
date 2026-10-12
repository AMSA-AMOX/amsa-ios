import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import { hiddenUserIds } from "@/lib/blocks";

type HubThreadRow = {
  id: number;
  askerId: number;
  title: string;
  question: string;
  category: string;
  categoryDomain: string | null;
  images: string[];
  status: string;
  isAnon: boolean;
  approvedBy: number | null;
  approvedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

type UserRow = {
  id: number;
  firstName: string;
  lastName: string;
  profilePic: string | null;
};

type Counts = {
  commentCounts: Map<number, number>;
  upvoteCounts: Map<number, number>;
  userUpvotedIds: Set<number>;
};

/** Askers, comment counts and upvotes all depend only on the thread rows — one wave. */
async function loadThreadExtras(rows: HubThreadRow[], viewerId: number, withCounts: boolean) {
  const userMap = new Map<number, UserRow>();
  const counts: Counts = { commentCounts: new Map(), upvoteCounts: new Map(), userUpvotedIds: new Set() };
  if (rows.length === 0) return { userMap, counts };

  const askerIds = Array.from(new Set(rows.filter((r) => !r.isAnon).map((r) => r.askerId)));
  const threadIds = rows.map((r) => r.id);

  const [usersRes, commentsRes, upvotesRes] = await Promise.all([
    askerIds.length > 0
      ? supabase.from("Users").select("id, firstName, lastName, profilePic").in("id", askerIds)
      : Promise.resolve({ data: [] as UserRow[] }),
    withCounts
      ? supabase.from("HubComments").select("threadId").in("threadId", threadIds)
      : Promise.resolve({ data: [] as { threadId: number }[] }),
    withCounts
      ? supabase.from("HubThreadUpvotes").select("threadId, userId").in("threadId", threadIds)
      : Promise.resolve({ data: [] as { threadId: number; userId: number }[] }),
  ]);

  ((usersRes.data ?? []) as UserRow[]).forEach((u) => userMap.set(u.id, u));
  ((commentsRes.data ?? []) as { threadId: number }[]).forEach((row) => {
    counts.commentCounts.set(row.threadId, (counts.commentCounts.get(row.threadId) ?? 0) + 1);
  });
  ((upvotesRes.data ?? []) as { threadId: number; userId: number }[]).forEach((row) => {
    counts.upvoteCounts.set(row.threadId, (counts.upvoteCounts.get(row.threadId) ?? 0) + 1);
    if (row.userId === viewerId) counts.userUpvotedIds.add(row.threadId);
  });

  return { userMap, counts };
}

function shapeThreads(rows: HubThreadRow[], userMap: Map<number, UserRow>, counts: Counts) {
  return rows.map((r) => ({
    id: r.id,
    title: r.title ?? "",
    body: r.question,
    category: r.category ?? "general",
    categoryDomain: r.categoryDomain ?? null,
    images: r.images ?? [],
    status: r.status,
    isAnon: r.isAnon,
    asker: r.isAnon ? null : (userMap.get(r.askerId) ?? null),
    commentCount: counts.commentCounts.get(r.id) ?? 0,
    upvoteCount: counts.upvoteCounts.get(r.id) ?? 0,
    hasUpvoted: counts.userUpvotedIds.has(r.id),
    approvedAt: r.approvedAt,
    createdAt: r.createdAt,
  }));
}

// GET /api/hub-threads — approved feed (cursor-paginated)
// GET /api/hub-threads?view=pending — board member+ pending queue
export async function GET(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  const url = new URL(request.url);
  const view = url.searchParams.get("view");
  const cursor = url.searchParams.get("cursor");
  const limitRaw = Number(url.searchParams.get("limit") ?? "20");
  const limit = Math.min(50, Math.max(1, Number.isFinite(limitRaw) ? limitRaw : 20));

  const SELECT = "id, askerId, title, question, category, categoryDomain, images, status, isAnon, approvedBy, approvedAt, createdAt, updatedAt";

  try {
    const isBoardPlus = ["board_member", "admin"].includes(payload.role);

    if (view === "pending") {
      if (!isBoardPlus) return NextResponse.json({ message: "Forbidden" }, { status: 403 });

      const { data, error } = await supabase
        .from("HubThreads")
        .select(SELECT)
        .eq("status", "pending")
        .order("createdAt", { ascending: true })
        .limit(limit);

      if (error) {
        console.error("GET /api/hub-threads?view=pending failed:", error);
        return NextResponse.json({ message: "Failed to load pending threads" }, { status: 500 });
      }

      const rows = (data ?? []) as HubThreadRow[];
      const { userMap, counts } = await loadThreadExtras(rows, payload.id, false);
      return NextResponse.json({ threads: shapeThreads(rows, userMap, counts) });
    }

    let query = supabase
      .from("HubThreads")
      .select(SELECT)
      .eq("status", "approved")
      .order("approvedAt", { ascending: false })
      .limit(limit);

    if (cursor) query = query.lt("approvedAt", cursor);

    const [{ data, error }, hidden] = await Promise.all([query, hiddenUserIds(payload.id)]);
    if (error) {
      console.error("GET /api/hub-threads failed:", error);
      return NextResponse.json({ message: "Failed to load threads" }, { status: 500 });
    }

    const allRows = (data ?? []) as HubThreadRow[];
    // The cursor comes from the unfiltered page so hidden threads don't end pagination early.
    const nextCursor = allRows.length === limit ? (allRows[allRows.length - 1].approvedAt ?? null) : null;
    const rows = allRows.filter((r) => !hidden.has(r.askerId));
    const { userMap, counts } = await loadThreadExtras(rows, payload.id, true);
    const threads = shapeThreads(rows, userMap, counts);

    return NextResponse.json({ threads, nextCursor });
  } catch (e) {
    console.error("GET /api/hub-threads exception:", e);
    return NextResponse.json({ message: "Failed to load threads" }, { status: 500 });
  }
}

// POST /api/hub-threads — any authenticated user submits a thread
export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const body = await request.json();
    const title = typeof body?.title === "string" ? body.title.trim() : "";
    const question = typeof body?.body === "string" ? body.body.trim() : "";
    const category = typeof body?.category === "string" ? body.category.trim() : "general";
    const categoryDomain = typeof body?.categoryDomain === "string" ? body.categoryDomain.trim() : null;
    const isAnon = typeof body?.isAnon === "boolean" ? body.isAnon : false;
    const images: string[] = Array.isArray(body?.images)
      ? body.images.filter((u: unknown) => typeof u === "string").slice(0, 1)
      : [];

    if (!title || title.length > 150) {
      return NextResponse.json({ message: "Title must be between 1 and 150 characters." }, { status: 400 });
    }
    if (question.length > 2000) {
      return NextResponse.json({ message: "Body must be at most 2000 characters." }, { status: 400 });
    }

    const now = new Date().toISOString();
    const { data: inserted, error } = await supabase
      .from("HubThreads")
      .insert({ askerId: payload.id, title, question, category, categoryDomain, images, isAnon, status: "pending", createdAt: now, updatedAt: now })
      .select("id")
      .single();

    if (error) {
      console.error("POST /api/hub-threads insert failed:", error);
      return NextResponse.json({ message: "Failed to submit post." }, { status: 500 });
    }

    return NextResponse.json({ thread: inserted }, { status: 201 });
  } catch (e) {
    console.error("POST /api/hub-threads exception:", e);
    return NextResponse.json({ message: "Failed to submit post." }, { status: 500 });
  }
}
