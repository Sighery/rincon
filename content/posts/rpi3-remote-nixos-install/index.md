+++
date = "2026-09-15T00:00:00+00:00"
draft = true
title = "Remotely installing NixOS on a Raspberry Pi 3"
summary = "Declaratively installing with disko and nixos-anywhere, and learning about trusted substituters for remote rebuilds"
# summary = "It was a bit of a struggle, but now I can provision new NixOS systems directly"
series = ["Self-Hosting", "NixOS", "Raspberry Pi"]
+++

<!-- {{< figure
	src="feature.webp"
	alt=""
	caption=""
	loading="eager"
	fetchpriority="high"
>}} -->

I have this old Raspberry Pi 3 I bought second had. So far I was using it with
[Raspberry Pi OS] to host a tiny [Home Assistant] setup, but it was always
mysteriously dying after a few days of uptime, requiring a reboot.

I was already interested in learning more about the state of _Ops_ in the Nix
world, so this was a nice excuse to go down the rabbit hole of remote NixOS
management with the little RasPi.

## What is NixOS?

{{< figure
	src="nix-triad.webp"
	alt="Humorous graphic of what is and is not Nix"
	caption="What Nix evangelists preach"
	attr="From u/SEbbaDK"
	attrlink="https://www.reddit.com/r/NixOS/comments/rffnx8/who_says_the_naming_is_confusing/"
>}}

There are three main things all confusingly referred as _Nix_, plus a fourth
also using the Nix prefix.

### Nix the package manager

First off there is [Nix, the package manager][Nix package manager]. The
website explains it more concisely than I could:

> Nix is a _purely functional package manager_. This means that it treats
> packages like values in purely functional programming languages such as
> Haskell — they are built by functions that don’t have side-effects, and they
> never change after they have been built. Nix stores packages in the
> _Nix store_, usually the directory `/nix/store`, where each package has its
> own unique subdirectory such as
> `/nix/store/b6gvzjyb2pg0kjfwrjmg1vfhh54ad73z-firefox-33.1/`
> where `b6gvzjyb2pg0…` is a unique identifier for the package that captures
> all its dependencies (it’s a cryptographic hash of the package’s build
> dependency graph).

The Nix package manager is built with C++. You can find its repository
[here][Nix package manager source].

### Nix the language

There is also [Nix, the language][Nix language]. Again a quote:

> The Nix language is designed for conveniently creating and composing
> _derivations_ – precise descriptions of how contents of existing files are
> used to derive new files. It is a domain-specific, purely functional, lazily
> evaluated, dynamically typed programming language.

To add to the confusion, Nix the language is also defined inside the Nix the
package manager's source code. Its parser can be found in
[`src/libexpr/parser.y`][Nix language parser]. That being said, if you want to
look up the language syntax, use the
[previously linked documentation][Nix language].

### Nix Packages collection: Nixpkgs

Something not shown in the previous graphic, but very much relevant, is
[Nixpkgs]. This contains a large set of _Nix expressions_:

> Packages are built from _Nix expressions_, . . . A Nix expression describes
> everything that goes into a package build action (a “derivation”): other
> packages, sources, the build script, environment variables for the build
> script, etc. Nix tries very hard to ensure that Nix expressions are
> _deterministic_: building a Nix expression twice should yield the same
> result.

### Nix Operating System: NixOS

Finally, [NixOS][NixOS how it works].

> In NixOS, the entire operating system — the kernel, applications, system
> packages, configuration files, and so on — is built by the Nix package
> manager. . . . . For instance, the configuration of the SSH daemon is also
> built from a Nix expression and stored under a path like
> `/nix/store/s2sjbl85xnrc18rl4fhn56irkxqxyk4p-sshd_config`. By building
> entire system configurations from a Nix expression, NixOS ensures that such
> configurations don’t overwrite each other, can be rolled back, and so on.

One thing that I left out of the Nixpkgs explanation in the previous
section—because it is yet another confusing intertwined concept—is that it
contains not only a collection of _derivations_, for building packages, as
well as _modules_. From [Writing NixOS Modules]:

> Each NixOS module is a file that handles one logical aspect of the
> configuration, such as a specific kind of hardware, a service, or network
> settings. A module configuration does not have to handle everything from
> scratch; it can use the functionality provided by other modules for its
> implementation. Thus a module can _declare_ options that can be used by
> other modules, and conversely can _define_ options provided by other modules
> in its own implementation.

All the NixOS modules are [also in Nixpkgs][Nixpkgs nixos/modules]. However,
use of Nixpkgs is not limited to NixOS. In fact, Nix the package manager can
be installed and ran in most other distributions, and it will consult Nixpkgs,
ignoring the NixOS modules stored within.

---

As you can see, the trifecta is indeed confusing. Everything is intertwined,
everything is Nix expressions. But by building on this base, one can truly
_declare_ a whole system.

<!-- I realise I should explain what NixOS even _is_, there might be some people
not yet familiar—despite the tireless work of Nix evangelists.

[Nix][Nix package manager] is a functional package manager. Built  -->

<!-- I have this old Raspberry Pi 3 I bought second hand. So far I was using it to
host [Home Assistant], to remotely control a few smart plugs. It was running
the default [Raspberry Pi OS], but from time to time it would just seemingly
die, all services would go down until I rebooted it.

I have managed Debian, Ubuntu, and all kinds of systems, but nowadays I have
settled on [NixOS]. The learning curve is steep, but after years I am used to
it, and being able to declaratively configure my whole system merits all the
downsides.

So far, whenever I have gotten a new system and installed NixOS on it, I get
the latest ISO, burn it into a USB stick, reboot to it, go through the GUI
install, which sets up a mostly default GNOME/Plasma system, once again
reboot, this time into the newly installed system, copy my configuration over
and finally apply it to end up with my desired system.

This is a huge waste of time. For my desktop systems I use [i3wm], no DE, so
whatever gets downloaded and set up during the GUI immediately becomes wasted
bandwidth and storage.

I also use [sops-nix] for managing my secrets. Sops-nix—based on [Sops]—uses
[Age keys][Age]—in my case derived from SSH keys, but it can use GPG keys
too—to manage the secrets en- and decryption.

I already run NixOS for most of my systems, however, so far, whenever I
install NixOS, I use the GUI installer burned onto a USB stick, and then
boot into the system -->



[Home Assistant]: https://www.home-assistant.io/
[Raspberry Pi OS]: https://www.raspberrypi.com/software/operating-systems/
[Nix package manager]: https://nixos.org/guides/how-nix-works/
[Nix language]: https://nix.dev/tutorials/nix-language.html
[NixOS how it works]: https://nixos.org/guides/how-nix-works/#how-does-nixos-work
[Nix package manager source]: https://github.com/NixOS/nix
[Nix language parser]: https://github.com/NixOS/nix/blob/18057950ca430ae42decd96174af50fe5dba59e7/src/libexpr/parser.y
[Nixpkgs]: https://github.com/NixOS/nixpkgs
[Writing NixOS Modules]: https://nixos.org/manual/nixos/unstable/#sec-writing-modules
[Nixpkgs nixos/modules]: https://github.com/NixOS/nixpkgs/tree/67a8379458e5772782cc545af1032202d0b731cb/nixos/modules
[NixOS modular services]: https://nixos.org/manual/nixos/stable/#modular-services
[NixOS]: https://nixos.org/
[i3wm]: https://i3wm.org/
[sops-nix]: https://github.com/mic92/sops-nix
[Sops]: https://getsops.io/
[Age]: https://age-encryption.org/
