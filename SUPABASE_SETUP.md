# Supabase + Google Sign-In Setup (Sakto)

Sakto works **offline** with just a name. The **Continue with Google** button signs the user in through **Supabase Auth**, which saves the account online:
- **Authentication → Users** holds the account itself.
- The **`profiles`** table holds the name, email, and photo.

Do these steps **once** per Supabase project. It takes about 15 minutes.

---

## 1. Create a Supabase project
1. Go to https://supabase.com and sign in. Click **New project**.
2. Pick a name (e.g. `sakto`), set a database password, choose the region closest to you (e.g. *Southeast Asia (Singapore)*), then click **Create**.
3. When it's ready, open **Project Settings → API** (or click **Connect** at the top) and copy:
   - **Project URL**, e.g. `https://abcdefghijkl.supabase.co`
   - **anon / publishable key**

> [!CAUTION]
> Never copy the **service_role / secret** key into the app.

## 2. Put the keys in the app
Open `lib/supabase_config.dart` and paste the two values you copied:

```dart
const supabaseUrl = 'https://abcdefghijkl.supabase.co';
const supabaseAnonKey = 'eyJhbGciOi...';   // anon / publishable key
```

> The anon key is designed to be public, so it's okay to commit it. The Row Level Security rules in step 6 are what protect the data.

## 3. Create Google OAuth credentials (Google Cloud Console)
1. Go to https://console.cloud.google.com and create a project (e.g. `Sakto`), or select an existing one.
2. Open **APIs & Services → OAuth consent screen** (called **Google Auth Platform** in newer consoles):
   - User type: **External**
   - App name: `Sakto`. Fill in the support email and the developer email.
   - Under **Audience / Test users**, add the Gmail accounts of everyone on your team. While the app is in *Testing*, only these accounts can sign in.
3. Open **APIs & Services → Credentials → Create credentials → OAuth client ID**:
   - Application type: **Web application** (not Android, because Supabase handles the Google page for us)
   - **Authorized redirect URIs** → add:
     ```text
     https://<your-project-ref>.supabase.co/auth/v1/callback
     ```
     (The exact URL is also shown in Supabase → Authentication → Providers → Google → *Callback URL*.)
4. Click **Create** and copy the **Client ID** and **Client secret**.

## 4. Enable Google in Supabase
1. In Supabase, go to **Authentication → Sign In / Providers → Google**.
2. Turn on **Enable Sign in with Google**.
3. Paste the **Client ID** and **Client secret** from step 3, then click **Save**.

## 5. Allow the app's redirect link
1. In Supabase, go to **Authentication → URL Configuration**.
2. Under **Redirect URLs**, click **Add URL** and add:
   ```text
   io.sakto.app://login-callback
   ```
3. Click **Save**.

This link is already registered in the app:
- `android/app/src/main/AndroidManifest.xml`: intent filter with scheme `io.sakto.app`, host `login-callback`
- `ios/Runner/Info.plist`: `CFBundleURLSchemes` → `io.sakto.app`
- `lib/supabase_config.dart` → `authRedirect`

## 6. Create the `profiles` table (saves the accounts)
In Supabase, open **SQL Editor → New query**, paste the script below, and click **Run**:

```sql
-- One row per signed-in Google user
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  full_name   text,
  email       text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Row Level Security: each user can only see / change their own row
alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert with check (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- Automatically create a profile the first time someone signs in
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, email, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.email,
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Stores each Google user's items, tags, cash on hand, splits, and history
create table if not exists public.user_data (
  id         uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_data enable row level security;

create policy "Users can view own data"
  on public.user_data for select using (auth.uid() = id);

create policy "Users can insert own data"
  on public.user_data for insert with check (auth.uid() = id);

create policy "Users can update own data"
  on public.user_data for update using (auth.uid() = id);
```

The app also **upserts** this row whenever the user signs in or edits their name in the drawer (**Profile → tap name**).

## 7. Run and test
```powershell
flutter pub get
flutter run
```
1. On the landing page, tap **Continue with Google**.
2. Pick your Google account in the browser. You're sent back to Sakto, signed in.
3. Check Supabase:
   - **Authentication → Users**: your account appears.
   - **Table Editor → profiles**: your name, email, and photo appear.

---

## Troubleshooting
| Problem | Fix |
|---|---|
| Tapping Google shows *"Google sign-in isn't set up yet"* | `supabaseUrl` / `supabaseAnonKey` in `lib/supabase_config.dart` are still empty. Paste them and fully restart the app (not hot reload). |
| After choosing an account, the browser opens `localhost:3000` | `io.sakto.app://login-callback` is missing from Supabase → **URL Configuration → Redirect URLs**. |
| *"Error 400: redirect_uri_mismatch"* | The Google Cloud **Authorized redirect URI** must be exactly `https://<project-ref>.supabase.co/auth/v1/callback`. |
| *"Access blocked: app has not completed verification"* | Add that Gmail as a **Test user** on the OAuth consent screen, or publish the app. |
| *"Unable to exchange external code"* | The Client secret in Supabase → Providers → Google is wrong. Paste it again. |
| Signed in, but the `profiles` table is empty | Run the SQL in step 6 again and check that RLS policies exist. |
| The browser stays open after login | Make sure the scheme in `AndroidManifest.xml` is exactly `io.sakto.app`, then do a full rebuild (`flutter clean && flutter run`). |
