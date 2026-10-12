import { NextResponse, after } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import { sendReportEmail } from "@/lib/email/resend";
import {
  REPORT_REASONS,
  REPORT_REASON_LABELS,
  REPORT_TARGET_LABELS,
  REPORT_TARGET_TYPES,
  resolveTarget,
  type ReportReason,
  type ReportTargetType,
} from "@/lib/reports";

const MAX_DETAILS = 1000;

// POST /api/reports — { targetType, targetId, reason, details? }
// Any signed-in member can report content they didn't write (or another
// member's profile). One report per member per item.
export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const body = await request.json().catch(() => ({}));
    const targetType = String(body?.targetType ?? "") as ReportTargetType;
    const targetId = String(body?.targetId ?? "").trim();
    const reason = String(body?.reason ?? "") as ReportReason;
    const details = typeof body?.details === "string" ? body.details.trim().slice(0, MAX_DETAILS) || null : null;

    if (!REPORT_TARGET_TYPES.includes(targetType) || !targetId) {
      return NextResponse.json({ message: "Invalid report target." }, { status: 400 });
    }
    if (!REPORT_REASONS.includes(reason)) {
      return NextResponse.json({ message: "Pick a reason." }, { status: 400 });
    }

    const target = await resolveTarget(targetType, targetId, payload.id);
    if (!target) {
      return NextResponse.json({ message: "That content no longer exists." }, { status: 404 });
    }
    if (target.ownerId === payload.id) {
      return NextResponse.json({ message: "You can't report your own content." }, { status: 400 });
    }

    const { data: report, error } = await supabase
      .from("ContentReports")
      .insert({
        reporterId: payload.id,
        targetType,
        targetId,
        targetUserId: target.ownerId,
        reason,
        details,
      })
      .select("id")
      .single();

    if (error) {
      if (error.code === "23505") {
        return NextResponse.json({ message: "You already reported this." }, { status: 409 });
      }
      console.error("POST /api/reports insert failed:", error);
      return NextResponse.json({ message: "Failed to submit report." }, { status: 500 });
    }

    const queueUrl = `${request.headers.get("origin") ?? new URL(request.url).origin}/dashboard/admin/reports`;
    after(async () => {
      const { data: reporter } = await supabase
        .from("Users")
        .select("id, email, firstName, lastName")
        .eq("id", payload.id)
        .maybeSingle();
      await sendReportEmail({
        targetLabel: REPORT_TARGET_LABELS[targetType],
        reasonLabel: REPORT_REASON_LABELS[reason],
        details,
        preview: target.preview,
        reporter: {
          id: payload.id,
          name: `${reporter?.firstName ?? ""} ${reporter?.lastName ?? ""}`.trim() || "A member",
          email: reporter?.email ?? "",
        },
        queueUrl,
      }).catch((e) => console.error("Report email failed:", e));
    });

    return NextResponse.json({ report: { id: report.id } }, { status: 201 });
  } catch (e) {
    console.error("POST /api/reports exception:", e);
    return NextResponse.json({ message: "Failed to submit report." }, { status: 500 });
  }
}
