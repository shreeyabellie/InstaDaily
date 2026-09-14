-- ============================================================
-- InstaDaily: Foundational Database Schema
-- Migration: 01_initial_schema.sql
-- Role: Member 4 (Database Schema & Realtime WebSockets)
-- ============================================================

-- ------------------------------------------------------------
-- 1. EXTENSIONS
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------
-- 2. HELPER FUNCTIONS & TRIGGERS FOR TIMESTAMPS
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- 3. USER / PROFILE SCHEMAS
-- ------------------------------------------------------------

-- PROFILES (References auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone TEXT UNIQUE,
    full_name TEXT,
    display_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ADDRESSES
CREATE TABLE IF NOT EXISTS public.addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    label TEXT NOT NULL DEFAULT 'Home',
    address_line1 TEXT NOT NULL,
    address_line2 TEXT,
    landmark TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    pincode TEXT NOT NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    is_default BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- USER PREFERENCES
CREATE TABLE IF NOT EXISTS public.user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    express_mode BOOLEAN DEFAULT false NOT NULL,
    dietary_preference TEXT DEFAULT 'any' NOT NULL,
    notifications_enabled BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ------------------------------------------------------------
-- 4. CATALOG SCHEMAS
-- ------------------------------------------------------------

-- BRANDS
CREATE TABLE IF NOT EXISTS public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- CATEGORIES (Supports hierarchical categories via parent_id)
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    parent_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- PRODUCTS
-- Note: All monetary amounts are stored as integer paise (1 INR = 100 paise)
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    brand_id UUID REFERENCES public.brands(id) ON DELETE SET NULL,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    unit TEXT NOT NULL,
    pack_size TEXT,
    description TEXT,
    image_url TEXT,
    mrp_paise INTEGER NOT NULL CHECK (mrp_paise >= 0),
    selling_price_paise INTEGER NOT NULL CHECK (selling_price_paise >= 0 AND selling_price_paise <= mrp_paise),
    delivery_eta_minutes INTEGER DEFAULT 10 CHECK (delivery_eta_minutes >= 0),
    is_active BOOLEAN DEFAULT true NOT NULL,
    is_veg BOOLEAN DEFAULT true NOT NULL,
    nutritional_info JSONB DEFAULT '{}'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ------------------------------------------------------------
-- 5. INVENTORY & FULFILLMENT
-- ------------------------------------------------------------

-- FULFILLMENT LOCATIONS (Dark stores)
CREATE TABLE IF NOT EXISTS public.fulfillment_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    city TEXT NOT NULL,
    pincode TEXT NOT NULL,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- INVENTORY (Per fulfillment location)
CREATE TABLE IF NOT EXISTS public.inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES public.fulfillment_locations(id) ON DELETE CASCADE,
    stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    reserved_quantity INTEGER NOT NULL DEFAULT 0 CHECK (reserved_quantity >= 0),
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT unique_product_location UNIQUE (product_id, location_id)
);

-- PRICE HISTORY
CREATE TABLE IF NOT EXISTS public.price_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    mrp_paise INTEGER NOT NULL CHECK (mrp_paise >= 0),
    selling_price_paise INTEGER NOT NULL CHECK (selling_price_paise >= 0),
    recorded_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ------------------------------------------------------------
-- 6. CHEF MODE (RECIPE TO CART)
-- ------------------------------------------------------------

-- INGREDIENTS
CREATE TABLE IF NOT EXISTS public.ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    category TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- RECIPES
CREATE TABLE IF NOT EXISTS public.recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    image_url TEXT,
    prep_time_minutes INTEGER NOT NULL DEFAULT 0 CHECK (prep_time_minutes >= 0),
    cook_time_minutes INTEGER NOT NULL DEFAULT 0 CHECK (cook_time_minutes >= 0),
    servings INTEGER NOT NULL DEFAULT 2 CHECK (servings > 0),
    is_veg BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- RECIPE INGREDIENTS
CREATE TABLE IF NOT EXISTS public.recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    ingredient_id UUID NOT NULL REFERENCES public.ingredients(id) ON DELETE CASCADE,
    quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL,
    optional BOOLEAN DEFAULT false NOT NULL,
    notes TEXT,
    CONSTRAINT unique_recipe_ingredient UNIQUE (recipe_id, ingredient_id)
);

-- RECIPE STEPS
CREATE TABLE IF NOT EXISTS public.recipe_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL CHECK (step_number > 0),
    instruction TEXT NOT NULL,
    duration_minutes INTEGER DEFAULT 0 CHECK (duration_minutes >= 0),
    CONSTRAINT unique_recipe_step UNIQUE (recipe_id, step_number)
);

-- RECIPE MEDIA
CREATE TABLE IF NOT EXISTS public.recipe_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video')),
    url TEXT NOT NULL,
    caption TEXT,
    display_order INTEGER DEFAULT 0 NOT NULL
);

-- INGREDIENT PRODUCT MAPPINGS (Maps abstract ingredient to store product SKU)
CREATE TABLE IF NOT EXISTS public.ingredient_product_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ingredient_id UUID NOT NULL REFERENCES public.ingredients(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT true NOT NULL,
    priority INTEGER DEFAULT 1 NOT NULL,
    CONSTRAINT unique_ingredient_product UNIQUE (ingredient_id, product_id)
);

-- ------------------------------------------------------------
-- 7. CART FOUNDATION (CANONICAL NAMING)
-- ------------------------------------------------------------

-- CARTS
CREATE TABLE IF NOT EXISTS public.carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    is_shared BOOLEAN DEFAULT false NOT NULL,
    name TEXT NOT NULL DEFAULT 'My Cart',
    share_code TEXT UNIQUE,
    is_locked BOOLEAN DEFAULT false NOT NULL,
    locked_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    locked_at TIMESTAMPTZ,
    billing_type TEXT NOT NULL DEFAULT 'single' CHECK (billing_type IN ('single', 'split_equal', 'split_by_item')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'checked_out', 'abandoned')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- CART MEMBERS (Supports owner, admin, member, editor, viewer)
CREATE TABLE IF NOT EXISTS public.cart_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES public.carts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'editor', 'viewer')),
    last_active_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT unique_cart_member UNIQUE (cart_id, user_id)
);

-- CART ITEMS
CREATE TABLE IF NOT EXISTS public.cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES public.carts(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    added_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price_paise INTEGER NOT NULL CHECK (unit_price_paise >= 0),
    is_shared BOOLEAN DEFAULT false NOT NULL,
    addition_token TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ------------------------------------------------------------
-- 8. ORDERS & ORDER STATUS HISTORY
-- ------------------------------------------------------------

-- ORDERS
-- Canonical status column name: order_status
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    cart_id UUID REFERENCES public.carts(id) ON DELETE SET NULL,
    address_id UUID REFERENCES public.addresses(id) ON DELETE SET NULL,
    fulfillment_location_id UUID REFERENCES public.fulfillment_locations(id) ON DELETE SET NULL,
    order_status TEXT NOT NULL DEFAULT 'pending' CHECK (order_status IN ('pending', 'confirmed', 'packing', 'out_for_delivery', 'delivered', 'cancelled')),
    item_total_paise INTEGER NOT NULL CHECK (item_total_paise >= 0),
    delivery_fee_paise INTEGER NOT NULL DEFAULT 0 CHECK (delivery_fee_paise >= 0),
    tip_paise INTEGER NOT NULL DEFAULT 0 CHECK (tip_paise >= 0),
    total_amount_paise INTEGER NOT NULL CHECK (total_amount_paise >= 0),
    editable_until TIMESTAMPTZ,
    delivery_eta TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ORDER ITEMS
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    added_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price_paise INTEGER NOT NULL CHECK (unit_price_paise >= 0),
    total_price_paise INTEGER NOT NULL CHECK (total_price_paise >= 0),
    is_shared BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ORDER STATUS HISTORY
CREATE TABLE IF NOT EXISTS public.order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ------------------------------------------------------------
-- 9. PAYMENTS & SPLIT BILLING
-- ------------------------------------------------------------

-- PAYMENTS
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('upi', 'card', 'netbanking', 'wallet', 'cod')),
    payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'processing', 'completed', 'failed', 'refunded')),
    transaction_reference TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- EXPENSES (For bill splitting among cart members)
CREATE TABLE IF NOT EXISTS public.expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    cart_id UUID REFERENCES public.carts(id) ON DELETE SET NULL,
    paid_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    total_amount_paise INTEGER NOT NULL CHECK (total_amount_paise >= 0),
    split_type TEXT NOT NULL DEFAULT 'equal' CHECK (split_type IN ('equal', 'exact', 'by_item')),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- EXPENSE PARTICIPANTS
CREATE TABLE IF NOT EXISTS public.expense_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    amount_owed_paise INTEGER NOT NULL CHECK (amount_owed_paise >= 0),
    has_paid BOOLEAN DEFAULT false NOT NULL,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT unique_expense_participant UNIQUE (expense_id, user_id)
);

-- MONEY REQUESTS
CREATE TABLE IF NOT EXISTS public.money_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    payer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    expense_id UUID REFERENCES public.expenses(id) ON DELETE SET NULL,
    amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ------------------------------------------------------------
-- 10. NOTIFICATIONS
-- ------------------------------------------------------------
-- Canonical column names: recipient_id and metadata
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('order_update', 'price_drop', 'pantry_restock', 'cart_activity', 'split_payment', 'system')),
    metadata JSONB DEFAULT '{}'::jsonb NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ------------------------------------------------------------
-- 11. INDEXES
-- ------------------------------------------------------------

-- Users & Addresses
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON public.addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON public.user_preferences(user_id);

-- Catalog
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_brand_id ON public.products(brand_id);
CREATE INDEX IF NOT EXISTS idx_products_slug ON public.products(slug);
CREATE INDEX IF NOT EXISTS idx_inventory_location ON public.inventory(location_id);
CREATE INDEX IF NOT EXISTS idx_price_history_product ON public.price_history(product_id);

-- Chef Mode
CREATE INDEX IF NOT EXISTS idx_recipe_ingredients_recipe ON public.recipe_ingredients(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_steps_recipe ON public.recipe_steps(recipe_id);
CREATE INDEX IF NOT EXISTS idx_ingredient_product_mappings_ing ON public.ingredient_product_mappings(ingredient_id);

-- Cart
CREATE INDEX IF NOT EXISTS idx_carts_owner_id ON public.carts(owner_id);
CREATE INDEX IF NOT EXISTS idx_carts_share_code ON public.carts(share_code);
CREATE INDEX IF NOT EXISTS idx_cart_members_cart ON public.cart_members(cart_id);
CREATE INDEX IF NOT EXISTS idx_cart_members_user ON public.cart_members(user_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON public.cart_items(cart_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_product ON public.cart_items(product_id);

-- Orders
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(order_status);
CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_order ON public.order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_order ON public.payments(order_id);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(recipient_id) WHERE is_read = false;

-- ------------------------------------------------------------
-- 12. SERVER-AUTHORITATIVE TRIGGERS
-- ------------------------------------------------------------

-- Trigger: Update updated_at
CREATE TRIGGER tr_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_addresses_updated_at BEFORE UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_user_pref_updated_at BEFORE UPDATE ON public.user_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_inventory_updated_at BEFORE UPDATE ON public.inventory FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_recipes_updated_at BEFORE UPDATE ON public.recipes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_carts_updated_at BEFORE UPDATE ON public.carts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_cart_items_updated_at BEFORE UPDATE ON public.cart_items FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER tr_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: 2-minute server-authoritative post-order edit window
CREATE OR REPLACE FUNCTION set_order_editable_window()
RETURNS TRIGGER AS $$
BEGIN
    NEW.editable_until := NEW.created_at + INTERVAL '2 minutes';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_order_editable_window
BEFORE INSERT ON public.orders
FOR EACH ROW
EXECUTE FUNCTION set_order_editable_window();

-- Trigger: Track order status changes in history
CREATE OR REPLACE FUNCTION record_order_status_history()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') OR (OLD.order_status IS DISTINCT FROM NEW.order_status) THEN
        INSERT INTO public.order_status_history (order_id, status, notes, created_at)
        VALUES (NEW.id, NEW.order_status, 'Status transitioned to ' || NEW.order_status, now());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_record_order_status
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION record_order_status_history();

-- Trigger: Record price change in price_history
CREATE OR REPLACE FUNCTION record_product_price_history()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') OR (OLD.selling_price_paise IS DISTINCT FROM NEW.selling_price_paise) OR (OLD.mrp_paise IS DISTINCT FROM NEW.mrp_paise) THEN
        INSERT INTO public.price_history (product_id, mrp_paise, selling_price_paise, recorded_at)
        VALUES (NEW.id, NEW.mrp_paise, NEW.selling_price_paise, now());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_product_price_history
AFTER INSERT OR UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION record_product_price_history();

-- Trigger: Auto-create profile on auth.users sign up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, phone, full_name, display_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.phone,
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.phone),
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(COALESCE(NEW.phone, NEW.email, 'User'), '@', 1)),
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------
-- 13. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fulfillment_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredient_product_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expense_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.money_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Catalog Data: Public read access
CREATE POLICY "Public can view active brands" ON public.brands FOR SELECT USING (true);
CREATE POLICY "Public can view categories" ON public.categories FOR SELECT USING (true);
CREATE POLICY "Public can view active products" ON public.products FOR SELECT USING (is_active = true);
CREATE POLICY "Public can view active locations" ON public.fulfillment_locations FOR SELECT USING (is_active = true);
CREATE POLICY "Public can view inventory" ON public.inventory FOR SELECT USING (true);
CREATE POLICY "Public can view price history" ON public.price_history FOR SELECT USING (true);
CREATE POLICY "Public can view recipes" ON public.recipes FOR SELECT USING (true);
CREATE POLICY "Public can view recipe ingredients" ON public.recipe_ingredients FOR SELECT USING (true);
CREATE POLICY "Public can view recipe steps" ON public.recipe_steps FOR SELECT USING (true);
CREATE POLICY "Public can view recipe media" ON public.recipe_media FOR SELECT USING (true);
CREATE POLICY "Public can view ingredients" ON public.ingredients FOR SELECT USING (true);
CREATE POLICY "Public can view ingredient mappings" ON public.ingredient_product_mappings FOR SELECT USING (true);

-- Profiles: Users can view any profile and update their own profile
CREATE POLICY "Users can view any profile" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Addresses: Users can manage their own addresses
CREATE POLICY "Users view own addresses" ON public.addresses FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own addresses" ON public.addresses FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own addresses" ON public.addresses FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own addresses" ON public.addresses FOR DELETE USING (auth.uid() = user_id);

-- User Preferences: Users can manage their own preferences
CREATE POLICY "Users view own preferences" ON public.user_preferences FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own preferences" ON public.user_preferences FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own preferences" ON public.user_preferences FOR UPDATE USING (auth.uid() = user_id);

-- Orders: Users can view and manage their own orders
CREATE POLICY "Users view own orders" ON public.orders FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own orders" ON public.orders FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own pending orders" ON public.orders FOR UPDATE USING (auth.uid() = user_id AND now() <= editable_until);

-- Order Items: Users can view items belonging to their orders
CREATE POLICY "Users view own order items" ON public.order_items FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.orders WHERE orders.id = order_items.order_id AND orders.user_id = auth.uid())
);

-- Order Status History: Users can view history for their orders
CREATE POLICY "Users view own order status history" ON public.order_status_history FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.orders WHERE orders.id = order_status_history.order_id AND orders.user_id = auth.uid())
);

-- Payments: Users can view their own payments
CREATE POLICY "Users view own payments" ON public.payments FOR SELECT USING (auth.uid() = user_id);

-- Notifications RLS
CREATE POLICY "Users view own notifications" ON public.notifications FOR SELECT USING (auth.uid() = recipient_id);
CREATE POLICY "Users update own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = recipient_id);

-- Expenses & Split Billing RLS
CREATE POLICY "Participants view expenses" ON public.expenses FOR SELECT USING (
    paid_by = auth.uid() OR EXISTS (SELECT 1 FROM public.expense_participants WHERE expense_participants.expense_id = expenses.id AND expense_participants.user_id = auth.uid())
);
CREATE POLICY "Payer creates expenses" ON public.expenses FOR INSERT WITH CHECK (paid_by = auth.uid());

CREATE POLICY "Participants view expense participant rows" ON public.expense_participants FOR SELECT USING (
    user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.expenses WHERE expenses.id = expense_participants.expense_id AND expenses.paid_by = auth.uid())
);
CREATE POLICY "Users update own participant status" ON public.expense_participants FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users view relevant money requests" ON public.money_requests FOR SELECT USING (
    requester_id = auth.uid() OR payer_id = auth.uid()
);
CREATE POLICY "Users send money requests" ON public.money_requests FOR INSERT WITH CHECK (requester_id = auth.uid());
CREATE POLICY "Payers update money requests" ON public.money_requests FOR UPDATE USING (payer_id = auth.uid() OR requester_id = auth.uid());

-- Base Carts RLS (Owner or Member Access)
CREATE POLICY "Users view carts they own or are members of" ON public.carts FOR SELECT USING (
    owner_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.cart_members WHERE cart_members.cart_id = carts.id AND cart_members.user_id = auth.uid())
);
CREATE POLICY "Users create carts" ON public.carts FOR INSERT WITH CHECK (owner_id = auth.uid());
CREATE POLICY "Owners and members update cart" ON public.carts FOR UPDATE USING (
    owner_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.cart_members WHERE cart_members.cart_id = carts.id AND cart_members.user_id = auth.uid())
);

CREATE POLICY "Users view cart members" ON public.cart_members FOR SELECT USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.cart_members cm WHERE cm.cart_id = cart_members.cart_id AND cm.user_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.carts c WHERE c.id = cart_members.cart_id AND c.owner_id = auth.uid())
);
CREATE POLICY "Users join cart as member" ON public.cart_members FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users update own membership" ON public.cart_members FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users leave cart" ON public.cart_members FOR DELETE USING (user_id = auth.uid());

CREATE POLICY "Members view cart items" ON public.cart_items FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.carts c WHERE c.id = cart_items.cart_id AND c.owner_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.cart_members cm WHERE cm.cart_id = cart_items.cart_id AND cm.user_id = auth.uid())
);
CREATE POLICY "Members insert cart items" ON public.cart_items FOR INSERT WITH CHECK (
    auth.uid() = added_by AND (
        EXISTS (SELECT 1 FROM public.carts c WHERE c.id = cart_items.cart_id AND c.owner_id = auth.uid()) OR
        EXISTS (SELECT 1 FROM public.cart_members cm WHERE cm.cart_id = cart_items.cart_id AND cm.user_id = auth.uid())
    )
);
CREATE POLICY "Members update cart items" ON public.cart_items FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.carts c WHERE c.id = cart_items.cart_id AND c.owner_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.cart_members cm WHERE cm.cart_id = cart_items.cart_id AND cm.user_id = auth.uid())
);
CREATE POLICY "Members delete cart items" ON public.cart_items FOR DELETE USING (
    added_by = auth.uid() OR
    EXISTS (SELECT 1 FROM public.carts c WHERE c.id = cart_items.cart_id AND c.owner_id = auth.uid()) OR
    EXISTS (SELECT 1 FROM public.cart_members cm WHERE cm.cart_id = cart_items.cart_id AND cm.user_id = auth.uid() AND cm.role IN ('owner', 'admin'))
);

-- ------------------------------------------------------------
-- 14. SUPABASE REALTIME CONFIGURATION (BASE CARTS)
-- ------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'carts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.carts;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'cart_members'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cart_members;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'cart_items'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cart_items;
    END IF;
EXCEPTION
    WHEN undefined_object THEN
        NULL;
END;
$$;
