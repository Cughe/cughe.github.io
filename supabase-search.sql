-- 私信用户搜索：按昵称或邮箱查找用户（在 Supabase → SQL Editor → New query 执行）
-- profiles 表没有 email，邮箱存在 auth.users，故用 security definer 函数联表查询。
-- 幂等：可重复执行。

create or replace function public.search_users(q text)
returns table (id uuid, nickname text, email text, avatar_url text)
language sql
security definer
set search_path = public, auth
as $$
  select p.id, p.nickname, u.email, p.avatar_url
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.id <> auth.uid()
    and (
      q is null or q = ''
      or p.nickname ilike '%' || q || '%'
      or u.email ilike '%' || q || '%'
    )
  order by p.nickname asc nulls last, u.email asc
  limit 50;
$$;

-- 只授权登录用户调用
revoke all on function public.search_users(text) from public;
grant execute on function public.search_users(text) to authenticated;

-- 刷新 PostgREST schema cache
notify pgrst, 'reload schema';

-- 说明：
-- - 不填搜索词（或留空）时返回全部其他用户；填了则匹配昵称或邮箱（不区分大小写、模糊匹配）。
-- - 函数排除了当前用户自己，且只返回昵称/邮箱/头像，不涉及密码等敏感信息。
-- - 前端若调用失败会回退到只查 profiles 的昵称搜索，不执行本脚本也能按昵称找人，但搜不了邮箱。
