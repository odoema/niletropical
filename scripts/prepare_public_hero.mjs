// Nile Tropical public homepage hero resolver.
// Resolves the authoritative CMS hero at build time so the browser sees the real image URL
// in the initial HTML instead of waiting for a client-side Supabase request.
const fs = require('node:fs');

const supabaseUrl = String(process.env.SUPABASE_URL || '').replace(/\\/$/, '');
const anonKey = String(process.env.SUPABASE_ANON_KEY || '');
if (!supabaseUrl || !anonKey) throw new Error('Missing Supabase build configuration.');

const endpoint = supabaseUrl + '/rest/v1/website_media_slots?select=slot_key,storage_path,alt_text&slot_key=eq.hero&is_active=eq.true&limit=1';
const response = await fetch(endpoint, { headers: { apikey: anonKey } });
if (!response.ok) throw new Error('Hero CMS lookup failed: HTTP ' + response.status);
const rows = await response.json();
const hero = rows[0];
if (!hero || !hero.storage_path) throw new Error('No active hero image is configured in website_media_slots.');

const publicUrl = supabaseUrl + '/storage/v1/object/public/cms/' + String(hero.storage_path)
  .split('/').map(encodeURIComponent).join('/');
const alt = String(hero.alt_text || 'Nile Tropical Industries homepage')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

let html = fs.readFileSync('index.html', 'utf8');
if (!html.includes('__NILE_HERO_IMAGE_URL__')) throw new Error('Hero URL placeholder not found.');
html = html.replaceAll('__NILE_HERO_IMAGE_URL__', publicUrl).replaceAll('__NILE_HERO_ALT__', alt);
const preload = '<link rel="preload" as="image" href="' + publicUrl + '" fetchpriority="high">';
html = html.replace('</head>', preload + '\\n</head>');
fs.writeFileSync('index.html', html, 'utf8');
console.log('Hero resolved at build time:', publicUrl);
