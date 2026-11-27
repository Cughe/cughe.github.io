-- 在 Supabase 后台 → SQL Editor → New query 中粘贴执行
-- 投稿系统：submissions 表 + 行级安全（RLS）
-- 本脚本可重复执行（幂等）

-- ========== 1. 建表 ==========
create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text default '投稿',
  summary text,
  content text not null,
  author_name text,
  author_email text,
  user_id uuid references auth.users(id) on delete set null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz default now(),
  reviewed_at timestamptz
);

-- ========== 2. 开启行级安全 ==========
alter table public.submissions enable row level security;

-- ========== 3. 策略（先删后建，可重复执行） ==========

-- 3.1 所有人（含匿名）可投稿，但只能插入 pending 状态
drop policy if exists "submissions_insert_pending" on public.submissions;
create policy "submissions_insert_pending"
  on public.submissions for insert
  to anon, authenticated
  with check (status = 'pending');

-- 3.2 所有人可读已通过的稿件（文章广场 / 全文页匿名访问）
drop policy if exists "submissions_select_approved" on public.submissions;
create policy "submissions_select_approved"
  on public.submissions for select
  using (status = 'approved');

-- 3.3 仅管理员可读全部稿件（审核后台要看 pending）
-- ★★★ 把下面的邮箱改成你自己的管理员邮箱，需与 review.html 里的 ADMIN_EMAILS 保持一致 ★★★
drop policy if exists "submissions_select_admin" on public.submissions;
create policy "submissions_select_admin"
  on public.submissions for select
  to authenticated
  using (auth.jwt() ->> 'email' = 'cyq142857@outlook.com');

-- 3.4 仅管理员可更新状态（通过 / 拒绝）
drop policy if exists "submissions_update_admin" on public.submissions;
create policy "submissions_update_admin"
  on public.submissions for update
  to authenticated
  using (auth.jwt() ->> 'email' = 'cyq142857@outlook.com')
  with check (auth.jwt() ->> 'email' = 'cyq142857@outlook.com');

-- ========== 4. 刷新缓存 ==========
notify pgrst, 'reload schema';

-- 说明：
-- - 管理员邮箱出现两处：本文件的两条策略 + review.html 的 ADMIN_EMAILS，改一处要两处都改。
-- - 通过 = 把 status 改成 approved；拒绝 = 改成 rejected。改完索引页自动更新，无需重新部署。
-- - status 只能取 pending / approved / rejected 三者之一。
