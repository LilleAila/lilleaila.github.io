---
title: "Configuring cloudflare tunnels on NixOS"
description: "Setting up declarative cloudflare tunnels on NixOS"
pubDate: "2024-10-03"
tags:
  - Tutorial
  - NixOS
---

I will assume that you have already configured your domain with cloudflare for this guide.

## Logging in

Use the `cloudflared` CLI to generate a cert to use for authentication:

```bash
nix run nixpkgs#cloudflared -- tunnel login
```

This creates the file `~/.cloudflared/cert.pem`. This file is required to create new tunnels. You can for example manage it using [sops-nix](https://github.com/Mic92/sops-nix) in home-manager:

```nix
# home-manager module

sops.secrets."cloudflared/cert".path = "${config.home.homeDirectory}/.cloudflared/cert.pem";
```

## Creating a tunnel

Use `cloudflared` to create the tunnel and get the credentials:

```bash
$ cloudflared tunnel create test
Tunnel credentials written to /home/olai/.cloudflared/4a2e3c16-1f7a-49ec-82aa-a1b2567b96d0.json. cloudflared chose this file based on where your origin certificate was found. Keep this file secret. To revoke these credentials, delete the tunnel.

Created tunnel test with id 4a2e3c16-1f7a-49ec-82aa-a1b2567b96d0
```

As the error says, this file should be kept secret, i use sops-nix for this too. Remember the tunnel id for later.

## Declaratively running the tunnel

First, enable the service and add the contents of the file from the previous section to sops, and give it the necessary permissions:

```nix
# NixOS module
services.cloudflared.enable = true;

sops.secrets."cloudflared/test" = {
    # Both are "cloudflared" by default
    owner = config.services.cloudflared.user;
    group = config.services.cloudflared.group;
};
```

Then, configure the `cloudflared` service to use the tunnel:

```nix
services.cloudflared.tunnels."4a2e3c16-1f7a-49ec-82aa-a1b2567b96d0" = {
  credentialsFile = config.sops.secrets."cloudflared/test".path;
  default = "http_status:404";
  ingress = {
    "test.olai.dev" = "http://localhost:8080";
  };
};
```

Replace

- `test.olai.dev` with your domain
- `localhost:8080` with the port your service is running on
- `4a2e3c16-1f7a-49ec-82aa-a1b2567b96d0` with your tunnel ID

That's it, now the tunnel should run and be visible in the cloudflare dashboard as "HEALTHY" under `Zero Trust -> Networks -> Tunnels`.

## Configure the domain

The last step is to add a DNS record so that the domain points to your tunnel. Navigate to `<Your domain> -> DNS -> Records` in the cloudflare dashboard, and add a CNAME record pointing to `<your tunnel id>.cfargotunnel.com`, and leave the other settings as-is. If everything went well, your local service should now be exposed at the domain specified.
