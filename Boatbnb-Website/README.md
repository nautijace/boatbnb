# Boatbnb — integrated dockside stays starter

Next.js App Router + TypeScript + Tailwind CSS 4 + Supabase. **Accommodation only:** boats remain docked; no charters or navigation.

## Run locally

1. `npm install`
2. Supabase is already connected to the existing **Nauti Vita Project** (`gzekslhrruxpmutdpchi`), and the Boatbnb schema was applied as migration `boatbnb_initial_schema` on November 7, 2026. **Do not rerun `supabase/schema.sql` on this project.**
3. `.env.local` is preconfigured with that project URL and its public publishable key. Never put a service-role key in this file.
4. Configure Supabase Auth email confirmation and allowed redirect URLs (`http://localhost:3000`).
5. `npm run dev` and visit http://localhost:3000.
6. Create an account at `/auth`, then create a draft at `/host/new`.

## Publishing a sample listing for local testing only

The application deliberately does not expose a public publish endpoint. To test guest discovery, after manually verifying a draft and marina permission, an authorized project administrator can use the Supabase SQL editor:

```sql
update public.boats set status='published' where id='YOUR_TEST_BOAT_UUID';
```

This is a **development-only** procedure. Do not use it as a production approval process.

## Connected Supabase
- Project: Nauti Vita Project (existing project, not a separately created Boatbnb project)
- Project ID: `gzekslhrruxpmutdpchi`
- API URL: `https://gzekslhrruxpmutdpchi.supabase.co`
- Tables deployed: `boats`, `bookings`, `blocked_dates`
- RLS enabled on all 3 tables; booking request RPC deployed
- Initial database is empty; sign up and create listings to populate it
- Confirmed migration and table presence with Supabase tools

## Implemented
- Search published listings by city and minimum guest capacity
- Detail page with nightly estimate and stationary-only policy
- Supabase email/password signup/signin
- Host dashboard and draft listing creation
- Authenticated reservation **requests**, calculated on the database server
- Guest trip/request history
- RLS isolation for hosts and guests

## Intentionally not implemented
- Real payments, Stripe Connect, refunds, taxes, and payouts
- Reservation confirmation or automated expiry (requests do not block dates)
- Admin approval UI and host listing editing
- Image uploads (drafts accept optional externally hosted image URL)
- Messaging, reviews, favorites, email notifications
- Availability calendar and owner blocks UI
- Production tests, anti-spam, moderation, security review

**Important:** Requests are NOT reservations. Guests must not rely on them for lodging. No payment is collected. The database enforces no overlap for future *confirmed* reservations, but confirmation must be implemented as a trusted, transactional operation. Listing owners cannot publish through browser policies. A real launch also needs marina authorization, insurance, accessibility/safety review, and applicable lodging compliance.

## File map
- `app/page.tsx` search and discovery
- `app/boats/[id]/page.tsx` listing details
- `app/boats/[id]/reserve.tsx` request form
- `app/auth` authentication
- `app/host` draft creation and dashboard
- `app/trips` guest request history
- `supabase/schema.sql` single clean database schema
