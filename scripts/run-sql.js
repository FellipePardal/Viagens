/**
 * Executa arquivos SQL contra o banco Postgres do Supabase.
 * Uso: node scripts/run-sql.js supabase/schema.sql supabase/policies.sql supabase/realtime.sql
 * Requer DATABASE_URL em .env.local
 */
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env.local') });

const { Client } = require('pg');

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('Uso: node scripts/run-sql.js <arquivo1.sql> [arquivo2.sql] ...');
  process.exit(1);
}

if (!process.env.DATABASE_URL) {
  console.error('ERRO: DATABASE_URL não definido em .env.local');
  console.error('Copie do Supabase: Settings → Database → Connection String (Session pooler)');
  process.exit(1);
}

async function main() {
  const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
  });

  try {
    console.log('Conectando ao Supabase Postgres...');
    await client.connect();
    console.log('OK — conectado\n');

    // Captura NOTICE do plpgsql
    client.on('notice', (msg) => {
      console.log(`  📢 ${msg.message}`);
    });

    for (const rel of files) {
      const filePath = path.resolve(rel);
      const name = path.basename(filePath);
      const sql = fs.readFileSync(filePath, 'utf-8');
      console.log(`▶ Rodando ${name} (${sql.length} chars)...`);
      const t0 = Date.now();
      try {
        const res = await client.query(sql);
        console.log(`  ✓ OK em ${Date.now() - t0}ms`);
        // Se houver linhas retornadas, printa
        const arr = Array.isArray(res) ? res : [res];
        for (const r of arr) {
          if (r && r.rows && r.rows.length > 0) {
            console.table(r.rows);
          }
        }
        console.log('');
      } catch (e) {
        console.error(`  ✗ ERRO em ${name}:`);
        console.error(`    ${e.message}`);
        if (e.hint) console.error(`    Hint: ${e.hint}`);
        if (e.position) console.error(`    Posição: caractere ${e.position}`);
        throw e;
      }
    }

    console.log('✓ Todos os SQLs executados com sucesso.');
  } finally {
    await client.end();
  }
}

main().catch((e) => { process.exit(1); });
