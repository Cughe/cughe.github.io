-- 在 Supabase 后台 → SQL Editor → New query 中粘贴执行
-- 用于存放用户头像、昵称、个性签名

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

-- 3. 策略：所有人可读资料（主页按钮显示昵称需要）
create policy "profiles_select_all"
  on public.profiles for select
  using (true);

-- 4. 策略：仅登录用户可插入自己的资料
create policy "profiles_insert_own"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

-- 5. 策略：仅本人可修改自己的资料
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- 说明：
-- - 头像这里存的是图片链接（avatar_url），把图片传到图床或 Supabase Storage 后把链接填进表单即可。
-- - 若还想限制"仅本人可删除"，可再加一条 delete 策略；当前页面没有删除功能，可不加。
