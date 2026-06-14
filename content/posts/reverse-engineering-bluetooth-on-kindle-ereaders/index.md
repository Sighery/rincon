+++
date = "2025-11-17T00:00:00+00:00"
draft = false
title = "Reverse engineering Bluetooth on Amazon Kindle eReaders"
summary = "A journey of learning C and reverse engineering to be more efficiently lazy"
series = ["Hacking Bluetooth on Kindle eReaders"]
embedimage = "kindle-start.webp"
+++

{{< figure
	src="./kindle-start.webp"
	alt="Kindle eReader with a smart ring"
	caption="How it started"
	loading="eager"
	fetchpriority="high"
>}}

For the longest time I read on an old Kindle 4 (2011), but in 2022 I finally
made the jump and got myself a Kindle Paperwhite 11th-generation
(2021)—referred to as the PW5 in the community.

The hardware in these devices is quite capable; it even runs a full Linux
system, heavily locked down as it is. This is not really a problem as long as
you hold off on updates—easier said than done with the aggressive auto-update
policy of these devices—and jailbreak it.

Overall I'm pretty happy with these new-generation devices, but one annoyance
that remained was the lack of remote page-turning capabilities. In all this
time Amazon—or more specifically its hardware division, Lab126—still hasn't
implemented this functionality. I'd like to cozy up in a blanket during the
winter days without having to pull my hand out every minute just to tap the
screen. Yes, I am lazy, but then again, programmers are famously so.

I have a cheap smart ring—Colmi R02—with an accelerometer that I bought on
Aliexpress. So how hard could it be to hook it up to the Kindle and enable
page-turns via hand gestures?

The rest of this article will focus on my journey reverse engineering the
Bluetooth stack used in newer Kindles. Keep in mind that I'm not a C
developer, nor do I know anything about the kernel, and I had likewise never
opened Ghidra before I started on this project. What you'll read here is based
on my own assumptions, and may be mistaken at times.

## The beginning

I managed to keep this Kindle Paperwhite mostly offline and out of the update
cycle for months until I got lucky and a jailbreak—[LanguageBreak][]—came out.
Turns out there is a lot of tooling people have built over the years that
still works, including SSH!

{{< figure
	src="./kindle-system.webp"
	alt="Kindle system"
	caption="I never said recent"
>}}

Most of this tooling is in various states of disrepair, but is still available
on the [Mobileread Kindle forums][]. I also found out there that, despite
interest in using the Bluetooth hardware over the years, there had simply been
no progress.

Resigned to doing it myself, I began digging into the Kindle's internals.
After all, it's Linux—how hard could it be? I figured it would just be a
matter of finding the BlueZ utilities and running a few commands; not that I
knew how BlueZ works or how it integrates into Linux.

Kindles already use Bluetooth, which allows you to listen to TTS of your
ebooks and Audible books, and during first setup, to skip entering your Wi-Fi
and Amazon account credentials by pairing with your phone.

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

From this I gathered that there was some proprietary tooling for interacting
with the Bluetooth stack; although at this point I was still unsure what I was
looking at. Some of you more experienced Linux developers may already have
spotted that none of this seems to be the configuration or tooling you would
expect in a BlueZ stack.

After examining these files, most turned out to be either configuration
files or stripped binaries. Some were executable, but there was no obvious way
to get a help print. But one did turn out to be quite interesting, `ace_bt_cli`.

{{< figure
	src="./ace_bt_cli.webp"
	alt="ace_bt_cli CLI utility"
	caption="One tool did have a help print, and a way to interact with the Bluetooth stack"
>}}

At this time, I still didn't understand how Bluetooth worked and couldn't
figure out what to do with these commands. So this just went nowhere for
several months.


## Getting involved with the community

While I was digging into the Kindle's internals, I came across a Discord
server for Kindle modding, and so I joined to see if anyone had cracked
Bluetooth yet. There I met [Clint][] and [Scam][], who were interested in the
Bluetooth stack and helped me tremendously with reverse engineering and
debugging. In fact, Clint has already
[built some Bluetooth applications and more][bueno monorepo].

Initially we focused on just establishing a Bluetooth Low Energy connection
through the `ace_bt_cli` utility. To this end, I got myself a Raspberry Pi
Pico 2W, a very capable microcontroller board with Bluetooth hardware, as well
as [strong C][Pi Pico SDK] and [Python support][Pi Pico MicroPython]. Using
this, I was able to adapt some examples to create
[my own Bluetooth LE GATT Server][pico-demo-gatt-service] with a LED toggle
Characteristic supporting read, write, and notifications.

{{< figure
	src="./raspberry-pi-pico-2w.webp"
	alt="Raspberry Pi Pico 2W"
	caption="Reversing is easier when you control the server component"
>}}


## A brief primer on Bluetooth

Before I continue, I realise it would be helpful to provide a brief
introduction to Bluetooth and to some of the terminology that I will use for
the rest of the article. If you are already familiar with Bluetooth, you can
[jump to the next section][Making first contact].

For a fuller introduction, one can read [The Bluetooth Low Energy Primer][]
from the actual Bluetooth Special Interest Group. Although this document is
lengthy and highly technical, it also covers many other aspects of the
Bluetooth standard that I won't discuss here.


### Types of Bluetooth

Generally, when we talk about Bluetooth, we're referring to either Bluetooth
Classic, the older mode—still very much in use—introduced in version 1.0; or
Bluetooth Low Energy—abbreviated as BLE, LE, or Bluetooth LE—introduced in
version 4.0. There are other modes, but they are irrelevant to this article,
in which we will focus primarily on BLE.

### Profile specifications (roles)

{{< figure
	src="./bluetooth-profile-specifications.webp"
	alt="Bluetooth profile specifications overview"
	caption="There are many roles and they depend on whether a connection is established"
	attr="<br>From Chris Svec @ https://embedded.fm/blog/ble-roles"
	attrlink="https://embedded.fm/blog/ble-roles"
>}}

Bluetooth devices can assume different roles before and after establishing a
connection. For the rest of this article, we will focus mainly on
functionality available after a connection has been established.

Before a connection is established, a BLE device can send out advertisement
packets that can be received by anyone. This is often used to have a
one-to-many relationship. At this stage, the devices are in either a
Peripheral or a Central role.

Once a connection has been established, one device will take on the role of
Server and the other the role of Client. The device that assumes the Server
role will be locked to that connection and unable to connect to other devices,
while the Client can connect to multiple Servers.

If you have a background in web development, you might find this a little
baffling: what kind of server only allows one connection? But consider the
name: _Low Energy_. In the BLE world, we want our Server devices to be "dumb"
and do as little work as possible—even hibernate—until they are actively
queried. This enables battery-powered devices, such as sensors, to last for
weeks.

The Client is therefore the "smart" device in this relationship, responsible
for discovering the available Services on each Server, and deciding when to
query for the data.


### Service specifications

This is part of the GATT—_Generic ATTribute Profile_—specification. From
[The Bluetooth Low Energy Primer][]:

> State data on servers resides in formally defined data items known as
> _characteristics_ and _descriptors_. Characteristics and descriptors are
> grouped inside constructs known as services. Services provide a context
> within which to assign meaning and behaviors to the characteristics and
> descriptors that they contain.

If I were to use a REST API analogy, Services would be the APIs for
interacting with a Server. The Characteristics and Descriptors a BLE product
implements depend on the specific device; however, the Bluetooth specification
introduces and defines many different generic Profiles. By selecting and
implementing a generic Profile, manufacturers can provide a common interface
while retaining custom functionality in the form of additional Characteristics
and Services.

This effectively means is that if you have an external temperature sensor, it
probably implements the [Environmental Sensing Profile][], which has a series
of Services and Characteristics defined in the Bluetooth specification. This
also means that, once you have implemented support for the Environmental
Sensing Profile keeping with the specification, any device using this same
Profile should work regardless of the manufacturer.

{{< figure
	src="./environmental-sensing-profile.webp"
	alt="Role/Service Relationships of the Environmental Sensing Profile"
	caption="In this profile Servers should at least implement the Environmental Sensing Service"
	attr="<br>From the Environmental Sensing Service specification, Section 2.2"
	attrlink="https://www.bluetooth.com/specifications/specs/html/?src=ESP_v1.0.1/out/en/index-en.html#UUID-b5e89d8f-5051-0d0b-4a4b-3b6d80f4984a"
>}}

I would also note that Services are generally more of a _construct_ rather
than an actual interactive item. You don't read or write Services, they are
primarily organisational. They are used for discovery (listing the available
Services in a BLE device), navigation (exploring Characteristics and
Descriptors), and reference (grouping related Characteristics).

Services are further categorised as either **Primary** or **Secondary**.
Primary Services are—and devices can have multiple Primary Services at
once—discoverable on their own, while Secondary Services are not discoverable
and must instead be _included_ into a Primary Service to be accessible to
clients. For the rest of this article we'll focus on Primary Services.

{{< figure
	src="service-architecture-overview.webp"
	alt="Overview of a Service structure"
	caption="Here a high-level overview of a Service structure"
	attr="<br>From the Core Specification v6.0, Volume 1, Part A, Section 6.5"
	attrlink="https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-60/out/en/architecture,-change-history,-and-conventions/architecture.html#UUID-4ec2eac1-8869-c29a-35fa-e3e736f98aa5"
>}}


### Characteristics

If Services are our APIs, then Characteristics are our endpoints. When using a
generic Profile, the list of permitted Characteristics for use with a Service
will be defined in the [Assigned Numbers specification][].

{{< figure
	src="./environmental-sensing-service-characteristics.webp"
	alt="Permitted Characteristics of the Environmental Sensing Service"
	caption="Permitted Characteristics of the Environmental Sensing Service"
	attr="<br>From the Bluetooth Assigned Numbers specification, Section 6.1.1"
	attrlink="https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Assigned_Numbers/out/en/Assigned_Numbers.pdf"
>}}

Additionally, Characteristics defined in the specification will use a fixed
UUID. For example, if we search for the Elevation Characteristic in the
document, we will find that its UUID is always `0x2A6C`. If we then go to the
[GATT Specification Supplement][], we can find the documentation for the
structure of this Characteristic.

{{< figure
	src="./elevation-characteristic.webp"
	alt="Elevation Characteristic structure"
	attr="From the Bluetooth GATT Specification Supplement, Section 3.87"
	attrlink="https://btprodspecificationrefs.blob.core.windows.net/gatt-specification-supplement/GATT_Specification_Supplement.pdf"
>}}

One final point about Characteristics is that the UUID in the specification
does not refer to a specific _instance_. Instead, the same Characteristic can
be part of multiple Services and Profiles, each with its own separate instance
of the Elevation Data Characteristic, but all using the same UUID.


### Descriptors

My REST API analogy breaks down here, but you can think of Descriptors as
metadata around a Characteristic. This includes things like an optional name,
the kind of operations it supports (e.g. read, write, notify, indicate), and
sometimes even specifying the type of data and format expected for that
Characteristic.

There are multiple descriptor types, but I will take this opportunity to
introduce the CCCD (Client Characteristic Configuration Descriptor), as this
will be relevant to one of the Bluetooth operations that will be introduced
later—notify.

{{< figure
	src="./client-characteristic-configuration-descriptor.webp"
	alt="Structure of the Client Characteristic Configuration Descriptor"
	caption="Structure of the Client Characteristic Configuration Descriptor"
	attr="<br>From Nordic Semiconductor's Bluetooth Low Energy Fundamentals course, Lesson 4"
	attrlink="https://academy.nordicsemi.com/courses/bluetooth-low-energy-fundamentals/lessons/lesson-4-bluetooth-le-data-exchange/topic/services-and-characteristics/"
>}}

Like Characteristics, Descriptors also have fixed UUIDs that are defined in
the Bluetooth specification. In the case of the CCCD, its UUID is `0x2902`.
The value field, which can be read and written, is two bits long. To enable
notifications, the first bit should be set to `1`; to enable indications, the
second bit should be set to `1`. To disable notifications or indications, the
corresponding bit should be set to `0`.

As a quick aside, and because I dislike footnotes, you may have noticed that I
didn't cover what happens when both the notification and indication bits are
set. Turns out that this is undefined behaviour and depends on the Server
implementation. This is neither defined nor covered in the specification.
{ class = "aside" }

Don't worry about what notifications and indications are just yet, as these
will be covered in the next section. The takeaway here is that a
Characteristic can have zero or more Descriptors, which act as metadata for
that Characteristic.

### GATT operations

From the previous sections, you may already have deduced some of the
operations that can be performed on a Characteristic, such as reading or
writing. I won't discuss them all, but I will explain the ones that are
relevant to this article.

These operations can be classified as either **Client-initiated**, or
**Server-initiated**. Unlike with REST APIs, the connection is bidirectional,
meaning Servers can send data to Clients without a prior request.

For **Client-initiated** operations, i.e. where the Client in the
connection requests data from the Server, we have: _read_, _write_—waits for
an acknowledgement from the Server, and _write without response_—completes
immediately.

For **Server-initiated** operations, we have: _notify_ and _indicate_. These
operations are used to subscribe to a given Characteristic and wait for the
Server to periodically provide the Client with the value—the frequency is left
to the Server implementation. The difference is that indications require an
acknowledgement from the Client, and so only one indication will be sent at a
time. Notifications, on the other hand, require no acknowledgement and
multiple notifications can arrive at a time.

One final point to mention is that Characteristics define the operations they
support via the Characteristic Properties field.

{{< figure
	src="./characteristic-properties.webp"
	alt="Specification of the Characteristic Properties field"
	caption="Specification of the Characteristic Properties field"
	attr="<br>From the Core Specification v6.0, Volume 3, Part G, Section 3.3.1.1"
	attrlink="https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/Core-60/out/en/host/generic-attribute-profile--gatt-.html#UUID-957d2ce5-401b-3cf3-1150-152d226887eb"
>}}


### Putting it all together: A practical example

Although there is no single tool in Linux that provides a good diagram of a
GATT Server, we can use the `gatttool` utility to query the Services,
Characteristics, and Descriptors in a Server. Below is the output of the tool
for my Pico Server.

```sh
$ gatttool -b CF:04:36:8E:BB:FC -I
[CF:04:36:8E:BB:FC][LE]> primary
attr handle: 0x0001, end grp handle: 0x0003 uuid: 00001800-0000-1000-8000-00805f9b34fb
attr handle: 0x0004, end grp handle: 0x0007 uuid: 0000180f-0000-1000-8000-00805f9b34fb
attr handle: 0x0008, end grp handle: 0x000a uuid: 00001801-0000-1000-8000-00805f9b34fb
attr handle: 0x000b, end grp handle: 0x0013 uuid: 0000ff10-1079-43e0-99be-1c0a675e86bf

[CF:04:36:8E:BB:FC][LE]> characteristics
handle: 0x0002, char properties: 0x02, char value handle: 0x0003, uuid: 00002a00-0000-1000-8000-00805f9b34fb
handle: 0x0005, char properties: 0x12, char value handle: 0x0006, uuid: 00002a19-0000-1000-8000-00805f9b34fb
handle: 0x0009, char properties: 0x02, char value handle: 0x000a, uuid: 00002b2a-0000-1000-8000-00805f9b34fb
handle: 0x000c, char properties: 0x1a, char value handle: 0x000d, uuid: 0000ff11-1079-43e0-99be-1c0a675e86bf
handle: 0x0010, char properties: 0x1a, char value handle: 0x0011, uuid: 0000ff12-1079-43e0-99be-1c0a675e86bf

[CF:04:36:8E:BB:FC][LE]> char-desc
handle: 0x0001, uuid: 00002800-0000-1000-8000-00805f9b34fb
handle: 0x0002, uuid: 00002803-0000-1000-8000-00805f9b34fb
handle: 0x0003, uuid: 00002a00-0000-1000-8000-00805f9b34fb
handle: 0x0004, uuid: 00002800-0000-1000-8000-00805f9b34fb
handle: 0x0005, uuid: 00002803-0000-1000-8000-00805f9b34fb
handle: 0x0006, uuid: 00002a19-0000-1000-8000-00805f9b34fb
handle: 0x0007, uuid: 00002902-0000-1000-8000-00805f9b34fb
handle: 0x0008, uuid: 00002800-0000-1000-8000-00805f9b34fb
handle: 0x0009, uuid: 00002803-0000-1000-8000-00805f9b34fb
handle: 0x000a, uuid: 00002b2a-0000-1000-8000-00805f9b34fb
handle: 0x000b, uuid: 00002800-0000-1000-8000-00805f9b34fb
handle: 0x000c, uuid: 00002803-0000-1000-8000-00805f9b34fb
handle: 0x000d, uuid: 0000ff11-1079-43e0-99be-1c0a675e86bf
handle: 0x000e, uuid: 00002902-0000-1000-8000-00805f9b34fb
handle: 0x000f, uuid: 00002901-0000-1000-8000-00805f9b34fb
handle: 0x0010, uuid: 00002803-0000-1000-8000-00805f9b34fb
handle: 0x0011, uuid: 0000ff12-1079-43e0-99be-1c0a675e86bf
handle: 0x0012, uuid: 00002902-0000-1000-8000-00805f9b34fb
handle: 0x0013, uuid: 00002901-0000-1000-8000-00805f9b34fb
```

This is still difficult to understand, so I created a diagram to illustrate
the entire GATT "database" of this Server:

{{< figure
	src="./pico-gatt-database.webp"
	alt="Pico Server GATT Database"
	caption="Pico Server GATT Database with three standard Services and a custom Service"
>}}

Now, let's take a closer look at this diagram. This server exposes four
Primary Services: `0x1800`, `0x1801`, `0x180F`, and
`0000FF10-1079-43E0-99BE-1C0A675E86BF`.

You may have noticed that some Services and Characteristics have short UUIDs
with the same format: `0000****-0000-1000-8000-00805F9B34FB`. This will be the
case for those Services and Characteristics defined in the specification. If
you implement these in your devices, you should use these UUIDs, and you can
also refer to them by their 16-bit short equivalent. However, for any custom
Services or Characteristics, you should generate and use new random 128-bit
UUIDs.

Interestingly, Bluetooth SIG members can pay to have their custom Services
included in the specification, allowing them to use the 16-bit format for
their Services.
{ class = "aside" }

The Services `0x1800`, `0x1801`, `0x180F` are part of the
[Assigned Numbers specification][], where we can find that they are the
_Generic Access Service_, the _Generic Attribute Service_, and the _Battery
Service_ respectively.

Having the _Generic Access Service_ (`0x1800`) is mandatory, and is normally
used to provide information such as the device name during Bluetooth scans.
This is done through its _Device Name Characteristic_ (`0x2A00`), which
supports only reads—its Characteristics Properties is set to `0x02`.

The next service, `0x1801`, corresponds to the _Generic Attribute Service_. It
contains a single readable Characteristic, `0x2B2A`, which corresponds to the
_Database Hash Characteristic_. This is used by Servers that might change
their Services or Characteristics at runtime. Clients can use this Service to
detect changes more quickly and easily. My Pico Server does not make use of
this functionality, but BTstack populates it automatically nonetheless.

Then we have the _Battery Service_, with UUID `0x180F`, and its _Battery Level
Characteristic_, with UUID `0x2A19`. Here we see our first Characteristic
supporting notifications—bits `0x02` and `0x10` are set in its Characteristic
Properties—meaning it will also have a Characteristic Client Configuration
Descriptor (CCCD) with UUID `0x2902`.

Finally, there is my custom Service with UUID
`0000FF10-1079-43E0-99BE-1C0A675E86BF`. As you can see, it has two
Characteristics. Since these are custom Characteristics—notice the lack of
short UUIDs—a client won't know what they are for or even what they are
called. To get around this, these Characteristics can define a Characteristic
User Description Descriptor (`0x2901`), where the string name for the
Characteristic can be queried. In this Service, I have then the _Counter_ and
_LED Status and Control_ Characteristics. Both have the Characteristic
Properties field set to `0x1A`, meaning they support read, write, and notify
(`0x02 + 0x08 + 0x10`).

And with this, we can return to the story of reverse engineering the Kindle
Bluetooth stack.

## Making first contact

After some learning and experimentation with Bluetooth, we figured out the
recipe for connecting from a Kindle—set up as a GATT Client—to the GATT Server
running on the Pi Pico. My Pico Server has a Characteristic with the UUID
`ff12`, that supports read, write, and notify. This can be used to read and
toggle the built-in LED by writing `ON` or `OFF`.

Here's a quick look into what reading and writing that Characteristic through
the `ace_bt_cli` utility looks like:

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

There are more commands inside the `ace_bt_cli` utility, which we can get by
running the `help` command. However, these will depend on the firmware
version. For example, none of the GATT Client BLE operations were implemented
before version 5.17. We will go more into detail later, but for now, this is a
good jumping-off point for the next stage of the investigation—looking into
the used libraries.

## Discovering the ace_bt library

Clearly the functionality exists at the kernel and firmware level, so then
it's just a matter of finding where this code is implemented. Using `ldd` or
`objdump` we can determine which C libraries (`.so` files) are loaded. This
leads us to the `libace_bt.so` library.

```sh { hl_Lines = [11,24] }
$ which ace_bt_cli
/usr/bin/ace_bt_cli

$ ldd /usr/bin/ace_bt_cli
  linux-vdso.so.1 (0xbec17000)
  /usr/lib/libenvload.so (0xb6ee3000)
  liblipc.so.1 => /usr/lib/liblipc.so.1 (0xb6eb5000)
  liblab126utils.so.1 => /usr/lib/liblab126utils.so.1 (0xb6ea9000)
  libstackdump.so.1 => /usr/lib/libstackdump.so.1 (0xb6e9f000)
  libdl.so.2 => /lib/libdl.so.2 (0xb6e94000)
  libace_bt_cli.so => /usr/lib/libace_bt_cli.so (0xb6e7a000)
  libace_log.so => /usr/lib/libace_log.so (0xb6e70000)
  libace_osal.so => /usr/lib/libace_osal.so (0xb6e67000)
  librt.so.1 => /lib/librt.so.1 (0xb6e58000)
  libc.so.6 => /lib/libc.so.6 (0xb6d25000)
  libgcc_s.so.1 => /lib/libgcc_s.so.1 (0xb6d01000)
  libcjson.so => /usr/lib/libcjson.so (0xb6cf2000)
  libdbus-1.so.3 => /usr/lib/libdbus-1.so.3 (0xb6cc1000)
  libpthread.so.0 => /lib/libpthread.so.0 (0xb6ca1000)
  libgthread-2.0.so.0 => /usr/lib/libgthread-2.0.so.0 (0xb6c95000)
  libglib-2.0.so.0 => /usr/lib/libglib-2.0.so.0 (0xb6b9e000)
  libcrypto.so.1.0.0 => /usr/lib/libcrypto.so.1.0.0 (0xb6a42000)
  /lib/ld-linux.so.3 (0xb6eec000)
  libace_bt.so => /usr/lib/libace_bt.so (0xb6a23000)
  libstdc++.so.6 => /usr/lib/libstdc++.so.6 (0xb68e0000)
  libm.so.6 => /lib/libm.so.6 (0xb686c000)
  libacehal_log.so.1 => /usr/lib/libacehal_log.so.1 (0xb6863000)
  libuthash.so => /usr/lib/libuthash.so (0xb685a000)
  libace_utils.so => /usr/lib/libace_utils.so (0xb6851000)
  libace_aipc.so => /usr/lib/libace_aipc.so (0xb6837000)
  libllog.so.1 => /usr/lib/libllog.so.1 (0xb682b000)
  libmetrics.so.1 => /usr/lib/libmetrics.so.1 (0xb681d000)
  libdynconf.so.1 => /usr/lib/libdynconf.so.1 (0xb6813000)
  libsoup-2.4.so.1 => /usr/lib/libsoup-2.4.so.1 (0xb67ba000)
  libgobject-2.0.so.0 => /usr/lib/libgobject-2.0.so.0 (0xb677a000)
  libappreg.so.1 => /usr/lib/libappreg.so.1 (0xb676d000)
  libsqlite3.so.0 => /usr/lib/libsqlite3.so.0 (0xb66a4000)
  libssl.so.1.0.0 => /usr/lib/libssl.so.1.0.0 (0xb6652000)
  libgio-2.0.so.0 => /usr/lib/libgio-2.0.so.0 (0xb6548000)
  libresolv.so.2 => /lib/libresolv.so.2 (0xb652c000)
  libffi.so.5 => /usr/lib/libffi.so.5 (0xb651e000)
  libgmodule-2.0.so.0 => /usr/lib/libgmodule-2.0.so.0 (0xb6513000)
  libxml2.so.2 => /usr/lib/libxml2.so.2 (0xb63f4000)
  libz.so.1 => /usr/lib/libz.so.1 (0xb63db000)
```

There are lots of libraries here, but if you were looking for
Bluetooth-related things, you would naturally focus on anything containing
`bluetooth` or its common abbreviation `bt` in the name. The relevant
libraries here are therefore `libace_bt_cli.so` and `libace_bt.so`. As you
might have guessed, `ace_bt_cli` includes `ace_bt`.

```sh
$ ldd /usr/lib/libace_bt_cli.so
  libace_bt.so => /usr/lib/libace_bt.so (0xb6e85000)
## Other lines removed for brevity ##
```

And as you'd expect, all these utilities and libraries are stripped.

```sh { class = "code-wrap" }
$ file /usr/bin/ace_bt_cli /usr/lib/libace_bt_cli.so /usr/lib/libace_bt.so

/usr/bin/ace_bt_cli:       ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux.so.3, for GNU/Linux 2.6.32, stripped

/usr/lib/libace_bt_cli.so: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, stripped

/usr/lib/libace_bt.so:     ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, stripped

```

## ARM Soft Float vs Hard Float

The previous `file` log that I shared was from a PW5 running firmware version
5.16.2.1.1. For comparison, here is the same command executed on the files
from a Kindle Colorsoft running 5.18.0.1.0.1—yes, version numbers are often
this convoluted.

```sh { class = "code-wrap" }
$ file /usr/bin/ace_bt_cli /usr/lib/libace_bt_cli.so /usr/lib/libace_bt.so

/usr/bin/ace_bt_cli:       ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 2.6.32, stripped

/usr/lib/libace_bt_cli.so: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, stripped

/usr/lib/libace_bt.so:     ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, stripped
```

Did you notice the different interpreters? It turns out that, from version
5.16.3, Lab126 switched all Kindles that were still receiving updates at that
time to ARMHF—ARM Hard Float. All previous firmware versions, even on
relatively new devices like my 2022 Kindle Paperwhite 11th-generation (PW5),
run ARM Soft Float, also known as ARMEL or SF in the Kindle modding community.

This effectively means that we have two targets. Binaries can sometimes be
made to work by simply patching the interpreter—keyword being _sometimes_. For
libraries, this is not an option.

## Underlying Bluetooth stack

If you look around in the system, you won't find any of the usual BlueZ files
or directories. There are no BlueZ binaries, such as `bluetoothctl` or
`bluetoothd`, and there is no `/etc/bluetooth` directory for the configuration
files.

However, if you look in the `/usr/lib` directory, you will find
`libbluetooth.so` which is produced by Bluedroid builds. Looking into the
strings confirms this.

```sh
$ strings libbluetooth.so | grep -i bluedroid
Bluedroid HAL needs to be init with test_mode set to 1.
/data/misc/bluedroid/LOCAL/b.key
/data/misc/bluedroid/LOCAL/a.key
/data/misc/bluedroid/.a2dp_ctrl
/data/misc/bluedroid/.a2dp_data
```

You can also download the [Bluedroid source code][Bluedroid] and compare the
symbol table of the `libbluetooth.so` file against the Bluedroid codebase,
which shows plenty of matches.

Bear in mind that this is a relatively recent development. Kindles from the
8th to 10th-generation (2016-2019) used NXP chips, and don't have this
Bluedroid library. From the 11th-generation onwards, Lab126 switched to
MediaTek chips, which appears to be when they started using the Bluedroid
stack. Some of these devices—like the Kindle Oasis 10th-generation (KOA3)—are
still receiving updates to this day. I don't have any of these devices, but
you can [download Kindle firmware files][Kindle firmware files] and unpack
them using [KindleTool][].

```sh
# Downloading Kindle Oasis 10th-gen (KOA3) 5.18.2 here
$ wget https://s3.amazonaws.com/firmwaredownloads/update_kindle_all_new_oasis_v2_5.18.2.bin

# Unpack
$ path/to/kindletool extract update_kindle_all_new_oasis_v2_5.18.2.bin unpack_dir/.

# Here is what you will see
$ ls unpack_dir/
data.stgz      rootfs.img.gz.sig
data.stgz.sig  update-payload.dat
imx7d_zelda/   update-payload.dat.sig
rootfs.img.gz

# rootfs is our interest since that will contain all the system files
$ cd unpack_dir && gunzip rootfs.img.gz

# Once we have our unpacked rootfs.img we can just mount it
$ mkdir tempmnt && sudo mount -o loop rootfs.img tempmnt/

$ ls tempmnt/
app/     keys/        pdata/   tmp@
bin/     lib/         proc/    tts/
chroot@  lost+found/  sbin/    usr/
dev/     mnt/         sys/     var/
etc/     opt/         system/
```

From a quick search, I found that `/usr/lib/libbsa.so` contains plenty of BLE
symbols. I have no idea what this stack is, but online searches indicate that
it is either a Broadcom, or a Cypress proprietary stack. There is no
`ace_bt_cli` binary, but a `/usr/bin/btui` binary—not available in my newer
devices—shows a similar, albeit more limited, help interface. Perhaps this was
a precursor to the later `ace_bt_cli` utility in the 11th-generation and
later.

That being said, the rest of the article will focus on the newer devices, as I
lack any devices from the 8th to 10th-generation. Investigating those is
therefore out of scope for me. However, if you have one of those devices, I
hope you find the rest of the article useful for your own investigations!


## Kindle Bluetooth stack architecture

The Kindle Bluetooth stack appears to be in a state of ongoing development,
meaning some of the things I mention here will not apply to older firmware
versions. For this example, I will showcase the stack from version 5.17, and
we can discuss some of the differences later.

{{< figure
	src="./kindle-bt-architecture.webp"
	alt="Architecture of the Bluetooth stack on Kindles 5.17 and above"
	caption="Architecture of the Bluetooth stack on Kindles 5.17 and above"
>}}

I would quickly mention that `major.minor.0` firmwares are limited to release
Kindles. Even if you know this firmware version exists for your device, you
won't be able to download it from the [Kindle firmware files][] page, no
matter if you manually change the URL to the `.0` version. I am unsure why
this is the case, but it means that I will investigate changes on the `.1`
releases and then assume that the change was initially implemented on the `.0`
release.
{ class = "aside" }

The Kindles use an old version of Upstart (0.6.6) as the init system, with
lots of custom jobs. The relevant one for us, `/etc/upstart/btmanagerd.conf`,
begins soon after system startup. The main interesting jobs that run before
`btmanagerd` are the `filesystems*` ones, setting up `/var/local` and the
`/mnt/us` userstore, on which `btmanagerd` indirectly depends. That being
said, I will leave an analysis of services running on a Kindle out of this
article.

Once `btmanagerd` is up and running, we can use `netstat` to inspect its open
sockets.

```sh
$ netstat -ap | grep btmanagerd
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address              Foreign Address         State       PID/Program name    
tcp        0      0 localhost.localdomain:8873 0.0.0.0:*               LISTEN      2920/btmanagerd

Active UNIX domain sockets (servers and established)
Proto RefCnt Flags       Type       State          I-Node PID/Program name   Path
unix  2      [ ACC ]     STREAM     LISTENING      17523 2920/btmanagerd     @/data/misc/bluedroid/.a2dp_ctrl
unix  2      [ ACC ]     SEQPACKET  LISTENING      17524 2920/btmanagerd     /dev/aipc/0/ss
unix  3      [ ]         STREAM     CONNECTED      17521 2920/btmanagerd     
unix  3      [ ]         STREAM     CONNECTED      17455 2920/btmanagerd     
unix  3      [ ]         STREAM     CONNECTED      19470 2920/btmanagerd     
unix  3      [ ]         SEQPACKET  CONNECTED      15988 2920/btmanagerd     /dev/aipc/0/ss
unix  3      [ ]         STREAM     CONNECTED      17522 2920/btmanagerd     
unix  3      [ ]         STREAM     CONNECTED      17453 2920/btmanagerd     
unix  3      [ ]         STREAM     CONNECTED      19471 2920/btmanagerd     
```

I have not investigated what the TCP socket is for yet, and it seems to be
unused by the Bluetooth clients built with `ace_bt`. Nonetheless, the interest
lies in the `/dev/aipc/0/ss` socket. This is created by the `ace_aipc`
library, which `btmanagerd` indirectly uses. Any client code that uses
`ace_bt` will also indirectly use `ace_aipc` and connect to the same socket.
The number appears to be deterministic, and Bluetooth will always use
`/dev/aipc/0/ss`.

Knowing this, you could inject yourself in the middle and inspect the data
being sent both ways using different tools such as `netstat`, `socat`, or even
`strace`.

```sh
$ strace -f -e trace=network ./kindlebt_test
Hello World from Kindle!
Is BLE enabled: 1
socket(PF_LOCAL, SOCK_DGRAM|SOCK_CLOEXEC, 0) = 3
connect(3, {sa_family=AF_LOCAL, sun_path="/dev/log"}, 110) = -1 EPROTOTYPE (Protocol wrong type for socket)
socket(PF_LOCAL, SOCK_STREAM|SOCK_CLOEXEC, 0) = 3
connect(3, {sa_family=AF_LOCAL, sun_path="/dev/log"}, 110) = 0
send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 79, MSG_NOSIGNAL) = 79
send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 111, MSG_NOSIGNAL) = 111
Process 27721 attached
[pid 27720] socket(PF_LOCAL, SOCK_SEQPACKET|SOCK_NONBLOCK, 0) = 4
[pid 27721] send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 153, MSG_NOSIGNAL <unfinished ...>
[pid 27720] connect(4, {sa_family=AF_LOCAL, sun_path="/dev/aipc/0/ss"}, 110 <unfinished ...>
[pid 27721] <... send resumed> )        = 153
[pid 27720] <... connect resumed> )     = 0
[pid 27720] setsockopt(4, SOL_SOCKET, SO_SNDBUF, [143232], 4) = 0
[pid 27720] setsockopt(4, SOL_SOCKET, SO_RCVBUF, [143232], 4) = 0
Process 27722 attached
[pid 27722] send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 134, MSG_NOSIGNAL) = 134
[pid 27720] send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 110, MSG_NOSIGNAL) = 110
[pid 27720] sendmsg(4, {msg_name(0)=NULL, msg_iov(2)=[{"Hl\0\0kindlebt_test\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 144}, {"Hl\0\0\353\3\0\0\353\3\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0", 32}], msg_controllen=0, msg_flags=0}, MSG_NOSIGNAL) = 176
[pid 27722] recvmsg(4, {msg_name(0)=NULL, msg_iov(2)=[{"Hl\0\0btmanagerd\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 144}, {"Hl\0\0\353\3\0\0\353\3\0\0000\0\2725M\377\212K}rU\2\23l\16\200\254\304\0\0", 16384}], msg_controllen=0, msg_flags=0}, 0) = 176
[pid 27722] recvmsg(4, 0xb5efeae4, 0)   = -1 EAGAIN (Resource temporarily unavailable)
[pid 27720] send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 149, MSG_NOSIGNAL) = 149
[pid 27720] send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 114, MSG_NOSIGNAL) = 114
Process 27723 attached
[pid 27720] send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 134, MSG_NOSIGNAL) = 134
p_data (size:27) = 1B 00 00 00 00 00 00 00 00 00 00 6B 69 6E 64 6C 
                   65 62 74 5F 74 65 73 74 00 00 00 
[pid 27720] sendmsg(4, {msg_name(0)=NULL, msg_iov(2)=[{"Hl\0\0kindlebt_test\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 144}, {"\33\0\0\0\0\0\0\0\0\0\0kindlebt_test\0\0\0", 27}], msg_controllen=0, msg_flags=0}, MSG_NOSIGNAL) = 171
[pid 27722] recvmsg(4, {msg_name(0)=NULL, msg_iov(2)=[{"h\v\0\0btmanagerd\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"..., 144}, {"\33L\231\356\266\0\0\0\0\0\0kindlebt_test\0\0\0", 16384}], msg_controllen=0, msg_flags=0}, 0) = 171
[pid 27722] recvmsg(4, 0xb5efeae4, 0)   = -1 EAGAIN (Resource temporarily unavailable)
[pid 27720] send(3, "<13>Nov  7 13:07:52 kindlebt_tes"..., 134, MSG_NOSIGNAL) = 134
Opened session status 0, session 0x1a548 (u32 107848)
```

Note that `strace` is not included on Kindles, but you can download an older
[armel or armhf version compiled by Debian][Debian snapshots strace] and use
it on your Kindle after unpacking. You might find this technique useful for
bringing other utilities to Kindles:

```sh { class = "code-wrap" }
# Unpack deb
$ ar x strace_4.9-2_armhf.deb
# Unpack compiled binaries
$ tar -xaf data.tar.xz
# Our compiled binary
$ file usr/bin/strace 
usr/bin/strace: ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-linux-armhf.so.3, for GNU/Linux 2.6.32, BuildID[sha1]=28e3ae6bc1a0a32aa6cce25696fcc4a3eef38961, stripped
```

So let's recap. We have a server component—`btmanagerd`—and different clients
that communicate with the server daemon via the Unix Domain socket
`/dev/aipc/0/ss` to request Bluetooth operations. In turn, the server will use
lower-level Bluetooth libraries such as `libbluetooth.so` from the Bluedroid
stack.

## Writing my own Bluetooth stack

With future plans to use the existing Bluetooth infrastructure for my remote
page-turning aspirations, I decided to write my own Bluetooth stack. This is
firstly because it provides a documented and open interface, but also because
it allows me to simplify and abstract some of the more complex operations. It
will also provide a single API target that can handle different versions of
the Kindle Bluetooth stack transparently.

The result of this work has been [KindleBT][], which currently supports all HF
firmwares for all 11th-generation and above devices. While the entire
Bluetooth API has not been implemented—I have mostly focused on the GATT
Client APIs—the rest of the APIs should require significantly less work to
support.

Non-exhaustive—but hopefully improving with time—
[documentation is also available][KindleBT documentation]. It includes
limitations, building instructions, and an always-up-to-date reference to the
[KindleBT public API][]. The documentation
[also includes an example of usage][KindleBT example].


## Bluetooth is event-driven

Regardless of the Bluetooth stack used, Bluetooth chips are inherently
asynchronous. You request a read or write operation from the stack, the stack
acknowledges the request, and at some future point you hopefully receive the
result of the operation. If you look at other Bluetooth stacks, you'll find
most of them offer an asynchronous API where you have to register callbacks to
wait for events.

{{< figure
	src="./btstack-main-loop.webp"
	alt="Example code of the main loop of a BTstack implementation"
	caption="Notice how we register handler callbacks for the Bluetooth packets<br>BTstack is used in the Raspberry Pi Pico SDK"
	attr="<br>From the BTstack documentation, Chapter Examples, Section Main Application Setup"
	attrlink="https://bluekitchen-gmbh.com/btstack/#examples/examples/#main-application-setup_1"
>}}

Even if they are wrappers over Bluedroid, both the `btmanagerd` server daemon
and the `ace_bt` library expose this particularity. Here is an edited excerpt
from the [KindleBT example][] reading a Characteristic. This is not working
code, nor is there any need to understand exactly what the KindleBT API looks
like. I simply wish to showcase the asynchronous nature of the API.

```c
void bleGattcReadCharsCallback(
    bleConnHandle conn_handle, bleGattCharacteristicsValue_t chars_value, status_t status
) {
    printf("Callback %s(): status %d conn_handle %p\n", __func__, status, conn_handle);
}

static bleGattClientCallbacks_t gatt_app_callbacks = {
    .size = sizeof(bleGattClientCallbacks_t),
    .on_ble_gattc_read_characteristics_cb = bleGattcReadCharsCallback,
};

static sessionHandle bt_session = NULL;

int main() {
    openSession(ACEBT_SESSION_TYPE_DUAL_MODE, &bt_session);
    bleRegisterGattClient(bt_session, &gatt_app_callbacks);
    bleReadCharacteristic(bt_session, conn_handle, charac->value);

    // bleGattcReadCharsCallback would be called afterwards
}
```

The way this works is that the client will register for these callbacks in
`btmanagerd` through the previously introduced IPC socket, using `ace_bt`. The
callbacks struct—here, `bleGattClientCallbacks_t`—will be scanned to create a
mask of the assigned callbacks. This will then be sent over the socket to
`btmanagerd`, which will forward events back to us.

[From reversed KindleBT code doing this registration][KindleBT reversed registering callbacks]:

```c { hl_Lines = [7,"11-14","18-20"] }
mask = create_client_callback_mask(callbacks);

uint32_t temp_aipc = (aipc_handle.server_id << 16) + aipc_handle.callback_server_id;
aceBt_serializeGattcRegisterData(&manager_callbacks, temp_aipc, mask, app_id);
log_debug("[%s()]: Register GATT Client session handle %p", __func__, session_handle);

status = registerBTClientData(session_handle, CALLBACK_INDEX_BLE_GATT_CLIENT, (void*)callbacks);
log_debug("[%s()]: registerBTClientData step. Result: %d", __func__, status);
if (status != ACEBT_STATUS_SUCCESS) return status;

status = registerBTEvtHandler(
    session_handle, pre5170_gattc_cb_handler, ACE_BT_CALLBACK_GATTC_INIT,
    ACE_BT_CALLBACK_GATTC_MAX
);
log_debug("[%s()]: registerBTEvtHandler step. Result: %d", __func__, status);
if (status != ACEBT_STATUS_SUCCESS) return status;

status = aipc_invoke_sync_call(
    ACE_BT_BLE_REGISTER_GATT_CLIENT_API, (void*)&manager_callbacks, manager_callbacks.size
);
```

The `ace_bt` library is closely linked to `btmanagerd`, as they both appear to
require simultaneous development. When a new callback type is introduced in
`ace_bt`, it also requires implementation in `btmanagerd` to receive the event
from the lower-level stack, translate it, and forward it to the `ace_bt`
client.

This is the reason why I haven't implemented support for SF devices in the
current KindleBT release: the `btmanagerd` daemon doesn't support the callback
for the BLE connection event, nor many other GATT Client events.
{ class = "aside" }

{{< figure
	src="./kindlebt-gattc-callback-handler.webp"
	alt="The callback handler for GATT Client operations reimplemented in KindleBT"
	caption="The GATT Client callback handler reversed and reimplemented in KindleBT"
	attr="<br>From the KindleBT codebase"
	attrlink="https://github.com/Sighery/kindlebt/blob/7a1a53f4ad02e0a4c11f330c2da6625d4388e765/src/compat_ace_handler.c#L9-L194"
>}}

In the previous figure you can see the GATT Client callback handler. This was
reversed from the `ace_bt` library in firmware version 5.17, and backported
into KindleBT so that it could work on devices with firmware version 5.16, in
which `ace_bt` doesn't yet implement this functionality.

Returning to the previous point, `btmanagerd` receives the raw Bluetooth
packet events, translates them into internal data structures, and then sends
the structures over the IPC socket. KindleBT then receives these structures,
determines the event type—in this case, the _GATT Client Read Characteristic_
event—and, if the application has registered for that event, executes the
callback.

{{< figure
	src="./ace_bt_manager_core-gattc_ipc_handler-read-char-event.webp"
	alt="Decompiled code of the GATT Client event handler and Read Characteristic case in btmanagerd/ace_bt_manager_core"
	caption="Here that same Read Characteristic event on the `btmanagerd` side"
>}}


## Dealing with breaking API changes

One of the earlier issues was identifying the ABI incompatibilities. It turns
out that `ace_bt` is still under active development, so there would be
breaking changes in the ABI from version to version, such as the removal of
certain functions, changes to the signature of others, and the introduction of
new functions.

```sh
# >=5.17 versions have all the new GATT Client APIs
$ nm -gD scribe1_5.17.3/libace_bt.so | grep "aceBT_bleReadCharacteristics"
0001262c T aceBT_bleReadCharacteristics

# While 5.16 versions have none of the GATT Client APIs
$ nm -gD scribe1_5.16.5/libace_bt.so | grep "aceBT_bleReadCharacteristics"

# Likewise, pre 5.16.3 versions, so SF, have none of the GATT Client APIs
$ nm -gD kpw5_5.16.2.1.1/libace_bt.so | grep "aceBT_bleReadCharacteristics"

# There are some other breaking API changes too:
$ nm -gD scribe1_5.17.3/libace_bt.so | grep -e "getSessionForTask" -e "getSessionForCallback"
00005890 T getSessionForTask

$ nm -gD scribe1_5.16.5/libace_bt.so | grep -e "getSessionForTask" -e "getSessionForCallback"
00005198 T getSessionForTask

$ nm -gD kpw5_5.16.2.1.1/libace_bt.so | grep -e "getSessionForTask" -e "getSessionForCallback"
000051a0 T getSessionForCallback
```

As I didn't want to have multiple build targets based on preprocessor
directives, I had to implement runtime ABI detection. For example,
[here an excerpt from the KindleBT codebase][KindleBT getSessionFromTask] to
detect whether we have `getSessionForCallback` or `getSessionForTask` and
provide a common API:

```c
#define _GNU_SOURCE

#include <kindlebt/compat_ace_shims.h>

#include <dlfcn.h>
#include <stdbool.h>

#include "log.h"

typedef sessionHandle (*getSessionForCallback_fn_t)(uint16_t);
typedef sessionHandle (*getSessionForTask_fn_t)(aceAipc_parameter_t*);

sessionHandle getSessionFromHandler(aceAipc_parameter_t* task) {
    static getSessionForCallback_fn_t old_api = NULL;
    static getSessionForTask_fn_t new_api = NULL;
    static bool initialized = false;

    if (!initialized) {
        new_api = (getSessionForTask_fn_t)dlsym(RTLD_DEFAULT, "getSessionForTask");
        if (!new_api) {
            old_api = (getSessionForCallback_fn_t)dlsym(RTLD_DEFAULT, "getSessionForCallback");
        }
        initialized = true;
    }

    if (new_api) {
        return new_api(task);
    } else if (old_api) {
        return old_api(task->callback_id);
    } else {
        // Nothing matched. We shouldn't reach this
        log_error("[%s()]: couldn't match any of the expected getSessionFor* symbols", __func__);
        return (sessionHandle)-1;
    }
}
```

The `getSessionFor*` functions are used in the callback handler and return the
same data with a mostly similar interface, so here we just needed to detect
and call the correct symbol at runtime.

Doing it this way means I can avoid multiple builds; it also means
applications don't need to worry about downloading the correct build or
figuring out what is the ABI of their included `ace_bt` library. They can
simply download the one KindleBT build for their architecture, and KindleBT
will resolve the different ABI versions and use the correct symbols.

However, some of the newer APIs, such as `aceBT_bleReadCharacteristics`, do
not have an older version. That meant that for these APIs, I had to reverse
engineer their implementation from the newer `ace_bt` versions, and
reimplement them so these operations would still work on Kindles with older
firmwares.
[Here is an example of the reversed `aceBT_bleReadCharacteristics` function][KindleBT pre5170_bleReadCharacteristic]
reimplemented in KindleBT:

```c
status_t pre5170_bleReadCharacteristic(
    sessionHandle session_handle, bleConnHandle conn_handle,
    bleGattCharacteristicsValue_t chars_value
) {
    log_debug("Called into pre 5.17 %s", __func__);

    status_t status;
    aipcHandles_t handle;

    status = getSessionInfo(session_handle, &handle);
    if (status != ACE_STATUS_OK) {
        log_error("[%s()]: Couldn't get session info. Result: %d", __func__, status);
        return ACE_STATUS_BAD_PARAM;
    }

    acebt_gattc_read_chars_req_data_t data;
    serialize_gattc_read_chars_req(&data, (uint32_t)conn_handle, chars_value);
    log_debug("[%s()]: Serialize request, status: %d", __func__, data.status);

    status = aipc_invoke_sync_call(ACE_BT_BLE_GATT_CLIENT_READ_CHARS_API, &data, data.size);
    if (status != ACE_STATUS_OK) {
        log_error("[%s()]: Failed to send AIPC call. Status: %d", __func__, status);
    }
    return status;
}
```

Then we just need another
[shim to detect whether the new symbol is available][KindleBT shim_bleReadCharacteristic],
and use it if so; otherwise, we should fall back on our reversed
implementation.

```c
typedef status_t (*aceBT_bleReadCharacteristics_fn_t)(
    sessionHandle, bleConnHandle, bleGattCharacteristicsValue_t
);

status_t shim_bleReadCharacteristic(
    sessionHandle session_handle, bleConnHandle conn_handle,
    bleGattCharacteristicsValue_t chars_value
) {
    static aceBT_bleReadCharacteristics_fn_t new_api = NULL;

#ifndef FORCE_OLD_API
    static bool initialized = false;

    if (!initialized) {
        new_api =
            (aceBT_bleReadCharacteristics_fn_t)dlsym(RTLD_DEFAULT, "aceBT_bleReadCharacteristics");
        initialized = true;
    }
#endif

    if (new_api) {
        return new_api(session_handle, conn_handle, chars_value);
    } else {
        return pre5170_bleReadCharacteristic(session_handle, conn_handle, chars_value);
    }
}
```

If you are interested in seeing the rest of the reversed GATT Client
operations, you can check the [KindleBT source code][KindleBT] and the
`compat_ace` files.


## What's next

Going forward I will be working on a Go service to allow remote page-turning
within the native Kindle reader. It is fairly easy to call and use C code from
a Go codebase thanks to CGO. First I would like to support the smart ring
shown in the picture at the beginning of the article, but other devices could
be implemented through generic Profiles. Support for [KOReader][] would also
be nice. And it would be highly amusing to get a [Kobo Remote][] working on a
Kindle.

I would also like to return to KindleBT and implement support for the missing
API operations. Sadly this becomes increasingly difficult with older firmware
versions and devices. The future of the project may be to build directly on
top of Bluedroid and have our own server daemon and library components,
bypassing `btmanagerd` and `ace_bt` entirely.

{{< figure
	src="./kindlebt_go-sneak-peek.webm"
	alt="Sneak peek of future projects using KindleBT"
	caption="It's a Go!"
	width="1640"
	height="1476"
>}}



[LanguageBreak]: https://github.com/notmarek/LanguageBreak
[Mobileread Kindle forums]: https://www.mobileread.com/forums/forumdisplay.php?f=150
[Clint]: https://github.com/clintharrison/
[Scam]: https://github.com/scamdotnet
[bueno monorepo]: https://github.com/clintharrison/bueno
[Pi Pico SDK]: https://www.raspberrypi.com/documentation/pico-sdk/index_doxygen.html
[Pi Pico MicroPython]: https://www.raspberrypi.com/documentation/microcontrollers/micropython.html
[pico-demo-gatt-service]: https://github.com/Sighery/pico-demo-gatt-service
[The Bluetooth Low Energy Primer]: https://www.bluetooth.com/bluetooth-le-primer/
[Making first contact]: #making-first-contact
[Environmental Sensing Profile]: https://www.bluetooth.com/specifications/specs/environmental-sensing-profile-1-0-1/
[Assigned Numbers specification]: https://www.bluetooth.com/specifications/assigned-numbers/
[GATT Specification Supplement]: https://www.bluetooth.com/specifications/gss/
[Bluedroid]: https://android.googlesource.com/platform/external/bluetooth/bluedroid/
[KindleTool]: https://github.com/NiLuJe/KindleTool
[KindleBT]: https://github.com/Sighery/kindlebt
[KindleBT documentation]: https://sighery.github.io/kindlebt/
[KindleBT public API]: https://sighery.github.io/kindlebt/group__KINDLEBT__PUBLIC__API.html
[KindleBT example]: https://sighery.github.io/kindlebt/basic_usage_8c-example.html
[KindleBT reversed registering callbacks]: https://github.com/Sighery/kindlebt/blob/7a1a53f4ad02e0a4c11f330c2da6625d4388e765/src/compat_ace_implementations.c#L69-L93
[Kindle firmware files]: https://www.amazon.com/gp/help/customer/display.html?nodeId=GKMQC26VQQMM8XSW
[Debian snapshots strace]: https://snapshot.debian.org/package/strace/4.9-2/
[KindleBT getSessionFromTask]: https://github.com/Sighery/kindlebt/blob/7a1a53f4ad02e0a4c11f330c2da6625d4388e765/src/compat_ace_shims.c#L17-L42
[KindleBT pre5170_bleReadCharacteristic]: https://github.com/Sighery/kindlebt/blob/7a1a53f4ad02e0a4c11f330c2da6625d4388e765/src/compat_ace_implementations.c#L162-L186
[KindleBT shim_bleReadCharacteristic]: https://github.com/Sighery/kindlebt/blob/7a1a53f4ad02e0a4c11f330c2da6625d4388e765/src/compat_ace_shims.c#L139-L160
[KindleBT source code]: https://github.com/Sighery/kindlebt/tree/7a1a53f4ad02e0a4c11f330c2da6625d4388e765/src
[KOReader]: https://koreader.rocks/
[Kobo Remote]: https://us.kobobooks.com/products/kobo-remote
