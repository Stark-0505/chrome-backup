# chrome-backup

Carries Chrome Beta's **signed-in account state** (all profiles) across a clean
KDE Fedora reinstall, without re-doing Google sign-in on every profile.

## What's in this repo — and what isn't

Only the automation. **No account data, tokens, or wallet secrets live here, on
purpose.** Those live in `chrome-beta-account-backup.tar.gz`, which you generate
yourself and move between machines by USB/cloud storage — never via git. See
"Why not just commit the archive?" below.

- `chrome-account-backup.sh`
  - `backup` — run on the OLD machine before wiping it. Pulls the sign-in-related
    files from every Chrome Beta profile (not cookies, history, or extensions),
    plus the KWallet secret that decrypts them, into `~/chrome-beta-account-backup.tar.gz`.
  - `restore` — run on the NEW machine, with that archive already sitting in `$HOME`.
    Puts the profile files and wallet secret back in place.
  - `setup` — `restore`, then installs Google Chrome Beta. This is what the
    one-liner below runs.

## Before wiping the old machine

```bash
./chrome-account-backup.sh backup     # writes chrome-beta-account-backup.tar.gz
./chrome-account-backup.sh encrypt    # writes chrome-beta-account-backup.tar.gz.gpg
                                       # (prompts you to set a passphrase — pick a
                                       # long, unique one, and save it in a password
                                       # manager, not in this repo)
git add chrome-beta-account-backup.tar.gz.gpg
git commit -m "update encrypted backup"
git push
```

Only the `.gpg` file gets committed — the `.gitignore` here blocks the plaintext
`*.tar.gz` from ever being added by accident.

## Fresh-install flow (fully automated)

1. Finish the Fedora KDE reinstall, log in — **don't open Chrome yet**.
2. Run:

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Stark-0505/chrome-backup/main/chrome-account-backup.sh | bash -s -- setup
   ```

   This pulls the encrypted backup from this repo, asks for your passphrase
   (via GPG's normal prompt — a dialog box on a KDE desktop session), decrypts
   it, restores every profile + the wallet secret, and installs Chrome Beta.
3. Log out, log back in, open Chrome Beta. Every profile should already show its
   Google account signed in.

No USB step. The only thing that has to happen manually is typing the
passphrase once.

> **Repo visibility:** this is a plain, unauthenticated `curl`, so it needs the
> repo to be **public**. GitHub's raw file URLs don't serve private repos
> without a token embedded in the request — that would mean managing yet
> another credential just to fetch a file that, encrypted, doesn't need one.

## Why encryption instead of just committing the archive?

`chrome-beta-account-backup.tar.gz` contains live OAuth refresh tokens for every
signed-in Google account on the machine, plus the KWallet secret that decrypts
them — and that same wallet secret also protects everything else stored in
KWallet (Wi-Fi passwords, other app credentials). Committing it in plaintext
would put all of that in the repo's history permanently, readable by anyone who
ever gets repo access. Encrypting it first (AES-256 via GPG, symmetric
passphrase) means the committed blob is only as strong as the passphrase —
which is why the passphrase should be long, unique to this, kept in a password
manager, and never written into this repo, the script, or a commit message.
Anyone downloading the blob without it gets nothing usable.
