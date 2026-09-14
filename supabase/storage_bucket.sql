-- ============================================================
-- Bucket 'option-images' para upload de fotos das opções
-- Público pra leitura (URLs diretas), upload/delete só autenticado
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('option-images', 'option-images', true, 5242880, array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update set public = true, file_size_limit = 5242880;

-- Policies em storage.objects
-- SELECT: qualquer um pode ler (bucket é público)
drop policy if exists "option-images public read" on storage.objects;
create policy "option-images public read"
  on storage.objects for select
  using (bucket_id = 'option-images');

-- INSERT: user autenticado, arquivo sob path do próprio user_id
drop policy if exists "option-images user upload" on storage.objects;
create policy "option-images user upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'option-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELETE: só o dono do arquivo pode apagar
drop policy if exists "option-images user delete" on storage.objects;
create policy "option-images user delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'option-images' and owner = auth.uid());
