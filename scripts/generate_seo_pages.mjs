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

function seoTitle(name) {
  const raw = strip(name);
  const suffix = ' | Nile Tropical Uganda';
  const max = 60;
  if ((raw + suffix).length <= max) return raw + suffix;
  const room = Math.max(20, max - suffix.length - 3);
  return raw.slice(0, room).replace(/\s+\S*$/, '').trim() + '...' + suffix;
}

function metaDescription(value, fallback) {
  const raw = strip(value || fallback);
  if (raw.length <= 155) return raw;
  return raw.slice(0, 152).replace(/\s+\S*$/, '').trim() + '...';
}

function imageAlt(product, image) {
  const stored = strip(image.alt_text || '');
  return stored || (product.name + ' - Nile Tropical Uganda');
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
function xml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
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
  const itemList = products.filter(p => p.slug).map((p, i) => ({
    '@type':'ListItem',
    position:i + 1,
    url:site + '/products/' + encodeURIComponent(p.slug) + '/',
    name:p.name
  }));
  const schema = {
    '@context':'https://schema.org',
    '@graph':[
      {'@type':'CollectionPage','@id':canonical+'#page','name':category.name + ' | Nile Tropical Uganda','url':canonical,'isPartOf':{'@id':site+'/#website'},'mainEntity':{'@type':'ItemList','itemListElement':itemList}},
      {'@type':'BreadcrumbList','itemListElement':[
        {'@type':'ListItem','position':1,'name':'Home','item':site+'/'},
        {'@type':'ListItem','position':2,'name':category.name,'item':canonical}
      ]}
    ]
  };
  return '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' + esc(seoTitle(category.name)) + '</title><meta name="description" content="' + esc(metaDescription(category.description, 'Shop ' + category.name + ' from Nile Tropical Industries in Uganda.')) + '"><meta name="robots" content="index,follow,max-image-preview:large"><link rel="canonical" href="' + esc(canonical) + '">' +
    '<style>body{margin:0;font-family:Arial,Helvetica,sans-serif;background:#f7f9fa;color:#17212b}.wrap{width:min(1100px,calc(100% - 28px));margin:auto}.top{background:#233e85;color:#fff;padding:11px 0}.nav{display:flex;justify-content:space-between;padding:18px 0}.btn{background:#233e85;color:#fff;padding:11px 16px;border-radius:12px;font-weight:800;text-decoration:none}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;padding:25px 0 50px}article{background:#fff;border:1px solid #dfe5e9;border-radius:16px;overflow:hidden}article a{display:block;padding-bottom:18px;text-decoration:none;color:inherit}article img{width:100%;aspect-ratio:1;object-fit:contain;background:#f1f4f7}article h2,article p,article strong{margin-left:17px;margin-right:17px}article h2{color:#003d70;font-size:19px;margin-top:15px;margin-bottom:7px}article p{color:#66717c;font-size:13px;line-height:1.55}article strong{color:#233e85}@media(max-width:800px){.grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:520px){.grid{grid-template-columns:1fr}}</style></head><body><div class="top"><div class="wrap">Nile Tropical Industries (U) Ltd · Nebbi, West Nile, Uganda</div></div><div class="wrap"><div class="nav"><strong style="color:#233e85">NILE TROPICAL</strong><a class="btn" href="' + site + '/app/">Shop online</a></div><main><nav aria-label="Breadcrumb"><a href="' + site + '/">Home</a> / <span>' + esc(category.name) + '</span></nav><h1>' + esc(category.name) + '</h1><p>' + esc(strip(category.description || 'Explore products from Nile Tropical Industries in Uganda.')) + '</p><div class="grid">' + items + '</div></main></div><script type="application/ld+json">' + json(schema) + '</script></body></html>';
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
  const categoryName = product.category_name || '';
  const categorySlug = product.category_slug || '';
  const categoryUrl = categorySlug ? site + '/categories/' + encodeURIComponent(categorySlug) + '/' : '';
  const variantSchemas = variants.map(v => {
    const variantInStock = Number(v.stock_quantity || 0) > 0;
    const variantPrice = Number(v.price);
    return {
      '@type': 'Product',
      '@id': canonical + '#variant-' + (v.id || v.sku),
      name: v.name ? product.name + ' - ' + v.name : product.name,
      description,
      sku: v.sku || v.id || product.id,
      brand: { '@type': 'Brand', name: product.brand || 'Nile Tropical' },
      category: categoryName || undefined,
      image: images,
      url: canonical,
      mainEntityOfPage: { '@id': canonical + '#page' },
      ...(product.updated_at ? { dateModified: new Date(product.updated_at).toISOString() } : {}),
      isVariantOf: { '@id': canonical + '#product-group' },
      offers: Number.isFinite(variantPrice) && variantPrice > 0 ? {
        '@type': 'Offer',
        url: canonical,
        priceCurrency: 'UGX',
        price: variantPrice.toFixed(0),
        availability: variantInStock ? 'https://schema.org/InStock' : 'https://schema.org/OutOfStock',
        seller: { '@type': 'Organization', name: 'Nile Tropical Industries (U) Ltd', url: site + '/' }
      } : undefined
    };
  });

  const productSchema = variants.length > 1 ? {
    '@type': 'ProductGroup',
    '@id': canonical + '#product-group',
    name: product.name,
    description,
    brand: { '@type': 'Brand', name: product.brand || 'Nile Tropical' },
    category: categoryName || undefined,
    url: canonical,
    mainEntityOfPage: { '@id': canonical + '#page' },
    ...(product.updated_at ? { dateModified: new Date(product.updated_at).toISOString() } : {}),
    image: images,
    variesBy: ['https://schema.org/size'],
    hasVariant: variantSchemas
  } : {
    ...variantSchemas[0],
    '@type': 'Product',
    '@id': canonical + '#product'
  };

  const relatedProducts = (product.related_products || []).filter(p => p.slug && p.id !== product.id).slice(0, 4);
  const relatedHtml = relatedProducts.length
    ? '<section><h2>Related products</h2><div class="related-grid">' +
      relatedProducts.map(p => {
        const img = (p.product_images || []).map(productImage).find(Boolean);
        return '<a class="related" href="' + site + '/products/' + encodeURIComponent(p.slug) + '/">' +
          (img ? '<img src="' + esc(img) + '" alt="' + esc(imageAlt(p, p.product_images?.find(i => productImage(i) === img) || {})) + '" loading="lazy">' : '') +
          '<strong>' + esc(p.name) + '</strong></a>';
      }).join('') +
      '</div></section>'
    : '';

  const schema = {
    '@context': 'https://schema.org',
    '@graph': [
      productSchema,
      ...(variants.length > 1 ? variantSchemas : []),
      {
        '@type':'WebPage',
        '@id':canonical + '#page',
        url:canonical,
        name:product.name,
        ...(product.updated_at ? { dateModified: new Date(product.updated_at).toISOString() } : {}),
        mainEntity:{'@id':canonical + (variants.length > 1 ? '#product-group' : '#product')}
      },
      {
        '@type':'BreadcrumbList',
        itemListElement:[
          {'@type':'ListItem','position':1,'name':'Home','item':site+'/'},
          ...(categoryName && categoryUrl ? [{'@type':'ListItem','position':2,'name':categoryName,'item':categoryUrl}] : []),
          {'@type':'ListItem','position':categoryName && categoryUrl ? 3 : 2,'name':product.name,'item':canonical}
        ]
      }
    ]
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
  const breadcrumbHtml = '<nav aria-label="Breadcrumb" style="font-size:13px;color:#66717c;margin-bottom:16px"><a href="' + site + '/">Home</a>' +
    (categoryName && categoryUrl ? ' / <a href="' + categoryUrl + '">' + esc(categoryName) + '</a>' : '') +
    ' / <span>' + esc(product.name) + '</span></nav>';
  const gallery = (product.product_images || []).map((img, i) => ({ src: productImage(img), alt: imageAlt(product, img), i })).filter(x => x.src).slice(0, 6).map(x => '<img src="' + esc(x.src) + '" alt="' + esc(x.alt) + '" loading="' + (x.i ? 'lazy' : 'eager') + '">').join('');
  return '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
    '<title>' + esc(seoTitle(product.name)) + '</title>' +
    '<meta name="description" content="' + esc(metaDescription(description, 'Shop ' + product.name + ' from Nile Tropical Uganda.')) + '">' +
    '<meta name="robots" content="index,follow,max-image-preview:large">' +
    '<link rel="canonical" href="' + esc(canonical) + '">' +
    '<meta property="og:type" content="product"><meta property="og:site_name" content="Nile Tropical Industries Ltd">' +
    '<meta property="og:title" content="' + esc(product.name + ' | Nile Tropical Uganda') + '">' +
    '<meta property="og:description" content="' + esc(metaDescription(description, 'Shop ' + product.name + ' from Nile Tropical Uganda.')) + '">' +
    '<meta property="og:url" content="' + esc(canonical) + '">' +
    '<meta property="og:locale" content="en_UG">' +
    '<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="' + esc(seoTitle(product.name)) + '"><meta name="twitter:description" content="' + esc(metaDescription(description, 'Shop ' + product.name + ' from Nile Tropical Uganda.')) + '">' +
    (images[0] ? '<meta property="og:image" content="' + esc(images[0]) + '">' : '') +
    '<style>body{margin:0;font-family:Arial,Helvetica,sans-serif;color:#17212b;background:#f7f9fa}a{color:inherit;text-decoration:none}.wrap{width:min(1060px,calc(100% - 28px));margin:auto}.top{background:#233e85;color:#fff;padding:10px 0;font-size:12px}.nav{display:flex;justify-content:space-between;align-items:center;padding:18px 0}.brand{font-weight:800;color:#233e85}.btn{display:inline-flex;padding:12px 17px;border-radius:12px;background:#233e85;color:#fff;font-weight:800}.hero{background:#fff;border-radius:20px;padding:28px;margin:18px 0;display:grid;grid-template-columns:1fr 1fr;gap:28px}.gallery{display:grid;grid-template-columns:repeat(2,1fr);gap:10px}.gallery img{width:100%;aspect-ratio:1;object-fit:contain;background:#f1f4f7;border-radius:14px}.hero h1{font-size:clamp(32px,5vw,52px);line-height:1.05;color:#003d70;margin:0 0 14px}.desc{color:#66717c;font-size:17px;line-height:1.7}.price{font-size:25px;font-weight:800;color:#233e85;margin:20px 0}.variants{margin-top:24px}.variant-grid{display:flex;flex-wrap:wrap;gap:10px}.variant{border:1px solid #dfe5e9;border-radius:12px;padding:12px 14px;background:#fff;min-width:120px}.variant span,.variant small{display:block}.variant span{color:#233e85;font-weight:800;margin-top:4px}.variant small{color:#66717c;margin-top:3px}section{background:#fff;border-radius:16px;padding:24px;margin:14px 0}section h2{color:#003d70;margin-top:0}footer{margin-top:35px;background:#002e54;color:#dbe7ee;padding:30px 0}.related-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.related{background:#fff;border:1px solid #dfe5e9;border-radius:14px;padding:10px;display:block}.related img{width:100%;aspect-ratio:1;object-fit:contain;background:#f1f4f7;border-radius:10px;margin-bottom:8px}.related strong{display:block;color:#003d70}@media(max-width:720px){.related-grid{grid-template-columns:repeat(2,1fr)}}@media(max-width:720px){.hero{grid-template-columns:1fr;padding:20px}.gallery{grid-template-columns:repeat(2,1fr)}} </style></head><body>' +
    '<div class="top"><div class="wrap">Nile Tropical Industries (U) Ltd · Nebbi, West Nile, Uganda</div></div>' +
    '<div class="wrap"><div class="nav"><a class="brand" href="' + site + '/">NILE TROPICAL</a><a class="btn" href="' + site + '/app/">Shop online</a></div>' +
    '<main>' + breadcrumbHtml + '<div class="hero"><div class="gallery">' + gallery + '</div><div><p style="color:#08783d;font-weight:800;text-transform:uppercase;letter-spacing:.08em">Nile Tropical product</p><h1>' + esc(product.name) + '</h1><p class="desc">' + esc(description) + '</p>' +
    (price != null ? '<div class="price">From UGX ' + money(price) + '</div>' : '') +
    '<a class="btn" href="' + site + '/app/#/product/' + encodeURIComponent(slug) + '">View and order online</a>' + variantHtml + '</div></div>' + sections + '</main></div>' +
    relatedHtml +
    '<footer><div class="wrap">Nile Tropical Industries (U) Ltd · Nebbi Municipality, Uganda · <a href="' + site + '/">Official website</a></div></footer>' +
    '<script type="application/ld+json">' + json(schema) + '</script></body></html>';
}

const [products, categories] = await Promise.all([
  api('products', new URLSearchParams({
    select: 'id,name,slug,category_id,short_description,full_description,benefits,how_to_use,ingredients,brand,is_active,deleted_at,created_at,updated_at,product_variants(*),product_images(*)',
    is_active: 'eq.true', deleted_at: 'is.null', order: 'created_at.desc'
  }).toString()),
  api('categories', new URLSearchParams({ select: 'id,name,slug,description,is_active,sort_order,updated_at', is_active: 'eq.true', order: 'sort_order' }).toString())
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

const categoryById = new Map(categories.map(c => [c.id, c]));
for (const p of products) {
  if (!p.slug) continue;
  const category = categoryById.get(p.category_id);
  p.category_name = category?.name || '';
  p.category_slug = category?.slug || '';
  p.related_products = products
    .filter(other => other.category_id === p.category_id && other.id !== p.id && other.slug)
    .slice(0, 4);
  const dir = path.join(out, 'products', p.slug);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'index.html'), productPage(p), 'utf8');
}

const urls = [
  { loc: site + '/', priority: '1.0', changefreq: 'weekly' },
  { loc: site + '/app/', priority: '0.9', changefreq: 'weekly' },
  ...categories.filter(c => c.slug).map(c => ({ loc: site + '/categories/' + encodeURIComponent(c.slug) + '/', priority: '0.7', changefreq: 'weekly', lastmod: c.updated_at })),
  ...products.filter(p => p.slug).map(p => ({ loc: site + '/products/' + encodeURIComponent(p.slug) + '/', priority: '0.8', changefreq: 'weekly', lastmod: p.updated_at || p.created_at }))
];
const xml = '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' +
  urls.map(u => '<url><loc>' + esc(u.loc) + '</loc>' + (u.lastmod ? '<lastmod>' + esc(new Date(u.lastmod).toISOString()) + '</lastmod>' : '') + '<changefreq>' + u.changefreq + '</changefreq><priority>' + u.priority + '</priority></url>').join('') +
  '</urlset>';
await fs.writeFile(path.join(out, 'sitemap.xml'), xml, 'utf8');

const feedItems = products.filter(p => p.slug).flatMap(p => {
  const activeVariants = (p.product_variants || []).filter(v => v.is_active !== false);
  const images = (p.product_images || []).map(productImage).filter(Boolean);
  if (!activeVariants.length || !images[0]) return [];

  const description = strip([
    p.short_description,
    p.full_description,
    p.benefits,
    p.how_to_use
  ].filter(Boolean).join(' ')).slice(0, 5000);

  return activeVariants
    .filter(v => Number(v.price) > 0)
    .map(variant => {
      const availability = Number(variant.stock_quantity || 0) > 0 ? 'in_stock' : 'out_of_stock';
      const title = variant.name ? p.name + ' - ' + variant.name : p.name;
      const lines = [
        '<item>',
        '<g:id>' + xml(variant.sku || variant.id || p.id) + '</g:id>',
        '<g:title>' + xml(title) + '</g:title>',
        '<g:description>' + xml(description || ('Shop ' + title + ' from Nile Tropical Uganda.')) + '</g:description>',
        '<g:link>' + xml(site + '/products/' + encodeURIComponent(p.slug) + '/') + '</g:link>',
        '<g:canonical_link>' + xml(site + '/products/' + encodeURIComponent(p.slug) + '/') + '</g:canonical_link>',
        '<g:image_link>' + xml(images[0]) + '</g:image_link>',
        ...images.slice(1, 11).map(src => '<g:additional_image_link>' + xml(src) + '</g:additional_image_link>'),
        '<g:availability>' + availability + '</g:availability>',
        '<g:condition>new</g:condition>',
        '<g:price>' + Number(variant.price).toFixed(2) + ' UGX</g:price>',
        '<g:brand>' + xml(p.brand || 'Nile Tropical') + '</g:brand>',
        '<g:item_group_id>' + xml(p.id) + '</g:item_group_id>',
        '</item>'
      ];
      return lines.join('');
    });
}).filter(Boolean).join('');
const merchantFeed = '<?xml version="1.0" encoding="UTF-8"?>' +
  '<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0"><channel>' +
  '<title>Nile Tropical Uganda Product Feed</title>' +
  '<link>' + xml(site + '/') + '</link>' +
  '<description>Products sold by Nile Tropical Industries (U) Ltd in Uganda.</description>' +
  feedItems +
  '</channel></rss>';
await fs.writeFile(path.join(out, 'merchant-feed.xml'), merchantFeed, 'utf8');
await fs.writeFile(path.join(out, 'robots.txt'), 'User-agent: *\nAllow: /\nSitemap: ' + site + '/sitemap.xml\n', 'utf8');
console.log('Generated ' + products.length + ' product SEO pages and ' + urls.length + ' sitemap URLs.');
