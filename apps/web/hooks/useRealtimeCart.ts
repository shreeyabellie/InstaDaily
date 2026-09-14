'use client';

import { useEffect, useState, useCallback, useRef } from 'react';
import { createClient } from '../lib/supabase/client';
import type { RealtimeChannel } from '@supabase/supabase-js';

export interface CartProduct {
  id: string;
  name: string;
  slug: string;
  unit: string;
  pack_size?: string | null;
  image_url?: string | null;
  mrp_paise: number;
  selling_price_paise: number;
  is_veg: boolean;
}

export interface CartItem {
  id: string;
  cart_id: string;
  product_id: string;
  added_by: string;
  assigned_to?: string | null;
  quantity: number;
  unit_price_paise: number;
  is_shared: boolean;
  addition_token?: string | null;
  created_at: string;
  updated_at: string;
  product?: CartProduct | null;
}

export interface CartMember {
  id: string;
  cart_id: string;
  user_id: string;
  role: 'owner' | 'admin' | 'member' | 'editor' | 'viewer';
  last_active_at: string;
  joined_at: string;
  display_name?: string | null;
  avatar_url?: string | null;
}

export interface Cart {
  id: string;
  owner_id: string;
  is_shared: boolean;
  name: string;
  share_code?: string | null;
  is_locked: boolean;
  locked_by?: string | null;
  locked_at?: string | null;
  billing_type: 'single' | 'split_equal' | 'split_by_item';
  status: 'active' | 'checked_out' | 'abandoned';
  created_at: string;
  updated_at: string;
}

export interface PresenceUser {
  id: string;
  name: string;
  imageUrl?: string;
  onlineAt: string;
}

export type RealtimeConnectionStatus = 'connecting' | 'connected' | 'disconnected' | 'error';

export interface AddItemOptions {
  quantity?: number;
  isShared?: boolean;
  assignedTo?: string | null;
  additionToken?: string | null;
  mergeMode?: 'detect_only' | 'merge' | 'keep_both';
}

export interface AddItemResult {
  conflict: boolean;
  action?: string;
  cart_item_id?: string;
  existing_item_id?: string;
  existing_quantity?: number;
  new_quantity?: number;
  message?: string;
}

export interface UseRealtimeCartReturn {
  cart: Cart | null;
  items: CartItem[];
  members: CartMember[];
  activeUsers: PresenceUser[];
  status: RealtimeConnectionStatus;
  isLoading: boolean;
  error: Error | null;
  addItem: (productId: string, options?: AddItemOptions) => Promise<AddItemResult>;
  updateQuantity: (itemId: string, quantity: number) => Promise<void>;
  removeItem: (itemId: string) => Promise<void>;
  lockCart: () => Promise<void>;
  unlockCart: () => Promise<void>;
  refresh: () => Promise<void>;
}

/**
 * Client React hook responsible for live collaborative Sync Cart synchronization
 * via Supabase Realtime WebSockets.
 *
 * Listens for INSERT, UPDATE, DELETE events on cart_items and cart_members,
 * tracks member presence, and synchronizes cart lock state.
 */
export function useRealtimeCart(cartId: string | null): UseRealtimeCartReturn {
  const [cart, setCart] = useState<Cart | null>(null);
  const [items, setItems] = useState<CartItem[]>([]);
  const [members, setMembers] = useState<CartMember[]>([]);
  const [activeUsers, setActiveUsers] = useState<PresenceUser[]>([]);
  const [status, setStatus] = useState<RealtimeConnectionStatus>('disconnected');
  const [isLoading, setIsLoading] = useState<boolean>(Boolean(cartId));
  const [error, setError] = useState<Error | null>(null);

  const channelRef = useRef<RealtimeChannel | null>(null);
  const isMountedRef = useRef<boolean>(true);

  // Helper to fetch full initial cart data
  const fetchData = useCallback(async () => {
    if (!cartId) return;

    try {
      setIsLoading(true);
      setError(null);
      const supabase = createClient();

      // Fetch cart record
      const { data: cartData, error: cartErr } = await supabase
        .from('carts')
        .select('*')
        .eq('id', cartId)
        .single();

      if (cartErr) throw cartErr;

      // Fetch items with joined product details
      const { data: itemsData, error: itemsErr } = await supabase
        .from('cart_items')
        .select(`
          id,
          cart_id,
          product_id,
          added_by,
          assigned_to,
          quantity,
          unit_price_paise,
          is_shared,
          addition_token,
          created_at,
          updated_at,
          products:product_id (
            id,
            name,
            slug,
            unit,
            pack_size,
            image_url,
            mrp_paise,
            selling_price_paise,
            is_veg
          )
        `)
        .eq('cart_id', cartId)
        .order('created_at', { ascending: true });

      if (itemsErr) throw itemsErr;

      // Fetch cart members with profile info
      const { data: membersData, error: membersErr } = await supabase
        .from('cart_members')
        .select(`
          id,
          cart_id,
          user_id,
          role,
          last_active_at,
          joined_at,
          profiles:user_id (
            display_name,
            avatar_url
          )
        `)
        .eq('cart_id', cartId)
        .order('joined_at', { ascending: true });

      if (membersErr) throw membersErr;

      if (!isMountedRef.current) return;

      setCart(cartData as Cart);

      const formattedItems: CartItem[] = (itemsData || []).map((row: Record<string, unknown>) => {
        const prod = row.products as CartProduct | null;
        return {
          id: row.id as string,
          cart_id: row.cart_id as string,
          product_id: row.product_id as string,
          added_by: row.added_by as string,
          assigned_to: (row.assigned_to as string) || null,
          quantity: Number(row.quantity),
          unit_price_paise: Number(row.unit_price_paise),
          is_shared: Boolean(row.is_shared),
          addition_token: (row.addition_token as string) || null,
          created_at: row.created_at as string,
          updated_at: row.updated_at as string,
          product: prod,
        };
      });
      setItems(formattedItems);

      const formattedMembers: CartMember[] = (membersData || []).map((row: Record<string, unknown>) => {
        const prof = row.profiles as { display_name?: string | null; avatar_url?: string | null } | null;
        return {
          id: row.id as string,
          cart_id: row.cart_id as string,
          user_id: row.user_id as string,
          role: row.role as 'owner' | 'admin' | 'member' | 'editor' | 'viewer',
          last_active_at: row.last_active_at as string,
          joined_at: row.joined_at as string,
          display_name: prof?.display_name || null,
          avatar_url: prof?.avatar_url || null,
        };
      });
      setMembers(formattedMembers);
    } catch (err: unknown) {
      if (isMountedRef.current) {
        setError(err instanceof Error ? err : new Error(String(err)));
      }
    } finally {
      if (isMountedRef.current) {
        setIsLoading(false);
      }
    }
  }, [cartId]);

  // Set up Realtime WebSockets subscription
  useEffect(() => {
    isMountedRef.current = true;

    if (!cartId) {
      setCart(null);
      setItems([]);
      setMembers([]);
      setActiveUsers([]);
      setStatus('disconnected');
      setIsLoading(false);
      return;
    }

    const supabase = createClient();
    setStatus('connecting');

    // Initial query
    fetchData();

    // Subscribe to dedicated cart realtime channel
    const channel = supabase.channel(`sync-cart:${cartId}`, {
      config: {
        presence: { key: cartId },
      },
    });

    channelRef.current = channel;

    // 1. Listen for cart_items changes (INSERT, UPDATE, DELETE)
    channel
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'cart_items',
          filter: `cart_id=eq.${cartId}`,
        },
        async (payload) => {
          const newItem = payload.new as CartItem;
          // Fetch product metadata for the newly inserted item
          const { data: productData } = await supabase
            .from('products')
            .select('id, name, slug, unit, pack_size, image_url, mrp_paise, selling_price_paise, is_veg')
            .eq('id', newItem.product_id)
            .single();

          if (!isMountedRef.current) return;

          setItems((currentItems) => {
            const exists = currentItems.some((item) => item.id === newItem.id);
            if (exists) return currentItems;
            return [...currentItems, { ...newItem, product: (productData as CartProduct) || null }];
          });
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'cart_items',
          filter: `cart_id=eq.${cartId}`,
        },
        (payload) => {
          const updatedItem = payload.new as CartItem;
          if (!isMountedRef.current) return;

          setItems((currentItems) =>
            currentItems.map((item) =>
              item.id === updatedItem.id
                ? { ...item, ...updatedItem, product: item.product }
                : item
            )
          );
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'DELETE',
          schema: 'public',
          table: 'cart_items',
          filter: `cart_id=eq.${cartId}`,
        },
        (payload) => {
          const deletedId = (payload.old as { id?: string })?.id;
          if (!deletedId || !isMountedRef.current) return;

          setItems((currentItems) =>
            currentItems.filter((item) => item.id !== deletedId)
          );
        }
      );

    // 2. Listen for cart_members changes (INSERT, UPDATE, DELETE)
    channel
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'cart_members',
          filter: `cart_id=eq.${cartId}`,
        },
        async (payload) => {
          const newMember = payload.new as CartMember;
          const { data: profile } = await supabase
            .from('profiles')
            .select('display_name, avatar_url')
            .eq('id', newMember.user_id)
            .single();

          if (!isMountedRef.current) return;

          setMembers((current) => {
            const exists = current.some((m) => m.id === newMember.id);
            if (exists) return current;
            return [
              ...current,
              {
                ...newMember,
                display_name: profile?.display_name || null,
                avatar_url: profile?.avatar_url || null,
              },
            ];
          });
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'cart_members',
          filter: `cart_id=eq.${cartId}`,
        },
        (payload) => {
          const updatedMember = payload.new as CartMember;
          if (!isMountedRef.current) return;

          setMembers((current) =>
            current.map((m) =>
              m.id === updatedMember.id ? { ...m, ...updatedMember } : m
            )
          );
        }
      )
      .on(
        'postgres_changes',
        {
          event: 'DELETE',
          schema: 'public',
          table: 'cart_members',
          filter: `cart_id=eq.${cartId}`,
        },
        (payload) => {
          const deletedId = (payload.old as { id?: string })?.id;
          if (!deletedId || !isMountedRef.current) return;

          setMembers((current) => current.filter((m) => m.id !== deletedId));
        }
      );

    // 3. Listen for carts metadata updates (e.g. is_locked, billing_type)
    channel.on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'carts',
        filter: `id=eq.${cartId}`,
      },
      (payload) => {
        if (!isMountedRef.current) return;
        setCart((current) => (current ? { ...current, ...(payload.new as Cart) } : (payload.new as Cart)));
      }
    );

    // 4. Presence tracking for live member avatars
    channel
      .on('presence', { event: 'sync' }, () => {
        if (!isMountedRef.current) return;
        const state = channel.presenceState();
        const users: PresenceUser[] = [];

        for (const key of Object.keys(state)) {
          const presences = state[key] as Array<Record<string, unknown>>;
          for (const presence of presences) {
            if (presence.id && presence.name) {
              users.push({
                id: String(presence.id),
                name: String(presence.name),
                imageUrl: presence.imageUrl ? String(presence.imageUrl) : undefined,
                onlineAt: String(presence.onlineAt || new Date().toISOString()),
              });
            }
          }
        }
        setActiveUsers(users);
      })
      .subscribe((subscribeStatus) => {
        if (!isMountedRef.current) return;

        if (subscribeStatus === 'SUBSCRIBED') {
          setStatus('connected');
          // Track current user presence
          supabase.auth.getUser().then(({ data: { user } }) => {
            if (user && isMountedRef.current) {
              channel.track({
                id: user.id,
                name: user.user_metadata?.display_name || user.email || 'Shopper',
                imageUrl: user.user_metadata?.avatar_url,
                onlineAt: new Date().toISOString(),
              });
            }
          });
        } else if (subscribeStatus === 'CHANNEL_ERROR') {
          setStatus('error');
          setError(new Error('Realtime WebSocket connection failed'));
        } else if (subscribeStatus === 'CLOSED' || subscribeStatus === 'TIMED_OUT') {
          setStatus('disconnected');
        }
      });

    // Cleanup subscription on unmount or cart change
    return () => {
      isMountedRef.current = false;
      channel.unsubscribe();
      supabase.removeChannel(channel);
      channelRef.current = null;
    };
  }, [cartId, fetchData]);

  // Action: Add or merge cart item
  const addItem = useCallback(
    async (productId: string, options: AddItemOptions = {}): Promise<AddItemResult> => {
      if (!cartId) throw new Error('Cannot add item: no active cart selected');

      const supabase = createClient();
      const {
        quantity = 1,
        isShared = false,
        assignedTo = null,
        additionToken = null,
        mergeMode = 'detect_only',
      } = options;

      const { data, error: rpcErr } = await supabase.rpc('add_or_merge_cart_item', {
        p_cart_id: cartId,
        p_product_id: productId,
        p_quantity: quantity,
        p_is_shared: isShared,
        p_assigned_to: assignedTo,
        p_addition_token: additionToken,
        p_merge_mode: mergeMode,
      });

      if (rpcErr) throw rpcErr;
      return data as AddItemResult;
    },
    [cartId]
  );

  // Action: Update quantity of an item
  const updateQuantity = useCallback(
    async (itemId: string, quantity: number): Promise<void> => {
      if (!cartId) return;

      const supabase = createClient();

      if (quantity <= 0) {
        const { error: delErr } = await supabase
          .from('cart_items')
          .delete()
          .eq('id', itemId);

        if (delErr) throw delErr;
      } else {
        const { error: updateErr } = await supabase
          .from('cart_items')
          .update({ quantity, updated_at: new Date().toISOString() })
          .eq('id', itemId);

        if (updateErr) throw updateErr;
      }
    },
    [cartId]
  );

  // Action: Remove an item
  const removeItem = useCallback(
    async (itemId: string): Promise<void> => {
      if (!cartId) return;
      const supabase = createClient();

      const { error: delErr } = await supabase
        .from('cart_items')
        .delete()
        .eq('id', itemId);

      if (delErr) throw delErr;
    },
    [cartId]
  );

  // Action: Lock cart for checkout
  const lockCart = useCallback(async (): Promise<void> => {
    if (!cartId) return;
    const supabase = createClient();

    const { error: lockErr } = await supabase.rpc('lock_cart_for_checkout', {
      p_cart_id: cartId,
    });

    if (lockErr) throw lockErr;
  }, [cartId]);

  // Action: Unlock cart
  const unlockCart = useCallback(async (): Promise<void> => {
    if (!cartId) return;
    const supabase = createClient();

    const { error: unlockErr } = await supabase.rpc('unlock_cart', {
      p_cart_id: cartId,
    });

    if (unlockErr) throw unlockErr;
  }, [cartId]);

  return {
    cart,
    items,
    members,
    activeUsers,
    status,
    isLoading,
    error,
    addItem,
    updateQuantity,
    removeItem,
    lockCart,
    unlockCart,
    refresh: fetchData,
  };
}
