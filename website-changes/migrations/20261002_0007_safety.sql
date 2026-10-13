-- Safety for user-generated content (App Store Review Guideline 1.2):
--   * "ContentReports" — reports on posts, hub threads and comments, college and
--     place reviews, direct questions and member profiles, with a moderation
--     status. Replaces "PostReports" (existing rows are copied in; the old
--     table is left in place but no longer written).
--   * "UserBlocks"     — who blocked whom. Blocked users are hidden both ways.
--   * Users."termsAcceptedAt" — when the member agreed to the Terms of Use.
-- It also redefines get_shell (adds pending.reports), get_notifications
-- (report notifications for every kind of content), get_network_members
-- (hides blocked members) and delete_user_account (removes reports and blocks).
--
-- Apply in the Supabase SQL editor BEFORE deploying the website changes that
-- use it; the current site keeps working against it. Safe to re-run.

set search_path = public;

alter table "Users" add column if not exists "termsAcceptedAt" timestamptz;

create table if not exists "ContentReports" (
  id             bigint generated always as identity primary key,
  "reporterId"   bigint not null references "Users"(id) on delete cascade,
  "targetType"   text   not null check ("targetType" in
                   ('post','hub_thread','hub_comment','college_review','place_review','question','user')),
  -- text, because review ids are uuids and everything else is numeric
  "targetId"     text   not null,
  -- author of the reported content (or the reported member), for moderation and cleanup
  "targetUserId" bigint references "Users"(id) on delete set null,
  reason         text   not null check (reason in
                   ('spam','harassment','hate','sexual','violence','self_harm','misinformation','other')),
  details        text   check (char_length(details) <= 1000),
  status         text   not null default 'open' check (status in ('open','removed','dismissed')),
  "createdAt"    timestamptz not null default now(),
  "resolvedBy"   bigint references "Users"(id) on delete set null,
  "resolvedAt"   timestamptz,
  unique ("reporterId", "targetType", "targetId")
);
create index if not exists content_reports_status_idx on "ContentReports" (status, "createdAt" desc);
create index if not exists content_reports_target_idx on "ContentReports" ("targetType", "targetId");

-- Existing post reports. Reports on posts that no longer exist count as handled.
insert into "ContentReports" ("reporterId", "targetType", "targetId", "targetUserId", reason, status, "createdAt")
select pr."reporterId", 'post', pr."postId"::text,
       case when p."userId"::text ~ '^[0-9]+$' then p."userId"::text::bigint end,
       'other', case when p.id is null then 'removed' else 'open' end, pr."createdAt"
from "PostReports" pr
left join "Posts" p on p.id = pr."postId"
on conflict ("reporterId", "targetType", "targetId") do nothing;

create table if not exists "UserBlocks" (
  "blockerId" bigint not null references "Users"(id) on delete cascade,
  "blockedId" bigint not null references "Users"(id) on delete cascade,
  "createdAt" timestamptz not null default now(),
  primary key ("blockerId", "blockedId"),
  check ("blockerId" <> "blockedId")
);
create index if not exists user_blocks_blocked_idx on "UserBlocks" ("blockedId");

-- ---------------------------------------------------------------------------
-- get_shell: + pending.reports (open reports, moderators only).
-- ---------------------------------------------------------------------------
create or replace function public.get_shell(
  p_user_id    bigint,
  p_role       text,
  p_seen_after timestamptz default null
) returns jsonb
language sql stable as $$
  with can_answer as (select p_role in ('ambassador','us_member','board_member','admin') as ok),
       is_mod     as (select p_role in ('admin','board_member') as ok),
       -- Mirrors the sources (and per-source limits) of get_notifications so
       -- the unseen count matches what the notifications page shows.
       recent as (
         select "createdAt" as at from "Users" where id = p_user_id
         union all (select "createdAt" from follows where "followingId" = p_user_id order by "createdAt" desc limit 20)
         union all (select "createdAt" from "Events" order by "createdAt" desc limit 20)
         union all (select "answeredAt" from "Threads" where "askerId" = p_user_id and answer is not null order by "answeredAt" desc limit 10)
         union all (select t."createdAt" from "Threads" t, can_answer where can_answer.ok and t."recipientId" = p_user_id and t.answer is null order by t."createdAt" desc limit 10)
         union all (select r."createdAt" from "ContentReports" r, is_mod where is_mod.ok and r.status = 'open' order by r."createdAt" desc limit 20)
       )
  select jsonb_build_object(
    'membershipStatus',    (select review_status from amsa_memberships where user_id = p_user_id),
    'unseenNotifications', (select count(*) from (select at from recent order by at desc limit 30) n
                              where n.at > coalesce(p_seen_after, '-infinity'::timestamptz)),
    'pending', jsonb_build_object(
      'posts',        case when (select ok from is_mod) then (select count(*) from "Posts" where "reviewStatus" = 'pending') else 0 end,
      'threads',      case when (select ok from is_mod) then (select count(*) from "HubThreads" where status = 'pending') else 0 end,
      'verification', case when p_role = 'admin'       then (select count(*) from amsa_memberships where review_status = 'pending') else 0 end,
      'reports',      case when (select ok from is_mod) then (select count(*) from "ContentReports" where status = 'open') else 0 end
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- get_notifications: post-report items replaced by open reports on any content.
-- ---------------------------------------------------------------------------
create or replace function public.get_notifications(
  p_user_id bigint,
  p_role    text
) returns jsonb
language sql stable as $$
  with can_answer as (select p_role in ('ambassador','us_member','board_member','admin') as ok),
       is_mod     as (select p_role in ('admin','board_member') as ok),
       items as (
         -- welcome
         select u."createdAt" as at, jsonb_build_object(
           'id', 'welcome-' || u.id, 'type', 'welcome',
           'title', trim('Welcome to AMSA, ' || coalesce(u."firstName", '') || '!'),
           'description', 'Your account is all set. Explore the network and connect with other Mongolian students.',
           'happenedAt', u."createdAt", 'href', '/dashboard/feed') as item
         from "Users" u where u.id = p_user_id
         union all
         -- new followers
         (select f."createdAt", jsonb_build_object(
           'id', 'follow-' || f."followerId" || '-' || f."createdAt", 'type', 'follow',
           'title', 'New follower',
           'description', coalesce(nullif(trim(coalesce(a."firstName",'') || ' ' || coalesce(a."lastName",'')), ''), 'Someone') || ' followed you.',
           'happenedAt', f."createdAt",
           'href', case when a.role in ('ambassador','us_member','board_member','admin') then '/dashboard/network/' || a.id end,
           'avatarUrl', a."profilePic")
         from follows f join "Users" a on a.id = f."followerId"
         where f."followingId" = p_user_id order by f."createdAt" desc limit 20)
         union all
         -- events
         (select e."createdAt", jsonb_build_object(
           'id', 'event-' || e.id, 'type', 'event', 'title', 'Event update',
           'description', coalesce(e.title, 'Untitled event') || ' is available in Events.',
           'happenedAt', coalesce(e."createdAt", e."startAt"), 'href', '/dashboard/events')
         from "Events" e order by e."createdAt" desc limit 20)
         union all
         -- questions asked to me (ambassador+)
         (select t."createdAt", jsonb_build_object(
           'id', 'thread-' || t.id, 'type', 'thread_question', 'title', 'New question',
           'description', coalesce(nullif(trim(coalesce(a."firstName",'') || ' ' || coalesce(a."lastName",'')), ''), 'Someone') || ' asked you a question.',
           'happenedAt', t."createdAt", 'href', '/welcome?threads=unanswered', 'avatarUrl', a."profilePic")
         from "Threads" t left join "Users" a on a.id = t."askerId", can_answer
         where can_answer.ok and t."recipientId" = p_user_id and t.answer is null
         order by t."createdAt" desc limit 10)
         union all
         -- my questions that got answered
         (select t."answeredAt", jsonb_build_object(
           'id', 'thread-answered-' || t.id, 'type', 'thread_answered', 'title', 'Question answered',
           'description', case when coalesce(t."isAnonymous", false) then 'Someone answered your question.'
                               else coalesce(nullif(trim(coalesce(r."firstName",'') || ' ' || coalesce(r."lastName",'')), ''), 'Someone') || ' answered your question.' end,
           'happenedAt', t."answeredAt", 'href', '/dashboard/inbox',
           'avatarUrl', case when coalesce(t."isAnonymous", false) then null else r."profilePic" end)
         from "Threads" t left join "Users" r on r.id = t."recipientId"
         where t."askerId" = p_user_id and t.answer is not null
         order by t."answeredAt" desc limit 10)
         union all
         -- open reports on any content (moderators)
         (select r."createdAt", jsonb_build_object(
           'id', 'report-' || r.id, 'type', 'content_report', 'title', 'Content reported',
           'description', coalesce(nullif(trim(coalesce(a."firstName",'') || ' ' || coalesce(a."lastName",'')), ''), 'Someone')
                          || ' reported ' || case r."targetType"
                               when 'post' then 'a post' when 'hub_thread' then 'a thread' when 'hub_comment' then 'a comment'
                               when 'college_review' then 'a college review' when 'place_review' then 'a place review'
                               when 'question' then 'a question' else 'a member' end || '.',
           'happenedAt', r."createdAt", 'href', '/dashboard/admin/reports', 'avatarUrl', a."profilePic")
         from "ContentReports" r left join "Users" a on a.id = r."reporterId", is_mod
         where is_mod.ok and r.status = 'open' order by r."createdAt" desc limit 20)
       )
  select jsonb_build_object('notifications', coalesce(
    (select jsonb_agg(item order by at desc) from (select * from items order by at desc nulls last limit 30) top),
    '[]'::jsonb));
$$;

-- ---------------------------------------------------------------------------
-- get_network_members: hides members the viewer blocked or was blocked by
-- (also applies to get_network_profile's "next profiles", which calls it).
-- ---------------------------------------------------------------------------
create or replace function public.get_network_members(
  p_viewer_id bigint,
  p_query     text default null,
  p_limit     integer default 24
) returns jsonb
language sql stable as $$
  with q as (
    select nullif(trim(regexp_replace(lower(coalesce(p_query, '')), '[^a-z0-9\s]', ' ', 'g')), '') as text
  ),
  tokens as (
    select t from q, regexp_split_to_table(q.text, '\s+') t where q.text is not null and t <> ''
  ),
  viewer_following as (select "followingId" as id from follows where "followerId" = p_viewer_id),
  cand as (
    select u.id, coalesce(u."firstName", '') as "firstName", coalesce(u."lastName", '') as "lastName",
           u."profilePic", u."schoolName", u."graduationYear", coalesce(u.role, 'member') as role,
           coalesce(u.logo_domain, public.edu_root_domain(u."schoolEmail")) as logo_domain,
           lower(regexp_replace(coalesce(u."firstName",'') || ' ' || coalesce(u."lastName",''), '[^a-z0-9\s]', ' ', 'gi')) as full_n,
           lower(regexp_replace(coalesce(u."firstName",''), '[^a-z0-9\s]', ' ', 'gi')) as first_n,
           lower(regexp_replace(coalesce(u."lastName",''),  '[^a-z0-9\s]', ' ', 'gi')) as last_n,
           lower(regexp_replace(coalesce(u."schoolName",''),'[^a-z0-9\s]', ' ', 'gi')) as school_n,
           (select count(*) from follows f where f."followingId" = u.id)::int as followers_count,
           (select count(*) from follows f where f."followerId"  = u.id)::int as following_count,
           (select count(*) from follows f join viewer_following v on v.id = f."followingId" where f."followerId" = u.id)::int as mutual_count,
           exists(select 1 from viewer_following v where v.id = u.id) as is_following,
           u."createdAt"
    from "Users" u, q
    where u.role in ('ambassador','us_member','board_member','admin','alum')
      and u.id <> p_viewer_id
      and not exists (select 1 from "UserBlocks" b
                      where (b."blockerId" = p_viewer_id and b."blockedId" = u.id)
                         or (b."blockerId" = u.id and b."blockedId" = p_viewer_id))
      and (q.text is null
           or (coalesce(u."firstName",'') || ' ' || coalesce(u."lastName",'') || ' ' || coalesce(u."schoolName",'')) ilike '%' || q.text || '%'
           or exists (select 1 from tokens t where (coalesce(u."firstName",'') || ' ' || coalesce(u."lastName",'') || ' ' || coalesce(u."schoolName",'')) ilike '%' || t.t || '%'))
  ),
  scored as (
    select c.*,
      case when q.text is null then 0 else
        (case when c.full_n = q.text then 220 else 0 end)
      + (case when c.full_n like q.text || '%' then 120 else 0 end)
      + (case when c.school_n like q.text || '%' then 80 else 0 end)
      + (case when c.school_n like '%' || q.text || '%' then 36 else 0 end)
      + coalesce((select sum(
            (case when c.first_n like t.t || '%' then 55 else 0 end)
          + (case when c.last_n  like t.t || '%' then 55 else 0 end)
          + (case when c.full_n  like '%' || t.t || '%' then 24 else 0 end)
          + (case when c.school_n like '%' || t.t || '%' then 22 else 0 end)) from tokens t), 0)
      + (case when c.role = 'ambassador' then 40 else 0 end)
      + least(c.followers_count, 15)
      + least(c.mutual_count * 3, 30)
      end as score
    from cand c, q
  )
  -- p_query given but nothing searchable in it → no results (matches the old JS).
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id, 'firstName', s."firstName", 'lastName', s."lastName", 'profilePic', s."profilePic",
    'schoolName', s."schoolName", 'graduationYear', s."graduationYear", 'role', s.role,
    'logoDomain', s.logo_domain,
    'followersCount', s.followers_count, 'followingCount', s.following_count,
    'mutualCount', s.mutual_count, 'isFollowing', s.is_following
  ) order by
      case when p_query is null then (s.role = 'ambassador')::int else s.score end desc,
      s.mutual_count desc, s.followers_count desc, s."firstName" asc), '[]'::jsonb)
  from (
    select * from scored s
    where p_query is null or s.score > 0
    order by case when p_query is null then (s.role = 'ambassador')::int else s.score end desc,
             s.mutual_count desc, s.followers_count desc, s."firstName" asc
    limit greatest(1, least(coalesce(p_limit, 24), 120))
  ) s;
$$;

-- ---------------------------------------------------------------------------
-- delete_user_account: also removes the member's reports and blocks.
-- ---------------------------------------------------------------------------
create or replace function public.delete_user_account(p_user_id bigint)
returns boolean
language plpgsql volatile as $$
begin
  if not exists (select 1 from "Users" where id = p_user_id) then
    return false;
  end if;

  -- Hub (Q&A): the user's questions, their comments, replies to those
  -- comments, and every vote on any of it. Replies are one level deep
  -- (parentId must be a top-level comment), so one pass covers them.
  delete from "HubCommentUpvotes"
  where "userId" = p_user_id
     or "commentId" in (
       select c.id from "HubComments" c
       where c."authorId" = p_user_id
          or c."threadId" in (select id from "HubThreads" where "askerId" = p_user_id)
          or c."parentId" in (select id from "HubComments" where "authorId" = p_user_id));

  delete from "HubComments" c
  where c."authorId" = p_user_id
     or c."threadId" in (select id from "HubThreads" where "askerId" = p_user_id)
     or c."parentId" in (select id from "HubComments" where "authorId" = p_user_id);

  delete from "HubThreadUpvotes"
  where "userId" = p_user_id
     or "threadId" in (select id from "HubThreads" where "askerId" = p_user_id);

  delete from "HubThreads" where "askerId" = p_user_id;

  -- Feed posts and the votes/reports on them.
  delete from "PostHelpfuls"
  where "userId" = p_user_id
     or "postId" in (select id from "Posts" where "userId" = p_user_id);

  delete from "PostReports"
  where "reporterId" = p_user_id
     or "postId" in (select id from "Posts" where "userId" = p_user_id);

  delete from "Posts" where "userId" = p_user_id;

  -- Direct questions to ambassadors, whichever side the user was on.
  delete from "Threads" where "askerId" = p_user_id or "recipientId" = p_user_id;

  -- Event reservations and the emails logged for them.
  delete from "EventEmails" where "userId" = p_user_id;
  delete from "EventReservations" where "userId" = p_user_id;

  -- Reviews they wrote, and their id in other reviews' helpful votes.
  delete from place_reviews where user_id = p_user_id;
  delete from college_reviews where user_id = p_user_id;

  update place_reviews
     set helpful_user_ids = (select coalesce(array_agg(x), '{}') from unnest(helpful_user_ids) x where x <> p_user_id)
   where p_user_id = any(helpful_user_ids);

  update college_reviews
     set helpful_user_ids = (select coalesce(array_agg(x), '{}') from unnest(helpful_user_ids) x where x <> p_user_id)
   where p_user_id = any(helpful_user_ids);

  -- Profile-owned rows.
  delete from "Education"      where "userId" = p_user_id;
  delete from "Experiences"    where "userId" = p_user_id;
  delete from "ShopRedemptions" where "userId" = p_user_id;
  delete from amsa_memberships where user_id = p_user_id;
  delete from follows          where "followerId" = p_user_id or "followingId" = p_user_id;

  -- Reports they filed or that are about them, and blocks either way.
  delete from "ContentReports" where "reporterId" = p_user_id or "targetUserId" = p_user_id;
  delete from "UserBlocks"     where "blockerId" = p_user_id or "blockedId" = p_user_id;

  delete from "Users" where id = p_user_id;
  return true;
end;
$$;
