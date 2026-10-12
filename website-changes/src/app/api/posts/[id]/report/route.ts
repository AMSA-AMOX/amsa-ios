import { NextResponse, after } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import { toUserId } from "@/lib/blocks";
import { sendReportEmail } from "@/lib/email/resend";
import { REPORT_REASONS, REPORT_REASON_LABELS, type ReportReason } from "@/lib/reports";

type RouteContext = {
  params: Promise<{ id: string }>;
};

// Kept for the web feed and older app builds; new clients use POST /api/reports.
// Reports now go to "ContentReports" (see migrations/20261002_0007_safety.sql).
export async function POST(request: Request, context: RouteContext) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  const params = await context.params;
  const postId = Number(params.id);
  if (!Number.isFinite(postId)) {
    return NextResponse.json({ message: "Invalid post id" }, { status: 400 });
  }

  const { data: post } = await supabase
    .from("Posts")
    .select("id, userId, body")
    .eq("id", postId)
    .single();

  if (!post) {
    return NextResponse.json({ message: "Post not found" }, { status: 404 });
  }
  const ownerId = toUserId(post.userId);
  if (ownerId === payload.id) {
    return NextResponse.json({ message: "You cannot report your own post." }, { status: 400 });
  }

  const body = await request.json().catch(() => ({}));
  const reason: ReportReason = REPORT_REASONS.includes(body?.reason) ? body.reason : "other";

  const { error } = await supabase.from("ContentReports").insert({
    reporterId: payload.id,
    targetType: "post",
    targetId: String(postId),
    targetUserId: ownerId,
    reason,
  });

  if (error) {
    // unique constraint = already reported
    if (error.code === "23505") {
      return NextResponse.json({ message: "You already reported this post." }, { status: 409 });
    }
    console.error("Post report insert failed:", error);
    return NextResponse.json({ message: "Failed to submit report." }, { status: 500 });
  }

  const queueUrl = `${request.headers.get("origin") ?? new URL(request.url).origin}/dashboard/admin/reports`;
  after(async () => {
    const { data: reporter } = await supabase
      .from("Users")
      .select("email, firstName, lastName")
      .eq("id", payload.id)
      .maybeSingle();
    await sendReportEmail({
      targetLabel: "Post",
      reasonLabel: REPORT_REASON_LABELS[reason],
      details: null,
      preview: String(post.body ?? "").slice(0, 280),
      reporter: {
        id: payload.id,
        name: `${reporter?.firstName ?? ""} ${reporter?.lastName ?? ""}`.trim() || "A member",
        email: reporter?.email ?? "",
      },
      queueUrl,
    }).catch((e) => console.error("Report email failed:", e));
  });

  return NextResponse.json({ ok: true });
}
