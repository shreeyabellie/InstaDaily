-- =============================================================================
-- InstaDaily — Sync Cart Schema
-- File: supabase/migrations/02_sync_cart_schema.sql
-- Target: PostgreSQL 15+ / Supabase
--
-- Purpose:
--   Shared cart membership, secure share links, collaborative editing,
--   optimistic concurrency metadata, conflict tracking, RLS, and Realtime.
--
-- Depends on:
--   01_initial_schema.sql
-- =============================================================================


-- =============================================================================
-- SECTION 1: ENUM TYPES
-- =============================================================================

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'membership_role'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.membership_role as enum (
      'owner',
      'editor',
      'viewer'
    );
  end if;
end
$$;


do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'membership_status'
      and typnamespace = 'public'::regnamespace
  ) then
    create type public.membership_status as enum (
      'invited',
      'active',
      'removed'
    );
  end if;
end
$$;


-- =============================================================================
-- SECTION 2: CART MEMBERS
-- =============================================================================

create table if not exists public.cart_members (
  id uuid primary key default gen_random_uuid(),

  cart_id uuid not null
    references public.carts(id)
    on delete cascade,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  role public.membership_role not null default 'editor',

  status public.membership_status not null default 'active',

  invited_at timestamptz,

  joined_at timestamptz,

  last_active_at timestamptz,

  created_at timestamptz not null default now(),

  updated_at timestamptz not null default now(),

  constraint cart_members_cart_user_unique
    unique (cart_id, user_id),

  constraint cart_members_joined_at_check
    check (
      status <> 'active'
      or joined_at is not null
    ),

  constraint cart_members_invited_at_check
    check (
      status = 'invited'
      or invited_at is not null
      or role = 'owner'
    )
);


-- =============================================================================
-- SECTION 3: SECURE CART SHARE LINKS
-- =============================================================================

create table if not exists public.cart_share_links (
  id uuid primary key default gen_random_uuid(),

  cart_id uuid not null
    references public.carts(id)
    on delete cascade,

  token_hash bytea not null,

  expires_at timestamptz,

  revoked_at timestamptz,

  created_by uuid not null
    references public.profiles(id)
    on delete restrict,

  created_at timestamptz not null default now(),

  constraint cart_share_links_token_hash_unique
    unique (token_hash),

  constraint cart_share_links_expiry_check
    check (
      expires_at is null
      or expires_at > created_at
    ),

  constraint cart_share_links_revoked_check
    check (
      revoked_at is null
      or revoked_at >= created_at
    )
);


-- =============================================================================
-- SECTION 4: SYNC METADATA FOR CART ITEMS
-- =============================================================================

alter table public.cart_items
  add column if not exists version bigint not null default 1;


alter table public.cart_items
  add column if not exists updated_by uuid
    references public.profiles(id)
    on delete set null;


alter table public.cart_items
  add column if not exists client_mutation_id uuid;


alter table public.cart_items
  add column if not exists last_synced_at timestamptz
    not null default now();


-- =============================================================================
-- SECTION 5: CART SYNC METADATA
-- =============================================================================

alter table public.carts
  add column if not exists version bigint not null default 1;


alter table public.carts
  add column if not exists last_modified_by uuid
    references public.profiles(id)
    on delete set null;


alter table public.carts
  add column if not exists share_enabled boolean
    not null default false;


-- =============================================================================
-- SECTION 6: CONFLICT RECORDS
-- =============================================================================

create table if not exists public.cart_item_conflicts (
  id uuid primary key default gen_random_uuid(),

  cart_id uuid not null
    references public.carts(id)
    on delete cascade,

  cart_item_id uuid
    references public.cart_items(id)
    on delete set null,

  product_id uuid not null
    references public.products(id)
    on delete restrict,

  existing_quantity integer not null
    check (existing_quantity > 0),

  incoming_quantity integer not null
    check (incoming_quantity > 0),

  existing_version bigint not null
    check (existing_version > 0),

  incoming_version bigint not null
    check (incoming_version > 0),

  existing_updated_by uuid
    references public.profiles(id)
    on delete set null,

  incoming_updated_by uuid
    references public.profiles(id)
    on delete set null,

  client_mutation_id uuid,

  resolution text
    not null default 'pending',

  resolved_quantity integer,

  resolved_by uuid
    references public.profiles(id)
    on delete set null,

  resolved_at timestamptz,

  created_at timestamptz not null default now(),

  constraint cart_item_conflicts_resolution_check
    check (
      resolution in (
        'pending',
        'keep_both',
        'merge'
      )
    ),

  constraint cart_item_conflicts_resolved_data_check
    check (
      (
        resolution = 'pending'
        and resolved_quantity is null
        and resolved_by is null
        and resolved_at is null
      )
      or
      (
        resolution in ('keep_both', 'merge')
        and resolved_quantity is not null
        and resolved_quantity > 0
        and resolved_by is not null
        and resolved_at is not null
      )
    )
);


-- =============================================================================
-- SECTION 7: HELPER FUNCTIONS
-- =============================================================================

create or replace function public.is_cart_member(
  p_cart_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.cart_members cm
    where cm.cart_id = p_cart_id
      and cm.user_id = p_user_id
      and cm.status = 'active'
  );
$$;


create or replace function public.is_cart_owner(
  p_cart_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.cart_members cm
    where cm.cart_id = p_cart_id
      and cm.user_id = p_user_id
      and cm.role = 'owner'
      and cm.status = 'active'
  );
$$;


create or replace function public.can_edit_cart(
  p_cart_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.cart_members cm
    where cm.cart_id = p_cart_id
      and cm.user_id = p_user_id
      and cm.status = 'active'
      and cm.role in ('owner', 'editor')
  );
$$;


create or replace function public.can_view_cart(
  p_cart_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_cart_member(p_cart_id, p_user_id);
$$;


-- =============================================================================
-- SECTION 8: SECURE SHARE TOKEN HASHING
-- =============================================================================

create or replace function public.hash_cart_share_token(
  p_token text
)
returns bytea
language sql
immutable
security definer
set search_path = public
as $$
  select digest(p_token, 'sha256');
$$;


-- =============================================================================
-- SECTION 9: CART OWNER MEMBERSHIP
-- =============================================================================

create or replace function public.fn_add_cart_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.cart_members (
    cart_id,
    user_id,
    role,
    status,
    invited_at,
    joined_at,
    last_active_at
  )
  values (
    new.id,
    new.user_id,
    'owner',
    'active',
    now(),
    now(),
    now()
  )
  on conflict (cart_id, user_id)
  do update
  set
    role = 'owner',
    status = 'active',
    joined_at = coalesce(public.cart_members.joined_at, now()),
    last_active_at = now(),
    updated_at = now();

  return new;
end;
$$;


drop trigger if exists carts_add_owner_trigger
on public.carts;


create trigger carts_add_owner_trigger
after insert
on public.carts
for each row
execute function public.fn_add_cart_owner();


-- =============================================================================
-- SECTION 10: BACKFILL EXISTING CART OWNERS
-- =============================================================================

insert into public.cart_members (
  cart_id,
  user_id,
  role,
  status,
  invited_at,
  joined_at,
  last_active_at
)
select
  c.id,
  c.user_id,
  'owner',
  'active',
  c.created_at,
  c.created_at,
  c.updated_at
from public.carts c
where c.user_id is not null
on conflict (cart_id, user_id)
do update
set
  role = 'owner',
  status = 'active',
  joined_at = coalesce(
    public.cart_members.joined_at,
    excluded.joined_at
  ),
  last_active_at = excluded.last_active_at,
  updated_at = now();


-- =============================================================================
-- SECTION 11: SHARE LINK CREATION
-- =============================================================================

create or replace function public.create_cart_share_link(
  p_cart_id uuid,
  p_expires_at timestamptz default now() + interval '7 days'
)
returns table (
  share_link_id uuid,
  share_token text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_token_hash bytea;
  v_link_id uuid;
  v_expires_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.is_cart_owner(p_cart_id, auth.uid()) then
    raise exception 'Only the cart owner can create a share link';
  end if;

  if not exists (
    select 1
    from public.carts
    where id = p_cart_id
      and status = 'active'
  ) then
    raise exception 'Cart is not active';
  end if;

  if p_expires_at is not null
     and p_expires_at <= now() then
    raise exception 'Share link expiry must be in the future';
  end if;

  v_token := encode(gen_random_bytes(32), 'base64url');

  v_token_hash := digest(v_token, 'sha256');

  v_expires_at := p_expires_at;

  insert into public.cart_share_links (
    cart_id,
    token_hash,
    expires_at,
    created_by
  )
  values (
    p_cart_id,
    v_token_hash,
    v_expires_at,
    auth.uid()
  )
  returning id
  into v_link_id;

  update public.carts
  set
    share_enabled = true,
    version = version + 1,
    last_modified_by = auth.uid(),
    updated_at = now()
  where id = p_cart_id;

  return query
  select
    v_link_id,
    v_token,
    v_expires_at;
end;
$$;


-- =============================================================================
-- SECTION 12: JOIN CART USING SHARE TOKEN
-- =============================================================================

create or replace function public.join_cart_with_share_token(
  p_token text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token_hash bytea;
  v_cart_id uuid;
  v_user_id uuid;
begin
  v_user_id := auth.uid();

  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_token is null or length(trim(p_token)) < 20 then
    raise exception 'Invalid share token';
  end if;

  v_token_hash := digest(trim(p_token), 'sha256');

  select csl.cart_id
  into v_cart_id
  from public.cart_share_links csl
  where csl.token_hash = v_token_hash
    and csl.revoked_at is null
    and (
      csl.expires_at is null
      or csl.expires_at > now()
    )
  limit 1;

  if v_cart_id is null then
    raise exception 'Share link is invalid or expired';
  end if;

  if not exists (
    select 1
    from public.carts c
    where c.id = v_cart_id
      and c.status = 'active'
  ) then
    raise exception 'Cart is no longer active';
  end if;

  insert into public.cart_members (
    cart_id,
    user_id,
    role,
    status,
    invited_at,
    joined_at,
    last_active_at
  )
  values (
    v_cart_id,
    v_user_id,
    'editor',
    'active',
    now(),
    now(),
    now()
  )
  on conflict (cart_id, user_id)
  do update
  set
    status = 'active',
    joined_at = coalesce(
      public.cart_members.joined_at,
      now()
    ),
    last_active_at = now(),
    updated_at = now();

  update public.carts
  set
    share_enabled = true,
    version = version + 1,
    last_modified_by = v_user_id,
    updated_at = now()
  where id = v_cart_id;

  return v_cart_id;
end;
$$;


-- =============================================================================
-- SECTION 13: REVOKE SHARE LINK
-- =============================================================================

create or replace function public.revoke_cart_share_link(
  p_share_link_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select cart_id
  into v_cart_id
  from public.cart_share_links
  where id = p_share_link_id;

  if v_cart_id is null then
    raise exception 'Share link not found';
  end if;

  if not public.is_cart_owner(v_cart_id, auth.uid()) then
    raise exception 'Only the cart owner can revoke a share link';
  end if;

  update public.cart_share_links
  set revoked_at = coalesce(revoked_at, now())
  where id = p_share_link_id;

  return true;
end;
$$;


-- =============================================================================
-- SECTION 14: UPDATE CART MEMBER ACTIVITY
-- =============================================================================

create or replace function public.fn_update_cart_member_activity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null then
    update public.cart_members
    set
      last_active_at = now(),
      updated_at = now()
    where cart_id = new.cart_id
      and user_id = auth.uid()
      and status = 'active';
  end if;

  return new;
end;
$$;


drop trigger if exists cart_items_member_activity_trigger
on public.cart_items;


create trigger cart_items_member_activity_trigger
after insert or update or delete
on public.cart_items
for each row
execute function public.fn_update_cart_member_activity();


-- =============================================================================
-- SECTION 15: CART ITEM VERSIONING
-- =============================================================================

create or replace function public.fn_sync_cart_item_metadata()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then

    new.version := 1;

  elsif tg_op = 'UPDATE' then

    new.version := old.version + 1;

  end if;

  if auth.uid() is not null then
    new.updated_by := auth.uid();
  end if;

  new.last_synced_at := now();

  return new;
end;
$$;


drop trigger if exists cart_items_sync_metadata_trigger
on public.cart_items;


create trigger cart_items_sync_metadata_trigger
before insert or update
on public.cart_items
for each row
execute function public.fn_sync_cart_item_metadata();


-- =============================================================================
-- SECTION 16: CART VERSIONING
-- =============================================================================

create or replace function public.fn_sync_cart_metadata()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then

    new.version := 1;

  elsif tg_op = 'UPDATE' then

    new.version := old.version + 1;

    if auth.uid() is not null then
      new.last_modified_by := auth.uid();
    end if;

  end if;

  return new;
end;
$$;


drop trigger if exists carts_sync_metadata_trigger
on public.carts;


create trigger carts_sync_metadata_trigger
before insert or update
on public.carts
for each row
execute function public.fn_sync_cart_metadata();


-- =============================================================================
-- SECTION 17: CART MEMBER UPDATED_AT
-- =============================================================================

create or replace function public.fn_cart_members_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;


drop trigger if exists cart_members_updated_at_trigger
on public.cart_members;


create trigger cart_members_updated_at_trigger
before update
on public.cart_members
for each row
execute function public.fn_cart_members_updated_at();


-- =============================================================================
-- SECTION 18: PROTECT CART OWNER
-- =============================================================================

create or replace function public.fn_protect_cart_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_count integer;
begin
  if tg_op = 'DELETE' then

    if old.role = 'owner' and old.status = 'active' then

      select count(*)
      into v_owner_count
      from public.cart_members
      where cart_id = old.cart_id
        and role = 'owner'
        and status = 'active';

      if v_owner_count <= 1 then
        raise exception 'The only active cart owner cannot be removed';
      end if;

    end if;

    return old;
  end if;

  if (
    old.role = 'owner'
    and old.status = 'active'
    and (
      new.role <> 'owner'
      or new.status <> 'active'
    )
  ) then

    select count(*)
    into v_owner_count
    from public.cart_members
    where cart_id = old.cart_id
      and role = 'owner'
      and status = 'active';

    if v_owner_count <= 1 then
      raise exception 'The only active cart owner cannot lose ownership';
    end if;

  end if;

  return new;
end;
$$;


drop trigger if exists protect_cart_owner_trigger
on public.cart_members;


create trigger protect_cart_owner_trigger
before update or delete
on public.cart_members
for each row
execute function public.fn_protect_cart_owner();


-- =============================================================================
-- SECTION 19: INDEXES
-- =============================================================================

create index if not exists cart_members_cart_id_idx
on public.cart_members(cart_id);


create index if not exists cart_members_user_id_idx
on public.cart_members(user_id);


create index if not exists cart_members_cart_status_idx
on public.cart_members(cart_id, status);


create index if not exists cart_members_user_status_idx
on public.cart_members(user_id, status);


create index if not exists cart_members_cart_role_idx
on public.cart_members(cart_id, role);


create index if not exists cart_share_links_cart_id_idx
on public.cart_share_links(cart_id);


create index if not exists cart_share_links_active_idx
on public.cart_share_links(cart_id, revoked_at, expires_at);


create index if not exists cart_share_links_token_hash_idx
on public.cart_share_links(token_hash);


create index if not exists cart_items_cart_version_idx
on public.cart_items(cart_id, version);


create index if not exists cart_items_updated_by_idx
on public.cart_items(updated_by);


create index if not exists cart_items_mutation_id_idx
on public.cart_items(client_mutation_id);


create index if not exists cart_item_conflicts_cart_id_idx
on public.cart_item_conflicts(cart_id);


create index if not exists cart_item_conflicts_item_id_idx
on public.cart_item_conflicts(cart_item_id);


create index if not exists cart_item_conflicts_product_id_idx
on public.cart_item_conflicts(product_id);


create index if not exists cart_item_conflicts_pending_idx
on public.cart_item_conflicts(cart_id, resolution);


-- =============================================================================
-- SECTION 20: ENABLE ROW LEVEL SECURITY
-- =============================================================================

alter table public.cart_members
enable row level security;


alter table public.cart_share_links
enable row level security;


alter table public.cart_item_conflicts
enable row level security;


-- =============================================================================
-- SECTION 21: CART MEMBERS RLS
-- =============================================================================

drop policy if exists cart_members_select_policy
on public.cart_members;


create policy cart_members_select_policy
on public.cart_members
for select
to authenticated
using (
  public.is_cart_member(cart_id, auth.uid())
);


drop policy if exists cart_members_insert_owner_policy
on public.cart_members;


create policy cart_members_insert_owner_policy
on public.cart_members
for insert
to authenticated
with check (
  public.is_cart_owner(cart_id, auth.uid())
);


drop policy if exists cart_members_update_owner_policy
on public.cart_members;


create policy cart_members_update_owner_policy
on public.cart_members
for update
to authenticated
using (
  public.is_cart_owner(cart_id, auth.uid())
)
with check (
  public.is_cart_owner(cart_id, auth.uid())
);


drop policy if exists cart_members_delete_owner_policy
on public.cart_members;


create policy cart_members_delete_owner_policy
on public.cart_members
for delete
to authenticated
using (
  public.is_cart_owner(cart_id, auth.uid())
);


-- =============================================================================
-- SECTION 22: SHARE LINK RLS
-- =============================================================================

drop policy if exists cart_share_links_select_owner_policy
on public.cart_share_links;


create policy cart_share_links_select_owner_policy
on public.cart_share_links
for select
to authenticated
using (
  public.is_cart_owner(cart_id, auth.uid())
);


drop policy if exists cart_share_links_insert_owner_policy
on public.cart_share_links;


create policy cart_share_links_insert_owner_policy
on public.cart_share_links
for insert
to authenticated
with check (
  public.is_cart_owner(cart_id, auth.uid())
  and created_by = auth.uid()
);


drop policy if exists cart_share_links_update_owner_policy
on public.cart_share_links;


create policy cart_share_links_update_owner_policy
on public.cart_share_links
for update
to authenticated
using (
  public.is_cart_owner(cart_id, auth.uid())
)
with check (
  public.is_cart_owner(cart_id, auth.uid())
);


drop policy if exists cart_share_links_delete_owner_policy
on public.cart_share_links;


create policy cart_share_links_delete_owner_policy
on public.cart_share_links
for delete
to authenticated
using (
  public.is_cart_owner(cart_id, auth.uid())
);


-- =============================================================================
-- SECTION 23: CONFLICT RLS
-- =============================================================================

drop policy if exists cart_item_conflicts_select_policy
on public.cart_item_conflicts;


create policy cart_item_conflicts_select_policy
on public.cart_item_conflicts
for select
to authenticated
using (
  public.is_cart_member(cart_id, auth.uid())
);


drop policy if exists cart_item_conflicts_insert_policy
on public.cart_item_conflicts;


create policy cart_item_conflicts_insert_policy
on public.cart_item_conflicts
for insert
to authenticated
with check (
  public.can_edit_cart(cart_id, auth.uid())
  and (
    incoming_updated_by = auth.uid()
    or incoming_updated_by is null
  )
);


drop policy if exists cart_item_conflicts_update_policy
on public.cart_item_conflicts;


create policy cart_item_conflicts_update_policy
on public.cart_item_conflicts
for update
to authenticated
using (
  public.can_edit_cart(cart_id, auth.uid())
)
with check (
  public.can_edit_cart(cart_id, auth.uid())
);


-- =============================================================================
-- SECTION 24: UPDATE EXISTING CART RLS FOR SHARED ACCESS
-- =============================================================================

drop policy if exists carts_select_own
on public.carts;


create policy carts_select_shared
on public.carts
for select
to authenticated
using (
  public.is_cart_member(id, auth.uid())
);


drop policy if exists carts_update_own
on public.carts;


create policy carts_update_shared
on public.carts
for update
to authenticated
using (
  public.can_edit_cart(id, auth.uid())
)
with check (
  public.can_edit_cart(id, auth.uid())
);


drop policy if exists carts_delete_own
on public.carts;


create policy carts_delete_owner
on public.carts
for delete
to authenticated
using (
  public.is_cart_owner(id, auth.uid())
);


-- =============================================================================
-- SECTION 25: UPDATE EXISTING CART ITEM RLS FOR SHARED ACCESS
-- =============================================================================

drop policy if exists cart_items_select_own
on public.cart_items;


create policy cart_items_select_shared
on public.cart_items
for select
to authenticated
using (
  public.is_cart_member(cart_id, auth.uid())
);


drop policy if exists cart_items_insert_own
on public.cart_items;


create policy cart_items_insert_shared
on public.cart_items
for insert
to authenticated
with check (
  public.can_edit_cart(cart_id, auth.uid())
);


drop policy if exists cart_items_update_own
on public.cart_items;


create policy cart_items_update_shared
on public.cart_items
for update
to authenticated
using (
  public.can_edit_cart(cart_id, auth.uid())
)
with check (
  public.can_edit_cart(cart_id, auth.uid())
);


drop policy if exists cart_items_delete_own
on public.cart_items;


create policy cart_items_delete_shared
on public.cart_items
for delete
to authenticated
using (
  public.can_edit_cart(cart_id, auth.uid())
);


-- =============================================================================
-- SECTION 26: SECURE FUNCTION EXECUTION
-- =============================================================================

revoke all
on function public.is_cart_member(uuid, uuid)
from public;


grant execute
on function public.is_cart_member(uuid, uuid)
to authenticated;


revoke all
on function public.is_cart_owner(uuid, uuid)
from public;


grant execute
on function public.is_cart_owner(uuid, uuid)
to authenticated;


revoke all
on function public.can_edit_cart(uuid, uuid)
from public;


grant execute
on function public.can_edit_cart(uuid, uuid)
to authenticated;


revoke all
on function public.can_view_cart(uuid, uuid)
from public;


grant execute
on function public.can_view_cart(uuid, uuid)
to authenticated;


revoke all
on function public.hash_cart_share_token(text)
from public;


grant execute
on function public.hash_cart_share_token(text)
to authenticated;


revoke all
on function public.create_cart_share_link(uuid, timestamptz)
from public;


grant execute
on function public.create_cart_share_link(uuid, timestamptz)
to authenticated;


revoke all
on function public.join_cart_with_share_token(text)
from public;


grant execute
on function public.join_cart_with_share_token(text)
to authenticated;


revoke all
on function public.revoke_cart_share_link(uuid)
from public;


grant execute
on function public.revoke_cart_share_link(uuid)
to authenticated;


-- =============================================================================
-- SECTION 27: SUPABASE REALTIME
-- =============================================================================

do $$
begin

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cart_members'
  ) then

    alter publication supabase_realtime
      add table public.cart_members;

  end if;


  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cart_items'
  ) then

    alter publication supabase_realtime
      add table public.cart_items;

  end if;


  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'carts'
  ) then

    alter publication supabase_realtime
      add table public.carts;

  end if;


  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cart_item_conflicts'
  ) then

    alter publication supabase_realtime
      add table public.cart_item_conflicts;

  end if;

end
$$;


-- =============================================================================
-- SECTION 28: REALTIME REPLICA IDENTITY
-- =============================================================================

alter table public.cart_members
replica identity full;


alter table public.cart_items
replica identity full;


alter table public.carts
replica identity full;


alter table public.cart_item_conflicts
replica identity full;


-- =============================================================================
-- SECTION 29: COMMENTS
-- =============================================================================

comment on table public.cart_members is
'Users who participate in a shared InstaDaily cart.';

comment on table public.cart_share_links is
'Secure, expiring share tokens used to join shared carts. Only token hashes are stored.';

comment on table public.cart_item_conflicts is
'Concurrent cart-item edit records used by the client to resolve Keep Both or Merge conflicts.';

comment on column public.cart_items.version is
'Monotonically increasing optimistic-concurrency version for collaborative cart updates.';

comment on column public.cart_items.client_mutation_id is
'Client-generated UUID used to identify an individual cart mutation and support idempotency/concurrency handling.';

comment on column public.carts.version is
'Monotonically increasing version for collaborative cart state.';


-- =============================================================================
-- END OF 02_sync_cart_schema.sql
-- =============================================================================