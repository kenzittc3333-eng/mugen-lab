-- MUGEN member access: review in an isolated Supabase project before applying.
begin;
create schema if not exists mugen_private;
revoke all on schema mugen_private from public, anon, authenticated;
create table mugen_private.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
create function public.mugen_is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from mugen_private.admins where user_id = auth.uid()) $$;
revoke all on function public.mugen_is_admin() from public;
grant execute on function public.mugen_is_admin() to anon, authenticated;

create table public.mugen_materials (
 id uuid primary key default gen_random_uuid(),
 title text not null check(length(title) between 1 and 200),
 subject text not null check(subject in ('数学','英語','国語','理科','社会','小学生','百マス計算','その他')),
 access_type text not null default 'free' check(access_type in ('free','paid')),
 published boolean not null default false,
 price_yen integer not null default 0 check(price_yen >= 0),
 duration_days integer not null default 30 check(duration_days between 1 and 366),
 free_url text,
 created_at timestamptz not null default now(),
 check(access_type <> 'free' or free_url is not null)
);
-- Content is separate from public metadata. Never place paid HTML in GitHub.
create table public.mugen_content (
 material_id uuid primary key references public.mugen_materials(id) on delete cascade,
 html text not null check(length(html) > 0)
);
create table public.mugen_entitlements (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 material_id uuid not null references public.mugen_materials(id) on delete cascade,
 starts_at timestamptz not null,
 expires_at timestamptz not null,
 payment_confirmed_at timestamptz not null,
 granted_by uuid not null references auth.users(id),
 revoked_at timestamptz,
 check(expires_at > starts_at)
);
create index on public.mugen_entitlements(user_id,material_id,expires_at);
alter table public.mugen_materials enable row level security;
alter table public.mugen_content enable row level security;
alter table public.mugen_entitlements enable row level security;
revoke all on public.mugen_materials,public.mugen_content,public.mugen_entitlements from anon,authenticated;
grant select on public.mugen_materials to anon,authenticated;
grant select on public.mugen_content,public.mugen_entitlements to authenticated;
grant insert,update,delete on public.mugen_materials,public.mugen_content to authenticated;
create policy catalog_read on public.mugen_materials for select using(published or public.mugen_is_admin());
create policy catalog_admin on public.mugen_materials for all to authenticated
 using(public.mugen_is_admin()) with check(public.mugen_is_admin());
create policy content_admin on public.mugen_content for all to authenticated
 using(public.mugen_is_admin()) with check(public.mugen_is_admin());
create policy grants_read on public.mugen_entitlements for select to authenticated
 using(user_id = auth.uid() or public.mugen_is_admin());
create policy content_read on public.mugen_content for select to authenticated using (
 exists(select 1 from public.mugen_materials m where m.id = material_id and m.published
 and (m.access_type = 'free' or exists(
 select 1 from public.mugen_entitlements e where e.material_id = m.id
 and e.user_id = auth.uid() and e.revoked_at is null
 and e.starts_at <= now() and now() < e.expires_at)))
);
-- The database clock controls the period; clients cannot grant themselves access.
create function public.mugen_confirm_payment(p_email text,p_material uuid,p_days integer)
returns uuid language plpgsql security definer set search_path = '' as $$
declare target uuid; result_id uuid;
begin
 if not public.mugen_is_admin() then raise exception '管理者権限が必要です'; end if;
 if p_days is null or p_days < 1 or p_days > 366 then raise exception '利用日数が不正です'; end if;
 select id into target from auth.users where lower(email) = lower(trim(p_email)) and email_confirmed_at is not null;
 if target is null then raise exception 'メール認証済みの利用者が見つかりません'; end if;
 if not exists(select 1 from public.mugen_materials where id = p_material and access_type = 'paid')
 then raise exception '有料教材が見つかりません'; end if;
 insert into public.mugen_entitlements(user_id,material_id,starts_at,expires_at,payment_confirmed_at,granted_by)
 values(target,p_material,now(),now()+make_interval(days=>p_days),now(),auth.uid()) returning id into result_id;
 return result_id;
end $$;
create function public.mugen_revoke_access(p_entitlement uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if not public.mugen_is_admin() then raise exception '管理者権限が必要です'; end if;
 update public.mugen_entitlements set revoked_at = now() where id = p_entitlement;
end $$;
revoke all on function public.mugen_confirm_payment(text,uuid,integer),public.mugen_revoke_access(uuid) from public;
grant execute on function public.mugen_confirm_payment(text,uuid,integer),public.mugen_revoke_access(uuid) to authenticated;
commit;
