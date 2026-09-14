import Image from 'next/image';
import Link from 'next/link';
import { Flame, Clock3, ChefHat, ChevronRight } from 'lucide-react';
import { SearchBar } from '@/components/Shop/SearchBar';
import { ExpressModeToggle } from '@/components/Shop/ExpressModeToggle';
import { Container } from '@instadaily/ui/components/Container';
import { Section } from '@instadaily/ui/components/Section';
import ProductCatalog, { type StoreProduct } from './ProductCatalog';
import { createClient } from '../apps/web/lib/supabase/server';

interface Product {
  id: string;
  name: string;
  brand: string;
  unit: string;
  imageUrl: string | null;
  priceInPaise: number;
  mrpInPaise: number;
  deliveryEtaMinutes: number;
}

interface RecipeHighlight {
  id: string;
  title: string;
  description: string;
  imageUrl: string | null;
  ingredientCount: number;
  cookTimeMinutes: number;
}

const FREQUENT_PURCHASES: readonly Product[] = [
  {
    id: 'prod_amul_toned_milk_500ml',
    name: 'Amul Taaza Toned Milk',
    brand: 'Amul',
    unit: '500 ml',
    imageUrl: null,
    priceInPaise: 2900,
    mrpInPaise: 3000,
    deliveryEtaMinutes: 10,
  },
  {
    id: 'prod_aashirvaad_atta_5kg',
    name: 'Aashirvaad Select Sharbati Atta',
    brand: 'Aashirvaad',
    unit: '5 kg',
    imageUrl: null,
    priceInPaise: 32900,
    mrpInPaise: 35500,
    deliveryEtaMinutes: 12,
  },
  {
    id: 'prod_amul_butter_500g',
    name: 'Amul Pasteurised Butter',
    brand: 'Amul',
    unit: '500 g',
    imageUrl: null,
    priceInPaise: 27500,
    mrpInPaise: 28500,
    deliveryEtaMinutes: 10,
  },
  {
    id: 'prod_amul_curd_400g',
    name: 'Amul Fresh Curd',
    brand: 'Amul',
    unit: '400 g',
    imageUrl: null,
    priceInPaise: 3900,
    mrpInPaise: 4000,
    deliveryEtaMinutes: 9,
  },
];

const PRODUCT_FEED: readonly Product[] = [
  {
    id: 'prod_amul_gold_milk_1l',
    name: 'Amul Gold Full Cream Milk',
    brand: 'Amul',
    unit: '1 L',
    imageUrl: null,
    priceInPaise: 6900,
    mrpInPaise: 7200,
    deliveryEtaMinutes: 11,
  },
  {
    id: 'prod_aashirvaad_multigrain_atta_5kg',
    name: 'Aashirvaad Multigrain Atta',
    brand: 'Aashirvaad',
    unit: '5 kg',
    imageUrl: null,
    priceInPaise: 33900,
    mrpInPaise: 36900,
    deliveryEtaMinutes: 14,
  },
  {
    id: 'prod_amul_cheese_slices_200g',
    name: 'Amul Cheese Slices',
    brand: 'Amul',
    unit: '200 g, 10 slices',
    imageUrl: null,
    priceInPaise: 12900,
    mrpInPaise: 13500,
    deliveryEtaMinutes: 10,
  },
  {
    id: 'prod_amul_ghee_1l',
    name: 'Amul Pure Ghee',
    brand: 'Amul',
    unit: '1 L',
    imageUrl: null,
    priceInPaise: 62900,
    mrpInPaise: 65900,
    deliveryEtaMinutes: 13,
  },
  {
    id: 'prod_aashirvaad_salt_1kg',
    name: 'Aashirvaad Iodised Salt',
    brand: 'Aashirvaad',
    unit: '1 kg',
    imageUrl: null,
    priceInPaise: 2800,
    mrpInPaise: 3000,
    deliveryEtaMinutes: 9,
  },
  {
    id: 'prod_amul_paneer_200g',
    name: 'Amul Fresh Paneer',
    brand: 'Amul',
    unit: '200 g',
    imageUrl: null,
    priceInPaise: 9900,
    mrpInPaise: 10500,
    deliveryEtaMinutes: 10,
  },
  {
    id: 'prod_aashirvaad_besan_1kg',
    name: 'Aashirvaad Besan',
    brand: 'Aashirvaad',
    unit: '1 kg',
    imageUrl: null,
    priceInPaise: 11900,
    mrpInPaise: 12900,
    deliveryEtaMinutes: 12,
  },
  {
    id: 'prod_amul_lassi_200ml',
    name: 'Amul Masti Lassi',
    brand: 'Amul',
    unit: '200 ml',
    imageUrl: null,
    priceInPaise: 3500,
    mrpInPaise: 3500,
    deliveryEtaMinutes: 9,
  },
];

const CHEF_MODE_RECIPE: RecipeHighlight = {
  id: 'recipe_paneer_butter_masala',
  title: 'Paneer Butter Masala',
  description:
    'Restaurant-style paneer butter masala with Amul Paneer, Amul Butter, and pantry staples — all delivered together in one basket.',
  imageUrl: null,
  ingredientCount: 9,
  cookTimeMinutes: 35,
};

function formatIndianRupees(amountInPaise: number): string {
  const rupees = amountInPaise / 100;
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: rupees % 1 === 0 ? 0 : 2,
  }).format(rupees);
}

function calculateDiscountPercent(priceInPaise: number, mrpInPaise: number): number {
  if (mrpInPaise <= priceInPaise || mrpInPaise <= 0) {
    return 0;
  }
  return Math.round(((mrpInPaise - priceInPaise) / mrpInPaise) * 100);
}

interface ProductTileProps {
  product: Product;
}

function ProductTile({ product }: ProductTileProps): React.JSX.Element {
  const discountPercent = calculateDiscountPercent(product.priceInPaise, product.mrpInPaise);

  return (
    <article className="group flex flex-col overflow-hidden rounded-2xl border border-neutral-200 bg-white transition-shadow duration-150 hover:shadow-md dark:border-neutral-800 dark:bg-neutral-900">
      <div className="relative aspect-square w-full bg-neutral-100 dark:bg-neutral-800">
        {product.imageUrl ? (
          <Image
            src={product.imageUrl}
            alt={product.name}
            fill
            sizes="(max-width: 640px) 50vw, (max-width: 1024px) 25vw, 200px"
            className="object-contain p-3"
          />
        ) : (
          <div
            className="flex h-full w-full items-center justify-center bg-gradient-to-br from-orange-50 to-neutral-100 text-xs font-medium text-neutral-400 dark:from-neutral-800 dark:to-neutral-900 dark:text-neutral-600"
            aria-hidden="true"
          >
            {product.brand}
          </div>
        )}
        {discountPercent > 0 && (
          <span className="absolute left-2 top-2 rounded-lg bg-[#F97316] px-2 py-1 text-[11px] font-bold leading-none text-white shadow-sm">
            {discountPercent}% OFF
          </span>
        )}
        <span className="absolute bottom-2 right-2 inline-flex items-center gap-1 rounded-lg bg-white/95 px-2 py-1 text-[10px] font-semibold text-neutral-700 shadow-sm dark:bg-neutral-900/90 dark:text-neutral-200">
          <Clock3 className="h-3 w-3 text-[#F97316]" aria-hidden="true" />
          {product.deliveryEtaMinutes} min
        </span>
      </div>

      <div className="flex flex-1 flex-col gap-2 p-3">
        <div>
          <p className="text-[11px] font-medium uppercase tracking-wide text-neutral-500 dark:text-neutral-400">
            {product.brand}
          </p>
          <h3 className="line-clamp-2 text-sm font-semibold leading-snug text-neutral-900 dark:text-neutral-50">
            {product.name}
          </h3>
          <p className="mt-1 text-xs text-neutral-500 dark:text-neutral-400">{product.unit}</p>
        </div>

        <div className="mt-auto flex items-end justify-between gap-2 pt-1">
          <div className="flex flex-col">
            <span className="text-sm font-bold text-neutral-900 dark:text-neutral-50">
              {formatIndianRupees(product.priceInPaise)}
            </span>
            {discountPercent > 0 && (
              <span className="text-xs text-neutral-400 line-through dark:text-neutral-500">
                {formatIndianRupees(product.mrpInPaise)}
              </span>
            )}
          </div>
          <button
            type="button"
            className="min-h-[36px] min-w-[64px] rounded-xl border-2 border-[#F97316] px-3 text-sm font-bold text-[#F97316] transition-colors duration-150 hover:bg-[#F97316] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F97316] focus-visible:ring-offset-2 dark:focus-visible:ring-offset-neutral-900"
          >
            Add
          </button>
        </div>
      </div>
    </article>
  );
}

interface SectionHeaderProps {
  title: string;
  subtitle?: string;
  href?: string;
}

function SectionHeader({ title, subtitle, href }: SectionHeaderProps): React.JSX.Element {
  return (
    <div className="mb-3 flex items-end justify-between px-4 sm:px-6">
      <div>
        <h2 className="text-lg font-bold text-neutral-900 dark:text-neutral-50 sm:text-xl">
          {title}
        </h2>
        {subtitle && (
          <p className="mt-0.5 text-sm text-neutral-500 dark:text-neutral-400">{subtitle}</p>
        )}
      </div>
      {href && (
        <Link
          href={href}
          className="inline-flex min-h-[44px] items-center gap-0.5 rounded-xl px-2 text-sm font-semibold text-[#F97316] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F97316] focus-visible:ring-offset-2 dark:focus-visible:ring-offset-neutral-950"
        >
          See all
          <ChevronRight className="h-4 w-4" aria-hidden="true" />
        </Link>
      )}
    </div>
  );
}

export default async function ShopHomePage(): Promise<React.JSX.Element> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('products')
    .select('id, name, slug, unit, pack_size, selling_price_paise, mrp_paise, delivery_eta_minutes, brands(name)')
    .eq('is_active', true)
    .order('name');

  return (
    <main className="min-h-screen bg-neutral-50 p-6 dark:bg-neutral-950">
      <header className="mb-8">
        <p className="text-sm">Delivering to Home — Koramangala, Bengaluru</p>
        <h1 className="text-3xl font-bold">InstaDaily</h1>
        <nav><Link href="/orders/frequent">Frequent purchases</Link>{' · '}<Link href="/sign-in">Sign in</Link></nav>
      </header>
      <section>
        <h2 className="mb-4 text-2xl font-bold">Shop groceries</h2>
        {error ? <p role="alert">Unable to load products: {error.message}</p> : <ProductCatalog products={(data ?? []) as StoreProduct[]} />}
      </section>
      <section className="mt-8">
        <h2 className="text-2xl font-bold">Chef Mode</h2>
        <Link href="/chef-mode/recipe_paneer_butter_masala">Cook Paneer Butter Masala</Link>
      </section>
    </main>
  );

  /* Legacy mock catalogue retained below for design reference only.
    <main className="min-h-screen bg-neutral-50 pb-24 dark:bg-neutral-950">
      <header className="sticky top-0 z-20 border-b border-neutral-200 bg-white/95 backdrop-blur-sm dark:border-neutral-800 dark:bg-neutral-950/95">
        <Container>
          <div className="flex flex-col gap-3 py-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <p className="text-xs font-medium text-neutral-500 dark:text-neutral-400">
                  Delivering to
                </p>
                <h1 className="text-lg font-extrabold text-neutral-900 dark:text-neutral-50">
                  Home &mdash; Koramangala, Bengaluru
                </h1>
              </div>
              <ExpressModeToggle />
            </div>
            <SearchBar />
          </div>
        </Container>
      </header>

      <Section className="pt-5">
        <Container>
          <div className="flex items-center gap-3 rounded-2xl bg-gradient-to-r from-orange-500 to-orange-400 px-5 py-4 text-white shadow-sm">
            <Flame className="h-6 w-6 flex-shrink-0" aria-hidden="true" />
            <div>
              <p className="text-sm font-bold leading-tight">
                Groceries delivered in 10 minutes
              </p>
              <p className="text-xs text-orange-50">
                Fresh dairy, staples and daily essentials, right to your door.
              </p>
            </div>
          </div>
        </Container>
      </Section>

      <Section className="pt-6">
        <SectionHeader
          title="Your Frequent Purchases"
          subtitle="Reorder your essentials in one tap"
          href="/orders/frequent"
        />
        <div className="scrollbar-hide flex gap-3 overflow-x-auto px-4 pb-2 sm:px-6">
          {FREQUENT_PURCHASES.map((product) => (
            <div key={product.id} className="w-36 flex-shrink-0 sm:w-44">
              <ProductTile product={product} />
            </div>
          ))}
        </div>
      </Section>

      <Section className="pt-6">
        <Container>
          <Link
            href={`/chef-mode/${CHEF_MODE_RECIPE.id}`}
            className="flex overflow-hidden rounded-2xl border border-neutral-200 bg-white shadow-sm transition-shadow duration-150 hover:shadow-md focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#F97316] focus-visible:ring-offset-2 dark:border-neutral-800 dark:bg-neutral-900 dark:focus-visible:ring-offset-neutral-950"
          >
            <div className="relative h-32 w-32 flex-shrink-0 bg-neutral-100 dark:bg-neutral-800 sm:h-40 sm:w-40">
              {CHEF_MODE_RECIPE.imageUrl ? (
                <Image
                  src={CHEF_MODE_RECIPE.imageUrl}
                  alt={CHEF_MODE_RECIPE.title}
                  fill
                  sizes="160px"
                  className="object-cover"
                />
              ) : (
                <div
                  className="flex h-full w-full items-center justify-center bg-gradient-to-br from-orange-100 to-orange-50 dark:from-orange-950 dark:to-neutral-900"
                  aria-hidden="true"
                >
                  <ChefHat className="h-10 w-10 text-[#F97316]" />
                </div>
              )}
            </div>
            <div className="flex flex-1 flex-col justify-center gap-1.5 p-4">
              <span className="inline-flex w-fit items-center gap-1 rounded-full bg-orange-100 px-2 py-0.5 text-[11px] font-bold uppercase tracking-wide text-[#F97316] dark:bg-orange-950 dark:text-orange-400">
                <ChefHat className="h-3 w-3" aria-hidden="true" />
                Chef Mode
              </span>
              <h3 className="text-base font-bold text-neutral-900 dark:text-neutral-50 sm:text-lg">
                {CHEF_MODE_RECIPE.title}
              </h3>
              <p className="line-clamp-2 text-sm text-neutral-500 dark:text-neutral-400">
                {CHEF_MODE_RECIPE.description}
              </p>
              <p className="text-xs font-medium text-neutral-400 dark:text-neutral-500">
                {CHEF_MODE_RECIPE.ingredientCount} ingredients &middot;{' '}
                {CHEF_MODE_RECIPE.cookTimeMinutes} min cook time
              </p>
            </div>
          </Link>
        </Container>
      </Section>

      <Section className="pt-6">
        <SectionHeader title="Recommended for You" subtitle="Best sellers, restocked daily" />
        <Container>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 sm:gap-4 md:grid-cols-4 lg:grid-cols-5">
            {PRODUCT_FEED.map((product) => (
              <ProductTile key={product.id} product={product} />
            ))}
          </div>
        </Container>
      </Section>
    </main>
  );
  */
}
