import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";
import {
  REPORT_REASON_LABELS,
  REPORT_TARGET_LABELS,
  resolveTarget,
  type ReportReason,
  type ReportTargetType,
} from "@/lib/reports";

type ReportRow = {
  id: number;
  reporterId: number;
  targetType: ReportTargetType;
  targetId: string;
  targetUserId: number | null;
  reason: ReportReason;
  details: string | null;
  status: "open" | "removed" | "dismissed";
  createdAt: string;
  resolvedAt: string | null;
};

type UserRow = { id: number; firstName: string | null; lastName: string | null; profilePic: string | null };

const isModerator = (role: string) => role === "admin" || role === "board_member";

// GET /api/admin/reports?status=open|all — the moderation queue (admins and board members)
export async function GET(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }
  if (!isModerator(payload.role)) {
    return NextResponse.json({ message: "Forbidden" }, { status: 403 });
  }

  const status = new URL(request.url).searchParams.get("status") === "all" ? "all" : "open";

  try {
    let query = supabase
      .from("ContentReports")
      .select("id, reporterId, targetType, targetId, targetUserId, reason, details, status, createdAt, resolvedAt")
      .order("createdAt", { ascending: status === "open" })
      .limit(100);
    if (status === "open") query = query.eq("status", "open");

    const { data, error } = await query;
    if (error) {
      console.error("GET /api/admin/reports failed:", error);
      return NextResponse.json({ message: "Failed to load reports." }, { status: 500 });
    }
    const rows = (data ?? []) as ReportRow[];

    const userIds = Array.from(
      new Set(rows.flatMap((r) => [r.reporterId, r.targetUserId]).filter((id): id is number => id != null)),
    );
    const [usersRes, targets] = await Promise.all([
      userIds.length > 0
        ? supabase.from("Users").select("id, firstName, lastName, profilePic").in("id", userIds)
        : Promise.resolve({ data: [] as UserRow[] }),
      // ≤100 small lookups; reports on the same item share one.
      (async () => {
        const keys = Array.from(new Set(rows.map((r) => `${r.targetType}:${r.targetId}`)));
        const resolved = await Promise.all(
          keys.map(async (key) => {
            const [type, ...rest] = key.split(":");
            return [key, await resolveTarget(type as ReportTargetType, rest.join(":"))] as const;
          }),
        );
        return new Map(resolved);
      })(),
    ]);
    const users = new Map(((usersRes.data ?? []) as UserRow[]).map((u) => [u.id, u]));

    return NextResponse.json({
      reports: rows.map((r) => {
        const target = targets.get(`${r.targetType}:${r.targetId}`) ?? null;
        return {
          id: r.id,
          targetType: r.targetType,
          targetLabel: REPORT_TARGET_LABELS[r.targetType],
          targetId: r.targetId,
          reason: r.reason,
          reasonLabel: REPORT_REASON_LABELS[r.reason] ?? r.reason,
          details: r.details,
          status: r.status,
          createdAt: r.createdAt,
          resolvedAt: r.resolvedAt,
          reporter: users.get(r.reporterId) ?? null,
          author: r.targetUserId != null ? (users.get(r.targetUserId) ?? null) : null,
          // null when the content was already deleted
          preview: target?.preview ?? null,
          href: target?.href ?? null,
        };
      }),
    });
  } catch (e) {
    console.error("GET /api/admin/reports exception:", e);
    return NextResponse.json({ message: "Failed to load reports." }, { status: 500 });
  }
}
