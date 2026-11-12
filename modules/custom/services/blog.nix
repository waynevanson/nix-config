{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.services.blog;

  stateDir = "/var/lib/blog";
  repoDir = "${stateDir}/repo";

  blogPackage =
    if cfg.package != null then
      cfg.package
    else
      inputs.blog.packages.${pkgs.stdenv.hostPlatform.system}.default;

  checkout = pkgs.writeShellScript "blog-checkout" ''
    set -eu

    repo=${lib.escapeShellArg repoDir}
    url=${lib.escapeShellArg cfg.repository}
    branch=${lib.escapeShellArg cfg.branch}

    if [ ! -d "$repo/.git" ]; then
      echo "cloning $url into $repo"
      rm -rf "$repo" "$repo.tmp"
      ${lib.getExe pkgs.git} clone --depth=1 --branch "$branch" "$url" "$repo.tmp"
      mv "$repo.tmp" "$repo"
    else
      echo "updating $repo"
      ${lib.getExe pkgs.git} -C "$repo" fetch --depth=1 origin "$branch"
      ${lib.getExe pkgs.git} -C "$repo" reset --hard FETCH_HEAD
      ${lib.getExe pkgs.git} -C "$repo" clean -fdx
    fi
  '';
in
{
  options.custom.services.blog = {
    enable = lib.mkEnableOption "Astro + Keystatic blog";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "blog.waynevanson.com";
      description = "Public domain for the blog.";
    };

    acmeHost = lib.mkOption {
      type = lib.types.str;
      default = "waynevanson.com";
      description = "Existing ACME certificate that should cover `domain`.";
    };

    repository = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/waynevanson/blog";
      description = "Git repository that Keystatic commits content to and the reader serves.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Branch to read content from.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3902;
      description = "Loopback port the Node server listens on.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "blog";
      description = "System user that owns the checkout and runs the server.";
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      defaultText = lib.literalExpression "inputs.blog.packages.\${system}.default";
      description = "Built blog (Astro `dist/` plus node_modules). Defaults to the blog flake's package.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.user} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = stateDir;
      description = "Astro + Keystatic blog";
    };

    # Keystatic authenticates editors through a GitHub App and commits content
    # with it. Create the app (see docs/02-blog.md) and fill these in with `sops`.
    sops.secrets.keystatic-github-client-id = {
      key = "keystatic/github-client-id";
    };
    sops.secrets.keystatic-github-client-secret = {
      key = "keystatic/github-client-secret";
    };
    sops.secrets.keystatic-secret = {
      key = "keystatic/secret";
    };

    sops.templates.blog-env = {
      content = ''
        KEYSTATIC_GITHUB_CLIENT_ID=${config.sops.placeholder.keystatic-github-client-id}
        KEYSTATIC_GITHUB_CLIENT_SECRET=${config.sops.placeholder.keystatic-github-client-secret}
        KEYSTATIC_SECRET=${config.sops.placeholder.keystatic-secret}
      '';
      owner = cfg.user;
      group = cfg.user;
      restartUnits = [ "blog.service" ];
    };

    # Content is a plain git checkout: Keystatic (GitHub mode) commits to the
    # repository, and the timer brings those commits onto the server.
    systemd.services.blog-checkout = {
      description = "Checkout the blog content repository";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.user;
        StateDirectory = "blog";
        WorkingDirectory = stateDir;
        Environment = [
          "HOME=${stateDir}"
          "GIT_TERMINAL_PROMPT=0"
        ];
        ExecStart = checkout;
        TimeoutStartSec = "5min";
      };
    };

    systemd.timers.blog-checkout = {
      description = "Periodically pull the blog content repository";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "2min";
      };
    };

    systemd.services.blog = {
      description = "Astro + Keystatic blog";
      after = [
        "network-online.target"
        "blog-checkout.service"
      ];
      wants = [
        "network-online.target"
        "blog-checkout.service"
      ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        HOST = "127.0.0.1";
        PORT = toString cfg.port;
        NODE_ENV = "production";
        BLOG_REPO_PATH = repoDir;
      };
      serviceConfig = {
        User = cfg.user;
        Group = cfg.user;
        WorkingDirectory = "${blogPackage}/share/blog";
        ExecStart = "${lib.getExe pkgs.nodejs_24} ${blogPackage}/share/blog/dist/server/entry.mjs";
        EnvironmentFile = config.sops.templates.blog-env.path;
        Restart = "on-failure";
        RestartSec = "5s";

        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    security.acme.certs.${cfg.acmeHost}.extraDomainNames = lib.mkAfter [ cfg.domain ];

    services.nginx.virtualHosts.${cfg.domain} = {
      useACMEHost = cfg.acmeHost;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Port $server_port;
          client_max_body_size 25m;
        '';
      };
    };
  };
}
