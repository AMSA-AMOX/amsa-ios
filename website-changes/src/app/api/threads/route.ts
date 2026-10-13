import { NextResponse, after } from "next/server";
import { supabase } from "@/lib/supabase";
import { ROLES, verifyToken } from "@/lib/auth";
import { hiddenUserIds, isBlockedEitherWay } from "@/lib/blocks";
import { pushNewQuestion } from "@/lib/push";

type ThreadRow = {
  id: number;
  askerId: number;
  recipientId: number;
  question: string;
  answer: string | null;
  answeredAt: string | null;
  createdAt: string;
  isAnonymous: boolean;
};

type UserRow = {
  id: number;
  firstName: string;
  lastName: string;
  profilePic: string | null;
  role: string | null;
};

type ThreadItem = {
  id: number;
  question: string;
  answer: string | null;
  answeredAt: string | null;
  createdAt: string;
  status: "answered" | "pending";
  isAnonymous: boolean;
  asker: { id: number; firstName: string; lastName: string; profilePic: string | null } | null;
  recipient: { id: number; firstName: string; lastName: string; profilePic: string | null } | null;
};

const SELECT_COLS = "id, askerId, recipientId, question, answer, answeredAt, createdAt, isAnonymous";

async function enrichThreads(rows: ThreadRow[]): Promise<ThreadItem[]> {
  if (rows.length === 0) return [];
  const userIds = Array.from(
    new Set([...rows.map((r) => r.askerId), ...rows.map((r) => r.recipientId)])
  );
  const { data: users } = await supabase
    .from("Users")
    .select("id, firstName, lastName, profilePic")
    .in("id", userIds);

  const byId = new Map<number, UserRow>(
    ((users ?? []) as UserRow[]).map((u) => [u.id, u])
  );

  return rows.map((r) => ({
    id: r.id,
    question: r.question,
    answer: r.answer,
    answeredAt: r.answeredAt,
    createdAt: r.createdAt,
    status: r.answer !== null ? "answered" : "pending",
    isAnonymous: r.isAnonymous ?? false,
    asker: byId.get(r.askerId) ?? null,
    recipient: byId.get(r.recipientId) ?? null,
  }));
}

// GET /api/threads
// ?view=inbox  → caller's inbox (sent or received depending on role)
// default      → all answered threads, cursor-paginated
export async function GET(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  const url = new URL(request.url);
  const view = url.searchParams.get("view");

  try {
    if (view === "inbox") {
      const isRecipient = [ROLES.AMBASSADOR, ROLES.US_MEMBER, ROLES.ADMIN, ROLES.BOARD_MEMBER].includes(
        payload.role as any
      );

      let query = supabase
        .from("Threads")
        .select(SELECT_COLS)
        .order("createdAt", { ascending: false })
        .limit(50);

      if (isRecipient) {
        query = query.eq("recipientId", payload.id);
      } else {
        query = query.eq("askerId", payload.id);
      }

      const [{ data, error }, hidden] = await Promise.all([query, hiddenUserIds(payload.id)]);
      if (error) {
        console.error("GET /api/threads?view=inbox failed:", error);
        return NextResponse.json({ message: "Failed to load inbox" }, { status: 500 });
      }

      const rows = ((data ?? []) as ThreadRow[]).filter((r) => !hidden.has(r.askerId) && !hidden.has(r.recipientId));
      const threads = await enrichThreads(rows);
      return NextResponse.json({ threads });
    }

    // Default: all answered threads, cursor-paginated
    const limitRaw = Number(url.searchParams.get("limit") ?? "25");
    const limit = Math.min(50, Math.max(1, Number.isFinite(limitRaw) ? limitRaw : 25));
    const cursor = url.searchParams.get("cursor");

    let query = supabase
      .from("Threads")
      .select(SELECT_COLS)
      .not("answer", "is", null)
      .order("answeredAt", { ascending: false })
      .limit(limit);

    if (cursor) {
      query = query.lt("answeredAt", cursor);
    }

    const { data, error } = await query;
    if (error) {
      console.error("GET /api/threads failed:", error);
      return NextResponse.json({ message: "Failed to load threads" }, { status: 500 });
    }

    const rows = (data ?? []) as ThreadRow[];
    const enriched = await enrichThreads(rows);
    // Hide recipient identity in public feed for anonymous answers
    const threads = enriched.map((t) =>
      t.isAnonymous ? { ...t, recipient: null } : t
    );
    const nextCursor =
      rows.length === limit ? (rows[rows.length - 1].answeredAt ?? null) : null;

    return NextResponse.json({ threads, nextCursor });
  } catch (e) {
    console.error("GET /api/threads exception:", e);
    return NextResponse.json({ message: "Failed to load threads" }, { status: 500 });
  }
}

// POST /api/threads — ask a question (member only)
export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  if (payload.role !== ROLES.MEMBER) {
    return NextResponse.json(
      { message: "Only members can ask questions." },
      { status: 403 }
    );
  }

  try {
    const body = await request.json();
    const recipientId = typeof body?.recipientId === "number" ? body.recipientId : null;
    const question =
      typeof body?.question === "string" ? body.question.trim() : "";
    const isPublic = typeof body?.isPublic === "boolean" ? body.isPublic : true;

    if (!recipientId || !Number.isFinite(recipientId)) {
      return NextResponse.json({ message: "recipientId is required." }, { status: 400 });
    }
    if (recipientId === payload.id) {
      return NextResponse.json(
        { message: "You cannot ask yourself a question." },
        { status: 400 }
      );
    }
    if (!question || question.length > 600) {
      return NextResponse.json(
        { message: "Question must be between 1 and 600 characters." },
        { status: 400 }
      );
    }

    if (await isBlockedEitherWay(payload.id, recipientId)) {
      return NextResponse.json({ message: "You can't send questions to this member." }, { status: 403 });
    }

    // Verify recipient exists and has the right role
    const { data: recipient, error: recipientError } = await supabase
      .from("Users")
      .select("id, firstName, lastName, profilePic, role")
      .eq("id", recipientId)
      .single();

    if (
      recipientError ||
      !recipient ||
      !["ambassador", "us_member", "board_member", "admin"].includes((recipient as UserRow).role ?? "")
    ) {
      return NextResponse.json(
        { message: "Recipient not found or not eligible to receive questions." },
        { status: 404 }
      );
    }

    const now = new Date().toISOString();
    const { data: inserted, error: insertError } = await supabase
      .from("Threads")
      .insert({ askerId: payload.id, recipientId, question, isPublic, createdAt: now, updatedAt: now })
      .select(SELECT_COLS)
      .single();

    if (insertError) {
      // Partial unique index violation — open question already exists
      if ((insertError as any).code === "23505") {
        return NextResponse.json(
          { message: "You already have an open question to this person. Wait for a reply before asking again." },
          { status: 409 }
        );
      }
      console.error("POST /api/threads insert failed:", insertError);
      return NextResponse.json({ message: "Failed to submit question." }, { status: 500 });
    }

    const { data: asker } = await supabase
      .from("Users")
      .select("id, firstName, lastName, profilePic")
      .eq("id", payload.id)
      .single();

    const thread: ThreadItem = {
      id: (inserted as ThreadRow).id,
      question: (inserted as ThreadRow).question,
      answer: null,
      answeredAt: null,
      createdAt: (inserted as ThreadRow).createdAt,
      status: "pending",
      isAnonymous: false,
      asker: (asker as UserRow) ?? null,
      recipient: recipient as UserRow,
    };

    after(() => pushNewQuestion(asker as UserRow | null, recipientId));

    return NextResponse.json({ thread }, { status: 201 });
  } catch (e) {
    console.error("POST /api/threads exception:", e);
    return NextResponse.json({ message: "Failed to submit question." }, { status: 500 });
  }
}
