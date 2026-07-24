+++
date = "2026-07-10T00:00:00+00:00"
draft = true
title = "FAFO: Blocking malicious traffic on my NixOS VPS"
summary = "You really should set up fail2ban"
series = ["Self-Hosting", "NixOS"]
+++

{{< figure
	src="feature.webp"
	alt="Screenshot of GoAccess showing amount of bot traffic"
	caption="If you run your own server, chances are most of your traffic is bots"
	loading="eager"
	fetchpriority="high"
>}}

This site is hosted with [Nginx] on a Hetzner VPS. I also use [Fail2ban] to
ban bots and other malicious traffic. I run [NixOS], so I will mostly show Nix
code. However, most of it is abstractions over the Nginx and Fail2ban
configuration, so one can simply copy the relevant bits and manually apply
them to any non-NixOS systems.

I am going to omit installing Nginx and Fail2ban. You know your distro, I am
sure it is in their repositories, you figure it out.


## Run SSH on a different port

That is about the first thing you should do. Seriously.
[Fail2ban has a pretty robust SSHD filter][fail2ban sshd filter], but running
your SSH server on a different port will immediately stop all of the SSH
malicious traffic.

If you don't want to specify the port every time you connect to your server,
you really should get familiar with your [`~/.ssh/config` file][ssh config].
An example configuration:

```ini
Host shortname
  hostname mysite.com
  identitiesOnly yes
  identityFile ~/.ssh/my_private_key
  port 1234
  user username
```

Then you could connect to your server by simply running `ssh shortname`. In
fact, that is pretty much my SSH config for this server:

```ini { file="temp.txt" caption="Sorry, you're not getting my port" attr="<br>From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/340445f91c620e8276c3388bd826006604348b47/home/sighery-common/ssh.nix#L60-L66" }
"wilem" = {
  user = "wilem";
  hostname = "sighery.com";
  port = builtins.elemAt secrets.wilem.ssh.ports 0;
  identityFile = "~/.ssh/wilem_wilem-${hostname}";
  identitiesOnly = true;
};
```

Temp text here to test padding:

```nix { title="Short description" caption="Sorry, you're not getting my port" attr="<br>From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/340445f91c620e8276c3388bd826006604348b47/home/sighery-common/ssh.nix#L60-L66" }
"wilem" = {
  user = "wilem";
  hostname = "sighery.com";
  port = builtins.elemAt secrets.wilem.ssh.ports 0;
  identityFile = "~/.ssh/wilem_wilem-${hostname}";
  identitiesOnly = true;
};
```


More text:

{{< figure
	src="feature.webp"
	caption="Testing"
>}}

Again more text:


### 


[Nginx]: https://nginx.org/
[Fail2ban]: https://github.com/fail2ban/fail2ban
[NixOS]: https://nixos.org/
[fail2ban sshd filter]: https://github.com/fail2ban/fail2ban/blob/86e415a76a98ea7497ba82ed0c5412e8c7c7d8c3/config/filter.d/sshd.conf
[ssh config]: https://man7.org/linux/man-pages/man5/ssh_config.5.html
