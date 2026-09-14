import Link from 'next/link';
import { createClient } from '../../../apps/web/lib/supabase/server';

export default async function FrequentPurchasesPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return <main><Link href="/">← Back to shop</Link><p>Sign in to see your frequent purchases.</p></main>;
  const { data, error } = await supabase
    .from('product_purchase_stats')
    .select('total_purchases, products(name, unit, selling_price_paise)')
    .eq('user_id', user.id)
    .order('total_purchases', { ascending: false });
  return <main><Link href="/">← Back to shop</Link><h1>Your frequent purchases</h1>{error ? <p role="alert">Unable to load purchases: {error.message}</p> : <ul>{(data ?? []).map((item: any) => <li key={item.products?.name}>{item.products?.name} — bought {item.total_purchases} times</li>)}</ul>}</main>;
}
