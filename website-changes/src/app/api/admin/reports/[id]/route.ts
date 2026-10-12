import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import { removeTarget, type ReportTargetType } from "@/lib/reports";

type RouteContext = { params: Promise<{ id: string }> };

// PATCH /api/admin/reports/[id] — { action: "remove" | "dismiss" }
// "remove" deletes the content (clears a reported profile) and closes every
// open report on it; "dismiss" closes them and leaves the content up.
export async function PATCH(request: Request, context: RouteContext) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }
  if (payload.role !== "admin" && payload.role !== "board_member") {
    return NextResponse.json({ message: "Forbidden" }, { status: 403 });
  }

  const { id } = await context.params;
  const reportId = Number(id);
  if (!Number.isFinite(reportId)) {
    return NextResponse.json({ message: "Invalid report ID." }, { status: 400 });
  }

  try {
    const body = await request.json().catch(() => ({}));
    const action = body?.action;
    if (action !== "remove" && action !== "dismiss") {
      return NextResponse.json({ message: "action must be 'remove' or 'dismiss'." }, { status: 400 });
    }

    const { data: report } = await supabase
      .from("ContentReports")
      .select("id, targetType, targetId")
      .eq("id", reportId)
      .maybeSingle<{ id: number; targetType: ReportTargetType; targetId: string }>();
    if (!report) {
      return NextResponse.json({ message: "Report not found." }, { status: 404 });
    }

    if (action === "remove") await removeTarget(report.targetType, report.targetId);

    const status = action === "remove" ? "removed" : "dismissed";
    const { error } = await supabase
      .from("ContentReports")
      .update({ status, resolvedBy: payload.id, resolvedAt: new Date().toISOString() })
      .eq("targetType", report.targetType)
      .eq("targetId", report.targetId)
      .eq("status", "open");
    if (error) {
      console.error("PATCH /api/admin/reports/[id] update failed:", error);
      return NextResponse.json({ message: "Failed to update report." }, { status: 500 });
    }

    return NextResponse.json({ status });
  } catch (e) {
    console.error("PATCH /api/admin/reports/[id] exception:", e);
    return NextResponse.json({ message: "Failed to update report." }, { status: 500 });
  }
}
