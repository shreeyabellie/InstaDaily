-- ============================================================
-- InstaDaily: Smart Pantry Schema & Automation Functions
-- Migration: 03_smart_pantry_schema.sql
-- Role: Member 4 (Database Schema & Realtime WebSockets)
-- ============================================================

-- This migration exclusively owns the Smart Pantry tables, triggers,
-- automated cadence tracking, price-drop alert detection, and Realtime.
-- Column names strictly conform to 01_initial_schema.sql:
--   - orders.order_status
--   - notifications.recipient_id
--   - notifications.metadata
--   - products.selling_price_paise

-- ------------------------------------------------------------
-- 1. SMART PANTRY TABLES
-- ------------------------------------------------------------

-- PANTRY ITEMS
CREATE TABLE IF NOT EXISTS public.pantry_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity >= 0),
    is_low_stock BOOLEAN DEFAULT false NOT NULL,
    last_purchased_at TIMESTAMPTZ,
    expected_exhaustion_date DATE,
    auto_reorder BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT unique_user_pantry_product UNIQUE (user_id, product_id)
);

-- PRODUCT PURCHASE STATS (Cadence tracking)
CREATE TABLE IF NOT EXISTS public.product_purchase_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    total_purchases INTEGER NOT NULL DEFAULT 1 CHECK (total_purchases >= 0),
    last_purchased_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    average_interval_days NUMERIC(8, 2) DEFAULT 0 CHECK (average_interval_days >= 0),
    cadence_confidence NUMERIC(3, 2) DEFAULT 0 CHECK (cadence_confidence >= 0 AND cadence_confidence <= 1),
    predicted_next_purchase_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    CONSTRAINT unique_user_product_stats UNIQUE (user_id, product_id)
);

-- PRICE DROP ALERTS
CREATE TABLE IF NOT EXISTS public.price_drop_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    target_price_paise INTEGER NOT NULL CHECK (target_price_paise > 0),
    alert_triggered BOOLEAN DEFAULT false NOT NULL,
    triggered_at TIMESTAMPTZ,
    triggered_price_paise INTEGER,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- ------------------------------------------------------------
-- 2. INDEXES
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pantry_items_user ON public.pantry_items(user_id);
CREATE INDEX IF NOT EXISTS idx_purchase_stats_user ON public.product_purchase_stats(user_id);
CREATE INDEX IF NOT EXISTS idx_price_drop_alerts_user ON public.price_drop_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_price_drop_alerts_product ON public.price_drop_alerts(product_id);

-- ------------------------------------------------------------
-- 3. UPDATED_AT TRIGGERS
-- ------------------------------------------------------------
CREATE TRIGGER tr_pantry_items_updated_at 
BEFORE UPDATE ON public.pantry_items 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_purchase_stats_updated_at 
BEFORE UPDATE ON public.product_purchase_stats 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER tr_price_drop_alerts_updated_at 
BEFORE UPDATE ON public.price_drop_alerts 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------
ALTER TABLE public.pantry_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_purchase_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.price_drop_alerts ENABLE ROW LEVEL SECURITY;

-- Pantry Items RLS
CREATE POLICY "Users view own pantry items" ON public.pantry_items FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own pantry items" ON public.pantry_items FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own pantry items" ON public.pantry_items FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own pantry items" ON public.pantry_items FOR DELETE USING (auth.uid() = user_id);

-- Purchase Stats RLS
CREATE POLICY "Users view own purchase stats" ON public.product_purchase_stats FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own purchase stats" ON public.product_purchase_stats FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own purchase stats" ON public.product_purchase_stats FOR UPDATE USING (auth.uid() = user_id);

-- Price Drop Alerts RLS
CREATE POLICY "Users view own price drop alerts" ON public.price_drop_alerts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users insert own price drop alerts" ON public.price_drop_alerts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own price drop alerts" ON public.price_drop_alerts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own price drop alerts" ON public.price_drop_alerts FOR DELETE USING (auth.uid() = user_id);

-- ------------------------------------------------------------
-- 5. REALTIME PUBLICATION CONFIGURATION
-- ------------------------------------------------------------
ALTER TABLE public.pantry_items REPLICA IDENTITY FULL;
ALTER TABLE public.price_drop_alerts REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'pantry_items'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.pantry_items;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'price_drop_alerts'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.price_drop_alerts;
    END IF;
EXCEPTION
    WHEN undefined_object THEN
        NULL;
END;
$$;

-- ------------------------------------------------------------
-- 6. PURCHASE CADENCE & PANTRY UPDATE TRIGGER ON DELIVERED ORDERS
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_delivered_order_pantry()
RETURNS TRIGGER AS $$
DECLARE
    v_item RECORD;
    v_stats RECORD;
    v_interval_days NUMERIC(8, 2);
    v_new_avg_interval NUMERIC(8, 2);
    v_new_confidence NUMERIC(3, 2);
    v_predicted_date TIMESTAMPTZ;
    v_exhaustion_date DATE;
BEGIN
    -- Only execute when order transitions to 'delivered'
    IF NEW.order_status = 'delivered' AND (OLD.order_status IS DISTINCT FROM 'delivered') THEN
        -- Loop through every purchased product in this delivered order
        FOR v_item IN
            SELECT product_id, quantity
            FROM public.order_items
            WHERE order_id = NEW.id
        LOOP
            -- Check existing purchase cadence stats for (user_id, product_id)
            SELECT * INTO v_stats
            FROM public.product_purchase_stats
            WHERE user_id = NEW.user_id AND product_id = v_item.product_id;

            IF v_stats.id IS NOT NULL THEN
                -- Calculate days elapsed since last purchase
                v_interval_days := GREATEST(1.0, EXTRACT(EPOCH FROM (now() - v_stats.last_purchased_at)) / 86400.0);

                -- Weighted moving average for purchase interval
                v_new_avg_interval := ROUND(
                    ((v_stats.average_interval_days * v_stats.total_purchases) + v_interval_days) / (v_stats.total_purchases + 1),
                    2
                );

                -- Increase confidence score asymptotically toward 0.99
                v_new_confidence := LEAST(0.99, ROUND(v_stats.cadence_confidence + 0.15, 2));

                -- Predict next purchase based on new average interval
                v_predicted_date := now() + (v_new_avg_interval || ' days')::INTERVAL;
                v_exhaustion_date := (now() + (v_new_avg_interval || ' days')::INTERVAL)::DATE;

                UPDATE public.product_purchase_stats
                SET total_purchases = v_stats.total_purchases + 1,
                    average_interval_days = v_new_avg_interval,
                    cadence_confidence = v_new_confidence,
                    last_purchased_at = now(),
                    predicted_next_purchase_at = v_predicted_date,
                    updated_at = now()
                WHERE id = v_stats.id;
            ELSE
                -- First recorded purchase of this product by this user
                v_new_avg_interval := 14.00; -- Default 2-week baseline
                v_new_confidence := 0.20;
                v_predicted_date := now() + INTERVAL '14 days';
                v_exhaustion_date := (now() + INTERVAL '14 days')::DATE;

                INSERT INTO public.product_purchase_stats (
                    user_id,
                    product_id,
                    total_purchases,
                    last_purchased_at,
                    average_interval_days,
                    cadence_confidence,
                    predicted_next_purchase_at
                )
                VALUES (
                    NEW.user_id,
                    v_item.product_id,
                    1,
                    now(),
                    v_new_avg_interval,
                    v_new_confidence,
                    v_predicted_date
                );
            END IF;

            -- Upsert into pantry_items
            INSERT INTO public.pantry_items (
                user_id,
                product_id,
                quantity,
                is_low_stock,
                last_purchased_at,
                expected_exhaustion_date,
                auto_reorder
            )
            VALUES (
                NEW.user_id,
                v_item.product_id,
                v_item.quantity,
                false,
                now(),
                v_exhaustion_date,
                false
            )
            ON CONFLICT (user_id, product_id) DO UPDATE
            SET quantity = public.pantry_items.quantity + EXCLUDED.quantity,
                is_low_stock = false,
                last_purchased_at = now(),
                expected_exhaustion_date = v_exhaustion_date,
                updated_at = now();

        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_order_delivered_pantry ON public.orders;
CREATE TRIGGER tr_order_delivered_pantry
AFTER UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.handle_delivered_order_pantry();

-- ------------------------------------------------------------
-- 7. PRICE DROP ALERT DETECTION TRIGGER
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_price_drop_alerts()
RETURNS TRIGGER AS $$
DECLARE
    v_alert RECORD;
    v_drop_amount_paise INTEGER;
BEGIN
    -- Only trigger when selling_price_paise has decreased
    IF (NEW.selling_price_paise < OLD.selling_price_paise) THEN
        v_drop_amount_paise := OLD.selling_price_paise - NEW.selling_price_paise;

        -- Find active alerts whose target price threshold is satisfied by new price
        FOR v_alert IN
            SELECT id, user_id, target_price_paise
            FROM public.price_drop_alerts
            WHERE product_id = NEW.id
              AND is_active = true
              AND target_price_paise >= NEW.selling_price_paise
        LOOP
            -- Mark alert as triggered
            UPDATE public.price_drop_alerts
            SET alert_triggered = true,
                triggered_at = now(),
                triggered_price_paise = NEW.selling_price_paise,
                updated_at = now()
            WHERE id = v_alert.id;

            -- Insert notification using canonical columns: recipient_id and metadata
            INSERT INTO public.notifications (
                recipient_id,
                title,
                message,
                type,
                metadata,
                is_read,
                created_at
            )
            VALUES (
                v_alert.user_id,
                'Price Drop: ' || NEW.name,
                NEW.name || ' dropped to ₹' || TRIM(TO_CHAR(NEW.selling_price_paise / 100.0, 'FM999999990.00')) || ' (Save ₹' || TRIM(TO_CHAR(v_drop_amount_paise / 100.0, 'FM999999990.00')) || ')',
                'price_drop',
                jsonb_build_object(
                    'product_id', NEW.id,
                    'product_name', NEW.name,
                    'old_price_paise', OLD.selling_price_paise,
                    'new_price_paise', NEW.selling_price_paise,
                    'target_price_paise', v_alert.target_price_paise,
                    'alert_id', v_alert.id
                ),
                false,
                now()
            );
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_product_price_drop_alerts ON public.products;
CREATE TRIGGER tr_product_price_drop_alerts
AFTER UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.check_price_drop_alerts();

-- ------------------------------------------------------------
-- 8. LOW-STOCK DETECTION & RESTOCK RPCs
-- ------------------------------------------------------------

-- Mark a pantry item as low stock and notify user
CREATE OR REPLACE FUNCTION public.mark_pantry_low_stock(p_pantry_item_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_item RECORD;
    v_product RECORD;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT pi.id, pi.user_id, pi.product_id, pi.quantity
    INTO v_item
    FROM public.pantry_items pi
    WHERE pi.id = p_pantry_item_id AND pi.user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pantry item not found';
    END IF;

    -- Update low stock flag
    UPDATE public.pantry_items
    SET is_low_stock = true,
        updated_at = now()
    WHERE id = v_item.id;

    SELECT name, unit, selling_price_paise
    INTO v_product
    FROM public.products
    WHERE id = v_item.product_id;

    -- Send restock reminder notification using canonical recipient_id and metadata
    INSERT INTO public.notifications (
        recipient_id,
        title,
        message,
        type,
        metadata,
        is_read,
        created_at
    )
    VALUES (
        v_user_id,
        'Running Low: ' || v_product.name,
        'Your ' || v_product.name || ' (' || v_product.unit || ') is running low in your Smart Pantry. Tap to reorder.',
        'pantry_restock',
        jsonb_build_object(
            'pantry_item_id', v_item.id,
            'product_id', v_item.product_id,
            'product_name', v_product.name,
            'unit', v_product.unit,
            'price_paise', v_product.selling_price_paise
        ),
        false,
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'pantry_item_id', v_item.id,
        'is_low_stock', true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Reorder low-stock pantry item directly into a cart
CREATE OR REPLACE FUNCTION public.reorder_pantry_item_to_cart(
    p_pantry_item_id UUID,
    p_cart_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_item RECORD;
    v_result JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT product_id INTO v_item
    FROM public.pantry_items
    WHERE id = p_pantry_item_id AND user_id = v_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pantry item not found';
    END IF;

    -- Add item to cart using merge mode
    v_result := public.add_or_merge_cart_item(
        p_cart_id => p_cart_id,
        p_product_id => v_item.product_id,
        p_quantity => 1,
        p_is_shared => false,
        p_assigned_to => v_user_id,
        p_addition_token => gen_random_uuid()::TEXT,
        p_merge_mode => 'merge'
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
