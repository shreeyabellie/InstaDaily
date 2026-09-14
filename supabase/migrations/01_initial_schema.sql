-- =============================================================================
-- InstaDaily — Initial Foundational Database Schema
-- File: supabase/migrations/01_initial_schema.sql
-- Target: PostgreSQL 15+ / Supabase
-- =============================================================================


-- =============================================================================
-- SECTION 1: EXTENSIONS
-- =============================================================================

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";


-- =============================================================================
-- SECTION 2: ENUM TYPES
-- =============================================================================

create type cart_status as enum (
  'active',
  'checked_out',
  'abandoned'
);

create type billing_type as enum (
  'group',
  'personal'
);

create type order_status as enum (
  'pending',
  'confirmed',
  'processing',
  'out_for_delivery',
  'delivered',
  'cancelled'
);

create type payment_status as enum (
  'pending',
  'paid',
  'failed',
  'refunded'
);

create type expense_status as enum (
  'pending',
  'settled',
  'cancelled'
);

create type expense_participant_status as enum (
  'pending',
  'paid',
  'declined'
);

create type money_request_status as enum (
  'pending',
  'paid',
  'declined',
  'cancelled'
);

create type notification_type as enum (
  'order_update',
  'payment',
  'money_request',
  'price_drop',
  'system'
);

create type difficulty as enum (
  'easy',
  'medium',
  'hard'
);

create type stock_status as enum (
  'in_stock',
  'low_stock',
  'out_of_stock'
);


-- =============================================================================
-- SECTION 3: UTILITY FUNCTIONS
-- =============================================================================

create or replace function public.fn_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


create sequence if not exists public.order_number_seq
start with 100001
increment by 1;


create or replace function public.fn_generate_order_number()
returns text
language plpgsql
as $$
begin
  return 'INST-' || nextval('public.order_number_seq')::text;
end;
$$;


-- =============================================================================
-- SECTION 4: USER PROFILES
-- =============================================================================

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,

  full_name text,
  phone text,
  avatar_url text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 5: ADDRESSES
-- =============================================================================

create table public.addresses (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references public.profiles(id) on delete cascade,

  label text not null default 'Home',
  recipient_name text not null,
  phone text not null,

  address_line_1 text not null,
  address_line_2 text,
  landmark text,

  city text not null,
  state text not null,
  postal_code text not null,
  country text not null default 'India',

  latitude numeric(10, 7),
  longitude numeric(10, 7),

  is_default boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 6: BRANDS
-- =============================================================================

create table public.brands (
  id uuid primary key default gen_random_uuid(),

  name text not null unique,
  slug text not null unique,
  logo_url text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 7: CATEGORIES
-- =============================================================================

create table public.categories (
  id uuid primary key default gen_random_uuid(),

  name text not null unique,
  slug text not null unique,

  parent_category_id uuid references public.categories(id) on delete set null,

  image_url text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 8: PRODUCTS
-- =============================================================================

create table public.products (
  id uuid primary key default gen_random_uuid(),

  brand_id uuid references public.brands(id) on delete set null,
  category_id uuid references public.categories(id) on delete set null,

  name text not null,
  slug text not null unique,
  description text,

  unit text not null default 'piece',

  mrp_paise integer not null check (mrp_paise >= 0),
  selling_price_paise integer not null check (
    selling_price_paise >= 0
    and selling_price_paise <= mrp_paise
  ),

  image_url text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 9: FULFILLMENT LOCATIONS
-- =============================================================================

create table public.fulfillment_locations (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  city text not null,
  state text not null,
  postal_code text,

  latitude numeric(10, 7),
  longitude numeric(10, 7),

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 10: INVENTORY
-- =============================================================================

create table public.inventory (
  id uuid primary key default gen_random_uuid(),

  product_id uuid not null references public.products(id) on delete cascade,
  location_id uuid not null references public.fulfillment_locations(id) on delete cascade,

  available_quantity integer not null default 0
    check (available_quantity >= 0),

  reserved_quantity integer not null default 0
    check (reserved_quantity >= 0),

  stock_status stock_status not null default 'out_of_stock',

  updated_at timestamptz not null default now(),

  unique(product_id, location_id)
);


-- =============================================================================
-- SECTION 11: PRICE HISTORY
-- =============================================================================

create table public.price_history (
  id uuid primary key default gen_random_uuid(),

  product_id uuid not null references public.products(id) on delete cascade,

  mrp_paise integer not null check (mrp_paise >= 0),
  selling_price_paise integer not null check (
    selling_price_paise >= 0
    and selling_price_paise <= mrp_paise
  ),

  recorded_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 12: CHEF MODE — INGREDIENTS
-- =============================================================================

create table public.ingredients (
  id uuid primary key default gen_random_uuid(),

  name text not null unique,
  description text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 13: CHEF MODE — RECIPES
-- =============================================================================

create table public.recipes (
  id uuid primary key default gen_random_uuid(),

  name text not null,
  slug text not null unique,

  description text,

  difficulty difficulty not null default 'easy',

  prep_time_minutes integer
    check (prep_time_minutes is null or prep_time_minutes >= 0),

  cook_time_minutes integer
    check (cook_time_minutes is null or cook_time_minutes >= 0),

  default_servings integer not null default 2
    check (default_servings > 0),

  image_url text,

  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 14: CHEF MODE — RECIPE INGREDIENTS
-- =============================================================================

create table public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),

  recipe_id uuid not null references public.recipes(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete cascade,

  quantity numeric(12, 3) not null
    check (quantity > 0),

  unit text not null,

  is_optional boolean not null default false,

  created_at timestamptz not null default now(),

  unique(recipe_id, ingredient_id)
);


-- =============================================================================
-- SECTION 15: CHEF MODE — RECIPE STEPS
-- =============================================================================

create table public.recipe_steps (
  id uuid primary key default gen_random_uuid(),

  recipe_id uuid not null references public.recipes(id) on delete cascade,

  step_number integer not null
    check (step_number > 0),

  instruction text not null,

  image_url text,

  created_at timestamptz not null default now(),

  unique(recipe_id, step_number)
);


-- =============================================================================
-- SECTION 16: CHEF MODE — RECIPE MEDIA
-- =============================================================================

create table public.recipe_media (
  id uuid primary key default gen_random_uuid(),

  recipe_id uuid not null references public.recipes(id) on delete cascade,

  media_url text not null,
  media_type text not null default 'image',

  sort_order integer not null default 0,

  created_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 17: CHEF MODE — INGREDIENT TO PRODUCT MAPPING
-- =============================================================================

create table public.ingredient_product_mappings (
  id uuid primary key default gen_random_uuid(),

  ingredient_id uuid not null references public.ingredients(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,

  priority integer not null default 1
    check (priority > 0),

  created_at timestamptz not null default now(),

  unique(ingredient_id, product_id)
);


-- =============================================================================
-- SECTION 18: BASIC CARTS
-- NOTE:
-- cart_members is intentionally NOT created here.
-- It belongs to 02_sync_cart_schema.sql.
-- =============================================================================

create table public.carts (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references public.profiles(id) on delete cascade,

  status cart_status not null default 'active',

  billing_type billing_type not null default 'personal',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 19: CART ITEMS
-- =============================================================================

create table public.cart_items (
  id uuid primary key default gen_random_uuid(),

  cart_id uuid not null references public.carts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,

  quantity integer not null default 1
    check (quantity > 0),

  unit_price_paise integer not null
    check (unit_price_paise >= 0),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(cart_id, product_id)
);


-- =============================================================================
-- SECTION 20: ORDERS
-- =============================================================================

create table public.orders (
  id uuid primary key default gen_random_uuid(),

  order_number text not null unique
    default public.fn_generate_order_number(),

  user_id uuid not null references public.profiles(id) on delete restrict,

  cart_id uuid references public.carts(id) on delete set null,

  delivery_address_id uuid references public.addresses(id) on delete set null,

  status order_status not null default 'pending',

  subtotal_paise integer not null default 0
    check (subtotal_paise >= 0),

  delivery_fee_paise integer not null default 0
    check (delivery_fee_paise >= 0),

  discount_paise integer not null default 0
    check (discount_paise >= 0),

  total_paise integer not null default 0
    check (total_paise >= 0),

  billing_type billing_type not null default 'personal',

  edit_lock_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 21: ORDER ITEMS
-- =============================================================================

create table public.order_items (
  id uuid primary key default gen_random_uuid(),

  order_id uuid not null references public.orders(id) on delete cascade,

  product_id uuid not null references public.products(id) on delete restrict,

  product_name text not null,

  quantity integer not null
    check (quantity > 0),

  unit_price_paise integer not null
    check (unit_price_paise >= 0),

  total_price_paise integer not null
    check (total_price_paise >= 0),

  created_at timestamptz not null default now(),

  unique(order_id, product_id)
);


-- =============================================================================
-- SECTION 22: ORDER STATUS HISTORY
-- =============================================================================

create table public.order_status_history (
  id uuid primary key default gen_random_uuid(),

  order_id uuid not null references public.orders(id) on delete cascade,

  status order_status not null,

  changed_by uuid references public.profiles(id) on delete set null,

  note text,

  created_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 23: PAYMENTS
-- =============================================================================

create table public.payments (
  id uuid primary key default gen_random_uuid(),

  order_id uuid not null references public.orders(id) on delete cascade,

  provider text not null,
  provider_transaction_id text,

  amount_paise integer not null
    check (amount_paise >= 0),

  status payment_status not null default 'pending',

  paid_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(provider, provider_transaction_id)
);


-- =============================================================================
-- SECTION 24: SPLIT BILLING — EXPENSES
-- =============================================================================

create table public.expenses (
  id uuid primary key default gen_random_uuid(),

  order_id uuid not null references public.orders(id) on delete cascade,

  created_by uuid not null references public.profiles(id) on delete restrict,

  title text not null,

  total_amount_paise integer not null
    check (total_amount_paise >= 0),

  status expense_status not null default 'pending',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 25: SPLIT BILLING — EXPENSE PARTICIPANTS
-- =============================================================================

create table public.expense_participants (
  id uuid primary key default gen_random_uuid(),

  expense_id uuid not null references public.expenses(id) on delete cascade,

  user_id uuid not null references public.profiles(id) on delete restrict,

  amount_owed_paise integer not null
    check (amount_owed_paise >= 0),

  amount_paid_paise integer not null default 0
    check (amount_paid_paise >= 0),

  status expense_participant_status not null default 'pending',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique(expense_id, user_id),

  check (amount_paid_paise <= amount_owed_paise)
);


-- =============================================================================
-- SECTION 26: SPLIT BILLING — MONEY REQUESTS
-- =============================================================================

create table public.money_requests (
  id uuid primary key default gen_random_uuid(),

  expense_id uuid not null references public.expenses(id) on delete cascade,

  requester_id uuid not null references public.profiles(id) on delete restrict,

  recipient_id uuid not null references public.profiles(id) on delete restrict,

  amount_paise integer not null
    check (amount_paise > 0),

  status money_request_status not null default 'pending',

  note text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  check (requester_id <> recipient_id)
);


-- =============================================================================
-- SECTION 27: NOTIFICATIONS
-- =============================================================================

create table public.notifications (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references public.profiles(id) on delete cascade,

  type notification_type not null,

  title text not null,
  message text not null,

  data jsonb not null default '{}'::jsonb,

  read_at timestamptz,

  created_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 28: USER PREFERENCES
-- =============================================================================

create table public.user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,

  notifications_enabled boolean not null default true,
  price_drop_alerts_enabled boolean not null default true,

  default_billing_type billing_type not null default 'personal',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);


-- =============================================================================
-- SECTION 29: PROFILE CREATION TRIGGER
-- =============================================================================

create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    full_name,
    avatar_url
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;


drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.fn_handle_new_user();


-- =============================================================================
-- SECTION 30: DEFAULT USER PREFERENCES TRIGGER
-- =============================================================================

create or replace function public.fn_create_default_preferences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_preferences (
    user_id
  )
  values (
    new.id
  )
  on conflict (user_id) do nothing;

  return new;
end;
$$;


drop trigger if exists create_default_preferences on public.profiles;

create trigger create_default_preferences
after insert on public.profiles
for each row
execute function public.fn_create_default_preferences();


-- =============================================================================
-- SECTION 31: INVENTORY STOCK STATUS
-- =============================================================================

create or replace function public.fn_update_inventory_stock_status()
returns trigger
language plpgsql
as $$
begin
  if new.available_quantity <= 0 then
    new.stock_status = 'out_of_stock';
  elsif new.available_quantity <= 5 then
    new.stock_status = 'low_stock';
  else
    new.stock_status = 'in_stock';
  end if;

  new.updated_at = now();

  return new;
end;
$$;


drop trigger if exists inventory_stock_status_trigger on public.inventory;

create trigger inventory_stock_status_trigger
before insert or update of available_quantity
on public.inventory
for each row
execute function public.fn_update_inventory_stock_status();


-- =============================================================================
-- SECTION 32: PRICE HISTORY TRIGGER
-- =============================================================================

create or replace function public.fn_products_record_price_history()
returns trigger
language plpgsql
as $$
begin
  insert into public.price_history (
    product_id,
    mrp_paise,
    selling_price_paise
  )
  values (
    new.id,
    new.mrp_paise,
    new.selling_price_paise
  );

  return new;
end;
$$;


drop trigger if exists products_price_history_trigger on public.products;

create trigger products_price_history_trigger
after insert on public.products
for each row
execute function public.fn_products_record_price_history();


create or replace function public.fn_products_record_price_change()
returns trigger
language plpgsql
as $$
begin
  if (
    old.mrp_paise <> new.mrp_paise
    or old.selling_price_paise <> new.selling_price_paise
  ) then

    insert into public.price_history (
      product_id,
      mrp_paise,
      selling_price_paise
    )
    values (
      new.id,
      new.mrp_paise,
      new.selling_price_paise
    );

  end if;

  return new;
end;
$$;


drop trigger if exists products_price_change_trigger on public.products;

create trigger products_price_change_trigger
after update of mrp_paise, selling_price_paise
on public.products
for each row
execute function public.fn_products_record_price_change();


-- =============================================================================
-- SECTION 33: ORDER EDIT LOCK
-- =============================================================================

create or replace function public.fn_orders_set_edit_lock()
returns trigger
language plpgsql
as $$
begin
  if new.edit_lock_at is null then
    new.edit_lock_at = now() + interval '2 minutes';
  end if;

  return new;
end;
$$;


drop trigger if exists orders_edit_lock_trigger on public.orders;

create trigger orders_edit_lock_trigger
before insert on public.orders
for each row
execute function public.fn_orders_set_edit_lock();


-- =============================================================================
-- SECTION 34: ORDER STATUS HISTORY
-- =============================================================================

create or replace function public.fn_record_order_status_change()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then

    insert into public.order_status_history (
      order_id,
      status,
      changed_by
    )
    values (
      new.id,
      new.status,
      new.user_id
    );

  elsif old.status <> new.status then

    insert into public.order_status_history (
      order_id,
      status,
      changed_by
    )
    values (
      new.id,
      new.status,
      new.user_id
    );

  end if;

  return new;
end;
$$;


drop trigger if exists orders_status_history_trigger on public.orders;

create trigger orders_status_history_trigger
after insert or update of status
on public.orders
for each row
execute function public.fn_record_order_status_change();


-- =============================================================================
-- SECTION 35: UPDATED_AT TRIGGERS
-- =============================================================================

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
before update on public.profiles
for each row
execute function public.fn_set_updated_at();


drop trigger if exists addresses_updated_at on public.addresses;
create trigger addresses_updated_at
before update on public.addresses
for each row
execute function public.fn_set_updated_at();


drop trigger if exists brands_updated_at on public.brands;
create trigger brands_updated_at
before update on public.brands
for each row
execute function public.fn_set_updated_at();


drop trigger if exists categories_updated_at on public.categories;
create trigger categories_updated_at
before update on public.categories
for each row
execute function public.fn_set_updated_at();


drop trigger if exists products_updated_at on public.products;
create trigger products_updated_at
before update on public.products
for each row
execute function public.fn_set_updated_at();


drop trigger if exists fulfillment_locations_updated_at on public.fulfillment_locations;
create trigger fulfillment_locations_updated_at
before update on public.fulfillment_locations
for each row
execute function public.fn_set_updated_at();


drop trigger if exists ingredients_updated_at on public.ingredients;
create trigger ingredients_updated_at
before update on public.ingredients
for each row
execute function public.fn_set_updated_at();


drop trigger if exists recipes_updated_at on public.recipes;
create trigger recipes_updated_at
before update on public.recipes
for each row
execute function public.fn_set_updated_at();


drop trigger if exists carts_updated_at on public.carts;
create trigger carts_updated_at
before update on public.carts
for each row
execute function public.fn_set_updated_at();


drop trigger if exists cart_items_updated_at on public.cart_items;
create trigger cart_items_updated_at
before update on public.cart_items
for each row
execute function public.fn_set_updated_at();


drop trigger if exists orders_updated_at on public.orders;
create trigger orders_updated_at
before update on public.orders
for each row
execute function public.fn_set_updated_at();


drop trigger if exists payments_updated_at on public.payments;
create trigger payments_updated_at
before update on public.payments
for each row
execute function public.fn_set_updated_at();


drop trigger if exists expenses_updated_at on public.expenses;
create trigger expenses_updated_at
before update on public.expenses
for each row
execute function public.fn_set_updated_at();


drop trigger if exists expense_participants_updated_at on public.expense_participants;
create trigger expense_participants_updated_at
before update on public.expense_participants
for each row
execute function public.fn_set_updated_at();


drop trigger if exists money_requests_updated_at on public.money_requests;
create trigger money_requests_updated_at
before update on public.money_requests
for each row
execute function public.fn_set_updated_at();


drop trigger if exists user_preferences_updated_at on public.user_preferences;
create trigger user_preferences_updated_at
before update on public.user_preferences
for each row
execute function public.fn_set_updated_at();


-- =============================================================================
-- SECTION 36: INDEXES
-- =============================================================================

create index profiles_phone_idx
on public.profiles(phone);


create index addresses_user_id_idx
on public.addresses(user_id);


create index addresses_default_idx
on public.addresses(user_id, is_default);


create index brands_name_trgm_idx
on public.brands using gin(name gin_trgm_ops);


create index categories_parent_idx
on public.categories(parent_category_id);


create index products_brand_idx
on public.products(brand_id);


create index products_category_idx
on public.products(category_id);


create index products_active_idx
on public.products(is_active);


create index products_name_trgm_idx
on public.products using gin(name gin_trgm_ops);


create index inventory_product_idx
on public.inventory(product_id);


create index inventory_location_idx
on public.inventory(location_id);


create index inventory_stock_status_idx
on public.inventory(stock_status);


create index price_history_product_idx
on public.price_history(product_id, recorded_at desc);


create index ingredients_name_trgm_idx
on public.ingredients using gin(name gin_trgm_ops);


create index recipes_name_trgm_idx
on public.recipes using gin(name gin_trgm_ops);


create index recipe_ingredients_recipe_idx
on public.recipe_ingredients(recipe_id);


create index recipe_ingredients_ingredient_idx
on public.recipe_ingredients(ingredient_id);


create index recipe_steps_recipe_idx
on public.recipe_steps(recipe_id);


create index recipe_media_recipe_idx
on public.recipe_media(recipe_id);


create index ingredient_product_mappings_ingredient_idx
on public.ingredient_product_mappings(ingredient_id);


create index ingredient_product_mappings_product_idx
on public.ingredient_product_mappings(product_id);


create index carts_user_id_idx
on public.carts(user_id);


create index carts_status_idx
on public.carts(status);


create index cart_items_cart_id_idx
on public.cart_items(cart_id);


create index cart_items_product_id_idx
on public.cart_items(product_id);


create index orders_user_id_idx
on public.orders(user_id);


create index orders_status_idx
on public.orders(status);


create index orders_created_at_idx
on public.orders(created_at desc);


create index orders_cart_id_idx
on public.orders(cart_id);


create index order_items_order_id_idx
on public.order_items(order_id);


create index order_items_product_id_idx
on public.order_items(product_id);


create index order_status_history_order_id_idx
on public.order_status_history(order_id, created_at desc);


create index payments_order_id_idx
on public.payments(order_id);


create index payments_status_idx
on public.payments(status);


create index expenses_order_id_idx
on public.expenses(order_id);


create index expenses_created_by_idx
on public.expenses(created_by);


create index expense_participants_expense_id_idx
on public.expense_participants(expense_id);


create index expense_participants_user_id_idx
on public.expense_participants(user_id);


create index money_requests_expense_id_idx
on public.money_requests(expense_id);


create index money_requests_requester_idx
on public.money_requests(requester_id);


create index money_requests_recipient_idx
on public.money_requests(recipient_id);


create index money_requests_status_idx
on public.money_requests(status);


create index notifications_user_id_idx
on public.notifications(user_id);


create index notifications_unread_idx
on public.notifications(user_id, read_at);


-- =============================================================================
-- SECTION 37: ROW LEVEL SECURITY
-- =============================================================================

alter table public.profiles enable row level security;
alter table public.addresses enable row level security;
alter table public.brands enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.fulfillment_locations enable row level security;
alter table public.inventory enable row level security;
alter table public.price_history enable row level security;
alter table public.ingredients enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_ingredients enable row level security;
alter table public.recipe_steps enable row level security;
alter table public.recipe_media enable row level security;
alter table public.ingredient_product_mappings enable row level security;
alter table public.carts enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.payments enable row level security;
alter table public.expenses enable row level security;
alter table public.expense_participants enable row level security;
alter table public.money_requests enable row level security;
alter table public.notifications enable row level security;
alter table public.user_preferences enable row level security;


-- =============================================================================
-- SECTION 38: PROFILE POLICIES
-- =============================================================================

create policy profiles_select_own
on public.profiles
for select
to authenticated
using (auth.uid() = id);


create policy profiles_update_own
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);


-- =============================================================================
-- SECTION 39: ADDRESS POLICIES
-- =============================================================================

create policy addresses_select_own
on public.addresses
for select
to authenticated
using (auth.uid() = user_id);


create policy addresses_insert_own
on public.addresses
for insert
to authenticated
with check (auth.uid() = user_id);


create policy addresses_update_own
on public.addresses
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);


create policy addresses_delete_own
on public.addresses
for delete
to authenticated
using (auth.uid() = user_id);


-- =============================================================================
-- SECTION 40: PUBLIC CATALOGUE POLICIES
-- =============================================================================

create policy brands_read_authenticated
on public.brands
for select
to authenticated
using (true);


create policy categories_read_authenticated
on public.categories
for select
to authenticated
using (true);


create policy products_read_authenticated
on public.products
for select
to authenticated
using (is_active = true);


create policy fulfillment_locations_read_authenticated
on public.fulfillment_locations
for select
to authenticated
using (is_active = true);


create policy inventory_read_authenticated
on public.inventory
for select
to authenticated
using (true);


create policy price_history_read_authenticated
on public.price_history
for select
to authenticated
using (true);


-- =============================================================================
-- SECTION 41: CHEF MODE POLICIES
-- =============================================================================

create policy ingredients_read_authenticated
on public.ingredients
for select
to authenticated
using (true);


create policy recipes_read_authenticated
on public.recipes
for select
to authenticated
using (is_active = true);


create policy recipe_ingredients_read_authenticated
on public.recipe_ingredients
for select
to authenticated
using (true);


create policy recipe_steps_read_authenticated
on public.recipe_steps
for select
to authenticated
using (true);


create policy recipe_media_read_authenticated
on public.recipe_media
for select
to authenticated
using (true);


create policy ingredient_product_mappings_read_authenticated
on public.ingredient_product_mappings
for select
to authenticated
using (true);


-- =============================================================================
-- SECTION 42: CART POLICIES
-- =============================================================================

create policy carts_select_own
on public.carts
for select
to authenticated
using (auth.uid() = user_id);


create policy carts_insert_own
on public.carts
for insert
to authenticated
with check (auth.uid() = user_id);


create policy carts_update_own
on public.carts
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);


create policy carts_delete_own
on public.carts
for delete
to authenticated
using (auth.uid() = user_id);


create policy cart_items_select_own
on public.cart_items
for select
to authenticated
using (
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);


create policy cart_items_insert_own
on public.cart_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);


create policy cart_items_update_own
on public.cart_items
for update
to authenticated
using (
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);


create policy cart_items_delete_own
on public.cart_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.carts c
    where c.id = cart_items.cart_id
      and c.user_id = auth.uid()
  )
);


-- =============================================================================
-- SECTION 43: ORDER POLICIES
-- =============================================================================

create policy orders_select_own
on public.orders
for select
to authenticated
using (auth.uid() = user_id);


create policy orders_insert_own
on public.orders
for insert
to authenticated
with check (auth.uid() = user_id);


create policy orders_update_own
on public.orders
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);


create policy order_items_select_own
on public.order_items
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_items.order_id
      and o.user_id = auth.uid()
  )
);


create policy order_status_history_select_own
on public.order_status_history
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = order_status_history.order_id
      and o.user_id = auth.uid()
  )
);


-- =============================================================================
-- SECTION 44: PAYMENT POLICIES
-- =============================================================================

create policy payments_select_own
on public.payments
for select
to authenticated
using (
  exists (
    select 1
    from public.orders o
    where o.id = payments.order_id
      and o.user_id = auth.uid()
  )
);


-- =============================================================================
-- SECTION 45: SPLIT BILLING POLICIES
-- =============================================================================

create policy expenses_select_own
on public.expenses
for select
to authenticated
using (auth.uid() = created_by);


create policy expenses_insert_own
on public.expenses
for insert
to authenticated
with check (auth.uid() = created_by);


create policy expenses_update_own
on public.expenses
for update
to authenticated
using (auth.uid() = created_by)
with check (auth.uid() = created_by);


create policy expense_participants_select_own
on public.expense_participants
for select
to authenticated
using (auth.uid() = user_id);


create policy expense_participants_insert_own_expense
on public.expense_participants
for insert
to authenticated
with check (
  exists (
    select 1
    from public.expenses e
    where e.id = expense_participants.expense_id
      and e.created_by = auth.uid()
  )
);


create policy money_requests_select_involved
on public.money_requests
for select
to authenticated
using (
  auth.uid() = requester_id
  or auth.uid() = recipient_id
);


create policy money_requests_insert_own
on public.money_requests
for insert
to authenticated
with check (auth.uid() = requester_id);


-- =============================================================================
-- SECTION 46: NOTIFICATION POLICIES
-- =============================================================================

create policy notifications_select_own
on public.notifications
for select
to authenticated
using (auth.uid() = user_id);


create policy notifications_update_own
on public.notifications
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);


-- =============================================================================
-- SECTION 47: USER PREFERENCE POLICIES
-- =============================================================================

create policy user_preferences_select_own
on public.user_preferences
for select
to authenticated
using (auth.uid() = user_id);


create policy user_preferences_insert_own
on public.user_preferences
for insert
to authenticated
with check (auth.uid() = user_id);


create policy user_preferences_update_own
on public.user_preferences
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);


-- =============================================================================
-- END OF 01_initial_schema.sql
--
-- NOT INCLUDED HERE:
--   - cart_members
--   - Sync Cart realtime logic
--   - Sync Cart conflict resolution
--   - Smart Pantry tables
--   - pantry_items
--   - product_purchase_stats
--   - price_drop_alerts
--   - Smart Pantry triggers/functions
--
-- Those belong in:
--   02_sync_cart_schema.sql
--   03_smart_pantry_schema.sql
-- =============================================================================