# Setup do Supabase — passo a passo

## 1. Rodar SQL

Abra o **SQL Editor** do seu projeto: https://supabase.com/dashboard/project/_/sql

Cole e execute os arquivos **nesta ordem**:

1. [`schema.sql`](schema.sql) — cria tabelas, triggers e funções
2. [`policies.sql`](policies.sql) — Row Level Security (segurança por linha)
3. [`realtime.sql`](realtime.sql) — habilita atualizações em tempo real

Cada um roda em 1-2 segundos. Se aparecer sucesso, próximo.

## 2. Habilitar Magic Link (email)

Já vem ligado por padrão. Confirme em:

**Authentication → Providers → Email** — verifica que está enabled e que "Confirm email" está ON.

## 3. (Opcional) Habilitar Google OAuth

Depois, quando quiser. Guia oficial: https://supabase.com/docs/guides/auth/social-login/auth-google

## 4. Configurar URL de redirect

**Authentication → URL Configuration**:

- **Site URL:** `http://localhost:8000` (dev) — depois trocar para URL do Vercel
- **Redirect URLs:** adicionar `http://localhost:8000/**` e depois `https://SEU-PROJETO.vercel.app/**`

## 5. Verificar

Vai em **Table Editor** e confirma que aparecem as tabelas:
- profiles, trips, trip_members, categories, travelers, days, blocks, checklist_items, quotes, map_points, trip_invites

Se todas estão lá com o cadeado 🔒 (RLS ativado), passou.
