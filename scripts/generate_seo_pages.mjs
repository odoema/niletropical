import fs from 'node:fs/promises';
import path from 'node:path';

const base = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const anon = process.env.SUPABASE_ANON_KEY || '';
const site = 'https://niletropicaluganda.com';

if (!base || !anon) throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY are required.');

const headers = { apikey: anon, Authorization: 'Bearer ' + anon };

async function api(table, query) {
  const r = await fetch(base + '/rest/v1/' + table + '?' + query, { headers });
  if (!r.ok) throw new Error(table + ': ' + r.status + ' ' + await r.text());
  return r.json();
}

function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
function json(value) {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}
function strip(value) {
  return String(value ?? '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}
function productImage(row) {
  const p = row.storage_path || row.url || '';
  if (!p) return '';
  if (/^https?:\/\//i.test(p)) return p;
  return base + '/storage/v1/object/public/product-images/' + p.split('/').map(encodeURIComponent).join('/');
}
function money(n) {
  return new Intl.NumberFormat('en-UG', { maximumFractionDigits: 0 }).format(Number(n || 0));
}

function categoryPage(category, products) {
  const canonical = site + '/categories/' + encodeURIComponent(category.slug) + '/';
  const items = products.map(p => {
    const img = (p.product_images || []).map(productImage).find(Boolean);
    const price = (p.product_variants || []).filter(v => v.is_active !== false)[0]?.price;
    return '<article><a href="' + site + '/products/' + encodeURIComponent(p.slug) + '/">' +
      (img ? '<img src="' + esc(img) + '" alt="' + esc(p.name) + '" loading="lazy">' : '') +
      '<h2>' + esc(p.name) + '</h2>' +
      '<p>' + esc(strip(p.short_description || 'Shop ' + p.name + ' from Nile Tropical Uganda.')) + '</p>' +
      (price != null ? '<strong>UGX ' + money(price) + '</strong>' : '') +
      '</a></article>';
  }).join('');
  const schema = {'@context':'https://schema.org','@type':'CollectionPage','name':category.name + ' | Nile Tropical Uganda','url':canonical,'isPartOf':{'@id':site+'/#website'}};
  return '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' + esc(category.name) + ' | Nile Tropical Uganda</title><meta name="description" content="' + esc(strip(category.description || ('Shop ' + category.name + ' from Nile Tropical Industries in Uganda.')).slice(0,155)) + '"><meta name="robots" content="index,follow,max-image-preview:large"><link rel="canonical" href="' + esc(canonical) + '">' +
    '<style>body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f7f9fa;color:#17212b}.wrap{width:min(1100px,calc(100% - 28px));margin:auto}.top{background:#233e85;color:#fff;padding:11px 0}.nav{display:flex;justify-content:space-between;padding:18px 0}.btn{background:#233e85;color:#fff;padding:11px 16px;border-radius:12px;font-weight:800;text-decoration:none}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;padding:25px 0 50px}article{background:#fff;border:1px solid #dfe5e9;border-radius:16px;overflow:hidden}article a{display:block;padding-bottom:18px;text-decoration:none;color:inherit}article img{width:100%;aspect-ratio:1;object-fit:contain;background:#f1f4f7}article h2,article p,article strong{margin-left:17px;margin-right:17px}article h2{color:#003d70;font-size:19px;margin-top:15px;margin-bottom:7px}article p{color:#66717c;font-size:13px;line-height:1.55}article strong{color:#233e85}@media(max-width:800px){.grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:520px){.grid{grid-template-columns:1fr}}</style></head><body><div class="top"><div class="wrap">Nile Tropical Industries (U) Ltd · Nebbi, West Nile, Uganda</div></div><div class="wrap"><div class="nav"><strong style="color:#233e85">NILE TROPICAL</strong><a class="btn" href="' + site + '/app/">Shop online</a></div><main><h1>' + esc(category.name) + '</h1><p>' + esc(strip(category.description || 'Explore products from Nile Tropical Industries in Uganda.')) + '</p><div class="grid">' + items + '</div></main></div><script type="application/ld+json">' + json(schema) + '</script></body></html>';
}

function productPage(product) {
  const slug = product.slug;
  const canonical = site + '/products/' + encodeURIComponent(slug) + '/';
  const variants = (product.product_variants || []).filter(v => v.is_active !== false);
  const images = (product.product_images || []).map(productImage).filter(Boolean);
  const first = variants[0];
  const inStock = variants.some(v => Number(v.stock_quantity || 0) > 0);
  const price = first ? Number(first.price) : null;
  const description = strip(product.short_description || product.full_description || ('Shop ' + product.name + ' from Nile Tropical Industries in Uganda.'));
  const long = strip(product.full_description || product.short_description || '');
  const benefits = strip(product.benefits || '');
  const how = strip(product.how_to_use || '');
  const ingredients = strip(product.ingredients || '');
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Product',
    name: product.name,
    description,
    sku: first?.sku || product.id,
    brand: { '@type': 'Brand', name: product.brand || 'Nile Tropical' },
    image: images,
    offers: first && price != null ? {
      '@type': 'Offer',
      url: canonical,
      priceCurrency: 'UGX',
      price: price.toFixed(0),
      availability: inStock ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
      seller: { '@type': 'Organization', name: 'Nile Tropical Industries (U) Ltd', url: site + '/' }
    } : undefined
  };
  const variantHtml = variants.length
    ? '<div class="variants"><h2>Available sizes and prices</h2><div class="variant-grid">' +
      variants.map(v => '<div class="variant"><strong>' + esc(v.name || v.sku || 'Size') + '</strong><span>UGX ' + money(v.price) + '</span><small>' +
        (Number(v.stock_quantity || 0) > 0 ? 'In stock' : 'Currently unavailable') + '</small></div>').join('') +
      '</div></div>'
    : '';
  const sections = [
    long && '<section><h2>About ' + esc(product.name) + '</h2><p>' + esc(long) + '</p></section>',
    benefits && '<section><h2>Benefits</h2><p>' + esc(benefits) + '</p></section>',
    how && '<section><h2>How to use</h2><p>' + esc(how) + '</p></section>',
    ingredients && '<section><h2>Ingredients</h2><p>' + esc(ingredients) + '</p></section>'
  ].filter(Boolean).join('');
  const gallery = images.slice(0, 6).map((src, i) => '<img src="' + esc(src) + '" alt="' + esc(product.name + ' - Nile Tropical Uganda') + '" loading="' + (i ? 'lazy' : 'eager') + '">').join('');
  return '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>' + esc(product.name) + ' | Nile Tropical Uganda</title>' +
    '<meta name="description" content="' + esc(description.slice(0, 155)) + '">' +
    '<meta name="robots" content="index,follow,max-image-preview:large">' +
    '<link rel="canonical" href="' + esc(canonical) + '">' +
    '<meta property="og:type" content="product"><meta property="og:site_name" content="Nile Tropical Industries Ltd">' +
    '<meta property="og:title" content="' + esc(product.name + ' | Nile Tropical Uganda') + '">' +
    '<meta property="og:description" content="' + esc(description.slice(0, 200)) + '">' +
    (images[0] ? '<meta property="og:image" content="' + esc(images[0]) + '">' : '') +
    '<style>body{margin:0;font-family:Arial,Helvetica,sans-serif;color:#17212b;background:#f7f9fa}a{color:inherit;text-decoration:none}.wrap{width:min(1060px,calc(100% - 28px));margin:auto}.top{background:#233e85;color:#fff;padding:10px 0;font-size:12px}.nav{display:flex;justify-content:space-between;align-items:center;padding:18px 0}.brand{font-weight:800;color:#233e85}.btn{display:inline-flex;padding:12px 17px;border-radius:12px;background:#233e85;color:#fff;font-weight:800}.hero{background:#fff;border-radius:20px;padding:28px;margin:18px 0;display:grid;grid-template-columns:1fr 1fr;gap:28px}.gallery{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}.gallery img{width:100%;aspect-ratio:1;object-fit:contain;background:#f1f4f7;border-radius:14px}.hero h1{font-size:clamp(32px,5vw,52px);line-height:1.05;color:#003d70;margin:0 0 14px}.desc{color:#66717c;font-size:17px;line-height:1.7}.price{font-size:25px;font-weight:800;color:#233e85;margin:20px 0}.variants{margin-top:24px}.variant-grid{display:flex;flex-wrap:wrap;gap:10px}.variant{border:1px solid #dfe5e9;border-radius:12px;padding:12px 14px;background:#fff;min-width:120px}.variant span,.variant small{display:block}.variant span{color:#233e85;font-weight:800;margin-top:4px}.variant small{color:#66717c;margin-top:3px}section{background:#fff;border-radius:16px;padding:24px;margin:14px 0}section h2{color:#003d70;margin-top:0}footer{margin-top:35px;background:#002e54;color:#dbe7ee;padding:30px 0}@media(max-width:720px){.hero{grid-template-columns:1fr;padding:20px}.gallery{grid-template-columns:repeat(2,1fr)}} </style></head><body>' +
    '<div class="top"><div class="wrap">Nile Tropical Industries (U) Ltd · Nebbi, West Nile, Uganda</div></div>' +
    '<div class="wrap"><div class="nav"><a class="brand" href="' + site + '/">NILE TROPICAL</a><a class="btn" href="' + site + '/app/">Shop online</a></div>' +
    '<main><div class="hero"><div class="gallery">' + gallery + '</div><div><p style="color:#08783d;font-weight:800;text-transform:uppercase;letter-spacing:.08em">Nile Tropical product</p><h1>' + esc(product.name) + '</h1><p class="desc">' + esc(description) + '</p>' +
    (price != null ? '<div class="price">From UGX ' + money(price) + '</div>' : '') +
    '<a class="btn" href="' + site + '/app/#/product/' + encodeURIComponent(slug) + '">View and order online</a>' + variantHtml + '</div></div>' + sections + '</main></div>' +
    '<footer><div class="wrap">Nile Tropical Industries (U) Ltd · Nebbi Municipality, Uganda · <a href="' + site + '/">Official website</a></div></footer>' +
    '<script type="application/ld+json">' + json(schema) + '</script></body></html>';
}

const [products, categories] = await Promise.all([
  api('products', new URLSearchParams({
    select: 'id,name,slug,short_description,full_description,benefits,how_to_use,ingredients,brand,is_active,deleted_at,created_at,product_variants(*),product_images(*)',
    is_active: 'eq.true', deleted_at: 'is.null', order: 'created_at.desc'
  }).toString()),
  api('categories', new URLSearchParams({ select: 'id,name,slug,description,is_active,sort_order', is_active: 'eq.true', order: 'sort_order' }).toString())
]);

const out = path.resolve('build/site');
await fs.mkdir(out, { recursive: true });
for (const category of categories) {
  if (!category.slug) continue;
  const categoryProducts = products.filter(p => p.category_id === category.id);
  const dir = path.join(out, 'categories', category.slug);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'index.html'), categoryPage(category, categoryProducts), 'utf8');
}

for (const p of products) {
  if (!p.slug) continue;
  const dir = path.join(out, 'products', p.slug);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'index.html'), productPage(p), 'utf8');
}

const urls = [
  { loc: site + '/', priority: '1.0', changefreq: 'weekly' },
  { loc: site + '/app/', priority: '0.9', changefreq: 'weekly' },
  ...categories.filter(c => c.slug).map(c => ({ loc: site + '/categories/' + encodeURIComponent(c.slug) + '/', priority: '0.7', changefreq: 'weekly' })),
  ...products.filter(p => p.slug).map(p => ({ loc: site + '/products/' + encodeURIComponent(p.slug) + '/', priority: '0.8', changefreq: 'weekly' }))
];
const xml = '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' +
  urls.map(u => '<url><loc>' + esc(u.loc) + '</loc><changefreq>' + u.changefreq + '</changefreq><priority>' + u.priority + '</priority></url>').join('') +
  '</urlset>';
await fs.writeFile(path.join(out, 'sitemap.xml'), xml, 'utf8');
await fs.writeFile(path.join(out, 'robots.txt'), 'User-agent: *\nAllow: /\nSitemap: ' + site + '/sitemap.xml\n', 'utf8');
console.log('Generated ' + products.length + ' product SEO pages and ' + urls.length + ' sitemap URLs.');
