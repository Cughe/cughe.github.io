-- 在 Supabase 后台 → SQL Editor → New query 中粘贴执行
-- 用于存放用户头像、昵称、个性签名
-- 本脚本可重复执行（幂等），不会因“策略已存在”而报错

-- 1. 建表（id 关联 auth.users，一个用户一条资料）
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text,
  avatar_url text,
  bio text,
  updated_at timestamptz default now()
);

-- 2. 开启行级安全（RLS）
alter table public.profiles enable row level security;

-- 3. 策略：先 drop 再 create，保证重复执行不报错
drop policy if exists "profiles_select_all" on public.profiles;
create policy "profiles_select_all"
  on public.profiles for select
  using (true);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 4. 刷新 PostgREST schema cache（表/策略变更后前端立即生效）
notify pgrst, 'reload schema';

-- 说明：
-- - 头像存图片链接（avatar_url），把图片传到图床或 Supabase Storage 后把链接填进表单即可。
-- - 若还想限制“仅本人可删除”，可再加一条 delete 策略；当前页面没有删除功能，可不加。
-- - 如果之前已经执行过旧版本，直接重新执行本脚本即可，不会有 “already exists” 报错。
