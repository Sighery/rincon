+++
date = "2026-09-13T00:00:00+00:00"
draft = false
title = "FAFO: Blocking malicious traffic on my NixOS server"
summary = "You really should set up Fail2Ban"
series = ["Self-Hosting", "NixOS", "Nginx", "Fail2Ban"]
+++

{{< figure
	src="feature.webp"
	alt="Screenshot of GoAccess showing amount of bot traffic"
	caption="If you run your own server, chances are most of your traffic is bots"
	loading="eager"
	fetchpriority="high"
>}}

This site is hosted on a Hetzner VPS with [Nginx]. I also use [Fail2Ban] to
ban bots and other malicious traffic. As I run [NixOS], I will mostly show Nix
code. However, most of it is abstractions over the Nginx and Fail2Ban
configurations, so one can simply copy the relevant parts and manually apply
them to any non-NixOS systems.

I am going to skip over installing Nginx and Fail2Ban. You know your distro, I
am sure it is in their repositories, you figure it out.


## Run SSH on a different port

This is about the first thing you should do. Seriously.
[Fail2Ban has a pretty robust SSHD filter][fail2ban sshd filter], but running
your SSH server on a different port will immediately stop all of the SSH
malicious traffic.

If you do not want to specify the port every time you connect to your server,
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

```nix { caption="Sorry, you're not getting my port" attr="From my NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/home/sighery-common/ssh.nix#L60-L66" }
"wilem" = {
  user = "wilem";
  hostname = "sighery.com";
  port = builtins.elemAt secrets.wilem.ssh.ports 0;
  identityFile = "~/.ssh/wilem_wilem-${hostname}";
  identitiesOnly = true;
};
```


## Enable the SSHD jail

Even if you run SSH on a non-standard port, might as well enable it,
especially as the Fail2Ban developers have already written the filter:

```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix#L44-L47" }
jails.sshd.settings = {
  maxretry = 10;
  bantime = "1h";
};
```

```ini { title="Will add the following in <code>/etc/fail2ban/jail.local</code>" }
[sshd]
bantime = 1h
enabled = true
maxretry = 10
port = <redacted>
```

Since most automated tools only try the default port this will normally go
unused. This would only come into play for more complex tools, or a dedicated
attacker. Or if you are really unlucky, yourself if you make too many login
mistakes.


## Nginx

This is where I get most of the malicious traffic. I have to serve the site
on well-known ports—80 and 443—so there is no avoiding it. The best one can do
is mitigate it.

I like to set up blocking in Nginx so I can return early with a [444]. Then I
couple this with a Fail2Ban filter for 444 requests, and a jail that
immediately bans the IP.

### Setting up the 444 filter

```nix { linenos=true attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix" }
{ pkgs, ... }:

let
  nginx-logpath = "/var/log/nginx/access.log";

  nginx-444-filter = pkgs.writeText "nginx-444" ''
    [Definition]
    failregex = ^<HOST>.+".+" 444 .+$
  '';
in
{
  services.fail2ban = {
    jails.nginx-444.settings = {
      enabled = true;
      filter = "nginx-444";
      backend = "auto";
      logpath = nginx-logpath;
      maxretry = 1;
      banaction = "iptables-multiport";
      port = "http,https";
    };
  };

  environment.etc."fail2ban/filter.d/nginx-444.local".source = nginx-444-filter;
}
```

This is the whole Nix config for this filter and jail. It is not the easiest
to follow if you're not familiar with Nix and the Fail2Ban module, so I will
replicate the steps for a non-declarative distribution.

First off it creates a new text file, lines 6–9. You can focus on lines 7–8
which will be the exact file contents, everything around it is the Nix
machinery.

Nix will put any created files [in the store][Nix store]. In line 24 it links
the file from the store into the `/etc/fail2ban/filter.d/nginx-444.local` path
Fail2Ban will expect by default.

Finally, lines 13–21 set up the jail using this new filter.

```ini { title="In <code>/etc/fail2ban/jail.local</code>" }
[nginx-444]
backend = auto
banaction = iptables-multiport
enabled = true
filter = nginx-444
logpath = /var/log/nginx/access.log
maxretry = 1
port = http,https
```

### Blocking unused HTTP methods

You can use [`map` variables][map variables], declared in the `http` block, to
limit the HTTP methods, and then check for this variable in your `server`
block:

```nix { linenos=true attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/nginx.nix" }
{ pkgs, ... }:

let
  nginx-forbidden-maps = pkgs.writeText "nginx-forbidden-maps.conf" ''
    map $request_method $is_attack_method {
      default 1;
      "GET" 0;
      "HEAD" 0;
    }
  '';
in
{
  services.nginx = {
    appendHttpConfig = ''
      include ${nginx-forbidden-maps};
    '';

    virtualHosts."sighery.com" = {
      extraConfig = ''
        if ($is_attack_method) { return 444; }
      '';
    };
  };
}
```

Like before, `pkgs.writeText` on line 4 is Nix-specific. Again, it will create
a file with the contents between the double single quotes—lines 5–9—in the Nix
store.

Nginx maps take in one or more source variables—here just `$request_method` on
line 5, and produce an output variable—`$is_attack_method` on the same line.
The inside of the block is where the pattern matching happens. Any
`$request_method` value will by default return `1`—`true`. Unless it matches
the strings `GET` or `HEAD`, in which case will return `0`—false.

One can declare the map variables directly in the `http` block, but here I am
declaring them on an external file I include on line 15. Then it is used in
the `server` block—line 20.

```nginx { title="Will produce this condensed Nginx config" }
http {
  include /nix/store/k5rjxmrn92pjpwjpkwn60bp9s52170q4-nginx-forbidden-maps.conf;

  server {
    server_name sighery.com;

    if ($is_attack_method) { return 444; }
  }
}
```

This is a site without a backend and no JavaScript, that serves only static
files. A normal user browsing the site will never be making `POST`, `PUT`,
`PATCH`, etc. requests. This, coupled with the previous Fail2Ban jail, will
immediately ban any malicious requests prodding at these unused HTTP methods.

### Blocking unused endpoints

Same way the HTTP methods are blocked, we can use another map with
`$request_uri` to block known attack endpoints that are not in use. This is
more likely to affect an actual user, if they go around typing known attack
vector URLs in their browser. But then again: FAFO.

```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/nginx.nix" }
{ pkgs, ... }:
let
  nginx-forbidden-maps = pkgs.writeText "nginx-forbidden-maps.conf" ''
    map $request_uri $is_attack_req {
      default 0;

      "/nginx.conf" 1;
      "/SDK/webLanguage" 1;
      "/actuator/health" 1;
      "/index.php" 1;
      "/public/index.php" 1;
      "/authenticate.leano" 1;
      "/info.php" 1;
      "/phpinfo.php" 1;
      "/config.json" 1;
      "/telescope/requests" 1;
      "/server-status" 1;
      "/Dr0v" 1;
      "/login" 1;
      "/wp-config.txt" 1;
      "/config.js" 1;
      "/dump.zip" 1;
      "/backup.tar.gz" 1;
      "/mailer.zip" 1;
      "/web.zip" 1;
      "/backup.sql.gz" 1;
      "/www.zip" 1;
      "/sendgrid_backup.zip" 1;
      "/smtp.zip" 1;
      "/sendgrid.zip" 1;
      "/sendgrid_export.zip" 1;
      "/db.sql.gz" 1;
      "/exports/sendgrid.zip" 1;
      "/site.zip" 1;
      "/sendgrid-backup.zip" 1;
      "/sendgrid-export.zip" 1;
      "/backup.zip" 1;
      "/backup/sendgrid.zip" 1;
      "/dump.sql.gz" 1;
      "/db.zip" 1;
      "/mail.zip" 1;
      "/email.zip" 1;
      "/sendgrid-config.zip" 1;
      "/images/images/cache.php" 1;

      "~^/\.env" 1;
      "~^/\.cache" 1;
      "~^/GponForm/" 1;
      "~^/cgi-bin/" 1;
      "~^/\.aws/" 1;
      "~^/\.docker/" 1;
      "~^/\.git/" 1;
      "~^/\+CSCOE\+/" 1;
      "~^/onvif/device_service" 1;
      "~^/workspace/drupal" 1;
      "~^/phpunit/" 1;
      "~^/wordpress/" 1;
      "~^/wp-json/" 1;
      "~^/wp-content/" 1;
      "~^/wp/" 1;
      "~^/cpanel" 1;

      "~*/vendor/phpunit/" 1;
      "~*/wp-includes/" 1;
      "~*xmlrpc\.php" 1;
      "~*/credentials\.json" 1;
    }

    map $uri $is_attack_req2 {
      default 0;

      "/bin/sh" 1;
    }

    map $args $is_attack_params {
      default 0;
      "~*(^|&)XDEBUG_SESSION_START=phpstorm(&|$)" 1;
      "~*allow_url_include(?:=|&|$)" 1;
    }

    map "$is_attack_req:$is_attack_req2:$is_attack_params" $block_request {
      default 0;
      "~*1" 1;
    }
  '';
in
{
  services.nginx = {
    appendHttpConfig = ''
      include ${nginx-forbidden-maps};
    '';

    virtualHosts."sighery.com" = {
      extraConfig = ''
        if ($is_attack_method) { return 444; }
        if ($block_request) { return 444; }
      '';
    };
  };
}
```

[`$request_uri`][$request_uri] contains the full request URI I use to match
common attack endpoints. My site uses no PHP, nor are there any links to PHP
files, so no normal user browsing the site would end up in `/index.php`.

The previously linked [map variables] documentation explains a bit more of the
string matching syntax as well as the matching priority.

[`$uri`][$uri] matches for path traversal attacks. Although, honestly, I am
not quite sure it is currently working.

[`$args`][$args] matches query params. Supposedly, you can match them as part
of `$request_uri` too, but I found it easier to match them here explicitly.

Then I put the combination of these three matches into `$block_request`. Here
I simply check for an OR condition, whether any of the maps was `1`—`true`.

### Multiple 404 in a short timespan

```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix" }
{ pkgs, ... }:

let
  nginx-logpath = "/var/log/nginx/access.log";

  nginx-404-filter = pkgs.writeText "nginx-404" ''
    [Definition]
    failregex = ^<HOST>.+?"(\w+) .*?" 404
  '';
in
{
  services.fail2ban = {
    jails.nginx-404.settings = {
      enabled = true;
      filter = "nginx-404";
      backend = "auto";
      logpath = nginx-logpath;
      findtime = 10;
      maxretry = 10;
      banaction = "iptables-multiport";
      port = "http,https";
    };
  };

  environment.etc."fail2ban/filter.d/nginx-404.local".source = nginx-404-filter;
}
```

Here I have set a Fail2Ban filter and jail so ten 404 requests within ten
seconds will trigger a ban. This might be better solved through
[Nginx's request limits][nginx limit_req], which would also kick in much
earlier than the Fail2Ban processing and eventual ban.

### Some RDP request

Weird requests with `Cookie: mstshash=Administr` strings.
[This article][RDP attack] has a good write-up. I would like to block them
directly from Nginx but I haven't found a way to do it yet.


```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix" }
{ pkgs, ... }:

let
  nginx-logpath = "/var/log/nginx/access.log";

  nginx-rdp-discovery-filter = pkgs.writeText "nginx-rdp-discovery" ''
    [Definition]
    failregex = ^<HOST> - - .+?[Cc]ookie:\s*?mstshash=
  '';
in
{
  services.fail2ban.jails.nginx-rdp-discovery.settings = {
    enabled = true;
    filter = "nginx-rdp-discovery";
    backend = "auto";
    logpath = nginx-logpath;
    maxretry = 1;
    banaction = "iptables-multiport";
    port = "http,https";
  };

  environment.etc."fail2ban/filter.d/nginx-rdp-discovery.local".source = nginx-rdp-discovery-filter;
}
```

### SSH probes

Sometimes the server will get requests such as
`0.1.2.3 - - [11/Sep/2026:14:31:51 +0000] sighery.com:443 "SSH-2.0-Go" 400 150 "-" "-" "-"`.
Suffice to say I do not want them either. I do not know how to match them from
Nginx, so Fail2Ban filter it is.

```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix" }
{ pkgs, ... }:

let
  nginx-logpath = "/var/log/nginx/access.log";

  nginx-ssh-probe-filter = pkgs.writeText "nginx-ssh-probe" ''
    [Definition]
    failregex = ^<HOST> - - .*SSH-2.0-
  '';
in
{
  services.fail2ban.jails.nginx-ssh-probe.settings = {
    enabled = true;
    filter = "nginx-ssh-probe";
    backend = "auto";
    logpath = nginx-logpath;
    maxretry = 1;
    banaction = "iptables-multiport";
    port = "http,https";
  };

  environment.etc."fail2ban/filter.d/nginx-ssh-probe.local".source = nginx-ssh-probe-filter;
}
```

### Some TLS handshake

Requests such as
`0.1.2.3 - - [11/Sep/2026:10:45:35 +0000] sighery.com:80 "\x16\x03\x01\x00\xEE\x01\x00\x00\xEA\x03\x03\xBB^\x97\xB3\x8F\x98\x16\xA7r\x99\xE6\x02\xE0{\xA3\x0B6\x8EmW" 400 150 "-" "-" "-"`
Apparently a [TLS handshake][TLS attack]. Another I do not know how to match
from Nginx.

```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix" }
{ pkgs, ... }:

let
  nginx-logpath = "/var/log/nginx/access.log";

  nginx-tls-handshake-filter = pkgs.writeText "nginx-tls-handshake" ''
    [Definition]
    failregex = ^<HOST> - - .+? "(\\\w+){5,}
  '';
in
{
  services.fail2ban.jails.nginx-tls-handshake.settings = {
    enabled = true;
    filter = "nginx-tls-handshake";
    backend = "auto";
    logpath = nginx-logpath;
    maxretry = 1;
    banaction = "iptables-multiport";
    port = "http,https";
  };

  environment.etc."fail2ban/filter.d/nginx-tls-handshake.local".source = nginx-tls-handshake-filter;
}
```


## Included Nginx filters

So far I have listed custom filters I have written. Fail2Ban also includes a
few useful Nginx filters. In NixOS, these are also available in
`/etc/fail2ban/filters.d/`.

### HTTP Auth errors

Defined [here][Fail2Ban nginx-http-auth filter]. In my server it will ban if
there are three failed attempts within six hours.

```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix#L55-L62" }
services.fail2ban.jails.nginx-http-auth.settings = {
  enabled = true;
  filter = "nginx-http-auth";
  maxretry = 3;
  findtime = "6h";
  banaction = "iptables-multiport";
  port = "http,https";
};
```

### 403 Forbidden

This filter will match logs produced by `deny all` routes. Defined
[here][Fail2Ban nginx-forbidden filter].

```nix { caption="This uses my default setting of 5 retries within 10 minutes" attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix#L65-L70" }
services.fail2ban.jails.nginx-forbidden.settings = {
  enabled = true;
  filter = "nginx-forbidden";
  banaction = "iptables-multiport";
  port = "http,https";
};
```

### 400 Bad Request

Defined [here][Fail2Ban nginx-bad-request filter]. The filter is defined for
systemd logs, but I keep my access logs in `access.log`, so I need to
overwrite the source.

```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix#L83-L91" }
services.fail2ban.jails.jails.nginx-bad-request.settings = {
  enabled = true;
  filter = "nginx-bad-request";
  backend = "auto";
  logpath = nginx-logpath;
  maxretry = 1;
  banaction = "iptables-multiport";
  port = "http,https";
};
```

### Botsearch: Services prodding

Defined [here][Fail2Ban nginx-botsearch filter]. Similar to my custom Nginx
map—`$is_attack_req`, blocking known attack endpoints—this filter includes a
small subset of those. I defined it twice so it uses both the file access log,
as well as the error logs that get sent to journal.

```nix { attr="From this server's NixOS configuration" attrlink="https://github.com/Sighery/dotfiles/blob/570bd81e17cdb3bce54d5422832e1fbc810d4a6a/hosts/wilem/fail2ban.nix" }
services.fail2ban.jails.nginx-botsearch-error-log.settings = {
  enabled = true;
  filter = "nginx-botsearch";
  maxretry = 1;
  banaction = "iptables-multiport";
  port = "http,https";
};

services.fail2ban.jails.nginx-botsearch.settings = {
  enabled = true;
  filter = "nginx-botsearch";
  backend = "auto";
  logpath = nginx-logpath;
  banaction = "iptables-multiport";
  port = "http,https";
};
```



[Nginx]: https://nginx.org/
[Fail2Ban]: https://github.com/fail2ban/fail2ban
[NixOS]: https://nixos.org/
[fail2ban sshd filter]: https://github.com/fail2ban/fail2ban/blob/86e415a76a98ea7497ba82ed0c5412e8c7c7d8c3/config/filter.d/sshd.conf
[ssh config]: https://man7.org/linux/man-pages/man5/ssh_config.5.html
[444]: https://http.dev/444
[Nix store]: https://nixos.org/guides/how-nix-works/
[map variables]: https://nginx.org/en/docs/http/ngx_http_map_module.html
[$request_uri]: https://nginx.org/en/docs/http/ngx_http_core_module.html#var_request_uri
[$uri]: https://nginx.org/en/docs/http/ngx_http_core_module.html#var_uri
[$args]: https://nginx.org/en/docs/http/ngx_http_core_module.html#var_args
[RDP attack]: https://nishtahir.com/i-looked-through-attacks-in-my-access-logs-2/
[TLS attack]: https://superuser.com/a/1481142
[nginx limit_req]: https://nginx.org/en/docs/http/ngx_http_limit_req_module.html
[Fail2Ban nginx-http-auth filter]: https://github.com/fail2ban/fail2ban/blob/557e7eecf951049135dd52724b7f494096192177/config/filter.d/nginx-http-auth.conf
[Fail2Ban nginx-forbidden filter]: https://github.com/fail2ban/fail2ban/blob/557e7eecf951049135dd52724b7f494096192177/config/filter.d/nginx-forbidden.conf
[Fail2Ban nginx-botsearch filter]: https://github.com/fail2ban/fail2ban/blob/557e7eecf951049135dd52724b7f494096192177/config/filter.d/nginx-botsearch.conf
[Fail2Ban nginx-bad-request filter]: https://github.com/fail2ban/fail2ban/blob/557e7eecf951049135dd52724b7f494096192177/config/filter.d/nginx-bad-request.conf
