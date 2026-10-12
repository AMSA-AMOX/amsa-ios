import "server-only";
import http2 from "node:http2";
import jwt from "jsonwebtoken";
import { supabase } from "@/lib/supabase";

/**
 * Push notifications to the iOS app through Apple Push Notification service (APNs).
 *
 * Off until APNS_KEY (the .p8 file's contents), APNS_KEY_ID and APNS_TEAM_ID are set.
 * Every send is best-effort: it never throws, so callers run it in `after()` and move on.
 * The texts and links mirror get_notifications, so a push and the row it becomes on the
 * notifications page say the same thing.
 */

const KEY = process.env.APNS_KEY?.replace(/\\n/g, "\n");
const KEY_ID = process.env.APNS_KEY_ID;
const TEAM_ID = process.env.APNS_TEAM_ID;
const BUNDLE_ID = process.env.APNS_BUNDLE_ID || "mn.amsa.app";

const HOSTS = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
} as const;
type Environment = keyof typeof HOSTS;

/** Roles whose profiles are public in the network (and who can answer questions). */
const PROFILE_ROLES = ["ambassador", "us_member", "board_member", "admin"];

type Push = { title: string; body: string; href?: string | null };
type NameRow = { firstName: string | null; lastName: string | null };

// APNs accepts a provider token for up to an hour and rejects refreshes more often than every
// 20 minutes, so one is reused for 50.
let providerToken: { value: string; issuedAt: number } | null = null;

function bearer(): string {
  if (!providerToken || Date.now() - providerToken.issuedAt > 50 * 60_000) {
    const value = jwt.sign({}, KEY!, { algorithm: "ES256", keyid: KEY_ID, issuer: TEAM_ID });
    providerToken = { value, issuedAt: Date.now() };
  }
  return providerToken.value;
}

function displayName(user: NameRow | null | undefined): string {
  return `${user?.firstName ?? ""} ${user?.lastName ?? ""}`.trim() || "Someone";
}

/** Sends `payload` to each token over one HTTP/2 connection. Resolves to the tokens APNs rejected for good. */
function deliver(environment: Environment, tokens: string[], payload: string): Promise<string[]> {
  return new Promise((resolve) => {
    const stale: string[] = [];
    let pending = tokens.length;
    const client = http2.connect(HOSTS[environment]);
    const finish = () => {
      if (--pending === 0) {
        client.close();
        resolve(stale);
      }
    };
    client.on("error", (error) => {
      console.error("APNs connection failed:", error);
      client.destroy();
      resolve(stale);
    });

    for (const token of tokens) {
      const request = client.request({
        ":method": "POST",
        ":path": `/3/device/${token}`,
        authorization: `bearer ${bearer()}`,
        "apns-topic": BUNDLE_ID,
        "apns-push-type": "alert",
        "content-type": "application/json",
      });
      let status = 0;
      let body = "";
      request.setEncoding("utf8");
      request.on("response", (headers) => {
        status = Number(headers[":status"]);
      });
      request.on("data", (chunk) => {
        body += chunk;
      });
      request.on("end", () => {
        if (status !== 200) {
          const reason = (() => {
            try {
              return JSON.parse(body).reason as string | undefined;
            } catch {
              return undefined;
            }
          })();
          // 410: the app was uninstalled or the token expired.
          if (status === 410 || reason === "BadDeviceToken" || reason === "DeviceTokenNotForTopic") stale.push(token);
          else console.error(`APNs rejected a push (${status}):`, reason ?? body);
        }
        finish();
      });
      request.on("error", (error) => {
        console.error("APNs request failed:", error);
        finish();
      });
      request.end(payload);
    }
  });
}

/** Pushes to every device the given members are signed in on. */
export async function sendPush(userIds: number[], push: Push): Promise<void> {
  if (!KEY || !KEY_ID || !TEAM_ID || userIds.length === 0) return;
  try {
    const { data, error } = await supabase
      .from("DeviceTokens")
      .select("token, environment")
      .in("userId", userIds);
    if (error) throw error;
    const rows = (data ?? []) as { token: string; environment: Environment }[];
    if (rows.length === 0) return;

    const payload = JSON.stringify({
      aps: { alert: { title: push.title, body: push.body }, sound: "default" },
      ...(push.href ? { href: push.href } : {}),
    });
    const stale = (
      await Promise.all(
        (Object.keys(HOSTS) as Environment[]).map((environment) => {
          const tokens = rows.filter((r) => r.environment === environment).map((r) => r.token);
          return tokens.length ? deliver(environment, tokens, payload) : Promise.resolve([]);
        }),
      )
    ).flat();
    if (stale.length) await supabase.from("DeviceTokens").delete().in("token", stale);
  } catch (error) {
    console.error("Push failed:", error);
  }
}

// ---------------------------------------------------------------------------
// One function per event. Each looks up the names it needs, so routes only pass ids.
// ---------------------------------------------------------------------------

export async function pushNewFollower(followerId: number, followingId: number): Promise<void> {
  const { data: follower } = await supabase
    .from("Users")
    .select("firstName, lastName, role")
    .eq("id", followerId)
    .maybeSingle<NameRow & { role: string | null }>();
  await sendPush([followingId], {
    title: "New follower",
    body: `${displayName(follower)} followed you.`,
    href: PROFILE_ROLES.includes(follower?.role ?? "") ? `/dashboard/network/${followerId}` : null,
  });
}

export async function pushNewQuestion(asker: NameRow | null, recipientId: number): Promise<void> {
  await sendPush([recipientId], {
    title: "New question",
    body: `${displayName(asker)} asked you a question.`,
    href: "/welcome?threads=unanswered",
  });
}

export async function pushQuestionAnswered(
  askerId: number,
  answerer: NameRow | null,
  isAnonymous: boolean,
): Promise<void> {
  await sendPush([askerId], {
    title: "Question answered",
    body: `${isAnonymous ? "Someone" : displayName(answerer)} answered your question.`,
    href: "/dashboard/inbox",
  });
}

export async function pushMembershipDecision(userId: number, approved: boolean): Promise<void> {
  await sendPush(
    [userId],
    approved
      ? {
          title: "Membership approved",
          body: "Your AMSA membership application was approved. Welcome aboard!",
          href: "/verification",
        }
      : {
          title: "Membership application update",
          body: "Your AMSA membership application wasn't approved. Open it to see the details.",
          href: "/verification",
        },
  );
}

/** To every admin: they're the ones who review applications. */
export async function pushNewApplication(applicantName: string): Promise<void> {
  const { data: admins } = await supabase.from("Users").select("id").eq("role", "admin");
  await sendPush(
    ((admins ?? []) as { id: number }[]).map((a) => a.id),
    {
      title: "New membership application",
      body: `${applicantName.trim() || "Someone"} applied for membership.`,
      href: "/dashboard/admin/verification",
    },
  );
}
