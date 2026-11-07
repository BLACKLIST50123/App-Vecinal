-- =====================================================================
-- Migración 0005 · Reconocimiento vecinal: agradecimientos y ayudas confirmadas
-- Ejecutar UNA vez en Supabase > SQL Editor. Es segura de repetir.
-- Requiere 0001–0004.
-- =====================================================================
-- Idea: el reconocimiento no se basa en puntos que uno mismo se pone.
-- Solo sube cuando la persona ayudada CONFIRMA quién la ayudó
-- ("¡Ya me ayudaron!" → elige a quién agradecer). Así es verificable.
-- =====================================================================

create table if not exists public.migraciones (
  version     text primary key,
  nombre      text not null,
  aplicada_en timestamptz not null default now()
);
alter table public.migraciones enable row level security;

-- Contador público de ayudas confirmadas (para mostrar el nivel).
alter table public.perfiles add column if not exists ayudas_confirmadas int not null default 0;
grant select (ayudas_confirmadas) on public.perfiles to anon, authenticated;

-- Agradecimientos: quien publicó un pedido o colecta agradece a quien
-- respondió ("Yo te ayudo" / "Yo aporto").
create table if not exists public.agradecimientos (
  publicacion_id uuid not null references public.publicaciones(id) on delete cascade,
  de_id          uuid not null references public.perfiles(id) on delete cascade default auth.uid(),
  para_id        uuid not null references public.perfiles(id) on delete cascade,
  de_nombre      text,
  titulo         text,
  mensaje        text check (char_length(mensaje) <= 200),
  created_at     timestamptz not null default now(),
  primary key (publicacion_id, para_id)
);
create index if not exists agradecimientos_para_idx on public.agradecimientos (para_id, created_at desc);

create or replace function public.antes_agradecer() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select nombre into new.de_nombre from public.perfiles where id = new.de_id;
  select titulo into new.titulo from public.publicaciones where id = new.publicacion_id;
  return new;
end $$;
drop trigger if exists agradecimientos_antes on public.agradecimientos;
create trigger agradecimientos_antes before insert on public.agradecimientos
  for each row execute function public.antes_agradecer();

create or replace function public.contar_agradecimiento() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    update public.perfiles set ayudas_confirmadas = ayudas_confirmadas + 1 where id = new.para_id;
    return new;
  else
    update public.perfiles set ayudas_confirmadas = greatest(ayudas_confirmadas - 1, 0) where id = old.para_id;
    return old;
  end if;
end $$;
drop trigger if exists agradecimientos_contar on public.agradecimientos;
create trigger agradecimientos_contar after insert or delete on public.agradecimientos
  for each row execute function public.contar_agradecimiento();

alter table public.agradecimientos enable row level security;
drop policy if exists agr_select on public.agradecimientos;
create policy agr_select on public.agradecimientos for select using (true);
-- Solo el autor de la publicación agradece, y solo a quien respondió.
drop policy if exists agr_insert on public.agradecimientos;
create policy agr_insert on public.agradecimientos for insert to authenticated
  with check (
    de_id = auth.uid()
    and para_id <> auth.uid()
    and exists (select 1 from public.publicaciones p
                where p.id = publicacion_id and p.autor_id = auth.uid())
    and exists (select 1 from public.ayudas a
                where a.publicacion_id = agradecimientos.publicacion_id and a.vecino_id = para_id)
  );
drop policy if exists agr_delete on public.agradecimientos;
create policy agr_delete on public.agradecimientos for delete to authenticated
  using (de_id = auth.uid());

insert into public.migraciones (version, nombre) values
  ('0001','Base'),('0002','Coordinación'),('0003','Confianza'),('0004','Red de Solidaridad')
  on conflict do nothing;
insert into public.migraciones (version, nombre)
  values ('0005', 'Reconocimiento: agradecimientos y ayudas confirmadas') on conflict do nothing;
