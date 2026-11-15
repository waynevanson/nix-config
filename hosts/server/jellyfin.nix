{
  services.jellyfin = {
    enable = true;

    # Open 8096/8920 TCP and 1900/7359 UDP so TVs and phones on the LAN can
    # reach the server directly; nginx proxies it publicly on top of that.
    openFirewall = true;

    # Transcoding runs on the CPU. The boxes in this house direct-play anyway,
    # and the NVIDIA card is on `nouveau`, which has no working encode path.
    # See docs/03-jellyfin.md before enabling hardware acceleration.
  };

  # `render`/`video` are what a `/dev/dri` device is usually owned by, so they
  # are already in place if hardware acceleration is turned on later.
  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  # `waynevanson` owns the copy of the collection, `jellyfin` reads it.
  users.users.waynevanson.extraGroups = [ "jellyfin" ];

  # Media lives on the RAID array so a rebuild of the OS disk does not lose the
  # collection. The setgid bit keeps files copied in as `waynevanson` writable
  # for both that user and Jellyfin.
  systemd.tmpfiles.settings.jellyfin-media = {
    "/srv/data/media"."d" = {
      mode = "2775";
      user = "jellyfin";
      group = "jellyfin";
    };
  };

  # The name is on the shared certificate, so its DNS record must exist or
  # renewal fails for every site on the certificate (blog, S3, WordPress).
  security.acme.certs."waynevanson.com".extraDomainNames = [ "jellyfin.waynevanson.com" ];

  services.nginx.virtualHosts."jellyfin.waynevanson.com" = {
    useACMEHost = "waynevanson.com";
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8096";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;

        # Video must stream through instead of being buffered to disk, and
        # Jellyfin sends large multipart bodies for library scans/uploads.
        proxy_buffering off;
        proxy_max_temp_file_size 0;
        client_max_body_size 0;
      '';
    };
  };
}
