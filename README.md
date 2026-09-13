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

## Próximos passos

- [ ] Migrar de localStorage para Supabase (Postgres + Auth + Realtime)
- [ ] Deploy no Vercel
- [ ] Convite de colaboradores por email
- [ ] Notificações de mudanças
