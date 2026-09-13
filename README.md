# Passageiro

Planejador de viagens colaborativo. HTML autocontido — React + Tailwind + Leaflet via CDN, dados no `localStorage` (por enquanto).

## Rodar localmente

```bash
npm install
npm run dev
# abre http://localhost:8000
```

## Editar

O código-fonte está em [`src.html`](src.html). Depois de editar, rode:

```bash
npm run build
```

Isso gera o [`index.html`](index.html) com o JSX pré-compilado (que é o arquivo servido).

## Estrutura

```
Viagens/
├── src.html       # source com JSX (edite aqui)
├── index.html     # versão compilada (servida)
├── build.js       # compila src.html → index.html
├── serve.js       # dev server local
└── package.json
```

## Módulos

- Biblioteca de viagens (múltiplas, arquivar, duplicar)
- Wizard com templates (Uruguai, Praia, Cidade, Aventura, Mochilão)
- Dashboard com KPIs, orçamento vs teto, próximos dias, clima, câmbio
- Orçamento multi-moeda com categorias customizáveis
- Roteiro dia-a-dia com blocos híbridos
- Checklist por fase
- Mapa Leaflet com geocoding
- Comparador de cotações
- Split de despesas entre companheiros
- Diário livre

## Integrações

- Câmbio ao vivo: [open.er-api.com](https://open.er-api.com) (cache 4h)
- Clima: [Open-Meteo](https://open-meteo.com) (16 dias antes da viagem)
- Geocoding: [Nominatim/OpenStreetMap](https://nominatim.openstreetmap.org)
- Mapas: Leaflet + tiles CartoDB Voyager

## Deploy (Vercel)

O repositório está pronto pra deploy em [Vercel](https://vercel.com):

1. Em [vercel.com/new](https://vercel.com/new), importe este repo do GitHub
2. Framework preset: **Other**
3. Build & Output settings já vêm do `vercel.json`:
   - Build command: `npm run build`
   - Output directory: `.`
4. Nenhuma env var necessária (Supabase config está inline no HTML)
5. Deploy — em ~30s fica online

Depois do primeiro deploy, adicione a URL do Vercel nas [Redirect URLs do Supabase](https://supabase.com/dashboard/project/_/auth/url-configuration):

- **Site URL:** `https://SEU-PROJETO.vercel.app`
- **Redirect URLs:** `https://SEU-PROJETO.vercel.app/**`

## Próximos passos

- [x] Migrar de localStorage para Supabase (Postgres + Auth + Realtime)
- [x] Convite de colaboradores por email
- [ ] Deploy no Vercel (em andamento)
- [ ] Google OAuth (opcional — magic link cobre 100% hoje)
- [ ] Merge inteligente de edits concorrentes
