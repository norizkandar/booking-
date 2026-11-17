# Eonix Booking — Universal Booking Platform

**Eonix Tech Studio** · GitHub Pages frontend + Supabase backend

This package is an upgraded, modular SaaS foundation for appointment and resource-based businesses: salons, barbers, spas, clinics, veterinary services, workshops, tutors/coaches, event venues, sports facilities and other service providers.

## Included
- Responsive premium dark/light interface (Dark Purple, Neon Purple, Electric Blue, Lavender)
- Supabase Auth email/password sign up and sign in
- Profile creation trigger
- Business workspace onboarding
- Roles foundation: `super_admin`, `business_owner`, `staff`, `customer`
- Multi-tenant business data model with Row Level Security
- Business profile, branches, services, customers, team membership
- Create and manage bookings; update booking status
- Calendar, reports and CSV export
- Availability, resources, reviews, promotions and platform-admin module foundations
- Modular source files; no giant single-file app

## 1. Create Supabase project
1. Create a project in Supabase.
2. Open **SQL Editor**.
3. Run `supabase/schema.sql` once.
4. Open **Project Settings → API** and copy the Project URL and anon/public key.

## 2. Configure frontend
Open `assets/js/config.js` and replace:
- `YOUR_SUPABASE_PROJECT_URL`
- `YOUR_SUPABASE_ANON_PUBLIC_KEY`

Use only the **anon/public** key in browser code. Never paste the `service_role` key into GitHub, HTML, JavaScript or any public repository.

## 3. Publish on GitHub Pages
Upload the complete folder structure to the repository root (keep the `assets/` and `supabase/` folders). In GitHub, open **Settings → Pages** and publish from the selected branch and `/ (root)` folder.

Because this uses ES modules, test through GitHub Pages or a local static server, not by opening `index.html` as a `file://` URL.

## 4. Supabase Auth settings
In Supabase **Authentication → URL Configuration**:
- Set Site URL to your published GitHub Pages URL.
- Add the exact published URL to Redirect URLs.
- Configure email confirmation and SMTP according to your deployment requirements.

## 5. Roles and security
- New accounts receive `customer` as their platform role.
- A user who creates a business becomes its `business_owner` through a database trigger.
- A business owner can add existing registered users as staff or additional business owners from Team & Access.
- `super_admin` is not self-selectable. Assign it manually from the trusted Supabase SQL Editor only after verifying the account.
- RLS is enabled on tenant data. Test with separate accounts for each role before real use.

## Important implementation status
This is a working SaaS foundation, not a finished commercial booking marketplace. Authentication, workspace creation, core service/booking operations and basic team management are wired to Supabase. The following need a further implementation and security test pass before public production use:
- Public customer-facing discovery and booking pages
- Slot calculation with timezone, staff/resource conflict detection and atomic booking RPC
- Full weekly availability and date exception editor
- Staff-specific schedules and service assignment
- Customer self-service booking history and cancellation rules
- Verified reviews, promotion redemption and notification delivery
- Payment provider integration and signed webhook verification
- Audit event automation, rate limiting, abuse protection, backups and monitoring
- Comprehensive RLS tests for every role and edge case

Do not collect real customer payments or promise a confirmed slot until the server-side scheduling and payment workflows are completed. A browser-side status change is not a substitute for payment verification.

## Project structure
```text
eonix-booking/
├── index.html
├── README.md
├── assets/
│   ├── css/styles.css
│   └── js/
│       ├── config.js
│       ├── supabase.js
│       └── app.js
└── supabase/
    └── schema.sql
```
