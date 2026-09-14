-- Cart membership must be granted through the SECURITY DEFINER share-code RPC,
-- not by a client inserting itself into an arbitrary cart.
DROP POLICY IF EXISTS "Users join cart as member" ON public.cart_members;

-- Lock down the search path for all SECURITY DEFINER cart functions.
ALTER FUNCTION public.is_cart_member(UUID, UUID) SET search_path = public, pg_temp;
ALTER FUNCTION public.is_cart_owner_or_admin(UUID, UUID) SET search_path = public, pg_temp;
ALTER FUNCTION public.create_shared_cart(TEXT, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.join_cart_by_share_code(TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.add_or_merge_cart_item(UUID, UUID, INTEGER, BOOLEAN, UUID, TEXT, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.lock_cart_for_checkout(UUID) SET search_path = public, pg_temp;
ALTER FUNCTION public.unlock_cart(UUID) SET search_path = public, pg_temp;

-- Explicitly expose only the application RPCs. Helper functions are server-only.
REVOKE ALL ON FUNCTION public.is_cart_member(UUID, UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_cart_owner_or_admin(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_shared_cart(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_cart_by_share_code(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_or_merge_cart_item(UUID, UUID, INTEGER, BOOLEAN, UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.lock_cart_for_checkout(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unlock_cart(UUID) TO authenticated;
