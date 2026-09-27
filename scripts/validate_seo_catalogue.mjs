import {URL} from 'node:url';

const SUPABASE_URL = (process.env.SUPABASE_URL || '').replace(/\/$/, '');
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || '';
if (!SUPABASE_URL || !SUPABASE_ANON_KEY) throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY are required.');

const headers = { apikey: SUPABASE_ANON_KEY };
async function api(table, params) {
  const u = new URL(SUPABASE_URL + '/rest/v1/' + table);
  for (const [k,v] of Object.entries(params)) u.searchParams.set(k,v);
  const r = await fetch(u,{headers});
  if (!r.ok) throw new Error('Supabase REST ' + table + ' failed: ' + r.status + ' ' + await r.text());
  return r.json();
}
const products = await api('products',{select:'id,slug,name,category_id,is_active,deleted_at',is_active:'eq.true',deleted_at:'is.null',limit:'1000'});
const variants = await api('product_variants',{select:'id,product_id,sku,price,is_active',is_active:'eq.true',limit:'5000'});
const images = await api('product_images',{select:'id,product_id,storage_path',limit:'10000'});
const categories = await api('categories',{select:'id,slug,name,is_active,deleted_at',is_active:'eq.true',deleted_at:'is.null',limit:'1000'});

const errors = [];
const ids = new Set(products.map(p=>p.id));
const catIds = new Set(categories.map(c=>c.id));
const slugSeen = new Map();
for (const p of products) {
  if (!p.id || !p.name || !String(p.name).trim()) errors.push('Active product missing name: '+p.id);
  if (!p.slug || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(p.slug)) errors.push('Invalid active product slug: '+p.id+' '+p.slug);
  if (slugSeen.has(p.slug)) errors.push('Duplicate active product slug: '+p.slug);
  slugSeen.set(p.slug,p.id);
  if (!p.category_id || !catIds.has(p.category_id)) errors.push('Active product missing active category: '+p.id);
}
const skuSeen = new Set();
for (const v of variants) {
  if (!ids.has(v.product_id)) errors.push('Active variant points to missing/inactive product: '+v.id);
  if (!v.sku || !String(v.sku).trim()) errors.push('Active variant missing SKU: '+v.id);
  if (skuSeen.has(v.sku)) errors.push('Duplicate active SKU: '+v.sku);
  skuSeen.add(v.sku);
  if (v.price === null || Number.isNaN(Number(v.price)) || Number(v.price) < 0) errors.push('Invalid active variant price: '+v.id);
}
for (const i of images) {
  if (!ids.has(i.product_id)) errors.push('Image points to missing/inactive product: '+i.id);
  if (!i.storage_path || String(i.storage_path).includes('..') || String(i.storage_path).startsWith('/')) errors.push('Invalid image storage path: '+i.id);
}
if (errors.length) {
  console.error('SEO CATALOGUE GATE FAILED');
  errors.forEach(e=>console.error('- '+e));
  process.exit(1);
}
console.log('SEO catalogue gate passed: '+products.length+' active products, '+variants.length+' active variants, '+images.length+' images, '+categories.length+' active categories.');
