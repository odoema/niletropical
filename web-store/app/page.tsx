'use client';

import { useEffect, useMemo, useState } from 'react';
import { supabase } from '../lib/supabase';

type Product = {
  id: string;
  name: string;
  slug: string;
  description?: string | null;
  category_id?: string | null;
  product_variants?: Array<{ price?: number | null; is_active?: boolean | null }>;
  product_images?: Array<{ storage_path?: string | null; url?: string | null; is_main?: boolean | null; sort_order?: number | null }>;
};

type Category = {
  id: string;
  name: string;
  slug: string;
};

type CartItem = Product & { quantity: number };

const BUCKET = 'product-images';

function imageUrl(product: Product) {
  const images = [...(product.product_images ?? [])].sort((a, b) =>
    Number(Boolean(b.is_main)) - Number(Boolean(a.is_main)) || (a.sort_order ?? 0) - (b.sort_order ?? 0)
  );
  const path = images[0]?.url || images[0]?.storage_path;
  if (!path) return '';
  if (path.startsWith('http')) return path;
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  return base ? `${base}/storage/v1/object/public/${BUCKET}/${path}` : '';
}

function price(product: Product) {
  const variant = product.product_variants?.find((v) => v.is_active !== false) ?? product.product_variants?.[0];
  return Number(variant?.price ?? 0);
}

function money(value: number) {
  return new Intl.NumberFormat('en-UG', {
    style: 'currency',
    currency: 'UGX',
    maximumFractionDigits: 0,
  }).format(value);
}

export default function Storefront() {
  const [products, setProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [search, setSearch] = useState('');
  const [category, setCategory] = useState('all');
  const [cart, setCart] = useState<CartItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const saved = window.localStorage.getItem('nile-tropical-cart');
    if (saved) {
      try { setCart(JSON.parse(saved)); } catch {}
    }
  }, []);

  useEffect(() => {
    window.localStorage.setItem('nile-tropical-cart', JSON.stringify(cart));
  }, [cart]);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      setLoading(true);
      setError('');
      if (!supabase) {
        setError('Store configuration is missing.');
        setLoading(false);
        return;
      }

      const [productsResult, categoriesResult] = await Promise.all([
        supabase
          .from('products')
          .select('id,name,slug,description,category_id,product_variants(*),product_images(*)')
          .eq('is_active', true)
          .order('created_at', { ascending: false }),
        supabase.from('categories').select('id,name,slug').order('name'),
      ]);

      if (cancelled) return;
      if (productsResult.error) {
        setError(productsResult.error.message);
      } else {
        setProducts((productsResult.data ?? []) as Product[]);
      }
      if (!categoriesResult.error) {
        setCategories((categoriesResult.data ?? []) as Category[]);
      }
      setLoading(false);
    }
    load();
    return () => { cancelled = true; };
  }, []);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return products.filter((p) => {
      const matchesSearch = !q || p.name.toLowerCase().includes(q) || (p.description ?? '').toLowerCase().includes(q);
      const matchesCategory = category === 'all' || p.category_id === category;
      return matchesSearch && matchesCategory;
    });
  }, [products, search, category]);

  const cartCount = cart.reduce((sum, item) => sum + item.quantity, 0);

  function addToCart(product: Product) {
    setCart((current) => {
      const found = current.find((item) => item.id === product.id);
      if (found) return current.map((item) => item.id === product.id ? { ...item, quantity: item.quantity + 1 } : item);
      return [...current, { ...product, quantity: 1 }];
    });
  }

  return (
    <main>
      <header className="topbar">
        <a className="brand" href="#">
          <div className="brand-mark">NILE</div>
          <div><strong>Nile Tropical</strong><span>Industries (U) Ltd</span></div>
        </a>
        <nav>
          <a href="#shop">Shop</a>
          <a href="#about">About</a>
          <a href="#contact">Contact</a>
          <button className="cart-button" onClick={() => document.getElementById('cart')?.scrollIntoView({ behavior: 'smooth' })}>
            Cart <b>{cartCount}</b>
          </button>
        </nav>
      </header>

      <section className="hero">
        <div className="hero-copy">
          <span className="eyebrow">MADE IN UGANDA · NATURAL CARE</span>
          <h1>Everyday care, <em>naturally.</em></h1>
          <p>Discover Nile Tropical products for personal care, hygiene, sun care, soaps, lotions and botanical wellness.</p>
          <a className="primary" href="#shop">Shop products</a>
        </div>
        <div className="hero-card">
          <span>20</span>
          <small>products in our current catalogue</small>
          <div className="hero-line" />
          <span>7</span>
          <small>product categories</small>
        </div>
      </section>

      <section id="shop" className="shop-section">
        <div className="section-heading">
          <div>
            <span className="eyebrow">THE COLLECTION</span>
            <h2>Shop Nile Tropical</h2>
          </div>
          <div className="cart-summary">{cartCount} item{cartCount === 1 ? '' : 's'} in cart</div>
        </div>

        <div className="toolbar">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search products..."
            aria-label="Search products"
          />
          <select value={category} onChange={(e) => setCategory(e.target.value)} aria-label="Filter by category">
            <option value="all">All categories</option>
            {categories.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </div>

        {loading && <div className="state">Loading the Nile Tropical catalogue…</div>}
        {error && <div className="state error">{error}</div>}

        {!loading && !error && (
          <div className="product-grid">
            {filtered.map((product) => (
              <article className="product-card" key={product.id}>
                <div className="product-image">
                  {imageUrl(product)
                    ? <img src={imageUrl(product)} alt={product.name} loading="lazy" />
                    : <div className="image-fallback">NILE<br /><span>No image</span></div>}
                </div>
                <div className="product-info">
                  <h3>{product.name}</h3>
                  <strong>{money(price(product))}</strong>
                  <button onClick={() => addToCart(product)}>Add to cart</button>
                </div>
              </article>
            ))}
          </div>
        )}

        {!loading && !error && filtered.length === 0 && <div className="state">No products match your search.</div>}
      </section>

      <section id="cart" className="cart-section">
        <div>
          <span className="eyebrow">YOUR ORDER</span>
          <h2>Shopping cart</h2>
        </div>
        {cart.length === 0 ? (
          <p className="muted">Your cart is empty. Add products from the collection above.</p>
        ) : (
          <div className="cart-box">
            {cart.map((item) => (
              <div className="cart-row" key={item.id}>
                <div><strong>{item.name}</strong><span>{money(price(item))} × {item.quantity}</span></div>
                <button onClick={() => setCart((c) => c.filter((x) => x.id !== item.id))}>Remove</button>
              </div>
            ))}
            <div className="cart-total">
              <span>Total</span>
              <strong>{money(cart.reduce((sum, item) => sum + price(item) * item.quantity, 0))}</strong>
            </div>
            <a className="primary" href="#contact">Proceed to order</a>
          </div>
        )}
      </section>

      <section id="about" className="about-section">
        <span className="eyebrow">NILE TROPICAL INDUSTRIES</span>
        <h2>Rooted in Uganda. Made for everyday life.</h2>
        <p>We develop and distribute practical personal-care, hygiene and botanical products, with a focus on quality, accessibility and local enterprise.</p>
      </section>

      <footer id="contact">
        <div>
          <div className="brand"><div className="brand-mark">NILE</div><div><strong>Nile Tropical</strong><span>Industries (U) Ltd</span></div></div>
          <p>Plot 27 Abindu Road, Olyeko Cell, Abindu Division, Nebbi Municipality, Uganda.</p>
        </div>
        <div className="footer-contact">
          <strong>Contact</strong>
          <a href="tel:+256393001071">+256 393 001071</a>
          <a href="tel:+256700957796">+256 700 957796</a>
          <a href="tel:+256774103235">+256 774 103235</a>
          <a href="tel:+256775582283">+256 775 582283</a>
        </div>
      </footer>
    </main>
  );
}
