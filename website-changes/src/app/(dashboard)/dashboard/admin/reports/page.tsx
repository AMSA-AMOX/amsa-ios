"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { invalidateShell } from "@/hooks/useShell";

type ReportUser = { id: number; firstName: string | null; lastName: string | null; profilePic: string | null };

type Report = {
  id: number;
  targetType: string;
  targetLabel: string;
  targetId: string;
  reasonLabel: string;
  details: string | null;
  createdAt: string;
  reporter: ReportUser | null;
  author: ReportUser | null;
  preview: string | null;
  href: string | null;
};

const nameOf = (u: ReportUser | null) => (u ? `${u.firstName ?? ""} ${u.lastName ?? ""}`.trim() || "Member" : "Unknown");

function formatRelative(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const m = Math.floor(diff / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  if (d < 30) return `${d}d ago`;
  return new Date(iso).toLocaleDateString();
}

function ReportCard({ report, busy, onResolve }: {
  report: Report;
  busy: boolean;
  onResolve: (report: Report, action: "remove" | "dismiss") => void;
}) {
  return (
    <div className="bg-white rounded-2xl border border-red-100 shadow-sm overflow-hidden">
      <div className="px-5 py-4 space-y-2">
        <div className="flex items-center gap-2 flex-wrap text-xs">
          <span className="px-2 py-0.5 rounded-full bg-red-50 text-red-700 font-semibold">{report.targetLabel}</span>
          <span className="font-semibold text-gray-700">{report.reasonLabel}</span>
          <span className="text-gray-400">· reported by {nameOf(report.reporter)} · {formatRelative(report.createdAt)}</span>
        </div>
        {report.author && <p className="text-xs text-gray-500">Posted by {nameOf(report.author)}</p>}
        {report.preview !== null ? (
          <p className="text-sm text-gray-800 whitespace-pre-wrap">{report.preview || "(no text)"}</p>
        ) : (
          <p className="text-sm italic text-gray-400">This content was already deleted.</p>
        )}
        {report.details && (
          <p className="text-sm text-gray-600"><span className="font-semibold">Note:</span> {report.details}</p>
        )}
      </div>
      <div className="px-5 py-3 border-t border-red-100 flex items-center gap-2 bg-red-50/40">
        {report.href ? (
          <Link href={report.href} className="flex-1 text-xs font-medium text-[#001049] hover:underline">View in context</Link>
        ) : (
          <span className="flex-1" />
        )}
        <button
          type="button"
          disabled={busy}
          onClick={() => onResolve(report, "dismiss")}
          className="px-3 py-1.5 rounded-lg text-xs font-semibold border border-gray-200 text-gray-600 hover:bg-gray-50 transition disabled:opacity-50"
        >
          Dismiss
        </button>
        <button
          type="button"
          disabled={busy || report.preview === null}
          onClick={() => onResolve(report, "remove")}
          className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-600 text-white hover:bg-red-700 transition disabled:opacity-50"
        >
          {report.targetType === "user" ? "Clear profile" : "Remove"}
        </button>
      </div>
    </div>
  );
}

export default function ReportsPage() {
  const { user, loading, authFetch } = useAuth();
  const router = useRouter();

  const [reports, setReports] = useState<Report[]>([]);
  const [pageLoading, setPageLoading] = useState(true);
  const [busyId, setBusyId] = useState<number | null>(null);

  const isModerator = user?.role === "board_member" || user?.role === "admin";

  const load = useCallback(async () => {
    setPageLoading(true);
    try {
      const data = await authFetch("/api/admin/reports");
      setReports((data.reports ?? []) as Report[]);
    } catch {
      setReports([]);
    } finally {
      setPageLoading(false);
    }
  }, [authFetch]);

  useEffect(() => {
    if (loading) return;
    if (!user) { router.push("/login"); return; }
    if (!isModerator) { router.push("/welcome"); return; }
    load();
  }, [loading, user, isModerator, router, load]);

  const resolve = async (report: Report, action: "remove" | "dismiss") => {
    if (action === "remove" && !confirm(report.targetType === "user"
      ? "Clear this member's photo, headline and bio?"
      : "Delete this content for everyone? This can't be undone.")) return;
    setBusyId(report.id);
    try {
      await authFetch(`/api/admin/reports/${report.id}`, { method: "PATCH", body: JSON.stringify({ action }) });
      // Every open report on the same item is closed together.
      setReports((prev) => prev.filter((r) => !(r.targetType === report.targetType && r.targetId === report.targetId)));
      invalidateShell();
    } catch (e: any) {
      alert(e?.message ?? "Failed to update report.");
    } finally {
      setBusyId(null);
    }
  };

  if (!user || !isModerator) return null;

  return (
    <div className="min-h-screen bg-gray-50 py-6 px-4 md:px-8">
      <div className="max-w-3xl mx-auto">
        <p className="text-sm text-gray-500 mt-1 mb-6">
          Reports from members. Our Terms promise action within 24 hours: remove content that breaks the rules,
          or dismiss the report.
        </p>

        {pageLoading && (
          <div className="space-y-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="bg-white rounded-2xl border border-gray-100 shadow-sm h-28 animate-pulse" />
            ))}
          </div>
        )}

        {!pageLoading && reports.length === 0 && (
          <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-10 text-center">
            <p className="text-sm font-semibold text-gray-500">No open reports.</p>
            <p className="text-xs text-gray-400 mt-1">Everything has been reviewed.</p>
          </div>
        )}

        {!pageLoading && reports.length > 0 && (
          <div className="space-y-3">
            <p className="text-xs text-gray-500 mb-1">{reports.length} open report{reports.length !== 1 ? "s" : ""}</p>
            {reports.map((r) => (
              <ReportCard key={r.id} report={r} busy={busyId === r.id} onResolve={resolve} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
