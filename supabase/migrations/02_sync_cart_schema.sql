-- ============================================================
-- InstaDaily: Collaborative Sync Cart Schema & Realtime Functions
-- Migration: 02_sync_cart_schema.sql
-- Role: Member 4 (Database Schema & Realtime WebSockets)
-- ============================================================

-- This migration extends the foundational carts, cart_members, and
-- cart_items tables created in 01_initial_schema.sql.
-- IT DOES NOT DUPLICATE FOUNDATIONAL CART TABLES.

-- ------------------------------------------------------------
-- 1. REPLICA IDENTITY FOR REALTIME WEBSOCKET DELETES
-- ------------------------------------------------------------
-- REPLICA IDENTITY FULL ensures DELETE events via Supabase Realtime
-- send the complete old record to all subscribed clients.
ALTER TABLE public.cart_items REPLICA IDENTITY FULL;
ALTER TABLE public.cart_members REPLICA IDENTITY FULL;
ALTER TABLE public.carts REPLICA IDENTITY FULL;

-- ------------------------------------------------------------
-- 2. SECURITY HELPER FUNCTIONS
-- ------------------------------------------------------------

-- Check if a user is an active member or owner of a cart
CREATE OR REPLACE FUNCTION public.is_cart_member(p_cart_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.carts WHERE id = p_cart_id AND owner_id = p_user_id
    ) OR EXISTS (
        SELECT 1 FROM public.cart_members WHERE cart_id = p_cart_id AND user_id = p_user_id
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Check if a user is the owner or admin of a cart
CREATE OR REPLACE FUNCTION public.is_cart_owner_or_admin(p_cart_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.carts WHERE id = p_cart_id AND owner_id = p_user_id
    ) OR EXISTS (
        SELECT 1 FROM public.cart_members WHERE cart_id = p_cart_id AND user_id = p_user_id AND role IN ('owner', 'admin')
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ------------------------------------------------------------
-- 3. SECURE SHARE LINKS & CONFLICT AUDITING TABLES
-- ------------------------------------------------------------

-- CART SHARE LINKS
-- Cryptographically hashed tokens for secure invite links with expiration/revocation
CREATE TABLE IF NOT EXISTS public.cart_share_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES public.carts(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    share_token_hash TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member', 'editor', 'viewer')),
    expires_at TIMESTAMPTZ,
    is_revoked BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- CART ITEM CONFLICTS
-- Records concurrent additions of identical products for ConflictModal resolution
CREATE TABLE IF NOT EXISTS public.cart_item_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES public.carts(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    existing_item_id UUID REFERENCES public.cart_items(id) ON DELETE SET NULL,
    existing_quantity INTEGER NOT NULL CHECK (existing_quantity > 0),
    incoming_quantity INTEGER NOT NULL CHECK (incoming_quantity > 0),
    initiated_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    resolution_status TEXT NOT NULL DEFAULT 'pending' CHECK (resolution_status IN ('pending', 'keep_both', 'merge', 'dismissed')),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- Indexes for Sync Cart extensions
CREATE INDEX IF NOT EXISTS idx_cart_share_links_cart ON public.cart_share_links(cart_id);
CREATE INDEX IF NOT EXISTS idx_cart_share_links_hash ON public.cart_share_links(share_token_hash);
CREATE INDEX IF NOT EXISTS idx_cart_conflicts_cart ON public.cart_item_conflicts(cart_id);
CREATE INDEX IF NOT EXISTS idx_cart_conflicts_status ON public.cart_item_conflicts(cart_id, resolution_status);

-- Enable RLS
ALTER TABLE public.cart_share_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart_item_conflicts ENABLE ROW LEVEL SECURITY;

-- RLS: Cart members can view share links; owners and admins can create/update them
CREATE POLICY "Cart members view share links" ON public.cart_share_links FOR SELECT USING (
    public.is_cart_member(cart_id, auth.uid())
);
CREATE POLICY "Owners and admins manage share links" ON public.cart_share_links FOR ALL USING (
    public.is_cart_owner_or_admin(cart_id, auth.uid())
);

-- RLS: Cart members can view and resolve cart item conflicts
CREATE POLICY "Cart members view conflicts" ON public.cart_item_conflicts FOR SELECT USING (
    public.is_cart_member(cart_id, auth.uid())
);
CREATE POLICY "Cart members create conflicts" ON public.cart_item_conflicts FOR INSERT WITH CHECK (
    public.is_cart_member(cart_id, auth.uid())
);
CREATE POLICY "Cart members update conflicts" ON public.cart_item_conflicts FOR UPDATE USING (
    public.is_cart_member(cart_id, auth.uid())
);

-- Realtime for conflicts
ALTER TABLE public.cart_item_conflicts REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'cart_item_conflicts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.cart_item_conflicts;
    END IF;
EXCEPTION
    WHEN undefined_object THEN
        NULL;
END;
$$;

-- ------------------------------------------------------------
-- 4. CART CREATION & SHARING RPCs
-- ------------------------------------------------------------

-- Generate unique 6-character alphanumeric share code
CREATE OR REPLACE FUNCTION public.generate_unique_cart_share_code()
RETURNS TEXT AS $$
DECLARE
    v_code TEXT;
    v_exists BOOLEAN;
BEGIN
    LOOP
        v_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT) FROM 1 FOR 6));
        SELECT EXISTS (SELECT 1 FROM public.carts WHERE share_code = v_code) INTO v_exists;
        EXIT WHEN NOT v_exists;
    END LOOP;
    RETURN v_code;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- RPC: Create a shared cart and register creator as owner member
CREATE OR REPLACE FUNCTION public.create_shared_cart(
    p_name TEXT DEFAULT 'Shared Cart',
    p_billing_type TEXT DEFAULT 'single'
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_cart_id UUID;
    v_share_code TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create a shared cart';
    END IF;

    v_share_code := public.generate_unique_cart_share_code();

    -- Insert cart using canonical owner_id column
    INSERT INTO public.carts (
        owner_id,
        is_shared,
        name,
        share_code,
        billing_type,
        status
    )
    VALUES (
        v_user_id,
        true,
        COALESCE(p_name, 'Shared Cart'),
        v_share_code,
        COALESCE(p_billing_type, 'single'),
        'active'
    )
    RETURNING id INTO v_cart_id;

    -- Add creator as owner in cart_members
    INSERT INTO public.cart_members (
        cart_id,
        user_id,
        role,
        last_active_at,
        joined_at
    )
    VALUES (
        v_cart_id,
        v_user_id,
        'owner',
        now(),
        now()
    )
    ON CONFLICT (cart_id, user_id) DO UPDATE
    SET role = 'owner', last_active_at = now();

    RETURN jsonb_build_object(
        'cart_id', v_cart_id,
        'name', p_name,
        'share_code', v_share_code,
        'role', 'owner',
        'is_shared', true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC: Join cart by share code
CREATE OR REPLACE FUNCTION public.join_cart_by_share_code(p_share_code TEXT)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_cart RECORD;
    v_existing_role TEXT;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to join cart';
    END IF;

    SELECT id, name, is_locked, status, owner_id
    INTO v_cart
    FROM public.carts
    WHERE UPPER(share_code) = UPPER(TRIM(p_share_code))
      AND status = 'active';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired cart share code';
    END IF;

    -- Check existing role or assign member
    SELECT role INTO v_existing_role
    FROM public.cart_members
    WHERE cart_id = v_cart.id AND user_id = v_user_id;

    IF v_existing_role IS NULL THEN
        INSERT INTO public.cart_members (
            cart_id,
            user_id,
            role,
            last_active_at,
            joined_at
        )
        VALUES (
            v_cart.id,
            v_user_id,
            CASE WHEN v_cart.owner_id = v_user_id THEN 'owner' ELSE 'member' END,
            now(),
            now()
        );
        v_existing_role := CASE WHEN v_cart.owner_id = v_user_id THEN 'owner' ELSE 'member' END;
    ELSE
        UPDATE public.cart_members
        SET last_active_at = now()
        WHERE cart_id = v_cart.id AND user_id = v_user_id;
    END IF;

    RETURN jsonb_build_object(
        'cart_id', v_cart.id,
        'name', v_cart.name,
        'role', v_existing_role,
        'is_locked', v_cart.is_locked
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 5. CONCURRENT ITEM ADDITIONS & DUPLICATE CONFLICT RESOLUTION
-- ------------------------------------------------------------
-- Supports ConflictModal with 3 modes:
-- 1. 'detect_only': Checks if product is already in cart, logging conflict record and returning info
-- 2. 'merge': Merges quantity into existing item
-- 3. 'keep_both': Inserts distinct item with addition_token for concurrent distinction
CREATE OR REPLACE FUNCTION public.add_or_merge_cart_item(
    p_cart_id UUID,
    p_product_id UUID,
    p_quantity INTEGER DEFAULT 1,
    p_is_shared BOOLEAN DEFAULT false,
    p_assigned_to UUID DEFAULT NULL,
    p_addition_token TEXT DEFAULT NULL,
    p_merge_mode TEXT DEFAULT 'detect_only'
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_cart_locked BOOLEAN;
    v_unit_price INTEGER;
    v_existing_item RECORD;
    v_new_item_id UUID;
    v_conflict_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to modify cart';
    END IF;

    -- Validate cart membership
    IF NOT public.is_cart_member(p_cart_id, v_user_id) THEN
        RAISE EXCEPTION 'Permission denied: user is not a member of this cart';
    END IF;

    -- Validate cart lock status
    SELECT is_locked INTO v_cart_locked FROM public.carts WHERE id = p_cart_id;
    IF v_cart_locked THEN
        RAISE EXCEPTION 'Cart is currently locked for checkout';
    END IF;

    -- Validate quantity
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero';
    END IF;

    -- Get live product selling price
    SELECT selling_price_paise INTO v_unit_price
    FROM public.products
    WHERE id = p_product_id AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product not found or inactive';
    END IF;

    -- Check for existing item with this product in the cart
    SELECT id, quantity, added_by, is_shared
    INTO v_existing_item
    FROM public.cart_items
    WHERE cart_id = p_cart_id AND product_id = p_product_id
    LIMIT 1;

    -- Mode 1: detect_only (Prompts user via UI ConflictModal)
    IF v_existing_item.id IS NOT NULL AND p_merge_mode = 'detect_only' THEN
        -- Record conflict audit record
        INSERT INTO public.cart_item_conflicts (
            cart_id,
            product_id,
            existing_item_id,
            existing_quantity,
            incoming_quantity,
            initiated_by,
            resolution_status
        )
        VALUES (
            p_cart_id,
            p_product_id,
            v_existing_item.id,
            v_existing_item.quantity,
            p_quantity,
            v_user_id,
            'pending'
        )
        RETURNING id INTO v_conflict_id;

        RETURN jsonb_build_object(
            'conflict', true,
            'conflict_id', v_conflict_id,
            'existing_item_id', v_existing_item.id,
            'existing_quantity', v_existing_item.quantity,
            'product_id', p_product_id,
            'message', 'Item already exists in cart'
        );
    END IF;

    -- Mode 2: merge (Increments quantity on existing item)
    IF v_existing_item.id IS NOT NULL AND p_merge_mode = 'merge' THEN
        UPDATE public.cart_items
        SET quantity = quantity + p_quantity,
            unit_price_paise = v_unit_price,
            updated_at = now()
        WHERE id = v_existing_item.id;

        -- Update any pending conflict records for this cart and product
        UPDATE public.cart_item_conflicts
        SET resolution_status = 'merge',
            resolved_at = now()
        WHERE cart_id = p_cart_id AND product_id = p_product_id AND resolution_status = 'pending';

        RETURN jsonb_build_object(
            'conflict', false,
            'action', 'merged',
            'cart_item_id', v_existing_item.id,
            'new_quantity', v_existing_item.quantity + p_quantity
        );
    END IF;

    -- Mode 3: keep_both or brand new item addition
    INSERT INTO public.cart_items (
        cart_id,
        product_id,
        added_by,
        assigned_to,
        quantity,
        unit_price_paise,
        is_shared,
        addition_token
    )
    VALUES (
        p_cart_id,
        p_product_id,
        v_user_id,
        COALESCE(p_assigned_to, v_user_id),
        p_quantity,
        v_unit_price,
        p_is_shared,
        COALESCE(p_addition_token, gen_random_uuid()::TEXT)
    )
    RETURNING id INTO v_new_item_id;

    IF v_existing_item.id IS NOT NULL AND p_merge_mode = 'keep_both' THEN
        UPDATE public.cart_item_conflicts
        SET resolution_status = 'keep_both',
            resolved_at = now()
        WHERE cart_id = p_cart_id AND product_id = p_product_id AND resolution_status = 'pending';
    END IF;

    RETURN jsonb_build_object(
        'conflict', false,
        'action', CASE WHEN v_existing_item.id IS NOT NULL THEN 'added_distinct' ELSE 'inserted' END,
        'cart_item_id', v_new_item_id,
        'quantity', p_quantity
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 6. PRESENCE & ACTIVE MEMBERS TRACKING
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_member_presence(p_cart_id UUID)
RETURNS VOID AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NOT NULL THEN
        UPDATE public.cart_members
        SET last_active_at = now()
        WHERE cart_id = p_cart_id AND user_id = v_user_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 7. LOCK & UNLOCK FOR CHECKOUT FLOW
-- ------------------------------------------------------------
-- Prevents race conditions during checkout (e.g. adding items while another member pays)
CREATE OR REPLACE FUNCTION public.lock_cart_for_checkout(p_cart_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_cart RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF NOT public.is_cart_member(p_cart_id, v_user_id) THEN
        RAISE EXCEPTION 'Permission denied: not a member of this cart';
    END IF;

    SELECT is_locked, locked_by, locked_at INTO v_cart FROM public.carts WHERE id = p_cart_id FOR UPDATE;

    IF v_cart.is_locked AND v_cart.locked_by <> v_user_id THEN
        -- Allow lock takeover if lock expired after 10 minutes
        IF v_cart.locked_at < now() - INTERVAL '10 minutes' THEN
            NULL;
        ELSE
            RAISE EXCEPTION 'Cart is already locked by another member';
        END IF;
    END IF;

    UPDATE public.carts
    SET is_locked = true,
        locked_by = v_user_id,
        locked_at = now()
    WHERE id = p_cart_id;

    RETURN jsonb_build_object(
        'success', true,
        'is_locked', true,
        'locked_by', v_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.unlock_cart(p_cart_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    IF NOT public.is_cart_owner_or_admin(p_cart_id, v_user_id) THEN
        IF NOT EXISTS (SELECT 1 FROM public.carts WHERE id = p_cart_id AND locked_by = v_user_id) THEN
            RAISE EXCEPTION 'Only the cart owner, admin, or current locker can unlock this cart';
        END IF;
    END IF;

    UPDATE public.carts
    SET is_locked = false,
        locked_by = NULL,
        locked_at = NULL
    WHERE id = p_cart_id;

    RETURN jsonb_build_object('success', true, 'is_locked', false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
