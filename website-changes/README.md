# Website changes: reporting, blocking, Terms and push notifications

These files add what App Store Review Guideline 1.2 asks of apps with user-generated content:

- a **Report** option on every post, thread, comment, review, direct question and member profile;
- the ability to **block** members;
- a reports queue for moderators;
- **Terms of Use** and a **Privacy Policy** that members agree to at signup.

They also send **push notifications** to the iOS app (see [Push notifications](#push-notifications)).

Paths below are relative to the root of the website repo. The folder mirrors that layout, so you can copy it over the repo.

## How to apply

1. **Run the SQL first.** Paste `migrations/20261002_0007_safety.sql` into the Supabase SQL editor and run it, then do the same with `migrations/20261012_0008_push.sql`. Both are safe to re-run. The current site keeps working against them, but the new code needs them: login reads the new `termsAcceptedAt` column, and the app registers devices in `DeviceTokens`.
2. **Copy the files**, or apply the patch from the website repo root:
   ```sh
   git apply --3way path/to/website.patch
   ```
   The replaced files were edited from the `reference-amsa-website/` snapshot. If any of them changed in the real repo since then, use the patch so `--3way` can merge.
3. **Optional:** set `REPORTS_TO_EMAIL` to the inbox that should receive report emails. It defaults to `FEEDBACK_TO_EMAIL`.
4. **Review the legal text** in `src/app/(main)/terms/page.tsx` and `src/app/(main)/privacy/page.tsx`. They are drafts. The contact email and effective date live in `src/lib/legal.ts` (currently `administration@amsa.mn`).
5. **Optional, for push:** set the `APNS_*` variables (see [Push notifications](#push-notifications)). Until then, pushes are skipped.
6. Run `npm run typecheck`, then deploy.

## Push notifications

The iOS app registers each device with the website after sign-in. The website then pushes:

| Event | Who gets it | Opens |
|---|---|---|
| Someone follows you | You | Their profile, if it's public |
| Someone asks you a question | You (ambassadors and up) | Your unanswered questions |
| Your question is answered | The asker | Inbox |
| An admin approves or rejects a membership application | The applicant | Membership form |
| Someone submits a membership application | Every admin | Verification queue |

The texts match the notifications page. The "Welcome to AMSA" notification after signup is sent by the app itself, because the device isn't registered yet when the account is created.

Pushes need a paid Apple Developer Program membership. Then:

1. In the Apple Developer portal, go to Certificates, Identifiers & Profiles → Keys, create a key with **Apple Push Notifications service (APNs)** enabled, and download the `.p8` file. You can only download it once.
2. Set these on the website (Vercel → Settings → Environment Variables):
   - `APNS_KEY`: the full contents of the `.p8` file, including the `BEGIN`/`END` lines. Newlines written as `\n` also work.
   - `APNS_KEY_ID`: the key's 10-character ID.
   - `APNS_TEAM_ID`: the team ID shown at the top right of the developer portal.
   - `APNS_BUNDLE_ID`: optional; defaults to `mn.amsa.app`.
3. In the app repo, turn on the Push Notifications entitlement: set `AMSA_DEVELOPMENT_TEAM` to the paid team and `AMSA_CODE_SIGN_ENTITLEMENTS = AMSA/AMSA.entitlements` in `Config/Base.xcconfig`.

Each send runs after the response (`after()`), so it never slows down or fails the request. Tokens that APNs reports as dead (app uninstalled, bad token) are deleted. Builds run from Xcode register sandbox tokens and TestFlight and App Store builds register production ones; each goes to the matching APNs server.

## Files

New:

| File | What it does |
|---|---|
| `migrations/20261002_0007_safety.sql` | `ContentReports` and `UserBlocks` tables, plus `Users.termsAcceptedAt`. Copies existing post reports into `ContentReports`. Updates `get_shell` (new `pending.reports` count), `get_notifications` (report notifications for every kind of content), `get_network_members` (hides blocked members) and `delete_user_account` (also removes reports and blocks). |
| `src/lib/reports.ts` | Report types and reasons; looking up and removing reported content. |
| `src/lib/blocks.ts` | `hiddenUserIds(viewer)`: members hidden from a viewer in either direction. |
| `src/lib/legal.ts` | Contact email and effective date for the legal pages. |
| `src/app/api/reports/route.ts` | `POST /api/reports` `{ targetType, targetId, reason, details? }`. Saves the report and emails moderators. |
| `src/app/api/admin/reports/route.ts` | `GET /api/admin/reports`: open reports with a preview (admins and board members). |
| `src/app/api/admin/reports/[id]/route.ts` | `PATCH` `{ action: "remove" \| "dismiss" }`. "remove" deletes the content, or clears a reported profile's photo, headline and bio, and closes every open report on that item. |
| `src/app/api/user/blocks/route.ts` | `GET` lists blocked members. `POST { userId }` blocks a member, removes follows both ways and deletes unanswered direct questions between the two. |
| `src/app/api/user/blocks/[id]/route.ts` | `DELETE`: unblock. |
| `src/app/api/user/terms/route.ts` | `POST`: records Terms acceptance for members who signed up before the checkbox existed. |
| `src/app/(main)/terms/page.tsx`, `src/app/(main)/privacy/page.tsx`, `src/components/legal/LegalPage.tsx` | `/terms` and `/privacy`. |
| `src/app/(dashboard)/dashboard/admin/reports/page.tsx` | The reports queue on the website. |
| `migrations/20261012_0008_push.sql` | `DeviceTokens`: one row per device, keyed by its APNs token, removed with the account. |
| `src/lib/push.ts` | Sends pushes through APNs (HTTP/2, signed with the `.p8` key), plus one function per event. Does nothing until the `APNS_*` variables are set. |
| `src/app/api/user/devices/route.ts` | `POST { token, environment }` registers this device for the signed-in member. `DELETE { token }` on sign-out. |

Changed:

| File | Change |
|---|---|
| `src/app/api/auth/signup/route.ts` | Requires `acceptedTerms: true` and saves `termsAcceptedAt`. |
| `src/app/api/auth/login/route.ts`, `src/app/api/auth/me/route.ts` | Return `termsAcceptedAt`. |
| `src/app/api/posts/[id]/report/route.ts` | Writes to `ContentReports` and emails moderators. Kept for the web feed. |
| `src/app/api/posts/route.ts`, `hub-threads/route.ts`, `hub-threads/[id]/route.ts`, `colleges/reviews/route.ts`, `places/reviews/route.ts`, `colleges/[id]/posts/route.ts` | Hide content from blocked members, in both directions. Moderation views are not filtered. |
| `src/app/api/threads/route.ts` | No new direct questions between blocked members; the inbox hides them. Pushes "New question". |
| `src/app/api/threads/[id]/route.ts` | Pushes "Question answered". |
| `src/app/api/admin/verification/[id]/route.ts` | Pushes the decision to the applicant. |
| `src/app/api/user/verification/route.ts` | Pushes new applications to admins. |
| `src/app/api/user/follows/route.ts` | Can't follow across a block. Pushes "New follower". |
| `src/app/api/user/network/[id]/route.ts` | Returns 404 when the member blocked you. Adds `blockedByMe` so the app can offer Unblock. |
| `src/app/api/me/shell/route.ts`, `src/app/api/user/notifications/route.ts` | Type updates (`pending.reports`, `content_report`). |
| `src/app/(main)/signup/member/page.tsx`, `src/context/AuthContext.tsx` | Terms checkbox on the website's signup form. |
| `src/components/DashboardSidebar.tsx`, `src/components/DashboardTopBar.tsx` | "Reports" admin link with a badge. |
| `src/lib/email/resend.ts` | `sendReportEmail`. |

## Not included

- Report and Block buttons on the website itself. They're in the app, which is what App Review checks. The APIs above work from the web too.
- The website doesn't ask existing members to accept the Terms. The app does, once, after sign-in.
- Lists that are public and cached by the CDN aren't filtered by blocks: members at a college, and members in a state.

## Checked

- The changed TypeScript type-checks with the website's libraries stubbed out. A full `npm run typecheck` didn't run because this Mac is low on disk space.
- `website.patch` applies cleanly to the snapshot.
- `src/lib/push.ts` was run against a fake local APNs server: the provider token verifies as ES256 with the right key and team IDs, headers and payloads are what APNs expects, sandbox and production tokens go to their own hosts, and dead tokens are deleted. It hasn't been run against Apple.
- None of it has been run against a database.
