-- MELTECH Careers: run this entire script in Supabase SQL Editor.
-- Then create an administrator user in Authentication and add that user's UUID
-- to public.career_admins (instructions are shown after the script).

create extension if not exists pgcrypto;

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  application_type text not null check (application_type in ('job','internship','attachment')),
  full_name text not null,
  phone text not null,
  email text not null,
  location text not null,
  position_applied text,
  institution text,
  course text,
  year_of_study text,
  qualifications text,
  experience text,
  skills text,
  motivation text,
  cv_path text not null,
  status text not null default 'new' check (status in ('new','reviewing','shortlisted','interview','accepted','rejected')),
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.applications add column if not exists position_applied text;
alter table public.applications add column if not exists institution text;
alter table public.applications add column if not exists course text;
alter table public.applications add column if not exists year_of_study text;
alter table public.applications add column if not exists qualifications text;
alter table public.applications add column if not exists experience text;
alter table public.applications add column if not exists skills text;
alter table public.applications add column if not exists motivation text;
alter table public.applications add column if not exists cv_path text;
alter table public.applications add column if not exists status text not null default 'new';
alter table public.applications add column if not exists admin_notes text;
alter table public.applications add column if not exists updated_at timestamptz not null default now();

create index if not exists applications_created_at_idx on public.applications (created_at desc);
create index if not exists applications_status_idx on public.applications (status);
create index if not exists applications_type_idx on public.applications (application_type);

create table if not exists public.career_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.applications enable row level security;
alter table public.career_admins enable row level security;

drop policy if exists "Public can submit career applications" on public.applications;
create policy "Public can submit career applications"
on public.applications for insert to anon, authenticated
with check (
  status = 'new'
  and application_type in ('job','internship','attachment')
  and length(trim(full_name)) between 2 and 150
  and length(trim(email)) between 3 and 254
  and length(trim(phone)) between 3 and 40
  and cv_path is not null
);

drop policy if exists "Career admins can read applications" on public.applications;
create policy "Career admins can read applications"
on public.applications for select to authenticated
using (exists (select 1 from public.career_admins a where a.user_id = auth.uid()));

drop policy if exists "Career admins can update applications" on public.applications;
create policy "Career admins can update applications"
on public.applications for update to authenticated
using (exists (select 1 from public.career_admins a where a.user_id = auth.uid()))
with check (exists (select 1 from public.career_admins a where a.user_id = auth.uid()));

drop policy if exists "Admins can read own admin record" on public.career_admins;
create policy "Admins can read own admin record"
on public.career_admins for select to authenticated using (user_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('application-cvs', 'application-cvs', false, 5242880,
  array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set public = false, file_size_limit = 5242880,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Applicants can upload CVs" on storage.objects;
create policy "Applicants can upload CVs"
on storage.objects for insert to anon, authenticated
with check (bucket_id = 'application-cvs');

drop policy if exists "Career admins can view CVs" on storage.objects;
create policy "Career admins can view CVs"
on storage.objects for select to authenticated
using (bucket_id = 'application-cvs' and exists (select 1 from public.career_admins a where a.user_id = auth.uid()));

drop policy if exists "Career admins can remove CVs" on storage.objects;
create policy "Career admins can remove CVs"
on storage.objects for delete to authenticated
using (bucket_id = 'application-cvs' and exists (select 1 from public.career_admins a where a.user_id = auth.uid()));

-- IMPORTANT: after creating the admin account in Supabase Authentication > Users,
-- copy its UUID and run the following as a separate statement, replacing the placeholder:
-- insert into public.career_admins (user_id) values ('PASTE-ADMIN-USER-UUID-HERE');
