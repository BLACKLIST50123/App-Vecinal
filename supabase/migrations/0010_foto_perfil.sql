-- =====================================================================
-- 0010 · Foto de perfil
-- Cada vecino puede poner una foto (cámara o galería). La foto se guarda
-- en Supabase Storage (bucket público "avatares") y la URL en el perfil.
-- Se puede ejecutar varias veces sin error.
-- =====================================================================

-- 1. Columna con la URL pública de la foto.
alter table public.perfiles add column if not exists foto_url text;

-- Todos pueden ver la foto; solo el dueño la cambia (la política
-- perfiles_update ya limita la fila a id = auth.uid()).
grant select (foto_url) on public.perfiles to anon, authenticated;
grant update (foto_url) on public.perfiles to authenticated;

-- 2. Bucket público, máximo 2 MB y solo imágenes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatares', 'avatares', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 3. Cada vecino solo puede subir, cambiar o borrar archivos en su propia
--    carpeta: avatares/<su id>/...  (la lectura es pública por el bucket).
drop policy if exists avatares_select_propio on storage.objects;
create policy avatares_select_propio on storage.objects for select to authenticated
  using (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatares_insert_propio on storage.objects;
create policy avatares_insert_propio on storage.objects for insert to authenticated
  with check (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatares_update_propio on storage.objects;
create policy avatares_update_propio on storage.objects for update to authenticated
  using (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatares_delete_propio on storage.objects;
create policy avatares_delete_propio on storage.objects for delete to authenticated
  using (bucket_id = 'avatares' and (storage.foldername(name))[1] = auth.uid()::text);

-- 4. Registro de migración.
insert into public.migraciones (version, nombre)
values ('0010', 'foto_perfil')
on conflict (version) do nothing;
