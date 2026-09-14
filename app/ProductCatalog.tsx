'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { createClient } from '../apps/web/lib/supabase/client';
import { useRealtimeCart } from '../apps/web/hooks/useRealtimeCart';

export type StoreProduct = {
  id: string;
  name: string;
  slug: string;
  unit: string;
  pack_size: string | null;
  selling_price_paise: number;
  mrp_paise: number;
  delivery_eta_minutes: number | null;
  brands: { name: string } | null;
};

function formatPrice(paise: number) {
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(paise / 100);
}

export default function ProductCatalog({ products }: { products: StoreProduct[] }) {
  const [query, setQuery] = useState('');
  const [message, setMessage] = useState<string | null>(null);
  const [addingId, setAddingId] = useState<string | null>(null);
  const [cartId, setCartId] = useState<string | null>(null);
  const { items, status: cartStatus } = useRealtimeCart(cartId);
  const visibleProducts = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    return normalized ? products.filter((product) => `${product.name} ${product.brands?.name ?? ''}`.toLowerCase().includes(normalized)) : products;
  }, [products, query]);

  async function addToCart(productId: string) {
    setAddingId(productId);
    setMessage(null);
    try {
      const supabase = createClient();
      const { data: { user }, error: userError } = await supabase.auth.getUser();
      if (userError) throw userError;
      if (!user) throw new Error('Please sign in before adding items to your cart.');
      const { data: existingCart, error: cartError } = await supabase.from('carts').select('id').eq('owner_id', user.id).eq('status', 'active').order('updated_at', { ascending: false }).limit(1).maybeSingle();
      if (cartError) throw cartError;
      let cartId = existingCart?.id;
      if (!cartId) {
        const { data: newCart, error: createError } = await supabase.from('carts').insert({ owner_id: user.id, name: 'My Cart' }).select('id').single();
        if (createError) throw createError;
        cartId = newCart.id;
      }
      setCartId(cartId);
      const { data, error } = await supabase.rpc('add_or_merge_cart_item', { p_cart_id: cartId, p_product_id: productId, p_quantity: 1, p_merge_mode: 'merge' });
      if (error) throw error;
      setMessage(data?.action === 'merged' ? 'Quantity updated in your cart.' : 'Added to your cart.');
    } catch (error) {
      setMessage(error instanceof Error ? error.message : 'Could not add this item to the cart.');
    } finally {
      setAddingId(null);
    }
  }

  return (
    <section>
      <label htmlFor="product-search">Search groceries</label>
      <input id="product-search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Milk, atta, paneer..." />
      {message && <p role="status">{message}{message.startsWith('Please sign in') && <> <Link href="/sign-in">Sign in</Link></>}</p>}
      {cartId && <p aria-live="polite">Cart: {items.reduce((total, item) => total + item.quantity, 0)} item(s) · sync {cartStatus}</p>}
      <div>
        {visibleProducts.map((product) => <article key={product.id}><p>{product.brands?.name ?? 'InstaDaily'}</p><h2>{product.name}</h2><p>{product.pack_size ?? product.unit} · {product.delivery_eta_minutes ?? 10} min</p><p><strong>{formatPrice(product.selling_price_paise)}</strong>{product.mrp_paise > product.selling_price_paise && <> <s>{formatPrice(product.mrp_paise)}</s></>}</p><button type="button" onClick={() => addToCart(product.id)} disabled={addingId === product.id}>{addingId === product.id ? 'Adding…' : 'Add'}</button></article>)}
      </div>
      {visibleProducts.length === 0 && <p>No products match your search.</p>}
    </section>
  );
}
