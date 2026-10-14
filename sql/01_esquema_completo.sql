-- by Fraam Tag Mascotas — ejecutar una sola vez en Supabase SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.pets (
  id uuid primary key default gen_random_uuid(),
  tag_code uuid not null unique default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 100),
  species text not null default 'Otra' check (species in ('Perro','Gato','Otra')),
  breed text,
  description text,
  photo_url text,
  owner_name text,
  owner_phone text,
  public_contact_phone text,
  public_whatsapp text,
  is_missing boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.found_reports (
  id uuid primary key default gen_random_uuid(),
  pet_id uuid not null references public.pets(id) on delete cascade,
  finder_name text,
  finder_phone text,
  message text,
  location_text text,
  status text not null default 'new' check (status in ('new','reviewed')),
  created_at timestamptz not null default now()
);
create index if not exists pets_created_at_idx on public.pets(created_at desc);
create index if not exists found_reports_created_at_idx on public.found_reports(created_at desc);
create index if not exists found_reports_pet_created_idx on public.found_reports(pet_id,created_at desc);

alter table public.admin_users enable row level security;
alter table public.pets enable row level security;
alter table public.found_reports enable row level security;

-- Solo un administrador autenticado puede consultar su propia fila.
drop policy if exists "admin can read own admin row" on public.admin_users;
create policy "admin can read own admin row" on public.admin_users for select to authenticated using (user_id = auth.uid());

-- Las tablas operativas solo son accesibles a administradores autenticados.
drop policy if exists "admins manage pets" on public.pets;
create policy "admins manage pets" on public.pets for all to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "admins read reports" on public.found_reports;
create policy "admins read reports" on public.found_reports for select to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
drop policy if exists "admins update reports" on public.found_reports;
create policy "admins update reports" on public.found_reports for update to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

-- Fotos públicas: solo el perfil de la mascota expone la URL; escritura reservada a admins.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('pet-photos','pet-photos',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists "admins upload pet photos" on storage.objects;
create policy "admins upload pet photos" on storage.objects for insert to authenticated
with check (bucket_id='pet-photos' and exists (select 1 from public.admin_users a where a.user_id=auth.uid()));
drop policy if exists "admins update pet photos" on storage.objects;
create policy "admins update pet photos" on storage.objects for update to authenticated
using (bucket_id='pet-photos' and exists (select 1 from public.admin_users a where a.user_id=auth.uid()))
with check (bucket_id='pet-photos' and exists (select 1 from public.admin_users a where a.user_id=auth.uid()));
drop policy if exists "admins delete pet photos" on storage.objects;
create policy "admins delete pet photos" on storage.objects for delete to authenticated
using (bucket_id='pet-photos' and exists (select 1 from public.admin_users a where a.user_id=auth.uid()));

-- Función pública devuelve SOLO campos autorizados, nunca datos privados del responsable.
create or replace function public.get_public_pet(p_tag_code uuid)
returns table(name text,species text,breed text,description text,photo_url text,public_contact_phone text,public_whatsapp text,is_missing boolean)
language sql stable security definer set search_path=public
as $$
  select p.name,p.species,p.breed,p.description,p.photo_url,p.public_contact_phone,p.public_whatsapp,p.is_missing
  from public.pets p where p.tag_code=p_tag_code limit 1;
$$;
revoke all on function public.get_public_pet(uuid) from public;
grant execute on function public.get_public_pet(uuid) to anon, authenticated;

-- Endpoint público para avisos. Máximo 5 por mascota en la última hora.
create or replace function public.submit_found_report(
  p_tag_code uuid, p_finder_name text default null, p_finder_phone text default null,
  p_message text default null, p_location_text text default null
) returns void language plpgsql security definer set search_path=public
as $$
declare v_pet_id uuid; v_count integer;
begin
  select id into v_pet_id from public.pets where tag_code=p_tag_code;
  if v_pet_id is null then raise exception 'No se encontró la mascota.'; end if;
  select count(*) into v_count from public.found_reports where pet_id=v_pet_id and created_at > now()-interval '1 hour';
  if v_count >= 5 then raise exception 'límite temporal de avisos alcanzado'; end if;
  if coalesce(length(trim(p_finder_name)),0)>80 or coalesce(length(trim(p_finder_phone)),0)>40 or coalesce(length(trim(p_message)),0)>1000 or coalesce(length(trim(p_location_text)),0)>200 then
    raise exception 'Uno o más campos superan el largo permitido.';
  end if;
  if coalesce(trim(p_finder_name),'')='' and coalesce(trim(p_finder_phone),'')='' and coalesce(trim(p_message),'')='' and coalesce(trim(p_location_text),'')='' then
    raise exception 'Completá al menos un campo.';
  end if;
  insert into public.found_reports(pet_id,finder_name,finder_phone,message,location_text)
  values(v_pet_id,nullif(trim(p_finder_name),''),nullif(trim(p_finder_phone),''),nullif(trim(p_message),''),nullif(trim(p_location_text),''));
end;
$$;
revoke all on function public.submit_found_report(uuid,text,text,text,text) from public;
grant execute on function public.submit_found_report(uuid,text,text,text,text) to anon, authenticated;

-- Privilegios de tablas: las políticas RLS siguen siendo la barrera de acceso.
grant select on public.admin_users to authenticated;
grant select,insert,update,delete on public.pets to authenticated;
grant select,update on public.found_reports to authenticated;
