+++
title = "About"
summary = "What's this about?"
date = '2026-06-12T00:00:00+00:00'
draft = false
hidetitle = true
+++

### Who am I

Hey there. I'm Lucian, the person behind all the articles. I enjoy programming
and tinkering, so that's what most of my articles are about. Most of my
projects are open-source, and can be found on my [GitHub].

### Where to find me

Sometimes I stream on [Twitch]; these are either programming streams, or
outdoor cycling streams. A full list of my socials and how to reach me can be
found in the footer.

### AI use

**I don't use AI in any of my articles**.

Over the years I've relied on plenty of blogs and articles for learning, so I
wanted to contribute back, as well as document some of my open-source work
which otherwise goes unnoticed.

But for me, a big reason to do this at all, is that I like writing and I want
to get better at it. This is not a product I am selling; I don't care for
_time to market_. I want to improve, and one can only do so through practice;
someone else doing your work won't teach you anything.

### About the site

The site is built with [Hugo] and my custom theme Simplex. Simplex was
inspired by [belluzj's site], who is the creator of the lovely
[Fantasque Sans Mono font] I also use.

You can find the site's code [here][Rincon]. All the code, templates, themes,
etc are under the [AGPLv3 license][Rincon AGPLv3]. The content—articles,
photos, etc—use the
[Creative Commons Attribution-NonCommercial-ShareAlike 4.0 license][Rincon CC BY-NC-SA 4.0].

The [robots.txt] should already block most of the AI scrappers, but just so
it's clear: I am against my content being used to train any commercial or
closed-source models.

### Data collection

**I don't use client-side analytics nor JavaScript**.

The site is hosted with [Nginx]. Nginx will log HTTP/S requests, which I use
to block attacks with [Fail2ban]. Beware, the filters and ban times are set
quite aggressively.

I also gather analytics from the Nginx access logs. Some of the fragments
logged are IP address, request timestamp, request URL, referrer, and user
agent.



[GitHub]: https://github.com/Sighery
[Twitch]: https://twitch.tv/Sighery
[robots.txt]: /robots.txt
[Hugo]: https://gohugo.io/
[belluzj's site]: https://belluzj.github.io/
[Fantasque Sans Mono font]: https://github.com/belluzj/fantasque-sans
[Rincon]: https://github.com/Sighery/rincon
[Rincon AGPLv3]: https://github.com/Sighery/rincon/blob/master/LICENSE-AGPL
[Rincon CC BY-NC-SA 4.0]: https://github.com/Sighery/rincon/blob/master/LICENSE-CC-BY-NC-SA
[Nginx]: https://nginx.org/
[Fail2ban]: https://github.com/fail2ban/fail2ban
