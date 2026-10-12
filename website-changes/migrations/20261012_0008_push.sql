-- Push notifications for the iOS app: one row per device, keyed by its APNs
-- device token. A device that signs in to another account moves to it (the
-- token is the primary key), and rows go away with the account (cascade) or
-- when APNs reports the token is no longer valid (src/lib/push.ts).
--
-- Like the other tables it is readable by the anon role (no RLS yet). A token
-- alone can't send pushes; that also needs the APNs key, which only the server has.
--
-- Apply in the Supabase SQL editor before deploying the code that uses it.
-- Safe to re-run.

set search_path = public;

create table if not exists "DeviceTokens" (
  token        text        primary key,
  "userId"     bigint      not null references "Users"(id) on delete cascade,
  platform     text        not null default 'ios' check (platform in ('ios')),
  -- Builds run from Xcode get sandbox tokens; TestFlight and App Store builds get production ones.
  environment  text        not null default 'production' check (environment in ('sandbox', 'production')),
  "createdAt"  timestamptz not null default now(),
  "updatedAt"  timestamptz not null default now()
);
create index if not exists device_tokens_user_idx on "DeviceTokens" ("userId");
