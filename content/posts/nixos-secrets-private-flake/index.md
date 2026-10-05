+++
date = "2026-10-05T00:00:00+00:00"
draft = false
title = "Keeping NixOS secrets, secret"
summary = "The NixOS ecosystem has a few secrets management solutions that allow you to encrypt secrets, and decrypt them at runtime. But what if you don't want to share your encryted secrets publicly?"
series = ["NixOS", "Secrets management", "Sops"]
+++


The two mature secrets management solutions in the NixOS world are [sops-nix]
and [agenix]. Both support [age] keys for encryption, although sops-nix also
allows using GPG keys.

There is an upcoming [nix-secrets] contender that promises to integrate
directly in your NixOS configuration. A non-Nix option is [git-crypt], which
has been around forever.

All these tools have one thing in common: they all encrypt secrets, store the
encrypted values in the repository, and decrypt them at runtime.

This poses somewhat of a risk. The encrypted files are _currently_ safe, but
are they _post quantum_ safe?


## A typical sops-nix configuration

The [sops-nix usage] documentation contains more information, but I will skip
over the complexities to demonstrate the basic premise of the article.

```yaml { file=".sops.yaml" caption="A basic sops configuration" }
keys:
  - &admin age1hfhgprxggnufexarrwljt8d40qtnraj26mure75xsdzy9nt56pfqtnyh6u
  - &host age1eyq4te36xg022tyjp94xceeayss7wxr78pq3m7vzh4pgxd8jwpdq4f3qm0

creation_rules:
  - path_regex: '[^/]+\.(yaml|json|env|ini)$'
    key_groups:
      - age:
        - *admin
        - *host
```

```yaml { file="my_secret_file.yaml" caption="Encrypted file after running <code>sops my_secret_file.yaml</code>" }
acme_api_key: ENC[AES256_GCM,data:/Rh0E9b+BQ==,iv:vJL+eYnTP3h6/KLnSXcoTUn+Lj0+/temEVNYVC304LQ=,tag:hM2CWhKpW9/77GaaMFSGAw==,type:str]
acme_api_secret: ENC[AES256_GCM,data:/a10W01J6A==,iv:UzX/Lt2EGJNeePJq3OfpLLyuE29sSnjW0tgemPwDiNU=,tag:P8HNBPMqSHvzGVYGOyGCAA==,type:str]
sops:
  age:
    - enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSB1cm1DWkxTZkw4bEZ4aXoz
        UGZmZGFsZVQvaGxjRkNlTkZILzJ0M3UyQVdFCnFBZW04TEpYNU1jbm9WdiswWDd6
        QjJ0bUt4RjdQSC9pVm9sWDVGOW0vT0UKLS0tIDI5VmptcWNtVEFwb2VLalJHL1Vr
        VGcyRnZCalYzVWEyeXJqLzhTc0x3cEEK8IhIApZR9gFzGK0tgB4soz0j2mkMZFQd
        YvYUEF616kRK7AFyfHCyHbDI5LsiND6yfUw55VJp53qpxrD0QMy2bA==
        -----END AGE ENCRYPTED FILE-----
      recipient: age1hfhgprxggnufexarrwljt8d40qtnraj26mure75xsdzy9nt56pfqtnyh6u
    - enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBVS3RQbFJVamxjYTQwSkRn
        ZCtyN2YrUU1mV0dVU09oa3BYb09TTTFHU1Q0CjFtQTBpR0U0TWFMTWIwQTUzU3cy
        RVRTTlBOV29PUDBIUUJuUFY0R0VBZXMKLS0tIHU0eGtQZUkwbE8xaGJxUzMrN3pu
        QzhTSEN5YWF2a0FyL29QdEhRVXE5aU0KMlTvNOwNbIvUPrkoZ9PE97DFavv2CzZa
        bYykWz0yMHKkPPs/uWeOtsWSjputC1q1OxIpGGxKbIZknV/uEzdcZg==
        -----END AGE ENCRYPTED FILE-----
      recipient: age1eyq4te36xg022tyjp94xceeayss7wxr78pq3m7vzh4pgxd8jwpdq4f3qm0
  lastmodified: "2026-10-04T01:09:33Z"
  mac: ENC[AES256_GCM,data:0Cdo5VyxxLPDElAgCGKl1Js19igMZeCcm7EcRInbpXF4/1x2qB0hHLOWXhP+3WUxweWYocyvV/GgBFpkkgn6zKe7p0KCdBv+Cl0VQcmlj+aIpn+o1nPXBZGfVMvgPVUp4x4j9vczgqR0isOns+79Zsf5NjhJX1zRMPjpbSggbSg=,iv:JrYa/7AHQumuA0XL94uKt9HBdzJeD6D9zLkjU2cfr0s=,tag:T+l5HIvSf42UtzY3B8kpTQ==,type:str]
  unencrypted_suffix: _unencrypted
  version: 3.13.3
```

This encrypted file contains the API credentials to allow for ACME—automatic
certificate renewals. The NixOS configuration would then reference the secrets
like so:

```nix { hl_lines=[4, 8, 18] }
{ config, ... }:

{
  # Basic Sops setup
  sops.defaultSopsFile = ./my_secret_file.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # Declaring secrets we want to decrypt and their permissions
  sops.secrets."acme_api_key" = {
    mode = "0400";
    owner = "acme";
  };
  sops.secrets."acme_api_secret" = {
    mode = "0400";
    owner = "acme";
  };

  # Passing the decrypted files to the ACME service
  security.acme = {
    acceptTerms = true;
    defaults.email = "owner@mydomain.com";

    certs."mydomain.com" = {
      domain = "mydomain.com";
      dnsProvider = "my_dns_provider";
      dnsPropagationCheck = true;

      credentialFiles = {
        "PROVIDER_API_KEY_FILE" = config.sops.secrets."acme_api_key".path;
        "PROVIDER_API_SECRET_FILE" = config.sops.secrets."acme_api_secret".path;
      };
    };
  };
}
```

The decrypted values are never passed directly. Instead, the values are
written to decrypted files, and their paths are passed to the services that
need them. This can be a problem for programs that don't support providing
secrets through file references.
{ class = "aside" }

This is _currently_ safe, and you will find plenty of people committing these
files as is into their public repositories. However, depending on the keys 
used to encrypt, as well as the encryption tool, this might or might not be
_post quantum_ safe.


## Not quite secrets: sensitive values

One limitation from `sops-nix`—as well as `agenix`—is that secrets
[cannot be used at evaluation time][sops-nix evaluation time limitation].

> It is not possible to use secrets at evaluation time of nix code. This is
> because sops-nix decrypts secrets only in the activation phase of nixos i.e.
> in `nixos-rebuild switch` on the target machine.

The _evaluation_ phase in NixOS resolves your configuration—that is, all the
values and dependencies—and builds a giant Bash script to establish the new
desired system state. The _activation_ phase is where this Bash script gets
executed.
{ class = "aside" }

My configuration contains values that are not quite secrets, but that I
nonetheless want to keep private. These are values like my work email, Wi-Fi
SSIDs, some service ports, etc.

```nix
{ ... }:

{
  programs.ssh.settings = {
    "private.work_git.domain" = {
      user = "git";
      identityFile = "~/.ssh/work_git_key";
      identitiesOnly = true;
    };
  };

  programs.git.includes = [
    {
      contents = {
        user = {
          email = "private.email@company.com";
          name = "Full Name";
        };
      };
    }
  ];
}
```

This example shows a basic [Home Manager] SSH and Git user configuration, full
of _not quite secrets_, but definitely _sensitive values_. Displaying your
work email is not a big deal, but having it publicly listed "leaks"
information like where you work at, and makes you a target for phishing
attacks.

So while it is not a problem if they became public, I would rather avoid the
hassle and keep them private too. Sadly, I cannot just chuck them in with the
rest of the secrets and reference them in the NixOS config.


## Two birds with one stone: a private flake

Instead of keeping the encrypted secrets in the same repository as my NixOS
configurations, which is public, I can fetch them from an external private
repository. With flakes this is trivial:

```nix { caption="Abridged example from my own configuration" }
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets.url = "github:Sighery/dotfiles-secrets";
  };

  outputs = { self, nixpkgs, sops-nix, secrets }: {
    nixosConfigurations.panda = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";

      modules = [
        {
          system.stateVersion = "26.05";
          networking.hostName = "panda";
        }
        ./hosts/panda/configuration.nix

        sops-nix.nixosModules.sops
      ];

      specialArgs = { inherit secrets; };
    };
  };
}
```

This requires authentication. For this, I am using
[GitHub Personal Access Tokens]. More accurately, I will generate a
[fine-grained PAT] that has read-only access to this repository:

{{< figure
	src="./new_pat.webp"
	attr="Creating a new fine-grained GitHub PAT"
	attrlink="https://github.com/settings/personal-access-tokens/new"
>}}

Once you have the PAT, you can configure Nix to [use it][Nix access-tokens]:

```sh { class="code-wrap" }
export NIX_CONFIG="access-tokens = github.com=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S"
```

After a `nixos-rebuild` it will be cached in the Nix store and the token will
go unused. You would only need to set it again after you change the secrets
and update the input, so the new version is fetched and stored.

### What the private flake looks like

```sh
.
├── flake.nix
├── README.md
└── secrets
    ├── common
    │   ├── networking-wireless.yaml
    │   └── syncthing-relay.yaml
    ├── loxez
    │   └── main.yaml
    ├── panda
    │   └── main.yaml
    ├── sonar
    │   └── main.yaml
    ├── tiber
    │   └── main.yaml
    └── wilem
        └── main.yaml
```

The previous `.sops.yaml` example was already based on my setup. Mine simply
includes more hosts, as well as common secrets that can be decrypted by
multiple hosts.

### Storing sensitive values

Since I am already storing secrets in this external flake, I can also store
the sensitive values here. Any output of the `flake.nix` can be referenced at
evaluation time:

```nix { caption="All the output names are arbitrary, just remember what you named them" }
{
  outputs = { ... }: {
    git = {
      work = {
        work_email = "private.email@company.com";
        work_name = "Full Name";
      };
    };

    ssh = {
      work_domain = "private.work_git.domain";
    };
  };
}
```

### Using the private flake in the public facing configuration

We can do attribute lookups with the `private_flake.customAttribute` syntax:

```nix { caption="The previous HM configuration, with the sensitive values approach" }
{ secrets, ... }:

{
  programs.ssh.settings = {
    secrets.ssh.work_domain = {
      user = "git";
      identityFile = "~/.ssh/work_git_key";
      identitiesOnly = true;
    };
  };

  programs.git.includes = [
    {
      contents = {
        user = {
          email = secrets.git.work.work_email;
          name = secrets.git.work.work_name;
        };
      };
    }
  ];
}
```

Likewise, secret files can also be referenced and decrypted from the flake
directly. By coercing the flake into a string—like
`"${private_flake}/my_secret_file.yaml"`—Nix will find its store path and look
for the given file in its source tree:

```nix { caption="Adding token support was <a target='_blank' rel='noopener' href='https://github.com/NixOS/nixpkgs/pull/541149'>my first Nixpkgs contribution!</a>" attr="From my NixOS configurations" attrlink="https://github.com/Sighery/dotfiles/blob/d7e42ac18d55262971dceb5b3b130af9b0aff35d/hosts/wilem/syncthing-relay.nix" }
{ config, secrets, ... }:

{
  sops.secrets."tokens/wilem" = {
    sopsFile = "${secrets}/secrets/common/syncthing-relay.yaml";
  };

  services.syncthing.relay = {
    enable = true;
    token = config.sops.secrets."tokens/wilem".path;
  };
}
```

### Something to keep in mind

One thing to note is that while the sensitive values and encrypted secrets
will no longer be publicly listed, they will still be in the world-readable
Nix store.

This is basically unavoidable, and would still be the case even if you listed
the sensitive values publicly and kept the secrets in the same public
repository.



[sops-nix]: https://github.com/mic92/sops-nix
[agenix]: https://github.com/ryantm/agenix
[age]: https://age-encryption.org/
[nix-secrets]: https://github.com/unnamed-systems/nix-secrets
[git-crypt]: https://github.com/agwa/git-crypt
[sops-nix usage]: https://github.com/mic92/sops-nix#usage-example
[sops-nix evaluation time limitation]: https://github.com/mic92/sops-nix#using-secrets-at-evaluation-time
[Home Manager]: https://github.com/nix-community/home-manager
[GitHub Personal Access Tokens]: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
[fine-grained PAT]: https://github.com/settings/personal-access-tokens
[Nix access-tokens]: https://nix.dev/manual/nix/2.22/command-ref/conf-file.html#conf-access-tokens
[syncthing-relay token]: https://github.com/NixOS/nixpkgs/pull/541149
