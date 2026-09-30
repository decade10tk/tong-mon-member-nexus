-- Tông Môn — Member Nexus
-- Run this file in Supabase SQL Editor as the project owner.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text not null default 'Đệ tử mới' check (char_length(display_name) between 2 and 40),
  role text not null default 'de_tu' check (role in ('tong_chu','thai_thuong_truong_lao','truong_lao','duong_chu','chap_su','de_tu')),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  minecraft_username text check (minecraft_username is null or char_length(minecraft_username)<=32),
  discord_username text check (discord_username is null or char_length(discord_username)<=80),
  bio text check (bio is null or char_length(bio)<=400),
  avatar_url text check (avatar_url is null or char_length(avatar_url)<=500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists profiles_status_idx on public.profiles(status);
create index if not exists profiles_role_idx on public.profiles(role);

create table if not exists public.membership_audit (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  action text not null check (action in ('approved','rejected','role_changed')),
  old_value text,
  new_value text,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id,email,display_name,minecraft_username,discord_username,role,status)
  values (
    new.id, new.email,
    coalesce(nullif(left(trim(new.raw_user_meta_data->>'display_name'),40),''),'Đệ tử mới'),
    nullif(left(trim(new.raw_user_meta_data->>'minecraft_username'),32),''),
    nullif(left(trim(new.raw_user_meta_data->>'discord_username'),80),''),
    'de_tu','pending'
  ) on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();

-- Prevent users from changing their own role/status/email even if they craft direct API requests.
create or replace function public.protect_profile_privileges()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and auth.uid() = old.id then
    if new.role is distinct from old.role or new.status is distinct from old.status or new.email is distinct from old.email then
      raise exception 'role, status and email are managed by authorized server/database workflows';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists profiles_protect_privileges on public.profiles;
create trigger profiles_protect_privileges before update on public.profiles for each row execute procedure public.protect_profile_privileges();

create or replace function public.current_member_role()
returns text language sql stable security definer set search_path = '' as $$
  select p.role from public.profiles p where p.id=auth.uid() and p.status='approved' limit 1;
$$;
create or replace function public.is_approved_member()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.profiles p where p.id=auth.uid() and p.status='approved');
$$;

alter table public.profiles enable row level security;
alter table public.membership_audit enable row level security;
drop policy if exists "approved members can read approved profiles" on public.profiles;
create policy "approved members can read approved profiles" on public.profiles for select to authenticated using (status='approved' and public.is_approved_member());
drop policy if exists "users can read own profile" on public.profiles;
create policy "users can read own profile" on public.profiles for select to authenticated using (id=auth.uid());
drop policy if exists "users can update safe fields on own profile" on public.profiles;
create policy "users can update safe fields on own profile" on public.profiles for update to authenticated using (id=auth.uid() and status='approved') with check (id=auth.uid() and status='approved');
drop policy if exists "managers can read all profiles" on public.profiles;
create policy "managers can read all profiles" on public.profiles for select to authenticated using (public.current_member_role() in ('tong_chu','thai_thuong_truong_lao'));
drop policy if exists "managers can read audit" on public.membership_audit;
create policy "managers can read audit" on public.membership_audit for select to authenticated using (public.current_member_role() in ('tong_chu','thai_thuong_truong_lao'));

-- SECURITY DEFINER RPCs are the only normal client path to review applications or change ranks.
create or replace function public.review_membership(target_user_id uuid, approve_request boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare actor_role text; old_status text;
begin
  select p.role into actor_role from public.profiles p where p.id=auth.uid() and p.status='approved';
  if actor_role is distinct from 'tong_chu' then raise exception 'Only Tông chủ may review membership'; end if;
  select p.status into old_status from public.profiles p where p.id=target_user_id for update;
  if old_status is null then raise exception 'Target profile not found'; end if;
  if old_status <> 'pending' then raise exception 'Only pending requests can be reviewed'; end if;
  update public.profiles set status=case when approve_request then 'approved' else 'rejected' end where id=target_user_id;
  insert into public.membership_audit(actor_id,target_user_id,action,old_value,new_value)
  values(auth.uid(),target_user_id,case when approve_request then 'approved' else 'rejected' end,old_status,case when approve_request then 'approved' else 'rejected' end);
end; $$;

create or replace function public.change_member_role(target_user_id uuid, new_role text)
returns void language plpgsql security definer set search_path = '' as $$
declare actor_role text; old_role text; target_status text;
begin
  select p.role into actor_role from public.profiles p where p.id=auth.uid() and p.status='approved';
  if actor_role not in ('tong_chu','thai_thuong_truong_lao') then raise exception 'Insufficient privileges'; end if;
  if new_role not in ('thai_thuong_truong_lao','truong_lao','duong_chu','chap_su','de_tu') then raise exception 'Invalid target role'; end if;
  select p.role,p.status into old_role,target_status from public.profiles p where p.id=target_user_id for update;
  if old_role is null then raise exception 'Target profile not found'; end if;
  if target_status <> 'approved' then raise exception 'Only approved members can be ranked'; end if;
  if old_role='tong_chu' then raise exception 'Tông chủ role cannot be changed through this workflow'; end if;
  -- Thái thượng trưởng lão can manage ordinary ranks but cannot appoint/remove Tông chủ or fellow TTRs.
  if actor_role='thai_thuong_truong_lao' and (old_role='thai_thuong_truong_lao' or new_role='thai_thuong_truong_lao') then raise exception 'Only Tông chủ can appoint or remove a Thái thượng trưởng lão'; end if;
  update public.profiles set role=new_role where id=target_user_id;
  insert into public.membership_audit(actor_id,target_user_id,action,old_value,new_value)
  values(auth.uid(),target_user_id,'role_changed',old_role,new_role);
end; $$;

revoke all on function public.review_membership(uuid,boolean) from public, anon;
grant execute on function public.review_membership(uuid,boolean) to authenticated;
revoke all on function public.change_member_role(uuid,text) from public, anon;
grant execute on function public.change_member_role(uuid,text) to authenticated;
revoke all on function public.current_member_role() from public, anon;
grant execute on function public.current_member_role() to authenticated;
revoke all on function public.is_approved_member() from public, anon;
grant execute on function public.is_approved_member() to authenticated;

-- Bootstrap instructions: after registering your account, run the one-time UPDATE shown in README.
-- Do not expose a service_role key in frontend code.
