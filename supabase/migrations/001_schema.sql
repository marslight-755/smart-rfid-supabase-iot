create extension if not exists pgcrypto;
create or replace function public.hash_token(value text) returns text language sql immutable as $$ select encode(extensions.digest(value::bytea,'sha256'),'hex'); $$;

create table public.organizations (id uuid primary key default gen_random_uuid(), name text not null, created_at timestamptz not null default now());
create table public.organization_members (organization_id uuid references public.organizations(id) on delete cascade, user_id uuid references auth.users(id) on delete cascade, role text not null default 'member' check (role in ('admin','member','viewer')), primary key (organization_id,user_id));
create table public.devices (id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id) on delete cascade, device_code text not null unique, name text not null default '', enabled boolean not null default true, sample_interval_seconds integer not null default 10, created_at timestamptz not null default now());
create table public.device_credentials (device_id uuid primary key references public.devices(id) on delete cascade, token_hash text not null unique, created_at timestamptz not null default now(), rotated_at timestamptz);
create table public.telemetry (id bigint generated always as identity primary key, device_id uuid not null references public.devices(id) on delete cascade, boot_id uuid not null, sequence bigint not null, measured_at timestamptz, received_at timestamptz not null default now(), temperature_c double precision, ph double precision, voltage_v double precision, status text not null default 'RUNNING', unique(device_id,boot_id,sequence));
create index telemetry_device_time_idx on public.telemetry(device_id, measured_at desc);
create table public.device_latest (device_id uuid primary key references public.devices(id) on delete cascade, received_at timestamptz not null, measured_at timestamptz, temperature_c double precision, ph double precision, voltage_v double precision, status text not null default 'RUNNING');

create or replace function public.is_org_member(target_org uuid) returns boolean language sql security definer set search_path=public as $$ select exists(select 1 from organization_members where organization_id=target_org and user_id=auth.uid()); $$;
create or replace function public.device_org(target_device uuid) returns uuid language sql security definer set search_path=public as $$ select organization_id from devices where id=target_device; $$;

alter table organizations enable row level security; alter table organization_members enable row level security; alter table devices enable row level security; alter table telemetry enable row level security; alter table device_latest enable row level security; alter table device_credentials enable row level security;
create policy org_members_read on organizations for select to authenticated using (is_org_member(id));
create policy own_membership_read on organization_members for select to authenticated using (user_id=auth.uid());
create policy devices_read on devices for select to authenticated using (is_org_member(organization_id));
create policy telemetry_read on telemetry for select to authenticated using (is_org_member(device_org(device_id)));
create policy latest_read on device_latest for select to authenticated using (is_org_member(device_org(device_id)));
revoke all on device_credentials from anon, authenticated;

alter publication supabase_realtime add table public.device_latest;

-- Provisioning example (run after creating an Auth user):
-- insert into organizations(name) values ('Demo Customer') returning id;
-- insert into organization_members(organization_id,user_id,role) values ('ORG_UUID','AUTH_USER_UUID','admin');
-- insert into devices(organization_id,device_code,name) values ('ORG_UUID','ESP32-001','Demo Sensor') returning id;
-- Store hash_token('secret') in device_credentials; use the same SHA-256 secret only on the device.
