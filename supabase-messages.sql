-- 在 Supabase 后台 → SQL Editor → New query 中粘贴执行
-- 私信系统：messages 表 + 行级安全（RLS），可重复执行

-- ========== 1. 建表 ==========
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  content text not null,
  read boolean not null default false,
  created_at timestamptz default now()
);

-- 常用查询索引
create index if not exists messages_sender_idx on public.messages(sender_id);
create index if not exists messages_receiver_idx on public.messages(receiver_id);

-- ========== 2. 开启行级安全 ==========
alter table public.messages enable row level security;

-- ========== 3. 策略（先删后建） ==========

-- 3.1 只有收发双方能看某条消息
drop policy if exists "messages_select_participants" on public.messages;
create policy "messages_select_participants"
  on public.messages for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- 3.2 只能以自己身份发消息
drop policy if exists "messages_insert_own" on public.messages;
create policy "messages_insert_own"
  on public.messages for insert
  to authenticated
  with check (auth.uid() = sender_id);

-- 3.3 只有接收方能更新（标记已读）
drop policy if exists "messages_update_receiver" on public.messages;
create policy "messages_update_receiver"
  on public.messages for update
  to authenticated
  using (auth.uid() = receiver_id)
  with check (auth.uid() = receiver_id);

-- ========== 4. 开启 Realtime（实时收消息） ==========
-- 把 messages 表加入 supabase_realtime 发布（已加入则忽略报错）
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end $$;

-- ========== 5. 刷新缓存 ==========
notify pgrst, 'reload schema';

-- 说明：
-- - 私信仅收发双方可见，且只能以登录自己身份发送，安全由 RLS 保证。
-- - Realtime 已开启，对方发消息时你的私信面板会实时刷新（无需手动刷新页面）。
-- - 用户列表读的是 profiles 表（昵称/头像），所以要先执行过 supabase-profiles.sql 建档。
