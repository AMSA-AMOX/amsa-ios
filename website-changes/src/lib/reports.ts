import "server-only";
import { supabase } from "@/lib/supabase";
import { toUserId } from "@/lib/blocks";

export const REPORT_TARGET_TYPES = [
  "post",
  "hub_thread",
  "hub_comment",
  "college_review",
  "place_review",
  "question",
  "user",
] as const;
export type ReportTargetType = (typeof REPORT_TARGET_TYPES)[number];

export const REPORT_REASONS = [
  "spam",
  "harassment",
  "hate",
  "sexual",
  "violence",
  "self_harm",
  "misinformation",
  "other",
] as const;
export type ReportReason = (typeof REPORT_REASONS)[number];

export const REPORT_REASON_LABELS: Record<ReportReason, string> = {
  spam: "Spam or scam",
  harassment: "Harassment or bullying",
  hate: "Hate speech",
  sexual: "Sexual content",
  violence: "Violence or threats",
  self_harm: "Self-harm",
  misinformation: "False information",
  other: "Something else",
};

export const REPORT_TARGET_LABELS: Record<ReportTargetType, string> = {
  post: "Post",
  hub_thread: "Thread",
  hub_comment: "Comment",
  college_review: "College review",
  place_review: "Place review",
  question: "Direct question",
  user: "Member profile",
};

export type ResolvedTarget = {
  /** Author of the content, or the member for a profile report. */
  ownerId: number | null;
  /** Short text moderators see in the queue and the email. */
  preview: string;
  /** Dashboard page where the content appears, when there is one. */
  href: string | null;
};

const clip = (text: string | null | undefined, max = 280) => {
  const value = (text ?? "").trim().replace(/\s+/g, " ");
  return value.length > max ? `${value.slice(0, max)}…` : value;
};

/**
 * Looks up the reported content. Returns null when it doesn't exist, or when
 * `reporterId` may not report it (only the two people in a direct question can
 * report it).
 */
export async function resolveTarget(
  type: ReportTargetType,
  targetId: string,
  reporterId?: number,
): Promise<ResolvedTarget | null> {
  switch (type) {
    case "post": {
      const { data } = await supabase.from("Posts").select("id, userId, body").eq("id", Number(targetId)).maybeSingle();
      if (!data) return null;
      return { ownerId: toUserId(data.userId), preview: clip(data.body), href: `/dashboard/feed?reportedPostId=${data.id}` };
    }
    case "hub_thread": {
      const { data } = await supabase
        .from("HubThreads")
        .select("id, askerId, title, question")
        .eq("id", Number(targetId))
        .maybeSingle();
      if (!data) return null;
      return {
        ownerId: toUserId(data.askerId),
        preview: clip([data.title, data.question].filter(Boolean).join(" — ")),
        href: "/dashboard/threads",
      };
    }
    case "hub_comment": {
      const { data } = await supabase
        .from("HubComments")
        .select("id, authorId, content")
        .eq("id", Number(targetId))
        .maybeSingle();
      if (!data) return null;
      return { ownerId: toUserId(data.authorId), preview: clip(data.content), href: "/dashboard/threads" };
    }
    case "college_review": {
      const { data } = await supabase
        .from("college_reviews")
        .select("id, user_id, content, college_id")
        .eq("id", targetId)
        .maybeSingle();
      if (!data) return null;
      return {
        ownerId: toUserId(data.user_id),
        preview: clip(data.content),
        href: `/dashboard/research/college/${data.college_id}`,
      };
    }
    case "place_review": {
      const { data } = await supabase
        .from("place_reviews")
        .select("id, user_id, content, state_abbr")
        .eq("id", targetId)
        .maybeSingle();
      if (!data) return null;
      return {
        ownerId: toUserId(data.user_id),
        preview: clip(data.content),
        href: `/dashboard/places/${String(data.state_abbr ?? "").toLowerCase()}`,
      };
    }
    case "question": {
      const { data } = await supabase
        .from("Threads")
        .select("id, askerId, recipientId, question, answer")
        .eq("id", Number(targetId))
        .maybeSingle();
      if (!data) return null;
      const askerId = toUserId(data.askerId);
      const recipientId = toUserId(data.recipientId);
      if (reporterId !== undefined && reporterId !== askerId && reporterId !== recipientId) return null;
      // The reporter is flagging the other person's side of the conversation.
      const reportingAnswer = reporterId !== undefined && reporterId === askerId;
      return {
        ownerId: reportingAnswer ? recipientId : askerId,
        preview: clip(reportingAnswer ? data.answer : data.question),
        href: null,
      };
    }
    case "user": {
      const { data } = await supabase
        .from("Users")
        .select("id, firstName, lastName, headline, bio")
        .eq("id", Number(targetId))
        .maybeSingle();
      if (!data) return null;
      const name = `${data.firstName ?? ""} ${data.lastName ?? ""}`.trim() || "Member";
      return {
        ownerId: data.id,
        preview: clip([name, data.headline, data.bio].filter(Boolean).join(" — ")),
        href: `/dashboard/network/${data.id}`,
      };
    }
  }
}

/**
 * Moderator "Remove": deletes the content (for a profile, clears its photo,
 * headline and bio). Throws when the database refuses.
 */
export async function removeTarget(type: ReportTargetType, targetId: string): Promise<void> {
  const check = (result: { error: { message: string } | null }) => {
    if (result.error) throw new Error(result.error.message);
  };

  switch (type) {
    case "post": {
      const id = Number(targetId);
      check(await supabase.from("PostHelpfuls").delete().eq("postId", id));
      check(await supabase.from("PostReports").delete().eq("postId", id));
      check(await supabase.from("Posts").delete().eq("id", id));
      return;
    }
    case "hub_thread": {
      const id = Number(targetId);
      const { data: comments } = await supabase.from("HubComments").select("id").eq("threadId", id);
      const commentIds = (comments ?? []).map((c: { id: number }) => c.id);
      if (commentIds.length > 0) check(await supabase.from("HubCommentUpvotes").delete().in("commentId", commentIds));
      check(await supabase.from("HubThreadUpvotes").delete().eq("threadId", id));
      check(await supabase.from("HubComments").delete().eq("threadId", id));
      check(await supabase.from("HubThreads").delete().eq("id", id));
      return;
    }
    case "hub_comment": {
      const id = Number(targetId);
      const { data: replies } = await supabase.from("HubComments").select("id").eq("parentId", id);
      const ids = [id, ...(replies ?? []).map((r: { id: number }) => r.id)];
      check(await supabase.from("HubCommentUpvotes").delete().in("commentId", ids));
      check(await supabase.from("HubComments").delete().eq("parentId", id));
      check(await supabase.from("HubComments").delete().eq("id", id));
      return;
    }
    case "college_review":
      check(await supabase.from("college_reviews").delete().eq("id", targetId));
      return;
    case "place_review":
      check(await supabase.from("place_reviews").delete().eq("id", targetId));
      return;
    case "question":
      check(await supabase.from("Threads").delete().eq("id", Number(targetId)));
      return;
    case "user":
      check(
        await supabase
          .from("Users")
          .update({ profilePic: null, headline: null, bio: null })
          .eq("id", Number(targetId)),
      );
      return;
  }
}
