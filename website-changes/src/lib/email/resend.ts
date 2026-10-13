import "server-only";
import { Resend } from "resend";
import { supabase } from "@/lib/supabase";

type TemplateKey =
  | "reservation_confirmation"
  | "waitlist_placed"
  | "waitlist_promoted"
  | "reservation_expired";

type EventEmailInput = {
  eventId: number;
  userId: number;
  userEmail: string;
  templateKey: TemplateKey;
  dedupeKey: string;
  subject: string;
  html: string;
  metadata?: Record<string, unknown>;
};

const resendApiKey = process.env.RESEND_API_KEY;
const fromEmail = process.env.RESEND_FROM_EMAIL || "administration@amsa.mn";
const welcomeFromEmail = process.env.RESEND_WELCOME_FROM || fromEmail;
const welcomeTemplateId = process.env.RESEND_WELCOME_TEMPLATE_ID;
const resend = resendApiKey ? new Resend(resendApiKey) : null;

export function buildEventEmailHtml(input: {
  title: string;
  body: string;
  ctaText?: string;
  ctaUrl?: string;
}): string {
  const cta = input.ctaText && input.ctaUrl
    ? `<p><a href="${input.ctaUrl}" style="display:inline-block;padding:10px 14px;background:#001049;color:#fff;border-radius:8px;text-decoration:none;">${input.ctaText}</a></p>`
    : "";

  return `
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#111;">
      <h2 style="margin-bottom:12px;">${input.title}</h2>
      <p>${input.body}</p>
      ${cta}
      <p style="margin-top:20px;color:#666;font-size:13px;">AMSA Events</p>
    </div>
  `;
}

/**
 * Sends the welcome email on signup using the published Resend dashboard
 * template referenced by RESEND_WELCOME_TEMPLATE_ID. Failures are logged and
 * swallowed so they never block the signup flow.
 */
export async function sendWelcomeEmail(input: {
  userEmail: string;
  firstName: string;
}): Promise<void> {
  if (!resend) {
    console.warn("Skipping welcome email: RESEND_API_KEY is not configured");
    return;
  }
  if (!welcomeTemplateId) {
    console.warn("Skipping welcome email: RESEND_WELCOME_TEMPLATE_ID is not configured");
    return;
  }

  const result = await resend.emails.send({
    from: welcomeFromEmail,
    to: input.userEmail,
    template: {
      id: welcomeTemplateId,
      variables: {
        firstName: input.firstName,
      },
    },
  });

  if (result.error) {
    console.error("Failed to send welcome email with Resend:", result.error.message);
  }
}

/**
 * Sends the password-reset link. Failures are logged and swallowed so the
 * forgot-password endpoint never reveals whether an account exists.
 */
export async function sendPasswordResetEmail(input: {
  userEmail: string;
  firstName?: string;
  resetUrl: string;
}): Promise<void> {
  if (!resend) {
    console.warn("Skipping password reset email: RESEND_API_KEY is not configured");
    return;
  }

  const greeting = input.firstName ? `Hi ${input.firstName},` : "Hi,";
  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#111;">
      <h2 style="margin-bottom:12px;">Reset your AMSA password</h2>
      <p>${greeting}</p>
      <p>We received a request to reset your password. Click the button below to choose a new one. This link expires in 1 hour.</p>
      <p><a href="${input.resetUrl}" style="display:inline-block;padding:10px 14px;background:#001049;color:#fff;border-radius:8px;text-decoration:none;">Reset password</a></p>
      <p style="color:#666;font-size:13px;">If you didn't request this, you can safely ignore this email — your password won't change.</p>
      <p style="margin-top:20px;color:#666;font-size:13px;">AMSA</p>
    </div>
  `;

  const result = await resend.emails.send({
    from: fromEmail,
    to: input.userEmail,
    subject: "Reset your AMSA password",
    html,
  });

  if (result.error) {
    console.error("Failed to send password reset email with Resend:", result.error.message);
  }
}

export async function sendEventEmail(input: EventEmailInput): Promise<void> {
  const { data: existing } = await supabase
    .from("EventEmails")
    .select("id")
    .eq("dedupeKey", input.dedupeKey)
    .maybeSingle();

  if (existing) return;

  if (!resend) {
    console.warn("Skipping event email send: RESEND_API_KEY is not configured");
    return;
  }

  const result = await resend.emails.send({
    from: fromEmail,
    to: input.userEmail,
    subject: input.subject,
    html: input.html,
  });

  if (result.error) {
    console.error("Failed to send email with Resend:", result.error.message);
    return;
  }

  const { error: logError } = await supabase.from("EventEmails").insert({
    eventId: input.eventId,
    userId: input.userId,
    templateKey: input.templateKey,
    dedupeKey: input.dedupeKey,
    metadata: {
      ...(input.metadata || {}),
      resendId: result.data?.id ?? null,
    },
  });

  if (logError) {
    console.error("Failed to write EventEmails log:", logError.message);
  }
}

const feedbackToEmail = process.env.FEEDBACK_TO_EMAIL || "telmenbayarbaatar@amsa.mn";

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/**
 * Delivers an in-app feedback submission to the admin inbox. Reply-To is set
 * to the member so admins can answer directly from their mail client.
 * Throws on failure so the API can tell the user it wasn't sent.
 */
export async function sendFeedbackEmail(input: {
  category: string;
  message: string;
  page: string | null;
  user: { id: number; email: string; firstName: string; lastName: string; role: string };
}): Promise<void> {
  if (!resend) throw new Error("RESEND_API_KEY is not configured");

  const name = `${input.user.firstName} ${input.user.lastName}`.trim() || "A member";
  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#111;">
      <h2 style="margin-bottom:12px;">New feedback: ${escapeHtml(input.category)}</h2>
      <p style="white-space:pre-wrap;padding:12px 14px;background:#f5f5f5;border-radius:8px;">${escapeHtml(input.message)}</p>
      <table style="font-size:13px;color:#444;border-collapse:collapse;margin-top:16px;">
        <tr><td style="padding:2px 12px 2px 0;">From</td><td>${escapeHtml(name)} &lt;${escapeHtml(input.user.email)}&gt; (#${input.user.id}, ${escapeHtml(input.user.role)})</td></tr>
        <tr><td style="padding:2px 12px 2px 0;">Page</td><td>${escapeHtml(input.page ?? "—")}</td></tr>
        <tr><td style="padding:2px 12px 2px 0;">Sent</td><td>${new Date().toISOString()}</td></tr>
      </table>
      <p style="margin-top:20px;color:#666;font-size:13px;">Reply to this email to answer ${escapeHtml(input.user.firstName || "them")} directly.</p>
    </div>
  `;

  const result = await resend.emails.send({
    from: fromEmail,
    to: feedbackToEmail,
    replyTo: input.user.email,
    subject: `[AMSA feedback] ${input.category}: ${input.message.slice(0, 60).replace(/\s+/g, " ")}${input.message.length > 60 ? "…" : ""}`,
    html,
  });

  if (result.error) throw new Error(result.error.message);
}

const reportsToEmail = process.env.REPORTS_TO_EMAIL || feedbackToEmail;

/**
 * Tells moderators about a new content report. The Terms promise action
 * within 24 hours, so this goes out immediately; the queue at
 * /dashboard/admin/reports is the record.
 */
export async function sendReportEmail(input: {
  targetLabel: string;
  reasonLabel: string;
  details: string | null;
  preview: string;
  reporter: { id: number; name: string; email: string };
  queueUrl: string;
}): Promise<void> {
  if (!resend) {
    console.warn("Skipping report email: RESEND_API_KEY is not configured");
    return;
  }

  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#111;">
      <h2 style="margin-bottom:12px;">${escapeHtml(input.targetLabel)} reported: ${escapeHtml(input.reasonLabel)}</h2>
      <p style="white-space:pre-wrap;padding:12px 14px;background:#f5f5f5;border-radius:8px;">${escapeHtml(input.preview || "(no text)")}</p>
      ${input.details ? `<p><strong>Reporter's note:</strong> ${escapeHtml(input.details)}</p>` : ""}
      <table style="font-size:13px;color:#444;border-collapse:collapse;margin-top:16px;">
        <tr><td style="padding:2px 12px 2px 0;">Reported by</td><td>${escapeHtml(input.reporter.name)} &lt;${escapeHtml(input.reporter.email)}&gt; (#${input.reporter.id})</td></tr>
        <tr><td style="padding:2px 12px 2px 0;">Sent</td><td>${new Date().toISOString()}</td></tr>
      </table>
      <p><a href="${input.queueUrl}" style="display:inline-block;padding:10px 14px;background:#001049;color:#fff;border-radius:8px;text-decoration:none;">Open the reports queue</a></p>
      <p style="margin-top:20px;color:#666;font-size:13px;">Please remove or dismiss within 24 hours.</p>
    </div>
  `;

  const result = await resend.emails.send({
    from: fromEmail,
    to: reportsToEmail,
    subject: `[AMSA report] ${input.targetLabel}: ${input.reasonLabel}`,
    html,
  });

  if (result.error) console.error("Failed to send report email with Resend:", result.error.message);
}
