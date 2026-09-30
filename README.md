# Tông Môn — Member Nexus

Website full-stack starter: Next.js App Router + Supabase Auth + PostgreSQL/RLS. UI uses the dark fantasy/cyberpunk cyan-purple identity from the original preview, with member dossiers and an actual `<video loop>` slot for the aura panel.

## Features in this project

- Email/password registration and login using Supabase Auth.
- New accounts get `status = pending`, `role = de_tu` via a database trigger.
- Pending users cannot browse the member directory.
- Approved members can view approved profiles and edit only their own profile fields.
- Tông chủ can approve/reject requests.
- Tông chủ and Thái thượng trưởng lão can change ordinary member ranks. Only Tông chủ can appoint/remove Thái thượng trưởng lão. This starter deliberately does not provide a client workflow for transferring the Tông chủ role.
- PostgreSQL Row Level Security (RLS), a profile privilege-protection trigger, security-definer RPCs with explicit role checks, and an audit log for approval/rank changes.
- Member detail pages and responsive layout.
- Aura video player at `public/aura-loop.mp4`, with poster and CSS fallback. A real licensed loop MP4 is not bundled; add one as described below.

## Before starting

Install **Node.js LTS** from https://nodejs.org/ and use a recent version (Node 20.9+ for Next.js 15). Install Git optionally. You do not need to know Linux.

## Step 1 — Create a Supabase project

1. Open https://supabase.com/ and create a free project.
2. Save the database password in a password manager; don't put it in this repository.
3. Wait for the database to finish provisioning.
4. In **Project Settings → API** (or **Connect**, depending on dashboard version), copy the project URL and the publishable/anon key. Never copy the `service_role` secret into a `NEXT_PUBLIC_` variable or browser code.
5. Open **SQL Editor → New query**. Open `supabase/migrations/0001_initial.sql` from this project, copy all SQL into the editor and run it.

## Step 2 — Configure the app on Windows 11

1. Extract the project folder somewhere simple, for example `C:\Projects\tong-mon-member-nexus`.
2. Open the folder in VS Code (recommended) or a terminal.
3. Copy `.env.example` to a new file named `.env.local`.
4. Fill these values from Supabase:

```env
NEXT_PUBLIC_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

5. Open Terminal in the project folder and run:

```bash
npm install
npm run dev
```

6. Open http://localhost:3000. Keep the terminal running while testing. Stop it with `Ctrl+C`.

## Step 3 — Configure email confirmation

In Supabase Dashboard → **Authentication → URL Configuration**, add your local site URL `http://localhost:3000`. Review **Authentication → Providers → Email**. For initial testing you may disable email confirmation in a private test project, but for a public website keep confirmation enabled and configure email delivery. Do not use a real password on a project you don't control.

## Step 4 — Make your account Tông chủ (one time)

1. Register your own account through `/register`.
2. Confirm your email if confirmation is enabled, then sign in once so the profile row is created.
3. In Supabase → SQL Editor, run the following once, replacing the email with the exact email used for your account:

```sql
update public.profiles
set role = 'tong_chu', status = 'approved'
where lower(email) = lower('YOUR-EMAIL@example.com');
```

4. Verify exactly one row was updated. If zero rows changed, check email confirmation and that your account has signed in/created a profile. Do not promote users based on an email supplied in a chat.
5. Sign out and sign in again; visit `/admin`.

This one-time bootstrap is performed by the trusted project owner in the SQL Editor. Do not expose the database owner credentials or service-role key to users.

## Step 5 — Test authorization

- Register a second test account. It should be pending and should not see `/members` or `/admin`.
- As Tông chủ, approve it in `/admin`.
- Sign in as the second account. It should be able to view members and edit its own public profile fields.
- Try changing `role` or `status` directly through the browser Supabase client: the database trigger should reject the attempt.
- A normal approved member should be redirected away from `/admin`; RPCs independently validate permissions in PostgreSQL, so bypassing the UI is not sufficient to gain authority.

Use test accounts first. Test the current policy set before adding more features.

## Step 6 — Add a real aura loop video

The player is already implemented with `<video autoPlay muted loop playsInline>`. To use a real moving aura, obtain a short MP4/WebM loop that you own or have permission to use, ideally 5–15 seconds, 720p or 1080p, muted, and compressed for the web. Place the MP4 at:

`public/aura-loop.mp4`

No binary video is included in this source package, so the project uses `public/aura-poster.svg` and the animated CSS aura as a fallback until you add the video. Keep the file small to avoid slow loading and high bandwidth use. Respect the asset's license.

## Step 7 — Deploy free-first (Vercel + Supabase)

1. Create a GitHub account if needed; create a **private** repository and upload this project. Never commit `.env.local`.
2. Open https://vercel.com/, import the repository and choose the default Next.js settings.
3. In Vercel → Project → Settings → Environment Variables, add `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` for Production (and Preview if wanted).
4. Deploy.
5. Copy the production URL from Vercel. In Supabase → Authentication → URL Configuration, set the production URL as the Site URL and add it to the Redirect URLs list. Test signup, email confirmation, login, pending state, approval, profile editing, and logout on the deployed site.
6. Check current provider quotas and terms before relying on free tiers. Free plans and limits can change; free hosting is not a guarantee of unlimited traffic or storage.

## Important security notes

- Never put the Supabase `service_role` key in a `NEXT_PUBLIC_*` variable, client component, repository, or screenshot.
- Keep RLS enabled. Don't create broad `using (true)` policies on profiles or audit tables.
- Role and status changes should go through reviewed SQL/RPC workflows. The SQL bootstrap is intentionally manual.
- Supabase Auth handles password storage; this app does not store plaintext passwords.
- Profile avatar URL is currently a URL field, not an upload pipeline. A future version can add Supabase Storage with a strict per-user bucket policy.
- Discord username is profile text only; Discord OAuth/bot integration is not configured.
- The project has not been deployed by this package generation. You must connect your own Supabase and hosting accounts.

## Project structure

```text
app/
  page.tsx                 landing page
  login/page.tsx           login form
  register/page.tsx        registration request
  pending/page.tsx         approval state + own profile editor
  members/page.tsx         approved member directory
  members/[id]/page.tsx    dossier + aura video slot
  admin/page.tsx           request review + role administration
  server-actions.ts        server-side form actions
  globals.css              responsive cyberpunk theme
lib/
  auth.ts                  server-side session and role gates
  supabase/server.ts       server Supabase client
  supabase/client.ts       browser client helper
middleware.ts              session refresh
supabase/migrations/       database schema, RLS and secure RPCs
public/aura-poster.svg     fallback poster for aura video
```
