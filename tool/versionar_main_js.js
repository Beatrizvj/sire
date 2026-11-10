// Predeploy de Hosting: renombra build/web/main.dart.js a main.<hash>.dart.js y
// actualiza flutter_bootstrap.js. El nombre cambia solo cuando cambia el código,
// así el navegador puede guardarlo en caché y no lo descarga en cada visita.
// Firebase lo ejecuta una vez por cada target, por eso es idempotente.
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const web = path.join(__dirname, '..', 'build', 'web');
const original = path.join(web, 'main.dart.js');
const bootstrap = path.join(web, 'flutter_bootstrap.js');

const contenido = fs.readFileSync(bootstrap, 'utf8');

if (!fs.existsSync(original)) {
  if (/"mainJsPath":"main\.[0-9a-f]+\.dart\.js"/.test(contenido)) {
    console.log('main.dart.js ya está versionado.');
    process.exit(0);
  }
  throw new Error('No existe build/web/main.dart.js. Ejecuta primero: flutter build web');
}

const clave = '"mainJsPath":"main.dart.js"';
if (!contenido.includes(clave)) {
  throw new Error(`flutter_bootstrap.js no contiene ${clave}`);
}

const hash = crypto.createHash('sha256').update(fs.readFileSync(original)).digest('hex').slice(0, 12);
const nombre = `main.${hash}.dart.js`;

// Quita versiones de builds anteriores para no publicarlas de nuevo.
for (const archivo of fs.readdirSync(web)) {
  if (/^main\.[0-9a-f]+\.dart\.js$/.test(archivo)) fs.unlinkSync(path.join(web, archivo));
}

fs.renameSync(original, path.join(web, nombre));
fs.writeFileSync(bootstrap, contenido.replace(clave, `"mainJsPath":"${nombre}"`));
console.log(`main.dart.js -> ${nombre}`);
