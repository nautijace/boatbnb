-- Boatbnb MVP: run in a NEW Supabase project. Do not run over prior phase migrations.
create extension if not exists btree_gist;
create table public.boats (
 id uuid primary key default gen_random_uuid(),owner_id uuid not null references auth.users(id) on delete cascade,
 title text not null check(length(trim(title)) between 3 and 150),description text not null default '',
 boat_type text not null check(boat_type in ('Sailboat','Motor yacht','Catamaran','Houseboat','Other')),
 city text not null,country text not null default 'United States',marina text not null,
 capacity integer not null check(capacity between 1 and 30),bedrooms integer not null default 1 check(bedrooms>=0),
 beds integer not null default 1 check(beds>=1),bathrooms integer not null default 1 check(bathrooms>=0),
 price_per_night numeric(10,2) not null check(price_per_night>0),cleaning_fee numeric(10,2) not null default 0 check(cleaning_fee>=0),
 minimum_nights integer not null default 1 check(minimum_nights>=1),photo_url text,
 wifi boolean not null default false,air_conditioning boolean not null default false,kitchen boolean not null default false,shore_power boolean not null default false,
 house_rules text not null default '',stationary_only boolean not null default true check(stationary_only=true),
 status text not null default 'draft' check(status in ('draft','published')),
 created_at timestamptz not null default now()
);
create table public.bookings (
 id uuid primary key default gen_random_uuid(),boat_id uuid not null references public.boats(id),guest_id uuid not null references auth.users(id),
 start_date date not null,end_date date not null,guests integer not null check(guests>=1),
 nightly_rate numeric(10,2) not null,cleaning_fee numeric(10,2) not null,total_price numeric(10,2) not null,
 status text not null default 'requested' check(status in ('requested','cancelled','confirmed')),
 created_at timestamptz not null default now(),check(end_date>start_date)
);
-- Even if trusted server code later confirms a booking, overlapping confirmed bookings are forbidden.
alter table public.bookings add constraint confirmed_bookings_no_overlap exclude using gist (boat_id with =,daterange(start_date,end_date,'[)') with &&) where (status='confirmed');
create table public.blocked_dates (id uuid primary key default gen_random_uuid(),boat_id uuid not null references public.boats(id) on delete cascade,start_date date not null,end_date date not null,reason text,check(end_date>start_date));
create index boats_search_idx on public.boats(status,city,capacity);
create index bookings_guest_idx on public.bookings(guest_id,created_at desc);
alter table public.boats enable row level security;
alter table public.bookings enable row level security;
alter table public.blocked_dates enable row level security;
create policy "Published boats visible" on public.boats for select using(status='published' or owner_id=(select auth.uid()));
create policy "Owners create drafts" on public.boats for insert to authenticated with check(owner_id=(select auth.uid()) and status='draft' and stationary_only=true);
-- No direct update or delete policy: approvals and edits must be implemented via trusted routes.
create policy "Guests see own requests" on public.bookings for select to authenticated using(guest_id=(select auth.uid()));
create policy "Hosts see boat requests" on public.bookings for select to authenticated using(exists(select 1 from public.boats b where b.id=boat_id and b.owner_id=(select auth.uid())));
create policy "Hosts read blocks" on public.blocked_dates for select to authenticated using(exists(select 1 from public.boats b where b.id=boat_id and b.owner_id=(select auth.uid())));
-- Guests may create REQUESTS only, not confirmed bookings. No payment or approval is performed.
create or replace function public.create_booking_request(p_boat_id uuid,p_start date,p_end date,p_guests integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_boat public.boats%rowtype;v_id uuid;v_nights integer;
begin
 if auth.uid() is null then raise exception 'Sign in required';end if;
 if p_start<current_date or p_end<=p_start or p_guests<1 then raise exception 'Invalid dates or guests';end if;
 select * into v_boat from public.boats where id=p_boat_id and status='published' and stationary_only=true;
 if not found then raise exception 'Listing unavailable';end if;
 if v_boat.owner_id=auth.uid() then raise exception 'You cannot book your own boat';end if;
 v_nights:=p_end-p_start;
 if v_nights<v_boat.minimum_nights or v_nights>90 or p_guests>v_boat.capacity then raise exception 'Stay does not meet listing requirements';end if;
 if exists(select 1 from public.bookings b where b.boat_id=p_boat_id and b.status='confirmed' and b.start_date<p_end and b.end_date>p_start) or exists(select 1 from public.blocked_dates d where d.boat_id=p_boat_id and d.start_date<p_end and d.end_date>p_start) then raise exception 'Dates unavailable';end if;
 insert into public.bookings(boat_id,guest_id,start_date,end_date,guests,nightly_rate,cleaning_fee,total_price,status)
 values(p_boat_id,auth.uid(),p_start,p_end,p_guests,v_boat.price_per_night,v_boat.cleaning_fee,v_nights*v_boat.price_per_night+v_boat.cleaning_fee,'requested') returning id into v_id;
 return v_id;
end;$$;
revoke all on function public.create_booking_request(uuid,date,date,integer) from public,anon;
grant execute on function public.create_booking_request(uuid,date,date,integer) to authenticated;
-- NOTE: publishing is intentionally unavailable to browser users. Admin workflow required.
