# Jellyfin (`jellyfin.waynevanson.com`)

The server runs [Jellyfin](https://jellyfin.org)'s media server from
`hosts/server/jellyfin.nix`. It listens on `:8096` for devices on the
LAN, and nginx reverse-proxies it on `https://jellyfin.waynevanson.com` using
the shared `waynevanson.com` certificate.

- Library root: `/srv/data/media` (on the RAID array, survives reinstalls)
- State/cache: `/var/lib/jellyfin`, `/var/cache/jellyfin` (OS SSD)
- Transcoding: software only (see below)

## 1. DNS (do this first)

Create an `A` record for `jellyfin.waynevanson.com` at the same address as
`waynevanson.com`. The name is part of the shared `waynevanson.com` ACME
certificate, so **a missing record makes renewal fail for every site on it**
(blog, S3, WordPress), not just Jellyfin.

## 2. Deploy

```sh
nix run .#server switch
```

Verify, then finish the first-run wizard:

```sh
curl -I https://jellyfin.waynevanson.com
systemctl status jellyfin.service nginx.service
```

Also open `http://<server-lan-ip>:8096` from the LAN; the reverse proxy serves
`127.0.0.1:8096`, so if the public URL fails but this works the problem is in
nginx/DNS, not Jellyfin.

> **Finish the first-run wizard immediately after deploying.** Until an admin
> account exists, anyone who loads the URL gets the setup page and can claim the
> server. If you can't do it right away, comment out the nginx vhost and the
> `extraDomainNames` entry and add them afterwards.

## 3. Add media

```sh
# on the server
sudo mkdir -p /srv/data/media/{movies,shows,music}
# copy from your workstation, e.g.
rsync -avP ~/Videos/ /server:/srv/data/media/movies/
```

`/srv/data/media` is `jellyfin:jellyfin` with the setgid bit, and
`waynevanson` is in the `jellyfin` group, so both can write to it.

In the dashboard add libraries pointing at `/srv/data/media/movies`,
`/srv/data/media/shows` and so on. Jellyfin prefers the usual
`Movies/Name (Year)/Name (Year).mkv` and `Shows/Name/Season 01/S01E01.mkv`
layouts for metadata matching.

## 4. Watching on the TV

**Use the network, not the HDMI cable.** The TV only needs to be on the same
LAN as the server, and playback then direct-plays (the TV decodes the file, so
no CPU transcoding and full quality).

1. On the TV, open the Play Store and install **Jellyfin** (`org.jellyfin.androidtv`).
   Canvas TVs run Google TV, so this is available. If the store build is
   missing, sideload the APK from <https://jellyfin.org/downloads> with
   `adb install` or the "Downloader" app.
2. In the app, add the server address `http://<server-lan-ip>:8096` (or
   `http://server:8096` if your router's DNS resolves hostnames).
3. Sign in with the admin account, or create a dedicated user for the TV.

Check that the stream is direct-playing when a movie starts
(Dashboard → Activity). If it is transcoding, the TV's decoder does not support
that codec — usually 10-bit HEVC or AV1 — and the Ryzen 2400G will struggle
with 4K. Prefer H.264 or 8-bit HEVC files for reliability.

Casting from the Jellyfin phone app to the TV also works, since Google TV
includes a Chromecast receiver.

### HDMI fallback

The server already drives the TV over HDMI (nouveau framebuffer). Running a
full-screen client locally is possible with Kodi plus its Jellyfin addon:

```nix
services.kodi.enable = true;
services.kodi.package = pkgs.kodi.withPackages (p: [ p.jellyfin ]);
```

That takes over the console on a spare VT, and with `nouveau` there is no
hardware video decode, so it is limited to roughly 1080p H.264. It is only
worth it if the TV's own app turns out to be unusable.

## Public access

The vhost is enabled in `hosts/server/jellyfin.nix` alongside the
`extraDomainNames` entry on the `waynevanson.com` certificate. To take it back
LAN-only, remove those two blocks (the `:8096` listener and firewall rule stay).
TCP 80/443 must be forwarded on the router (already needed for the other sites).

Before exposing it publicly, create a Jellyfin user with a strong password, and
consider disabling remote sign-up in Dashboard → Users.

## Hardware transcoding (optional, not enabled)

The machine has a GTX 1660 Super (Turing NVENC: H.264 and HEVC 8/10-bit). It is
currently on the open `nouveau` driver, which cannot encode, so Jellyfin runs on
the CPU.

To enable it: switch the card to the proprietary driver
(`hardware.nvidia.enable`/`hardware.graphics.enable` with
`hardware.nvidia.open = true` for Turing, keeping the kernel module out of the
initrd so a driver failure doesn't break boot), then allow the NVIDIA devices in
the unit and select NVENC:

```nix
services.jellyfin = {
  hardwareAcceleration = {
    enable = true;
    type = "nvenc";
    device = "/dev/nvidia0";
  };
};
systemd.services.jellyfin.serviceConfig.DeviceAllow = lib.mkForce [
  "/dev/nvidiactl rw"
  "/dev/nvidia0 rw"
  "/dev/nvidia-modeset rw"
  "/dev/dri/renderD128 rw"
];
```

Verify with `nvidia-smi` during playback. Do this only after confirming the
cards work without it: changing the GPU driver on a machine whose console is
the TV is the kind of change that can leave you with a black screen.

## Troubleshooting

```sh
systemctl status jellyfin.service
journalctl -u jellyfin.service -f
curl -I http://127.0.0.1:8096
```
