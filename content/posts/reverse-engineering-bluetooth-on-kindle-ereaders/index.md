+++
date = "2025-10-24T00:00:00+00:00"
draft = true
title = "Reverse engineering Bluetooth on Amazon Kindle eReaders"
summary = "A journey of learning C and reverse engineering to be more efficiently lazy"
series = ["Hacking Bluetooth on Kindle eReaders"]
embedimage = "kindle-start.webp"
+++

{{< figure
	src="./kindle-start.webp"
	alt="Kindle eReader with a smart ring"
	caption="How it started"
>}}

I've always been an avid reader; until recently however, I had a very old
Kindle 4 (2011). This past year I finally made the jump to the next decade and
got myself a Kindle Paperwhite 11th generation.

The hardware for these things is quite capable and even runs a full Linux
system, heavily locked down as it is. That's not really a problem as long as
you wait without updating—easier said than done with the aggressive
autoupdate policy of these devices—and jailbreak it.

Overall I'm pretty happy with these new gen devices, but one annoyance that
remained was the lack of remote page turning options. I'd like to cozy up in a
blanket during the winter days and not have to get my hand out every minute to
tap the screen. Yes, I am lazy, but then again, we programmers are famously
lazy.

I have a cheap Chinese smart ring with accelerometer that I got off
Aliexpress, so how hard could it be to hook up this thing to the Kindle and
implement page turns with hand gestures?

The rest of this post will be my journey trying to reverse engineer the
Bluetooth stack used in newer Kindles. Mind that I'm not a C developer, nor do
I know anything about the kernel, and I had likewise never even opened Ghidra
before I set on this project. What you'll read here is knowledge built on my
assumptions, therefore likely mistaken at times.

## The beginning

I managed to keep this Kindle Paperwhite mostly offline and out of the update
cycle for months until I got lucky and [LanguageBreak][]—a jailbreak—came out.
Turns out there was a lot of old tooling people had built over the years that
still worked, even SSH!

{{< figure
	src="./kindle-system.webp"
	alt="Kindle system"
	caption="I never said recent"
	loading="lazy"
>}}

Most of this tooling is in various states of disrepair and still available in
the [Mobileread Kindle forums][]. Which is also where I found out that despite
interest over the years to make use of the Bluetooth hardware on these
devices, there was just no progress on that front.

Armed with the resignation of having to do it myself, I started digging into
the Kindle internals. I thought, "It's Linux, how bad could it be?" I figured
it was just a matter of finding the BlueZ stuff and running a few commands;
not that I even knew _how_ BlueZ works, nor how it integrates in Linux.

Kindles have and use Bluetooth: when registering the device you can skip
entering your Wifi and account credentials if you pair it to your phone, to
listen to TTS of your ebooks, and to listen to Audible books.

So first thing to do, look for files:

```sh
$ find . -regextype awk -regex ".*(bluetooth|bt).*"
### Many lines removed for brevity ###
/opt/zbluetooth
/opt/zbluetooth/bt_stack.conf.logon
/etc/upstart/acsbtfd.conf
/etc/upstart/asr_bt_reboot.conf
/etc/upstart/asr_bt_userstore.conf
/etc/upstart/btmanagerd.conf
/usr/bin/ace_bt_framework_client
/usr/bin/ace_bt_cli
/usr/bin/ace_bt_framework_server
/usr/bin/btmanagerd
/usr/bin/acsbtfd
/usr/bin/btd
/usr/bin/btconnectionhelper
/usr/bin/lipcd-scripts/lipc-events/btReauthenticated.sh
/usr/bin/lipcd-scripts/lipc-events/btReconfirmed.sh
/usr/share/webkit-1.0/pillow/javascripts/bt_wizard_dialog.js
/usr/lib/libacehal_bt.so
/usr/lib/libace_bt.so
/usr/lib/libace_bt_cli.so
/usr/lib/libbluetooth.so
/lib/modules/4.9.77-lab126/extra/wmt_cdev_bt.ko
```

From this I figured there was some amount of proprietary tooling to interact
with the Bluetooth stack, even if at this point I was quite clueless on what I
was looking at. Some of you more experienced Linux developers might have
already spotted that so far, none of this seems to be configuration or tooling
you'd expect for a BlueZ stack.

After some digging in these files, most turned out to be either configuration
files, or stripped binaries, some executable with no discernable way to get a
help print. But one did turn out to be quite interesting, `ace_bt_cli`.

{{< figure
	src="./ace_bt_cli.webp"
	alt="ace_bt_cli CLI utility"
	caption="One tool did have a help print, and a way to interact with the Bluetooth stack"
	loading="lazy"
>}}

At this time I was still quite lost about how Bluetooth worked so I couldn't
figure out what I was doing with these commands. And so this just went nowhere
for some months.


[LanguageBreak]: https://github.com/notmarek/LanguageBreak
[Mobileread Kindle forums]: https://www.mobileread.com/forums/forumdisplay.php?f=150


## Getting involved with the community

At some point a new Discord server for Kindle modding got created and I joined
to find out if anyone had tried to dig into Bluetooth yet. There I found some
kindred spirits in [Clint][] and [Scam][] who helped me tremendously with
reverse engineering and debugging. In fact, Clint has already
[built some Bluetooth applications and more][bueno monorepo].

In here we started to unravel this whole thing; at first just focusing on
getting a Bluetooth Low Energy connection through the `ace_bt_cli` utility.
For this I decided to get myself a couple of Raspberry Pi Pico 2W; a very
capable microboard with Bluetooth Low Energy hardware, as well as
[strong C][Pi Pico SDK] and [Python support][Pi Pico MicroPython]. With this I
was able to adapt some examples into having
[my own Bluetooth LE GATT Server][pico-demo-gatt-service] with a LED toggle
Characteristic supporting read, write, and notifications.

{{< figure
	src="./raspberry-pi-pico-2w.webp"
	alt="Raspberry Pi Pico 2W"
	caption="Reversing is easier when you control the server component"
	loading="lazy"
>}}


[Clint]: https://github.com/clintharrison/
[Scam]: https://github.com/scamdotnet
[bueno monorepo]: https://github.com/clintharrison/bueno
[Pi Pico SDK]: https://www.raspberrypi.com/documentation/pico-sdk/index_doxygen.html
[Pi Pico MicroPython]: https://www.raspberrypi.com/documentation/microcontrollers/micropython.html
[pico-demo-gatt-service]: https://github.com/Sighery/pico-demo-gatt-service


## A short primer on Bluetooth

Before I continue, I realise it's probably a good idea to have a short
introduction on Bluetooth and some of the topics and jargo I'll be using in
the rest of the article. If you already know Bluetooth, you'll likely want to
[jump to the next section][Making first contact].

For a full introduction you'll want to read
[The Bluetooth Low Energy Primer][] from the actual Bluetooth Special Interest
Group. This document is quite technical and very long, and it'll also go into
many other parts of the Bluetooth standard that I won't cover here.


[The Bluetooth Low Energy Primer]: https://www.bluetooth.com/bluetooth-le-primer/
[Making first contact]: #making-first-contact


### Types of Bluetooth

Generally, when we talk Bluetooth, we're either talking about Bluetooth
Classic, the older standard from 1.0 up until 3.0 and still in use in older
devices; and Bluetooth Low Energy (also abbreviated as Bluetooth LE, BLE, or
LE), from version 4.0 forward. There are more, but they are irrelevant for
this article, in which we'll mostly focus on BLE.

### Profile specifications (roles)

{{< figure
	src="./bluetooth-profile-specifications.webp"
	alt="Bluetooth profile specifications overview"
	loading="lazy"
	attr="From Chris Svec @ https://embedded.fm/blog/ble-roles"
	attrlink="https://embedded.fm/blog/ble-roles"
>}}

There are likewise multiple types of roles Bluetooth devices can take before
or after connection. But for the rest of this article, we'll mostly focus on
Server and Client roles.

Before a connection is established, a BLE device can send out advertisment
packets that can be received by anyone. This is often used to have a
one-to-many relationship.

After a connection is established, one of them will assume the Server role,
and the other will assume the Client role. Whichever device assumes the Server
role will be locked to that connection and unable to connect to other devices,
while a Client can connect to multiple Servers.

If you come from a webdev background, this might be a bit baffling, what kind
of server only allows one connection? But reflect on the name:
_Low Energy_. In the case of BLE, we want our Server devices to be
"dumb" and do as little work as possible, even hibernate unless they are
actively queried. That allows you to have something like a battery-powered
temperature sensor set up as a Server lasting for weeks, as it'll only do work
once queried.

The Client is therefore the "smart" device in this relationship, taking care
of discovering the available Services on each Server, and deciding when to
query for the data.


### Service specifications

This is part of the GATT (Generic Attribute Profile). From the Bluetooth Low
Energy Primer:

> State data on servers resides in formally defined data items known as
> _characteristics_ and _descriptors_. Characteristics and descriptors are
> grouped inside constructs known as services. Services provide a context
> within which to assign meaning and behaviors to the characteristics and
> descriptors that they contain.

What this effectively means is that Services are our "APIs" to interact with a
Server. What Characteristic and Descriptors each BLE device will have depends
on the specific device, but there are overall Generic Profiles that
manufacturers can choose to implement to provide a common interface, keeping
custom functionality to extra Characteristics/Services.

What this means is that if you have an external temperature sensor, it
probably implements the [Environmental Sensing Profile][], which has a series
of Services and Characteristics defined in the Bluetooth standard. Which also
means that if you implement support for the Environmental Sensing Profile
once, any device using this same Profile will automatically work, regardless
of manufacturer—or generally should.

{{< figure
	src="./environmental-sensing-profile.webp"
	alt="Role/Service Relationships of the Environmental Sensing Profile"
	loading="lazy"
	caption="In this profile Servers should at least implement the Environmental Sensing Service"
	attr="<br>From the Environmental Sensing Service standard"
	attrlink="https://www.bluetooth.com/specifications/specs/html/?src=ESP_v1.0.1/out/en/index-en.html#UUID-b5e89d8f-5051-0d0b-4a4b-3b6d80f4984a"
>}}

I would note that generally Services are more of a _construct_ rather than an
actual interactable item. You don't read or write Services, they are primarily
organizational. They are used for discovery—listing available Services in a
BLE device—, navigation—exploring Characteristics and Descriptors—, and
sometimes reference—grouping related Characteristics.

Services are further categorized into **Primary** and **Secondary**. Primary
Services are—and devices can have multiple Primary Services at
once—discoverable on their own, while Secondary Services are not discoverable
and must instead be _included_ into a Primary Service to be accessible to
clients. For the rest of this article we'll generally focus on Primary
Services.

{{< figure
	src="service-architecture-overview.webp"
	alt="Overview of a Service architecture"
	loading="lazy"
	caption="Here a high-level overview of a Service architecture"
	attr="<br>From the Core Specification v6.0, Volume 1, Part A, Section 6.5"
	attrlink="https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-60/out/en/architecture,-change-history,-and-conventions/architecture.html#UUID-4ec2eac1-8869-c29a-35fa-e3e736f98aa5"
>}}


[Environmental Sensing Profile]: https://www.bluetooth.com/specifications/specs/environmental-sensing-profile-1-0-1/


### Characteristics

If Services are our APIs, then Characteristics are our endpoints. When using a
Generic Profile, the list of available Characteristics will be defined in the
[Assigned Numbers specification][].

{{< figure
	src="./environmental-sensing-service-characteristics.webp"
	alt="Permitted Characteristics of the Environmental Sensing Service"
	caption="Permitted Characteristics of the Environmental Sensing Service"
	loading="lazy"
	attr="<br>From the Bluetooth Assigned Numbers specification"
	attrlink="https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/Assigned_Numbers.pdf"
>}}

Additionally, Characteristics defined in the spec will use a fixed UUID. So if
we take the Elevation Characteristic, and search for it in the document, we'll
find its UUID will always be `0x2A6C`. Now, if we go to the
[GATT Specification Supplement][] we can find the documentation for the
structure of this Characteristic

{{< figure
	src="./elevation-characteristic.webp"
	alt="Elevation Characteristic structure"
	loading="lazy"
	attr="From the Bluetooth GATT Specification Supplement"
	attrlink="https://btprodspecificationrefs.blob.core.windows.net/gatt-specification-supplement/GATT_Specification_Supplement.pdf"
>}}

One last thing that I'll mention about Characteristics is that they are not
locked to specific Services, but rather the same Characteristic can be present
in multiple Services, as well as be part of other Profiles that also offer
elevation data. Note that this doesn't mean the same Characteristic
**instance**, but rather the same spec-defined Characteristic—which by spec
will also have the same UUID—is declared and used in multiple Services, each
Service having its own instance of it.


[Assigned Numbers specification]: https://www.bluetooth.com/specifications/assigned-numbers/
[GATT Specification Supplement]: https://www.bluetooth.com/specifications/gss/


### Descriptors

Here my REST API analogy kind of breaks down, but you can think of Descriptors
as metadata around a Characteristic. This includes things like an optional
name, what kind of operations it supports—read, write, notify, indicate—,
sometimes even specifying the type of data and format expected for that
Characteristic.

There are multiple descriptor types, but I'll take the chance to introduce the
CCCD (Client Characteristic Configuration Descriptor), as it'll be relevant to
one of the later Bluetooth operations I'll reference later—notify.

{{< figure
	src="./client-characteristic-configuration-descriptor.webp"
	alt="Structure of the Client Characteristic Configuration Descriptor"
	caption="Structure of the Client Characteristic Configuration Descriptor"
	loading="lazy"
	attr="<br>From Nordic Semiconductor's Bluetooth Low Energy Fundamentals course, Lesson 4"
	attrlink="https://academy.nordicsemi.com/courses/bluetooth-low-energy-fundamentals/lessons/lesson-4-bluetooth-le-data-exchange/topic/services-and-characteristics/"
>}}

Like Characteristics, Descriptors also have fixed UUIDs defined in the
Bluetooth spec. In the case of the CCCD, its UUID is `0x2902`. The value field
you can read and write to is 2 bits long. For enabling notifications, you'd
set the first bit to `1`; for enabling indications, you'd set the second bit
to `1`. To disable, you'd set the corresponding bit to `0`.

As a quick aside, and because I hate footnotes, you may have noticed I didn't
cover what happens when both notification and indication bits are set. Turns
out, that's undefined behaviour and depends on the Server implementation. This
is something not defined nor covered in the specification.
{ class = "aside" }

Don't worry about what notifications and indications are just yet, as that
will be covered in the next section. The takeaway here is that a
Characteristic can have from zero to many Descriptors, and Descriptors will
act as metadata for a given Characteristic.

### GATT operations

From the previous sections, you might have already deduced certain supported
operations you can perform on a Characteristic, like reading or writing. I
won't go into all of them but I'll explain the relevant ones for this article.

These operations can be classified into either **Client-initiated**, or
**Server-initiated**. This is because unlike with REST APIs, the connection is
bidirectional and Servers can send data to Clients without a prior request.

For **Client-initiated** operations, that is, where the Client in the
connection requests data from the Server, we have: _read_, _write_—waits for
an acknowledgement from the Server—, and _write without response_—completes
immediately.

For **Server-initiated** operations, we have: _notify_ and _indicate_. These
operations are used to subscribe to a given Characteristic and wait for the
Server to feed the Client with the value periodically—the frequency is left to
the Server implementation—. The difference is that indications require an
acknowledgement from the Client, and so only one indication will be sent at a
time, while notifications require no acknowledgement and multiple can arrive
at once.

One last thing I'll mention here is that Characteristics define what
operations they support through the Characteristic Properties field.

{{< figure
	src="./characteristic-properties.webp"
	alt="Specification of the Characteristic Properties field"
	caption="Specification of the Characteristic Properties field"
	loading="lazy"
	attr="<br>From the Core Specification v6.0, Volume 3, Part G, Section 3.3.1.1"
	attrlink="https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-60/out/en/host/generic-attribute-profile--gatt-.html#UUID-957d2ce5-401b-3cf3-1150-152d226887eb"
>}}

And with this, we can come back to the story of reverse engineering the Kindle
Bluetooth stack.

## Making first contact

After a while of learning and experimenting with Bluetooth, we figured out the
recipe for connecting from a Kindle, set up as a GATT Client, to the GATT
Server running on the Pi Pico. My Pico Server has a Characteristic with UUID
`ff120000000000000000000000000000`, supporting read/write/notify, which can be
used to read and toggle the built-in LED by writing `ON` or `OFF`.

A quick view into what reading and writing a Characteristic through the
`ace_bt_cli` utility looks like:

```sh
$ ace_bt_cli
ACEBTCLI BT Client :: start
p_data (size:27) = 1B 00 00 00 00 00 00 00 00 00 00 61 63 65 5F 62
                   74 5F 63 6C 69 00 00 00 00 00 00
ACEBTCLI BT Client :: opened session with 0x18570

# Registration steps are necessary, more on that later
>: ble regble
ACEBTCLI CLI callback : aceBtCli_bleRegCallback() status: 0
ACEBTCLI Register BLE Client Success

>: ble regGattc
ACEBTCLI Register Gatt Client Success

# Actual connection
>: ble connect CF:04:36:8E:BB:FC 2 10 true
ACEBTCLI str: CF04368EBBFC
ACEBTCLI aceBtCli_aclStateChangedCallback() status:0 addr:CF:04:36:8E:BB:FC state:0, transport:0, reason:0
ACEBTCLI CLI callback : aceBtCli_bleConnStateChangedCallback()
ACEBTCLI state 0 status 0 connHandle 0xb5f067b0 addr fc
ACEBTCLI GATT Client Connect Success
# Format is <bdaddr> <conn_param> <conn_priority> <auto_connect>
# These values are not explained, but rather had to be reverse engineered

# Discovery and retrieval of Services
>: ble getdb 0xb5f067b0
ACEBTCLI CLI callback : aceBtCli_bleGattcGetDbCallback()
ACEBTCLI connHandle 0xb5f067b0 no_svc 4
ACEBTCLI Gatt Database index :0 0xb5f00808
ACEBTCLI Service 0 uuid 18 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  serviceType 0
ACEBTCLI        Gatt Characteristics 0 uuid 2a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI Gatt Database index :1 0xb5f0083c
ACEBTCLI Service 0 uuid 18 0f 00 00 00 00 00 00 00 00 00 00 00 00 00 00  serviceType 0
ACEBTCLI        Gatt Characteristics with Notifications 0 uuid 2a 19 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI                Descriptor UUID 29 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI Gatt Database index :2 0xb5f00870
ACEBTCLI Service 0 uuid 18 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00  serviceType 0
ACEBTCLI        Gatt Characteristics 0 uuid 2b 2a 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI Gatt Database index :3 0xb5f008a4
ACEBTCLI Service 0 uuid ff 10 00 00 00 00 00 00 00 00 00 00 00 00 00 00  serviceType 0
ACEBTCLI        Gatt Characteristics 0 uuid ff 11 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI                Descriptor 1 UUID 29 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI                Descriptor 2 UUID 29 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI        Gatt Characteristics 1 uuid ff 12 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI                Descriptor 1 UUID 29 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI                Descriptor 2 UUID 29 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI Discover Gatt Service Database Failure

# Read Characteristic
>: ble readChars ff120000000000000000000000000000
ACEBTCLI CLI callback : aceBtCli_bleGattcReadCharsCallback() status: 0
ACEBTCLI connHandle 0xb5f067b0
ACEBTCLI UUID:: ff 12 00 00 00 00 00 00 00 00 00 00 00 00 00 00
ACEBTCLI 4f
ACEBTCLI 46
ACEBTCLI 46
ACEBTCLI Read Characteristic Success
# Response was `4f 46 46` which is `OFF` in ASCII

# Write value ON, again in ASCII
>: ble writeChars 1 ff120000000000000000000000000000 4f4e
ACEBTCLI CLI callback : aceBtCli_bleGattcWriteCharsCallback()
ACEBTCLI connHandle 0xb5f067b0 gatt format 255
ACEBTCLI Write Characteristic Success
# Format is <response> <uuid> <value>
# <response> is a bool of whether response is required or not
```
