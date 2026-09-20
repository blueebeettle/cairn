# Locking down the Supabase backups bucket

Your backup service does **not** use database tables. It uses Storage:

```dart
client.storage.from('backups').uploadBinary(...)
client.storage.from('backups').download('${user.id}/latest.cairn')
```

So "enable RLS on your tables" does not apply. What matters is the `backups`
bucket and the policies on `storage.objects`.

The path is `{user.id}/latest.cairn` — the first folder is the owner's user id,
which is what makes a correct policy simple.

---

## About the syntax error

I ran the previous version through a real Postgres grammar parser. All four
statements parse clean and there are no smart quotes in them, so the SQL itself
was not the problem — **the instructions were.** The last version said "Storage →
Policies" and then "easiest route is the SQL Editor", which is ambiguous.

That matters because the two places take **different things**:

| where | what it expects |
|---|---|
| **SQL Editor** | the whole `create policy ...` statement |
| **Storage → Policies → New policy** | *only the expression* — the bit inside `using (...)` |

Pasting a full `create policy` statement into the dashboard's policy dialog is a
syntax error every time, because that box is expecting a boolean expression, not
a statement. Both forms are below. Use one or the other, not both.

If your error was something else, the two other common ones are covered at the
bottom.

---

## Step 1 — make the bucket private

Dashboard → **Storage** → `backups` bucket → ⋮ → **Edit bucket**.

**Public bucket must be OFF.**

A public bucket means anyone who guesses a path downloads that file without
signing in. The contents are encrypted, so they would get ciphertext rather than
someone's history — but the paths are predictable (`{uuid}/latest.cairn`), and a
public bucket usually comes with write policies that let anyone **overwrite or
delete** every backup. Erasing is the real damage here, not reading.

---

## Step 2, option A — the SQL Editor (recommended)

Dashboard → **SQL Editor** → **New query** → paste all of this → **Run**.

The `drop policy if exists` lines make it safe to run more than once, which the
previous version was not — if you ran it twice you would have hit
`policy ... already exists`, which reads like a syntax error but is not.

```sql
drop policy if exists "cairn_backups_select" on storage.objects;
drop policy if exists "cairn_backups_insert" on storage.objects;
drop policy if exists "cairn_backups_update" on storage.objects;
drop policy if exists "cairn_backups_delete" on storage.objects;

create policy "cairn_backups_select"
on storage.objects for select to authenticated
using (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "cairn_backups_insert"
on storage.objects for insert to authenticated
with check (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "cairn_backups_update"
on storage.objects for update to authenticated
using (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text)
with check (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "cairn_backups_delete"
on storage.objects for delete to authenticated
using (bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text);
```

Policy names no longer contain spaces or colons. The old ones were legal —
quoted identifiers can contain anything — but plain names are one less thing to
go wrong when something else quotes them for you.

---

## Step 2, option B — the dashboard dialog

Use this **instead of** option A. Storage → **Policies** → the `backups` bucket →
**New policy** → **For full customization**.

You get one dialog with four fields. Run through it **four times** — everything
is identical except the name and which operation you tick.

| Pass | Policy name | Allowed operation | Target roles |
|---|---|---|---|
| 1 | `cairn_backups_select` | tick **SELECT** only | `authenticated` |
| 2 | `cairn_backups_insert` | tick **INSERT** only | `authenticated` |
| 3 | `cairn_backups_update` | tick **UPDATE** only | `authenticated` |
| 4 | `cairn_backups_delete` | tick **DELETE** only | `authenticated` |

**Target roles is the field that matters.** It says *"Defaults to all (public)
roles if none selected"*. Left empty, the policy applies to `public` — which
includes `anon`, the key that ships inside your APK. Click the box and choose
`authenticated` on every pass. Getting this one field wrong leaves the bucket
open no matter how good the expression is.

**Policy definition** — identical on all four passes. The box comes pre-filled
with `bucket_id = 'backups'`. Clear it and paste:

```
bucket_id = 'backups' and (storage.foldername(name))[1] = auth.uid()::text
```

The pre-filled line on its own checks only *which bucket*, not *whose folder* —
it would let any signed-in user read everybody's backups. The second half is
what scopes it to the person asking.

On the UPDATE pass, if a second expression box appears after you tick the box,
paste the same expression into that one too. If only one box shows, there is
nothing more to do.

## What the expression means

`(storage.foldername(name))[1]` is the first path segment — the user id your code
already writes into the path. `auth.uid()` is whoever is asking. They must match,
so a signed-in person reaches their own folder and nothing else.

The **update** policy is the one people leave out. Without it the first backup
succeeds and every one after it fails, which looks like a random bug rather than
a missing permission.

---

## Step 3 — prove it is actually closed

Do not trust the dashboard. From a terminal, with the anon key out of
`supabase_backup_service.dart`:

```
curl -s -o /dev/null -w "%{http_code}\n" \
  "https://iegxiqmwujossvzxlrnh.supabase.co/storage/v1/object/backups/test/latest.cairn" \
  -H "apikey: PASTE_ANON_KEY_HERE"
```

**400 or 404 is what you want.** **200 means the bucket is readable without
signing in** — fix it before shipping.

Then in the app: sign in, back up, restore, back up a second time. If the second
backup fails, the update policy is missing.

---

## If you still get an error

**`must be owner of table objects`** — not a syntax error. On some projects
`storage.objects` is owned by `supabase_storage_admin` and the SQL Editor cannot
create policies on it. Use option B instead; the dashboard runs as the right
role.

**`policy "..." already exists`** — you ran it twice. The `drop policy if exists`
lines above prevent this. Run the whole block again, including the drops.

**`syntax error at or near "create"`** — you pasted a full statement into the
dashboard's expression box. Use option B's expression-only version, or move to
the SQL Editor.

Whatever the message, paste it to me verbatim rather than paraphrasing — the
three above look similar in the dashboard and mean completely different things.

---

## Then, while you are in there

**Account deletion.** Once strangers use this, they need a way to delete their
account and backup from inside the app. The delete policy is what makes that
possible: remove the object at `{user.id}/latest.cairn`, then delete the auth
user.

**The free tier pauses.** A Supabase project with no activity for a week gets
paused, and a paused project means everyone's cloud backup silently stops. This
is one reason the polish pass made Google Drive the recommended option — Drive
uses each user's own quota and has no such cliff.

---

## Why this is worth the trouble

Your anon key ships inside the APK. That is normal and unavoidable — every
Supabase app does it, and anyone can pull it out with a text editor. It is safe
**only** because policies stop it doing anything.

The encryption you built means a breach could not expose anyone's history, which
is genuinely the strongest position to be in. But an open bucket still lets
someone delete every backup you hold, and the people who lose them will have
trusted the app precisely because it offered backup.
