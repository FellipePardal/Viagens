/**
 * Build script — compila JSX de src.html para index.html
 * Uso: node build.js
 */
const fs = require('fs');
const path = require('path');
const Babel = require('@babel/standalone');

const SRC_FILE  = path.join(__dirname, 'src.html');
const DEST_FILE = path.join(__dirname, 'index.html');

const html = fs.readFileSync(SRC_FILE, 'utf-8');

const scriptRegex = /<script type="text\/babel" data-presets="react">([\s\S]*?)<\/script>/;
const match = html.match(scriptRegex);
if (!match) {
  console.error('Bloco <script type="text/babel"> não encontrado em src.html');
  process.exit(1);
}

const src = match[1];
console.log('Source JSX:', src.length, 'chars,', src.split('\n').length, 'linhas');

let compiled;
try {
  compiled = Babel.transform(src, { presets: [['react', { runtime: 'classic' }]] }).code;
  console.log('Compilado:  ', compiled.length, 'chars');
} catch (e) {
  console.error('Compile error:', e.message);
  process.exit(1);
}

let out = html.replace(scriptRegex, () => `<script>\n${compiled}\n</script>`);
out = out.replace(/<script src="https:\/\/unpkg\.com\/@babel\/standalone\/babel\.min\.js"><\/script>\n?/, '');

fs.writeFileSync(DEST_FILE, out, 'utf-8');
console.log('OK — index.html atualizado');
