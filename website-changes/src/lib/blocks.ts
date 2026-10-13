import "server-only";
import { supabase } from "@/lib/supabase";

/**
 * Members hidden from `viewerId`: everyone they blocked and everyone who
 * blocked them (blocking hides content both ways). Empty for signed-out
 * viewers, and while the UserBlocks table doesn't exist yet.
 */
export async function hiddenUserIds(viewerId: number | null | undefined): Promise<Set<number>> {
  if (!viewerId) return new Set();
  const { data, error } = await supabase
    .from("UserBlocks")
    .select("blockerId, blockedId")
    .or(`blockerId.eq.${viewerId},blockedId.eq.${viewerId}`);
  if (error) {
    if (error.code !== "PGRST205") console.error("hiddenUserIds failed:", error);
    return new Set();
  }
  return new Set(
    ((data ?? []) as { blockerId: number; blockedId: number }[]).map((row) =>
      row.blockerId === viewerId ? row.blockedId : row.blockerId,
    ),
  );
}

/** True when either member has blocked the other. */
export async function isBlockedEitherWay(a: number, b: number): Promise<boolean> {
  const hidden = await hiddenUserIds(a);
  return hidden.has(b);
}

/** Normalizes the mixed number/string user ids some tables return. */
export function toUserId(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "" && Number.isFinite(Number(value))) return Number(value);
  return null;
}
