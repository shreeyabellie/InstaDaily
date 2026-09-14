-- ============================================================
-- InstaDaily: Realistic Indian Grocery Seed Data
-- Migration: seed.sql
-- Role: Member 4 (Database Schema & Realtime WebSockets)
-- ============================================================

-- ------------------------------------------------------------
-- 1. DEMO AUTH USERS & PROFILES
-- ------------------------------------------------------------
-- Safely populate auth.users to satisfy foreign key constraints
INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    phone
) VALUES
('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'aarav@instadaily.in', crypt('password123', gen_salt('bf')), now(), '{"provider":"phone","providers":["phone"]}'::jsonb, '{"full_name":"Aarav Sharma","display_name":"Aarav"}'::jsonb, now(), now(), '+919876543210'),
('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'priya@instadaily.in', crypt('password123', gen_salt('bf')), now(), '{"provider":"phone","providers":["phone"]}'::jsonb, '{"full_name":"Priya Patel","display_name":"Priya"}'::jsonb, now(), now(), '+919876543211'),
('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rohan@instadaily.in', crypt('password123', gen_salt('bf')), now(), '{"provider":"phone","providers":["phone"]}'::jsonb, '{"full_name":"Rohan Gupta","display_name":"Rohan"}'::jsonb, now(), now(), '+919876543212')
ON CONFLICT (id) DO NOTHING;

-- Profiles (matching demo user UUIDs)
INSERT INTO public.profiles (id, phone, full_name, display_name, avatar_url) VALUES
('00000000-0000-0000-0000-000000000001', '+919876543210', 'Aarav Sharma', 'Aarav', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=120'),
('00000000-0000-0000-0000-000000000002', '+919876543211', 'Priya Patel', 'Priya', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120'),
('00000000-0000-0000-0000-000000000003', '+919876543212', 'Rohan Gupta', 'Rohan', 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=120')
ON CONFLICT (id) DO UPDATE 
SET full_name = EXCLUDED.full_name,
    display_name = EXCLUDED.display_name,
    avatar_url = EXCLUDED.avatar_url;

-- Addresses (Matches app/page.tsx header: "Home — Koramangala, Bengaluru")
INSERT INTO public.addresses (
    id, user_id, label, address_line1, address_line2, landmark, city, state, pincode, is_default
) VALUES (
    'd0000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'Home',
    'Flat 402, Sunshine Heights',
    '4th Cross, 5th Block',
    'Near Sony World Signal',
    'Bengaluru',
    'Karnataka',
    '560034',
    true
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_preferences (id, user_id, express_mode, dietary_preference, notifications_enabled) VALUES
('e0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', true, 'veg', true)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- 2. BRANDS
-- ------------------------------------------------------------
INSERT INTO public.brands (id, name, slug, logo_url) VALUES
('b0000000-0000-0000-0000-000000000001', 'Amul', 'amul', 'https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?w=200'),
('b0000000-0000-0000-0000-000000000002', 'Aashirvaad', 'aashirvaad', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=200'),
('b0000000-0000-0000-0000-000000000003', 'Tata', 'tata', 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=200'),
('b0000000-0000-0000-0000-000000000004', 'Fortune', 'fortune', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=200'),
('b0000000-0000-0000-0000-000000000005', 'MDH', 'mdh', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=200'),
('b0000000-0000-0000-0000-000000000006', 'Everest', 'everest', 'https://images.unsplash.com/photo-1509358271058-acd22cc93898?w=200'),
('b0000000-0000-0000-0000-000000000007', 'Mother Dairy', 'mother-dairy', 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=200'),
('b0000000-0000-0000-0000-000000000008', 'Britannia', 'britannia', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=200')
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- 3. CATEGORIES
-- ------------------------------------------------------------
INSERT INTO public.categories (id, name, slug, image_url) VALUES
('c0000000-0000-0000-0000-000000000001', 'Dairy & Breakfast', 'dairy-breakfast', 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400'),
('c0000000-0000-0000-0000-000000000002', 'Atta & Flours', 'atta-flours', 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400'),
('c0000000-0000-0000-0000-000000000003', 'Dals & Pulses', 'dals-pulses', 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=400'),
('c0000000-0000-0000-0000-000000000004', 'Oils & Ghee', 'oils-ghee', 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400'),
('c0000000-0000-0000-0000-000000000005', 'Spices & Masalas', 'spices-masalas', 'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=400'),
('c0000000-0000-0000-0000-000000000006', 'Bakery & Breads', 'bakery-breads', 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400'),
('c0000000-0000-0000-0000-000000000007', 'Snacks & Biscuits', 'snacks-biscuits', 'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?w=400'),
('c0000000-0000-0000-0000-000000000008', 'Beverages & Tea', 'beverages-tea', 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=400')
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- 4. PRODUCTS (ALL PRICES IN PAISE, MATCHING UI SPECIFICATION)
-- ------------------------------------------------------------
INSERT INTO public.products (
    id, slug, name, brand_id, category_id, unit, pack_size, description,
    mrp_paise, selling_price_paise, delivery_eta_minutes, is_active, is_veg, nutritional_info
) VALUES
-- Amul Dairy Products (Matches app/page.tsx)
('a0000000-0000-0000-0000-000000000001', 'prod_amul_toned_milk_500ml', 'Amul Taaza Toned Milk', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '500 ml', '500ml pouch', 'Homogenized toned milk with 3.0% fat and 8.5% SNF.', 3000, 2900, 10, true, true, '{"calories": 58, "protein_g": 3.0, "fat_g": 3.0, "carbs_g": 4.8}'::jsonb),
('a0000000-0000-0000-0000-000000000002', 'prod_amul_butter_500g', 'Amul Pasteurised Butter', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '500 g', '500g carton', 'Utterly butterly delicious pasteurised salted butter made from fresh cream.', 28500, 27500, 10, true, true, '{"calories": 722, "fat_g": 80.0, "protein_g": 0.5}'::jsonb),
('a0000000-0000-0000-0000-000000000003', 'prod_amul_curd_400g', 'Amul Fresh Curd', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '400 g', '400g tub', 'Thick, creamy, pasteurized dahi prepared from cultured milk.', 4000, 3900, 9, true, true, '{"calories": 62, "protein_g": 3.7, "fat_g": 3.1}'::jsonb),
('a0000000-0000-0000-0000-000000000004', 'prod_amul_gold_milk_1l', 'Amul Gold Full Cream Milk', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '1 L', '1L tetra pack', 'Rich and creamy full cream milk with 6.0% fat and 9.0% SNF.', 7200, 6900, 11, true, true, '{"calories": 87, "protein_g": 3.5, "fat_g": 6.0}'::jsonb),
('a0000000-0000-0000-0000-000000000005', 'prod_amul_cheese_slices_200g', 'Amul Cheese Slices', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '200 g, 10 slices', '10 slices pack', 'Processed cheese slices perfect for sandwiches and burgers.', 13500, 12900, 10, true, true, '{"calories": 310, "protein_g": 20.0, "calcium_mg": 650}'::jsonb),
('a0000000-0000-0000-0000-000000000006', 'prod_amul_ghee_1l', 'Amul Pure Ghee', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000004', '1 L', '1L carton', 'Traditional pure desi ghee crafted from fresh milk fat with rich aroma.', 65900, 62900, 13, true, true, '{"calories": 900, "fat_g": 99.7}'::jsonb),
('a0000000-0000-0000-0000-000000000007', 'prod_amul_paneer_200g', 'Amul Fresh Paneer', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', '200 g', '200g vacuum pack', 'Soft and fresh malai paneer, rich in milk proteins.', 10500, 9900, 10, true, true, '{"calories": 289, "protein_g": 18.0, "fat_g": 22.0}'::jsonb),
('a0000000-0000-0000-0000-000000000008', 'prod_amul_lassi_200ml', 'Amul Masti Lassi', 'b0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000008', '200 ml', '200ml tetra pack', 'Refreshing traditional sweetened yogurt drink.', 3500, 3500, 9, true, true, '{"calories": 84, "protein_g": 2.2, "carbs_g": 13.5}'::jsonb),

-- Aashirvaad Staples (Matches app/page.tsx)
('a0000000-0000-0000-0000-000000000009', 'prod_aashirvaad_atta_5kg', 'Aashirvaad Select Sharbati Atta', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', '5 kg', '5kg bag', 'Made from 100% MP Sharbati wheat grains for softer rotis.', 35500, 32900, 12, true, true, '{"calories": 360, "protein_g": 12.0, "fiber_g": 11.2}'::jsonb),
('a0000000-0000-0000-0000-000000000010', 'prod_aashirvaad_multigrain_atta_5kg', 'Aashirvaad Multigrain Atta', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', '5 kg', '5kg bag', 'Wholesome blend of wheat, soya, chana, oat, maize, and psyllium husk.', 36900, 33900, 14, true, true, '{"calories": 365, "protein_g": 14.5, "fiber_g": 13.0}'::jsonb),
('a0000000-0000-0000-0000-000000000011', 'prod_aashirvaad_salt_1kg', 'Aashirvaad Iodised Salt', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000005', '1 kg', '1kg pouch', 'Solar-evaporated pure iodized table salt with moisture-lock technology.', 3000, 2800, 9, true, true, '{"sodium_mg": 38700, "iodine_ppm": 15}'::jsonb),
('a0000000-0000-0000-0000-000000000012', 'prod_aashirvaad_besan_1kg', 'Aashirvaad Besan', 'b0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000002', '1 kg', '1kg pouch', '100% pure chana dal ground besan with fine texture.', 12900, 11900, 12, true, true, '{"calories": 387, "protein_g": 22.0, "fiber_g": 10.8}'::jsonb),

-- Tata Products
('a0000000-0000-0000-0000-000000000013', 'prod_tata_sampann_toordal_1kg', 'Tata Sampann Unpolished Toor Dal', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000003', '1 kg', '1kg pouch', 'Naturally protein-rich unpolished arhar dal without artificial polish.', 19500, 17500, 11, true, true, '{"calories": 343, "protein_g": 22.3, "fiber_g": 15.0}'::jsonb),
('a0000000-0000-0000-0000-000000000014', 'prod_tata_tea_gold_500g', 'Tata Tea Gold', 'b0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000008', '500 g', '500g pouch', 'Exquisite blend of CTC tea with gently rolled long leaves for superior aroma.', 34000, 31000, 10, true, true, '{"caffeine_mg": 45, "antioxidants": "rich"}'::jsonb),

-- Fortune Oils
('a0000000-0000-0000-0000-000000000015', 'prod_fortune_sunflower_oil_1l', 'Fortune Sunlite Refined Sunflower Oil', 'b0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000004', '1 L', '1L pouch', 'Light and healthy sunflower cooking oil enriched with Vitamins A and D.', 16500, 14500, 11, true, true, '{"calories": 900, "fat_g": 100.0, "vit_a_mcg": 750}'::jsonb),

-- Spices & Masalas (MDH & Everest)
('a0000000-0000-0000-0000-000000000016', 'prod_mdh_deggi_mirch_100g', 'MDH Deggi Mirch Powder', 'b0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005', '100 g', '100g carton', 'Unique blend of red pepper offering rich natural red colour and mild heat.', 9800, 9200, 10, true, true, '{"calories": 320, "capsaicin": "mild"}'::jsonb),
('a0000000-0000-0000-0000-000000000017', 'prod_everest_garam_masala_100g', 'Everest Garam Masala', 'b0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000005', '100 g', '100g carton', 'Aromatic blend of 13 whole spices roasted to perfection.', 9500, 8800, 10, true, true, '{"calories": 380, "protein_g": 11.0}'::jsonb),
('a0000000-0000-0000-0000-000000000018', 'prod_everest_kasuri_methi_50g', 'Everest Kasuri Methi', 'b0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000005', '50 g', '50g box', 'Sun-dried fenugreek leaves from Nagaur, Rajasthan for authentic curries.', 4800, 4200, 10, true, true, '{"iron_mg": 33, "fiber_g": 24}'::jsonb),

-- Bakery & Biscuits (Britannia)
('a0000000-0000-0000-0000-000000000019', 'prod_britannia_brown_bread_400g', 'Britannia 100% Whole Wheat Bread', 'b0000000-0000-0000-0000-000000000008', 'c0000000-0000-0000-0000-000000000006', '400 g', '400g sliced loaf', 'Healthy whole wheat loaf made without maida, enriched with dietary fiber.', 5000, 4500, 10, true, true, '{"calories": 245, "protein_g": 9.0, "fiber_g": 6.5}'::jsonb),
('a0000000-0000-0000-0000-000000000020', 'prod_britannia_good_day_200g', 'Britannia Good Day Butter Cookies', 'b0000000-0000-0000-0000-000000000008', 'c0000000-0000-0000-0000-000000000007', '200 g', '200g pack', 'Rich butter biscuits with smiley patterns and crunchy bite.', 4500, 4000, 9, true, true, '{"calories": 485, "fat_g": 21.0, "carbs_g": 68.0}'::jsonb),

-- Mother Dairy Milk
('a0000000-0000-0000-0000-000000000021', 'prod_mother_dairy_milk_1l', 'Mother Dairy Full Cream Milk', 'b0000000-0000-0000-0000-000000000007', 'c0000000-0000-0000-0000-000000000001', '1 L', '1L pouch', 'Wholesome full cream cow and buffalo milk blend with 6.0% milk fat.', 7000, 6800, 11, true, true, '{"calories": 88, "protein_g": 3.4, "fat_g": 6.0}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- 5. FULFILLMENT DARK STORES & INVENTORY
-- ------------------------------------------------------------
INSERT INTO public.fulfillment_locations (id, name, address, city, pincode, latitude, longitude, is_active) VALUES
('f0000000-0000-0000-0000-000000000001', 'Koramangala Dark Store Hub', '80 Feet Road, 4th Block, Koramangala', 'Bengaluru', '560034', 12.9352, 77.6245, true),
('f0000000-0000-0000-0000-000000000002', 'Indiranagar Hub', '100 Feet Road, HAL 2nd Stage, Indiranagar', 'Bengaluru', '560038', 12.9719, 77.6412, true),
('f0000000-0000-0000-0000-000000000003', 'HSR Layout Store', '27th Main, Sector 1, HSR Layout', 'Bengaluru', '560102', 12.9121, 77.6446, true)
ON CONFLICT (id) DO NOTHING;

-- Seed inventory for all products across Koramangala Hub
INSERT INTO public.inventory (product_id, location_id, stock_quantity, reserved_quantity)
SELECT 
    p.id,
    'f0000000-0000-0000-0000-000000000001'::uuid,
    150,
    5
FROM public.products p
ON CONFLICT (product_id, location_id) DO NOTHING;

-- ------------------------------------------------------------
-- 6. CHEF MODE RECIPES & INGREDIENTS
-- ------------------------------------------------------------

-- Ingredients
INSERT INTO public.ingredients (id, name, category) VALUES
('90000000-0000-0000-0000-000000000001', 'Fresh Paneer', 'Dairy'),
('90000000-0000-0000-0000-000000000002', 'Salted Butter', 'Dairy'),
('90000000-0000-0000-0000-000000000003', 'Fresh Cream / Malai', 'Dairy'),
('90000000-0000-0000-0000-000000000004', 'Kashmiri Red Chilli', 'Spices'),
('90000000-0000-0000-0000-000000000005', 'Garam Masala', 'Spices'),
('90000000-0000-0000-0000-000000000006', 'Kasuri Methi', 'Spices'),
('90000000-0000-0000-0000-000000000007', 'Iodised Salt', 'Pantry'),
('90000000-0000-0000-0000-000000000008', 'Desi Ghee', 'Dairy'),
('90000000-0000-0000-0000-000000000009', 'Pure Sunflower Oil', 'Cooking Oils'),
('90000000-0000-0000-0000-000000000010', 'Black Urad Dal', 'Lentils'),
('90000000-0000-0000-0000-000000000011', 'Tea Leaves', 'Beverages'),
('90000000-0000-0000-0000-000000000012', 'Fresh Toned Milk', 'Dairy')
ON CONFLICT (id) DO NOTHING;

-- Map Chef Mode Ingredients to Store SKUs
INSERT INTO public.ingredient_product_mappings (ingredient_id, product_id, is_default, priority) VALUES
('90000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000007', true, 1), -- Paneer -> Amul Fresh Paneer
('90000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', true, 1), -- Butter -> Amul Butter
('90000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000016', true, 1), -- Chilli -> MDH Deggi Mirch
('90000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000017', true, 1), -- Garam Masala -> Everest Garam Masala
('90000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000018', true, 1), -- Kasuri Methi -> Everest Kasuri Methi
('90000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000011', true, 1), -- Salt -> Aashirvaad Salt
('90000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000006', true, 1), -- Ghee -> Amul Pure Ghee
('90000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000015', true, 1), -- Oil -> Fortune Sunflower Oil
('90000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000014', true, 1), -- Tea -> Tata Tea Gold
('90000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000001', true, 1)  -- Milk -> Amul Toned Milk
ON CONFLICT (ingredient_id, product_id) DO NOTHING;

-- Recipe 1: Paneer Butter Masala (Exact match for app/page.tsx id: 'recipe_paneer_butter_masala')
INSERT INTO public.recipes (
    id, title, slug, description, image_url, prep_time_minutes, cook_time_minutes, servings, is_veg
) VALUES (
    '80000000-0000-0000-0000-000000000001',
    'Paneer Butter Masala',
    'recipe_paneer_butter_masala',
    'Restaurant-style paneer butter masala with Amul Paneer, Amul Butter, and pantry staples — all delivered together in one basket.',
    'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=600',
    15,
    35,
    4,
    true
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.recipe_ingredients (recipe_id, ingredient_id, quantity, unit, optional, notes) VALUES
('80000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001', 400.00, 'g', false, 'Cut into 1-inch cubes'),
('80000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 50.00, 'g', false, 'Divided into two batches'),
('80000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000004', 2.00, 'tsp', false, 'Gives the rich red signature gravy hue'),
('80000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000005', 1.00, 'tsp', false, 'Freshly grounded'),
('80000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000006', 1.00, 'tbsp', false, 'Rubbed between palms'),
('80000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000007', 1.50, 'tsp', false, 'To taste'),
('80000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000009', 1.00, 'tbsp', false, 'For tempering gravy')
ON CONFLICT (recipe_id, ingredient_id) DO NOTHING;

INSERT INTO public.recipe_steps (recipe_id, step_number, instruction, duration_minutes) VALUES
('80000000-0000-0000-0000-000000000001', 1, 'Heat 1 tbsp oil and 25g Amul Butter in a heavy bottom pan. Add tomato puree, ginger garlic paste, and simmer for 8 minutes.', 10),
('80000000-0000-0000-0000-000000000001', 2, 'Add MDH Deggi Mirch, turmeric, and Everest Garam Masala. Sauté until oil separates from the masala.', 7),
('80000000-0000-0000-0000-000000000001', 3, 'Gently slide in fresh Amul Paneer cubes, remaining butter, crushed Everest Kasuri Methi, and simmer on low flame for 5 minutes.', 5)
ON CONFLICT (recipe_id, step_number) DO NOTHING;

-- Recipe 2: Dal Makhani
INSERT INTO public.recipes (
    id, title, slug, description, image_url, prep_time_minutes, cook_time_minutes, servings, is_veg
) VALUES (
    '80000000-0000-0000-0000-000000000002',
    'Dal Makhani',
    'recipe_dal_makhani',
    'Authentic Punjabi slow-cooked black lentils simmered with Amul Butter, pure ghee, and mild spices.',
    'https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600',
    20,
    45,
    4,
    true
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.recipe_ingredients (recipe_id, ingredient_id, quantity, unit, optional, notes) VALUES
('80000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000010', 250.00, 'g', false, 'Soaked overnight'),
('80000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000002', 60.00, 'g', false, 'Amul Salted Butter'),
('80000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000008', 2.00, 'tbsp', false, 'Amul Desi Ghee'),
('80000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000004', 1.50, 'tsp', false, 'For aroma and colour'),
('80000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000006', 1.00, 'tbsp', false, 'Crushed fenugreek'),
('80000000-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000007', 1.50, 'tsp', false, 'Iodised Salt')
ON CONFLICT (recipe_id, ingredient_id) DO NOTHING;

INSERT INTO public.recipe_steps (recipe_id, step_number, instruction, duration_minutes) VALUES
('80000000-0000-0000-0000-000000000002', 1, 'Pressure cook soaked black urad dal with salt and water for 6 whistles until velvety soft.', 25),
('80000000-0000-0000-0000-000000000002', 2, 'Prepare tadka in desi ghee with ginger garlic, tomato puree, and Deggi Mirch.', 10),
('80000000-0000-0000-0000-000000000002', 3, 'Combine dal with tadka and simmer with generous Amul butter and kasuri methi on low heat.', 10)
ON CONFLICT (recipe_id, step_number) DO NOTHING;

-- ------------------------------------------------------------
-- 7. COLLABORATIVE SYNC CART DEMO
-- ------------------------------------------------------------
INSERT INTO public.carts (
    id, owner_id, is_shared, name, share_code, is_locked, billing_type, status
) VALUES (
    '11111111-1111-1111-1111-111111111111',
    '00000000-0000-0000-0000-000000000001',
    true,
    'Weekend Dinner Cart',
    'WKND26',
    false,
    'split_by_item',
    'active'
) ON CONFLICT (id) DO NOTHING;

-- Members: Aarav (owner) and Priya (member)
INSERT INTO public.cart_members (cart_id, user_id, role, last_active_at) VALUES
('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000001', 'owner', now()),
('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000002', 'member', now())
ON CONFLICT (cart_id, user_id) DO NOTHING;

-- Live collaborative items in the shared cart
INSERT INTO public.cart_items (
    id, cart_id, product_id, added_by, assigned_to, quantity, unit_price_paise, is_shared, addition_token
) VALUES
('22222222-2222-2222-2222-222222222201', '11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 2, 9900, false, 'token_aarav_paneer'),
('22222222-2222-2222-2222-222222222202', '11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 1, 27500, false, 'token_priya_butter'),
('22222222-2222-2222-2222-222222222203', '11111111-1111-1111-1111-111111111111', 'a0000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000001', NULL, 1, 32900, true, 'token_group_atta')
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- 8. SMART PANTRY DEMO DATA & PURCHASE CADENCE
-- ------------------------------------------------------------

-- Persistent Pantry Items (Demonstrating low-stock detection & cadence)
INSERT INTO public.pantry_items (
    id, user_id, product_id, quantity, is_low_stock, last_purchased_at, expected_exhaustion_date, auto_reorder
) VALUES
('33333333-3333-3333-3333-333333333301', '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1, true, now() - INTERVAL '4 days', current_date - 1, true),
('33333333-3333-3333-3333-333333333302', '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000009', 1, false, now() - INTERVAL '18 days', current_date + 12, false),
('33333333-3333-3333-3333-333333333303', '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 2, false, now() - INTERVAL '2 days', current_date + 5, false)
ON CONFLICT (id) DO NOTHING;

-- Purchase Cadence Statistics
INSERT INTO public.product_purchase_stats (
    id, user_id, product_id, total_purchases, last_purchased_at, average_interval_days, cadence_confidence, predicted_next_purchase_at
) VALUES
('44444444-4444-4444-4444-444444444401', '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 8, now() - INTERVAL '4 days', 3.50, 0.85, now() - INTERVAL '12 hours'),
('44444444-4444-4444-4444-444444444402', '00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000009', 4, now() - INTERVAL '18 days', 30.00, 0.70, now() + INTERVAL '12 days')
ON CONFLICT (id) DO NOTHING;

-- Price Drop Alert
INSERT INTO public.price_drop_alerts (
    id, user_id, product_id, target_price_paise, alert_triggered, triggered_at, triggered_price_paise, is_active
) VALUES (
    '55555555-5555-5555-5555-555555555501',
    '00000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000006', -- Amul Ghee
    62000, -- Target ₹620.00 (Current ₹629.00)
    false,
    NULL,
    NULL,
    true
) ON CONFLICT (id) DO NOTHING;

-- Notifications (Canonical columns: recipient_id and metadata)
INSERT INTO public.notifications (
    id, recipient_id, title, message, type, metadata, is_read
) VALUES
('66666666-6666-6666-6666-666666666601', '00000000-0000-0000-0000-000000000001', 'Running Low: Amul Taaza Toned Milk', 'Your Amul Taaza Toned Milk (500 ml) is running low in your Smart Pantry. Tap to reorder.', 'pantry_restock', '{"pantry_item_id": "33333333-3333-3333-3333-333333333301", "product_id": "a0000000-0000-0000-0000-000000000001"}'::jsonb, false),
('66666666-6666-6666-6666-666666666602', '00000000-0000-0000-0000-000000000001', 'Priya added an item to your cart', 'Priya Patel added Amul Pasteurised Butter to Weekend Dinner Cart.', 'cart_activity', '{"cart_id": "11111111-1111-1111-1111-111111111111", "item_id": "22222222-2222-2222-2222-222222222202"}'::jsonb, true)
ON CONFLICT (id) DO NOTHING;
