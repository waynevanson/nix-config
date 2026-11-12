# Blog (`blog.waynevanson.com`)

An Astro site with [Keystatic](https://keystatic.com) as the CMS, served from
the home server.

- Site: <https://blog.waynevanson.com>
- Admin: <https://blog.waynevanson.com/keystatic>
- Content repository: <https://github.com/waynevanson/blog>

## How it works

- `modules/custom/services/blog.nix` runs the Astro Node server built by the
  blog flake (`github:waynevanson/blog`).
- `blog-checkout.timer` pulls `waynevanson/blog` into `/var/lib/blog/repo` every
  two minutes.
- The site reads posts from that checkout on every request, so a saved post is
  live after the next pull without a rebuild.
- Keystatic runs in GitHub mode. Signing in through `/keystatic` uses a GitHub
  App, and saves are committed straight to `waynevanson/blog`.
- nginx proxies the domain to `127.0.0.1:3902` and uses the existing
  `waynevanson.com` ACME certificate, which includes `blog.waynevanson.com`.

## First-time setup

### 1. DNS

Create an `A` record for `blog.waynevanson.com` pointing at the server's public
IP (the same address `waynevanson.com` uses). The certificate is issued with the
Spaceship DNS-01 challenge, so it will not validate until this record exists.

### 2. Create the GitHub App

Go to <https://github.com/settings/apps/new> and create an app:

- Homepage URL: `https://blog.waynevanson.com`
- Callback URL: `https://blog.waynevanson.com/api/keystatic/github/oauth/callback`
- Webhook: disabled
- Repository permissions:
  - `Contents`: Read and write
  - `Metadata`: Read-only

Generate a client secret, install the app on `waynevanson/blog`, and note the
app's **Client ID** and **Client secret**.

### 3. Store the credentials

```sh
sops .sops.secrets.yaml
```

Replace the placeholders under `keystatic`:

- `github-client-id` — the app's client ID
- `github-client-secret` — the app's client secret
- `secret` — already generated; any long random string works

Then deploy:

```sh
nix run .#server switch
```

### 4. Verify

```sh
curl -I https://blog.waynevanson.com
systemctl status blog.service blog-checkout.timer
journalctl -u blog.service -u blog-checkout.service
```

Open <https://blog.waynevanson.com/keystatic> and sign in with a GitHub account
that has write access to `waynevanson/blog`.

## Updating the app

Content changes do not require a deployment. Code changes in the blog repository
do:

```sh
nix flake update blog
nix run .#server switch
```
