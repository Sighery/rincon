+++
date = "2026-11-10T20:54:59+01:00"
draft = true
title = "Exploring post-quantum support in sops-nix"
summary = "The documentation is a bit lacking, but turns out Age, the underlying encryption tool used by sops-nix, supports post-quantum keys"
series = ["NixOS", "Secrets management", "Sops", "Age", "Post-quantum"]
+++

<!-- {{< figure
	src="feature.webp"
	alt=""
	caption=""
	loading="eager"
	fetchpriority="high"
>}} -->

Inspired by my [previous article][Keeping NixOS secrets, secret], I decided to
investigate the state of post-quantum encryption in [sops-nix]. While sops-nix
makes no mention of post-quantum support anywhere, it uses [Age] as the
underlying encryption tool, which _can_ generate post-quantum resistant keys.

## Age post-quantum keys

Post-quantum keys are a fairly recent development, introduced with the
[v1.3.0][Age v1.3.0] Age release in December 2025


[Keeping NixOS secrets, secret]: https://sighery.com/posts/nixos-secrets-private-flake/
[sops-nix]: https://github.com/mic92/sops-nix
[Age]: https://age-encryption.org/
[Age v1.3.0]: https://github.com/FiloSottile/age/releases/tag/v1.3.0
[Age post-quantum keys]: https://github.com/FiloSottile/age/blob/b74dce4cdbe35b5e5f66c06d9612b72f89028758/README.md#post-quantum-keys
