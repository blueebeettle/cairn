# What the account and backup feature obliges you to do

Written 14 September 2026, after login/signup, Google Drive and Supabase backup
landed.

`RELEASE.md` said "no sync, no accounts — export covers the real need without a
privacy policy, a Data Safety attestation and a web-accessible deletion route."
That is now out of date. Data leaves the device, so those become real.

None of this is a criticism of what you built. The encryption is genuinely well
done — AES-256-GCM, a fresh random salt and nonce per backup, gzip before
encrypt, authentication failures distinguished from corruption, and a magic
header that leaves room to version the format. Backups are unreadable to you,
which is the strongest position to be in. These are the things that come with
holding other people's data anyway.

---

## 1. Google Sign-In Removed (No OAuth / SHA-1 Configuration Required)

> [!NOTE]
> As of September 2026, Google Sign-In and Google Drive integration have been
> completely removed from Cairn.

This eliminated the fragility of registering OAuth client IDs and debug/release
SHA-1 certificate fingerprints in Google Cloud Console.

Instead, Cairn uses:
1. **Local Encrypted Vault Files (.cairn)**: Zero setup, AES-256-GCM encrypted,
   and 100% offline. Users can share or save to Google Drive or any cloud using
   the system share sheet.
2. **Cairn Cloud Account (Supabase)**: Straightforward email and password
   authentication for remote encrypted backup without third-party OAuth.

## 2. Check Row Level Security on the Supabase project — today

`SupabaseBackupService.defaultAnonKey` ships in the APK. That is normal and
expected: anon keys are designed to be public, and anyone can extract one from
any app that uses Supabase.

They are safe **only because Row Level Security is supposed to stop them doing
anything.** If RLS is off on any table, that key is full read and write access
to your database for anyone who opens the APK with a text editor.

Go to the Supabase dashboard → Authentication → Policies, and confirm for every
table:

- RLS is **enabled**.
- There is a policy restricting rows to `auth.uid() = user_id` or equivalent.
- There is no policy granting the `anon` role access to anything.

Supabase warns about unprotected tables in the dashboard. Do not ship until that
list is empty. The backups themselves are encrypted, so a breach would not
expose anyone's history — but an open table still means anyone can delete every
user's backup, or fill your storage quota.

## 3. You are now holding other people's data

Every user's cloud backup goes to **your** Supabase project. That makes you the
data controller, encrypted or not.

Required before the app reaches people who are not friends:

- **A privacy policy**, publicly hosted, linked from Settings → About. It needs
  to say what is stored (an encrypted blob and an email address), where, and how
  to get it deleted.
- **Account deletion**, reachable from inside the app — Settings → Account →
  Delete account, removing the auth user and their backup rows.
- If you ever go to Play: the **Data Safety form**, which is an attestation, and
  a **web-accessible** deletion request URL, not only an in-app one.

For a handful of testers who know you, a written note is enough. The moment it
goes to strangers or to Play, it is not.

## 4. Free-tier limits are a real ceiling

Supabase free tier pauses projects after a week of inactivity and caps database
and storage. A paused project means every user's cloud backup silently stops
working.

Google Drive `appdata` has no such problem — it uses each user's own quota, not
yours, which is why it is the right default and why the polish prompt makes it
the recommended option.

Worth deciding before you have users: if the Supabase project ever goes away,
what happens to people relying on it? The honest answer today is "their backups
stop", and the app should nudge them toward Drive or a local file.

## 5. Raise the PBKDF2 iteration count when convenient

`backup_crypto_engine.dart` uses 100,000 iterations of PBKDF2-HMAC-SHA256.
Current OWASP guidance for that algorithm is 600,000.

Not a blocker, and not worth breaking the format for on its own. The `CAIRN1`
magic header already gives you a clean way to do it: write new backups as
`CAIRN2` at the higher count, keep reading `CAIRN1` at 100,000 forever.

This matters more once the minimum password length is fixed, since iteration
count and password strength defend against the same attack and the password is
doing most of the work.

---

## The revised order to release

1. **This file's items 1 and 2** — the SHA-1 registration and the RLS check.
   Both are quick, and item 1 is invisible until it breaks in front of testers.
2. `PROMPT-final-ui-polish.md` — the backup screen's missing password warning is
   in there and is the highest-value single change.
3. Onboarding, if you still want it before release.
4. Keystore, release build, SPEC §8 device checks 4–8.
5. Privacy policy and in-app deletion, before it goes past people who know you.
