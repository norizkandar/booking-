-- EONIX BOOKING — Supabase PostgreSQL schema
-- Run this entire file in Supabase SQL Editor using a trusted project owner account.
-- Never expose the Supabase service_role key in frontend code.

create extension if not exists pgcrypto;

do $$ begin
  create type public.platform_role as enum ('customer','super_admin');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.business_role as enum ('business_owner','staff');
exception when duplicate_object then null; end $$;
do $$ begin
  create type public.booking_status as enum ('pending','confirmed','completed','cancelled','rejected');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null default '',
  phone text,
  platform_role public.platform_role not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null check (char_length(name) between 2 and 120),
  slug text unique,
  category text not null default 'general',
  description text,
  phone text,
  email text,
  website text,
  logo_url text,
  timezone text not null default 'Asia/Kuala_Lumpur',
  currency text not null default 'MYR',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.business_role not null default 'staff',
  status text not null default 'active' check(status in ('active','invited','suspended')),
  created_at timestamptz not null default now(),
  unique(business_id,user_id)
);

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  address text,
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  category text not null default 'General',
  description text,
  price numeric(12,2) not null default 0 check(price >= 0),
  duration_minutes integer not null default 30 check(duration_minutes between 5 and 1440),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references public.profiles(id) on delete set null,
  full_name text not null,
  email text,
  phone text,
  notes text,
  created_at timestamptz not null default now()
);
create unique index if not exists customers_business_email_unique
  on public.customers(business_id,lower(email)) where email is not null and email <> '';

create table if not exists public.resources (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete set null,
  name text not null,
  resource_type text not null default 'general',
  capacity integer not null default 1 check(capacity > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete set null,
  service_id uuid references public.services(id) on delete set null,
  customer_user_id uuid references public.profiles(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  customer_name text not null,
  customer_email text,
  customer_phone text,
  start_at timestamptz not null,
  end_at timestamptz not null,
  status public.booking_status not null default 'pending',
  total_amount numeric(12,2) not null default 0 check(total_amount >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(end_at > start_at)
);
create index if not exists bookings_business_start_idx on public.bookings(business_id,start_at);
create index if not exists bookings_customer_idx on public.bookings(customer_user_id,start_at);

create table if not exists public.availability_rules (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete cascade,
  weekday smallint not null check(weekday between 0 and 6),
  opens_at time,
  closes_at time,
  is_closed boolean not null default false,
  created_at timestamptz not null default now(),
  check(is_closed or (opens_at is not null and closes_at is not null and closes_at > opens_at))
);

create table if not exists public.availability_exceptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete cascade,
  exception_date date not null,
  is_closed boolean not null default true,
  opens_at time,
  closes_at time,
  reason text,
  created_at timestamptz not null default now()
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  customer_user_id uuid references public.profiles(id) on delete set null,
  rating smallint not null check(rating between 1 and 5),
  comment text,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.promotions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  code text not null,
  description text,
  discount_type text not null check(discount_type in ('percentage','fixed')),
  discount_value numeric(12,2) not null check(discount_value > 0),
  starts_at timestamptz,
  ends_at timestamptz,
  usage_limit integer,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(business_id,code)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete cascade,
  title text not null,
  body text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  business_id uuid references public.businesses(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Security helper functions. SECURITY DEFINER avoids recursive RLS lookups.
create or replace function public.is_super_admin()
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.profiles p where p.id=auth.uid() and p.platform_role='super_admin') $$;

create or replace function public.is_business_member(target_business uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(select 1 from public.business_members m where m.business_id=target_business and m.user_id=auth.uid() and m.status='active') $$;

create or replace function public.is_business_manager(target_business uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select public.is_super_admin() or exists(select 1 from public.business_members m where m.business_id=target_business and m.user_id=auth.uid() and m.status='active' and m.role='business_owner') $$;

create or replace function public.can_view_business_profile(target_user uuid)
returns boolean language sql stable security definer set search_path=public
as $$ select exists(
  select 1 from public.business_members mine
  join public.business_members theirs on theirs.business_id=mine.business_id
  where mine.user_id=auth.uid() and mine.status='active'
    and theirs.user_id=target_user and theirs.status='active'
) $$;

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end $$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public
as $$
begin
  insert into public.profiles(id,full_name,email)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),lower(new.email))
  on conflict(id) do update set email=excluded.email;
  return new;
end $$;

drop trigger if exists on_auth_user_created_eonix on auth.users;
create trigger on_auth_user_created_eonix after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.create_owner_membership()
returns trigger language plpgsql security definer set search_path=public
as $$ begin
  insert into public.business_members(business_id,user_id,role,status)
  values(new.id,new.owner_id,'business_owner','active')
  on conflict(business_id,user_id) do nothing;
  return new;
end $$;
drop trigger if exists on_business_created_owner_membership on public.businesses;
create trigger on_business_created_owner_membership after insert on public.businesses
for each row execute procedure public.create_owner_membership();

do $$ declare t text; begin
  foreach t in array array['profiles','businesses','services'] loop
    execute format('drop trigger if exists touch_updated_at on public.%I',t);
    execute format('create trigger touch_updated_at before update on public.%I for each row execute procedure public.touch_updated_at()',t);
  end loop;
  drop trigger if exists touch_updated_at on public.bookings;
  create trigger touch_updated_at before update on public.bookings for each row execute procedure public.touch_updated_at();
end $$;

-- RLS enabled on every tenant-sensitive table.
alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.branches enable row level security;
alter table public.services enable row level security;
alter table public.customers enable row level security;
alter table public.resources enable row level security;
alter table public.bookings enable row level security;
alter table public.availability_rules enable row level security;
alter table public.availability_exceptions enable row level security;
alter table public.reviews enable row level security;
alter table public.promotions enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles: users can see/update only their own profile; super admins can inspect.
drop policy if exists "profile_select_self_or_admin" on public.profiles;
create policy "profile_select_self_or_admin" on public.profiles for select to authenticated
using(id=auth.uid() or public.is_super_admin() or public.can_view_business_profile(id));
drop policy if exists "profile_update_self" on public.profiles;
create policy "profile_update_self" on public.profiles for update to authenticated
using(id=auth.uid()) with check(id=auth.uid() and platform_role='customer');

-- Business: owner creates own business; active members can view; managers update.
drop policy if exists "business_insert_owner" on public.businesses;
create policy "business_insert_owner" on public.businesses for insert to authenticated
with check(owner_id=auth.uid());
drop policy if exists "business_select_members" on public.businesses;
create policy "business_select_members" on public.businesses for select to authenticated
using(owner_id=auth.uid() or public.is_business_member(id) or public.is_super_admin());
drop policy if exists "business_update_manager" on public.businesses;
create policy "business_update_manager" on public.businesses for update to authenticated
using(public.is_business_manager(id)) with check(public.is_business_manager(id));
drop policy if exists "business_delete_manager" on public.businesses;
create policy "business_delete_manager" on public.businesses for delete to authenticated
using(public.is_business_manager(id));

-- Memberships: members can view their own business roster; only managers add/change/remove.
drop policy if exists "members_select_same_business" on public.business_members;
create policy "members_select_same_business" on public.business_members for select to authenticated
using(user_id=auth.uid() or public.is_business_member(business_id) or public.is_super_admin());
drop policy if exists "members_insert_manager" on public.business_members;
create policy "members_insert_manager" on public.business_members for insert to authenticated
with check(public.is_business_manager(business_id) and role <> 'business_owner');
drop policy if exists "members_update_manager" on public.business_members;
create policy "members_update_manager" on public.business_members for update to authenticated
using(public.is_business_manager(business_id)) with check(public.is_business_manager(business_id));
drop policy if exists "members_delete_manager" on public.business_members;
create policy "members_delete_manager" on public.business_members for delete to authenticated
using(public.is_business_manager(business_id));

-- Standard tenant policies for business-owned records.
do $$ declare t text; begin
  foreach t in array array['branches','services','customers','resources','availability_rules','availability_exceptions','reviews','promotions'] loop
    execute format('drop policy if exists tenant_select on public.%I',t);
    execute format('create policy tenant_select on public.%I for select to authenticated using(public.is_business_member(business_id) or public.is_super_admin())',t);
    execute format('drop policy if exists tenant_insert on public.%I',t);
    execute format('create policy tenant_insert on public.%I for insert to authenticated with check(public.is_business_manager(business_id))',t);
    execute format('drop policy if exists tenant_update on public.%I',t);
    execute format('create policy tenant_update on public.%I for update to authenticated using(public.is_business_manager(business_id)) with check(public.is_business_manager(business_id))',t);
    execute format('drop policy if exists tenant_delete on public.%I',t);
    execute format('create policy tenant_delete on public.%I for delete to authenticated using(public.is_business_manager(business_id))',t);
  end loop;
end $$;

-- Staff may manage booking statuses; business owners manage all booking records.
drop policy if exists bookings_select_member on public.bookings;
create policy bookings_select_member on public.bookings for select to authenticated
using(public.is_business_member(business_id) or customer_user_id=auth.uid() or public.is_super_admin());
drop policy if exists bookings_insert_member on public.bookings;
create policy bookings_insert_member on public.bookings for insert to authenticated
with check(public.is_business_member(business_id) and (created_by=auth.uid() or customer_user_id=auth.uid()));
drop policy if exists bookings_update_manager_or_staff on public.bookings;
create policy bookings_update_manager_or_staff on public.bookings for update to authenticated
using(public.is_business_member(business_id) or public.is_super_admin())
with check(public.is_business_member(business_id) or public.is_super_admin());
drop policy if exists bookings_delete_manager on public.bookings;
create policy bookings_delete_manager on public.bookings for delete to authenticated
using(public.is_business_manager(business_id));

-- Customers are private to the business. Customers cannot browse the customer directory.
-- Notifications are visible only to their recipient.
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications for select to authenticated using(user_id=auth.uid() or public.is_super_admin());
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
drop policy if exists notifications_insert_manager on public.notifications;
create policy notifications_insert_manager on public.notifications for insert to authenticated with check(public.is_business_manager(business_id) or user_id=auth.uid());

drop policy if exists audit_select_manager on public.audit_logs;
create policy audit_select_manager on public.audit_logs for select to authenticated using(public.is_business_manager(business_id) or public.is_super_admin());
drop policy if exists audit_insert_member on public.audit_logs;
create policy audit_insert_member on public.audit_logs for insert to authenticated with check(actor_id=auth.uid() and public.is_business_member(business_id));

-- IMPORTANT: Super Admin assignment must be performed manually by a trusted project owner:
-- update public.profiles set platform_role='super_admin' where email='trusted-admin@example.com';
-- Never expose service_role keys. Review policies and test with separate owner/staff/customer accounts before launch.
