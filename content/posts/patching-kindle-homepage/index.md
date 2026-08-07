+++
date = "2026-06-08T00:00:00+00:00"
draft = false
title = "React Native, Hermes bytecode, and the Kindle homepage"
summary = "Why are there ads on my Kindle homepage?"
series = ["Kindle Hermes"]
+++

{{< figure
	src="feature.webp"
	alt="Homepage of a Kindle Paperwhite 11th-generation"
	caption="Why are there ads on my Kindle homepage?"
	loading="eager"
	fetchpriority="high"
>}}

Ever wondered what powers the Kindle's homepage? Turns out, since
[5.14.2 (February 2022)][New Homepage Article], Kindles use [React Native][]
for their homepage app.

Before this the homepage used to be written in Java. Back then, some smart
people in the Mobileread forums figured out how to
[patch the Java bytecode][JBPatch]. If you have ever used Revanced, this was
similar.

Sadly, JBPatch has seen no development for well over a decade. Even if it did,
most of the previous Java stack—which was used for both the homepage and
readers—has since been replaced with a combination of React Native and C++.

Before I continue, I would like to thank [Marek][] for writing the first
version of [KPP_Patch][], a program to patch the Kindle's homepage React
Native app, which I later contributed to. Also [hexpwn][], active in the
Kindle modding scene, who contributed some fixes to make the specific Kindle's
React Native version supported in the disassembler we use.


## React Native

[React Native][]—RN for short—allows the same JavaScript code to run on
multiple platforms, using native APIs. Although the official support is
limited to Android and iOS, there are community
[implementations for other platforms][Community React Native platforms] like
macOS, visionOS, and tvOS among others.

There is also [Skia][React Native Skia] which promises Linux support, but I
have not been able to confirm this is what Amazon is using for the Kindle.

A while back, [Lukas1h][] figured out how to make
[custom React Native apps][react-native-kindle] that could run on the Kindle.
I have not tried this, and it was last tested with a PW3 on 5.13.7—2021, so
mileage might vary on newer devices and firmware versions.

Regardless, this article will not cover React Native, but rather will focus on
[Hermes][], a new JavaScript engine developed by Facebook. Since 2022, it has
also become the [default engine][React Native 0.70 announcement] for React
Native applications.

Hermes not only supports running JavaScript code, but can also precompile
JavaScript into bytecode ahead of time, and then execute that bytecode. This
allows for smaller bundle sizes and faster start-up times. It also makes
reverse engineering and modding React Native applications that much harder.
Effectively, to patch a React Native application, you will need to modify the
Hermes bytecode.


## Hermes bytecode

Initially I was planning on just getting the latest React Native and writing a
simple app, so I could disassemble the bytecode and learn off that. This
already proved challenging, as there is no official Linux target. But that
wasn't the only issue.

The Hermes bytecode is not yet stable. The bytecode is only runnable by the
same Hermes version that produced it. At the time of writing, Hermes is on
[bytecode version 99][Hermes bytecode v99]. Meanwhile, the Kindle's homepage
is still using version 84:

```sh
[root@kindle root]$ file /app/KPPMainApp/js/KPPMainApp.js.hbc
/app/KPPMainApp/js/KPPMainApp.js.hbc: Hermes JavaScript bytecode, version 84
```

So not only would I need React Native plus Skia for the Linux target, but I
would need specifically React Native with an old Hermes engine using bytecode
version 84, which also supports Skia. Clearly, this wasn't going to work.

Instead I decided to focus on getting the compatible Hermes engine built,
since I mostly care about Hermes bytecode, not so much the React Native APIs.
Turns out, other than a
[relatively heavy C++ build setup][Hermes build instructions], it is pretty
simple to build and run Hermes. This includes a compiler and a disassembler,
as well as the engine that runs both JavaScript and bytecode.

Sadly you cannot just build the latest Hermes version. Like I mentioned
before, bytecode is only runnable for the Hermes version that built it. The
latest Hermes that supports bytecode version 84 is [v0.11.0][Hermes v0.11.0]
from 2021. This version proved more challenging to build, as it used different
instructions, and an older CMake version.

[Here are the v0.11.0 build instructions][Hermes v0.11.0 build instructions].
If you use Nix, I already did the work of
[building a derivation][hermes_84-nix]. For this, I needed to use an old
CMake version—`3.07`—from 2017. If you are using a normal distribution,
hopefully the build instructions plus the CMake version tip will help you.

```sh
$ nix build "github:Sighery/hermes_84-nix"

$ ls ./result/bin/
hbcdump  hdb  hermes  hermesc  hvm

$ echo "print('Hello Hermes');" > sample.js
$ ./result/bin/hermes -emit-binary -out sample.hbc sample.js
$ file sample.hbc
sample.hbc: Hermes JavaScript bytecode, version 84
$ ./result/bin/hermes sample.hbc
Hello Hermes
```

There are no platform APIs in Hermes. Those are implemented in React Native
and executed in Hermes through [JSI][]. I have not compiled JSI, nor tried to
integrate it with my bare Hermes build. Hermes provides a single undocumented
`print` function—no `console.log`. This I have found enough for simple
programs.

You can check Hermes' current ECMAScript feature support
[here][Hermes current ECMAScript support].
{ class = "aside" }


### Picking a disassembler

The scene is not _super_ mature, but there are already a number of projects
targeting Hermes bytecode. Hermes includes a `hbcdump` binary when built, but
this will only work for the specific bytecode version it was compiled for.

From third-parties, the most up to date project seems to be [hermes-dec][]
from [P1 Security][]. This is a disassembler and decompiler, but sadly no
assembler. They also maintain a table of up to date [Hermes opcodes][] which
will be useful regardless of which tool you use.

Finally, what Marek went with, [hbctool by bongtrop][bongtrop/hbctool]. This
is both a disassembler and an assembler, offering a Python API. It is
abandonware at this point, with its last commit being 3 years ago. Not to
mention, the bytecode 84 version on the `main` branch is broken, as hexpwn's
fixes only got merged to the `add-hbc-83-89-and-improve-contribution` branch.

I have since [forked it][Sighery/hbctool], merging the HBC84 fixes into the
main branch, as well as adding some type hints. There is no PyPI release as I
might not continue improving it past the requirements of KPP_Patch. That being
said, you can just install from a Git repo—and even branch—directly:

```sh
$ pip install git+https://github.com/Sighery/hbctool.git
Collecting git+https://github.com/Sighery/hbctool.git
  Cloning https://github.com/Sighery/hbctool.git to /tmp/pip-req-build-5b60j_qn
  Running command git clone --filter=blob:none --quiet https://github.com/Sighery/hbctool.git /tmp/pip-req-build-5b60j_qn
  Resolved https://github.com/Sighery/hbctool.git to commit 8f9bd718445abc4d1068f9cf9702f79f090fc74b
  Installing build dependencies ... done
  Getting requirements to build wheel ... done
  Preparing metadata (pyproject.toml) ... done

# You can also specify a branch
$ pip install git+https://github.com/Sighery/hbctool.git@main
Collecting git+https://github.com/Sighery/hbctool.git@main
  Cloning https://github.com/Sighery/hbctool.git (to revision main) to /tmp/pip-req-build-8x7q9kik
  Running command git clone --filter=blob:none --quiet https://github.com/Sighery/hbctool.git /tmp/pip-req-build-8x7q9kik
  Resolved https://github.com/Sighery/hbctool.git to commit 8f9bd718445abc4d1068f9cf9702f79f090fc74b
  Installing build dependencies ... done
  Getting requirements to build wheel ... done
  Preparing metadata (pyproject.toml) ... done
```

`pyproject.toml` uses a similar syntax. You can see it in action in the
[KPP_Patch repository][KPP_Patch pyproject.toml].
{ class = "aside" }


## A simple Hermes application

Let us have a very simple JavaScript application and walk through the
disassembly. I will also take this opportunity to show a bit of the `hbctool`
disassembly output. First, our JavaScript program:

```javascript
var a = 1 + 2;
var b = 3 + 4;
print("Hello Hermes!");
print("Result was " + (a + b));
```

Now we can compile it, run the bytecode, and then disassemble it with
`hbctool`:

```sh
$ hermes -emit-binary -out sample.hbc sample.js

$ hermes sample.hbc
Hello Hermes!
Result was 10

$ hbctool disasm sample.hbc temp_dis
[*] Disassemble 'sample.hbc' to 'temp_dis' path
[*] Hermes Bytecode [ Source Hash: 59a4d9f079f8828e55dbbcd0084d0c5e066daf2f, HBC Version: 84 ]
[*] Done

$ ls temp_dis/
instruction.hasm  metadata.json  string.json
```

After disassembly we will see three files: `metadata.json` is for `hbctool`
to know how to re-assemble the program. `instruction.hasm` and `string.json`
is generally where the patches will happen. I will quickly show the contents
of these two files, and then I will move onto explaining the disassembly.

First, `string.json`, the string table. All strings in the program, be it
string literals, variables, or function names will be in this file. The
bytecode does not use strings directly, but rather references and fetches
strings by ID as needed from the string table.

```json
[
    {
        "id": 0,
        "isUTF16": false,
        "value": "Hello Hermes!"
    },
    {
        "id": 1,
        "isUTF16": false,
        "value": "Result was "
    },
    {
        "id": 2,
        "isUTF16": false,
        "value": "global"
    },
    {
        "id": 3,
        "isUTF16": false,
        "value": "a"
    },
    {
        "id": 4,
        "isUTF16": false,
        "value": "b"
    },
    {
        "id": 5,
        "isUTF16": false,
        "value": "print"
    }
]
```

`instruction.hasm` contains the pseudo-assembly, named Hermes Assembly—or
HASM—by `hbctool`:

```text
Function<global>0(1 params, 12 registers, 0 symbols):
	DeclareGlobalVar    	UInt32:3
	; Oper[0]: String(3) 'a'

	DeclareGlobalVar    	UInt32:4
	; Oper[0]: String(4) 'b'

	LoadConstUInt8      	Reg8:1, UInt8:3
	GetGlobalObject     	Reg8:0
	PutById             	Reg8:0, Reg8:1, UInt8:1, UInt16:3
	; Oper[3]: String(3) 'a'

	LoadConstUInt8      	Reg8:1, UInt8:7
	PutById             	Reg8:0, Reg8:1, UInt8:2, UInt16:4
	; Oper[3]: String(4) 'b'

	TryGetById          	Reg8:3, Reg8:0, UInt8:1, UInt16:5
	; Oper[3]: String(5) 'print'

	LoadConstUndefined  	Reg8:2
	LoadConstString     	Reg8:1, UInt16:0
	; Oper[1]: String(0) 'Hello Hermes!'

	Call2               	Reg8:1, Reg8:3, Reg8:2, Reg8:1
	TryGetById          	Reg8:1, Reg8:0, UInt8:1, UInt16:5
	; Oper[3]: String(5) 'print'

	GetByIdShort        	Reg8:3, Reg8:0, UInt8:2, UInt8:3
	; Oper[3]: String(3) 'a'

	GetByIdShort        	Reg8:0, Reg8:0, UInt8:3, UInt8:4
	; Oper[3]: String(4) 'b'

	Add                 	Reg8:3, Reg8:3, Reg8:0
	LoadConstString     	Reg8:0, UInt16:1
	; Oper[1]: String(1) 'Result was '

	Add                 	Reg8:0, Reg8:0, Reg8:3
	Call2               	Reg8:0, Reg8:1, Reg8:2, Reg8:0
	Ret                 	Reg8:0
EndFunction
```

Once again, the full list of opcodes can be found [here][Hermes opcodes], but
I will explain as I go. For any string references, `hbctool` will add a
comment—lines starting with a semicolon—with the string value that ID
references.

```text
DeclareGlobalVar    	UInt32:3
; Oper[0]: String(3) 'a'

DeclareGlobalVar    	UInt32:4
; Oper[0]: String(4) 'b'
```

First we see our declaration of the `a` and `b` globals. The number at the end
of the `UInt32:*` is the ID. This is the ID you would look up in the
string table, but `hbctool` has already done that work for us. So far,
these variables are uninitialised.

```text
LoadConstUInt8      	Reg8:1, UInt8:3
GetGlobalObject     	Reg8:0
PutById             	Reg8:0, Reg8:1, UInt8:1, UInt16:3
; Oper[3]: String(3) 'a'

LoadConstUInt8      	Reg8:1, UInt8:7
PutById             	Reg8:0, Reg8:1, UInt8:2, UInt16:4
; Oper[3]: String(4) 'b'
```

Next we are going to see the variables being initialised. Here we also see a
`GetGlobalObject` instruction. These is where the previously declared
variables were stored in. The bytecode loads the global object, and puts it in
the register 0—`Reg8:0`.

Then it loads the `uint8` value `3`—`UInt8:3`—into the first
register—`Reg8:1`. If you look at the code, it was adding `1 + 2`, but the
compiler has collapsed this operation and is now storing `3` directly.

Then we come to the `PutById` instruction. This one is slightly more complex.
The documentation has the following to say about it:

{{< figure
	src="./PutById_docs.webp"
	alt="Documentation for the PutById Hermes instruction"
	attr="From P1 Security's Hermes opcodes table"
	attrlink="https://p1sec.github.io/hermes-dec/opcodes_table.html"
>}}

I have been unable to figure out what `Arg3` maps to. Perhaps it is some
internal flag, or it might just be unused. Either way, it is irrelevant to
this example so I will skip it.
{ class = "aside" }

`Arg1`
: `Reg8:0`, the global object—previously loaded by `LoadGlobalObject`.

`Arg2`
: `Reg8:1`, holding `UInt8:3`—previously loaded by `LoadConstUInt8`. This will
  be the value.

`Arg4`
: `UInt16:3`, this is a string reference. If we were to look for the string
  with ID `3` in the strings table, we would find it maps to `a`, but
  `hbctool` has already done the work for us. This will be the property in the
  global object.

Coming back to JavaScript, this whole block would be something like:
`globals.a = 3;`

The following block is pretty much the same. The `globals` is already loaded
into `Reg8:0` so that operation is skipped. `LoadConstUInt8` is called again,
and it reuses `Reg8:1`, but this time loads `UInt8:7` into it (`3 + 4`). This
time the property for `PutById`—`UInt16:4`—is the string `b`.

```text
TryGetById          	Reg8:3, Reg8:0, UInt8:1, UInt16:5
; Oper[3]: String(5) 'print'

LoadConstUndefined  	Reg8:2
LoadConstString     	Reg8:1, UInt16:0
; Oper[1]: String(0) 'Hello Hermes!'

Call2               	Reg8:1, Reg8:3, Reg8:2, Reg8:1
```

The next part gets grouped a bit strangely by the `hbctool` disassembly, but
it is the `print("Hello Hermes!");` statement. I will explain, instruction by
instruction.

First we have `TryGetById`. This instruction is specifically for getting
global variables. `Arg2` is the global object, which remember is still loaded
in `Reg8:0`. `Arg3` is irrelevant. `Arg4`—`UInt16:5`—is referencing `print`
from the string table. And finally, `Arg1` is where we store the result to:
`Reg8:3`, previously unused.

`LoadConstUndefined` is pretty easy to understand: it loads `undefined` into
`Arg1`, another new register `Reg8:2`.

`LoadConstString` loads the string from `Arg2` into register `Arg1`. Here it
reuses `Reg8:1`, that previously contained an integer. `UInt16:0` references
the string `Hello Hermes!` from the string table.

Last line we arrive to the function call. There are `Call1` to `Call4`
instructions, the number at the end indicating the amount of arguments the
function takes. In the case of `Call2`: `Arg1` is the return value, `Arg1` the
closure to call, `Arg2` the first argument, and `Arg3` the second argument.

You can see the closure to call is `Reg8:3`, where `TryGetById` loaded the
`print` function to. `Arg3` is the `Hello Hermes!` string loaded into `Reg8:1`
by `LoadConstString`. `Arg2` is the `undefined` value in `Reg8:2`.

I am unsure why `print` needs two arguments, as there is no documentation for
this function I could find.
{ class = "aside" }

```text
TryGetById          	Reg8:1, Reg8:0, UInt8:1, UInt16:5
; Oper[3]: String(5) 'print'

GetByIdShort        	Reg8:3, Reg8:0, UInt8:2, UInt8:3
; Oper[3]: String(3) 'a'

GetByIdShort        	Reg8:0, Reg8:0, UInt8:3, UInt8:4
; Oper[3]: String(4) 'b'

Add                 	Reg8:3, Reg8:3, Reg8:0
LoadConstString     	Reg8:0, UInt16:1
; Oper[1]: String(1) 'Result was '

Add                 	Reg8:0, Reg8:0, Reg8:3
Call2               	Reg8:0, Reg8:1, Reg8:2, Reg8:0
Ret                 	Reg8:0
```

`TryGetById` loads `print` again from the global object.

`GetByIdShort` is a new instruction. Documentation is also unclear on what
`Arg3` does. `Arg1` is the register the value is stored to. `Arg2` is the
global object again—still loaded into `Reg8:0`. Finally, `Arg4` is the
string/property `a`. Its value is stored in the third register, `Reg8:3`.

A second `GetByIdShort` instruction for `b`, storing it in `Reg8:0`. This
overwrites the global object, but Hermes has decided this is fine as the
program is close to the end, and the global object won't be used anymore.

Then we see the first `Add` instruction. Here it is adding the value of the
variable `a`—stored in `Reg8:0`, and the value of the variable `b`—stored in
`Reg8:3`. The result is being put back into `Reg8:3`. This is the `(a + b)`
part of the `print("Result was " + (a + b));` statement.

`LoadConstString` loads the `Result was ` string into `Reg8:0`.

`Add` is also used for concatenation, so we see it here again, concatenating
`Reg8:0`—which contains the string `Result was `, with `Reg8:3`—which contains
the integer `7`. The result is put back into `Reg8:0`.

Next comes the `print` call, its closure was stored in `Reg8:1` still.
`Reg8:2` still contains the `undefined` value. And `Reg8:0` currently holds
`Result was 7` after the previous `Add` instruction.

`Ret` is pretty self-explanatory: it returns.


### A simple Hermes string patch

Now that I have introduced the string table and Hermes Assembly, I will show a
really simple patch to the string table. The `print("Hello Hermes!");`
statement is a really easy target, so I will patch that string:

```diff
--- a/temp_dis/string.json
+++ b/temp_dis/string.json
@@ -2,7 +2,7 @@
     {
         "id": 0,
         "isUTF16": false,
-        "value": "Hello Hermes!"
+        "value": "Hello Patched"
     },
     {
         "id": 1,
```

After reassembling it we can run it through `hermes`:

```sh
$ hbctool asm temp_dis/ sample.patched.hbc
[*] Assemble 'temp_dis/' to 'sample.patched.hbc' path
[*] Hermes Bytecode [ Source Hash: 59a4d9f079f8828e55dbbcd0084d0c5e066daf2f, HBC Version: 84 ]
[*] Done

$ hermes sample.patched.hbc
Hello Patched
Result was 10
```

If you are reassembling code, and you want to run it back through Hermes,
ensure it has a final `.hbc` file extension, otherwise Hermes will try to
execute it as a text file and fail.
{ class = "aside" }

Patching strings this way is quite limited. If we limit ourselves to the
string table edits, we cannot add new strings, and we must ensure any strings
we patch maintain the same length. You can do more powerful string patching,
but that requires getting deep into the `metadata.json` internals, adding new
string storage and fixing existing storage offsets when you change lengths.


### A simple Hermes opcode patch

Patching strings is quite limited, but patching opcodes is much more powerful.
Here I am going to patch the `var a = 1 + 2;` assignment, and instead I will
have `a` hold `5`:

```diff
--- a/temp_dis/instruction.hasm
+++ b/temp_dis/instruction.hasm
@@ -5,7 +5,7 @@ Function<global>0(1 params, 12 registers, 0 symbols):
     DeclareGlobalVar        UInt32:4
     ; Oper[0]: String(4) 'b'
 
-    LoadConstUInt8          Reg8:1, UInt8:3
+    LoadConstUInt8          Reg8:1, UInt8:5
     GetGlobalObject         Reg8:0
     PutById                 Reg8:0, Reg8:1, UInt8:1, UInt16:3
     ; Oper[3]: String(3) 'a'
```

Same reassembly steps as before:

```sh
$ hbctool asm temp_dis/ sample.patched.hbc
[*] Assemble 'temp_dis/' to 'sample.patched.hbc' path
[*] Hermes Bytecode [ Source Hash: 59a4d9f079f8828e55dbbcd0084d0c5e066daf2f, HBC Version: 84 ]
[*] Done

$ hermes sample.patched.hbc 
Hello Hermes!
Result was 12
```


### A slightly more complex Hermes application

So far we were dealing on the global object, using very simple operations.
The following might be a slightly more realistic example:

```javascript
function isPremium(userId) {
  return userId % 2 == 0;
}

const users = [
  { userId: 0 },
  { userId: 1 },
];

for (let user of users) {
  print(`Is user ${user.userId} premium? ${isPremium(user.userId)}`);
}
```

`hbctool` already shows the strings used so I will omit the string table, and
instead will focus fully on the Hermes assembly.

```text
Function<global>0(1 params, 21 registers, 0 symbols):
	DeclareGlobalVar    	UInt32:5
	; Oper[0]: String(5) 'isPremium'

	LoadConstUndefined  	Reg8:6
	GetGlobalObject     	Reg8:5
	LoadConstString     	Reg8:4, UInt16:0
	; Oper[1]: String(0) 'Is user '

	LoadConstString     	Reg8:3, UInt16:1
	; Oper[1]: String(1) ' premium? '

	CreateEnvironment   	Reg8:0
	CreateClosure       	Reg8:0, Reg8:0, UInt16:1
	PutById             	Reg8:5, Reg8:0, UInt8:1, UInt16:5
	; Oper[3]: String(5) 'isPremium'

	LoadConstUndefined  	Reg8:0
	NewObject           	Reg8:1
	LoadConstZero       	Reg8:2
	PutNewOwnByIdShort  	Reg8:1, Reg8:2, UInt8:7
	; Oper[2]: String(7) 'userId'

	NewArray            	Reg8:7, UInt16:2
	PutOwnByIndex       	Reg8:7, Reg8:1, UInt8:0
	NewObject           	Reg8:1
	LoadConstUInt8      	Reg8:2, UInt8:1
	PutNewOwnByIdShort  	Reg8:1, Reg8:2, UInt8:7
	; Oper[2]: String(7) 'userId'

	PutOwnByIndex       	Reg8:7, Reg8:1, UInt8:1
	Mov                 	Reg8:1, Reg8:7
	IteratorBegin       	Reg8:2, Reg8:1
	IteratorNext        	Reg8:7, Reg8:2, Reg8:1
	Mov                 	Reg8:8, Reg8:2
	JStrictEqual        	Addr8:62, Reg8:8, Reg8:6
	TryGetById          	Reg8:8, Reg8:5, UInt8:1, UInt16:6
	; Oper[3]: String(6) 'print'

	GetByIdShort        	Reg8:10, Reg8:7, UInt8:2, UInt8:7
	; Oper[3]: String(7) 'userId'

	GetByIdShort        	Reg8:9, Reg8:5, UInt8:3, UInt8:5
	; Oper[3]: String(5) 'isPremium'

	GetByIdShort        	Reg8:7, Reg8:7, UInt8:2, UInt8:7
	; Oper[3]: String(7) 'userId'

	Call2               	Reg8:9, Reg8:9, Reg8:6, Reg8:7
	TryGetById          	Reg8:7, Reg8:5, UInt8:4, UInt16:3
	; Oper[3]: String(3) 'HermesInternal'

	GetByIdShort        	Reg8:7, Reg8:7, UInt8:5, UInt8:4
	; Oper[3]: String(4) 'concat'

	Call4               	Reg8:7, Reg8:7, Reg8:4, Reg8:10, Reg8:3, Reg8:9
	Call2               	Reg8:0, Reg8:8, Reg8:6, Reg8:7
	Jmp                 	Addr8:-60
	Catch               	Reg8:1
	IteratorClose       	Reg8:2, UInt8:1
	Throw               	Reg8:1
	Ret                 	Reg8:0
EndFunction

Function<isPremium>1(2 params, 2 registers, 0 symbols):
	LoadParam           	Reg8:1, UInt8:1
	LoadConstUInt8      	Reg8:0, UInt8:2
	Mod                 	Reg8:1, Reg8:1, Reg8:0
	LoadConstZero       	Reg8:0
	StrictEq            	Reg8:0, Reg8:1, Reg8:0
	Ret                 	Reg8:0
EndFunction
```

Quite a lot of changes: `isPremium` is now a separate `Function` block, and
the global block is quite a lot more complex now. There are a few new
instructions, but I will not go line by line again. They are all
[in the documentation][Hermes opcodes] for the curious.

While this is a very short snippet, this is the kind of functionality you
might find on mobile apps. In such a case, one might want to patch this
function so it always returns `True`.

```diff
--- a/temp_dis/instruction.hasm
+++ b/temp_dis/instruction.hasm
@@ -63,10 +63,6 @@ Function<global>0(1 params, 21 registers, 0 symbols):
 EndFunction
 
 Function<isPremium>1(2 params, 2 registers, 0 symbols):
-    LoadParam               Reg8:1, UInt8:1
-    LoadConstUInt8          Reg8:0, UInt8:2
-    Mod                     Reg8:1, Reg8:1, Reg8:0
-    LoadConstZero           Reg8:0
-    StrictEq                Reg8:0, Reg8:1, Reg8:0
+    LoadConstTrue           Reg8:0
     Ret                     Reg8:0
 EndFunction
```

Like before, we reassemble it, and we will now see every user being marked as
premium:

```sh
$ hbctool asm temp_dis/ sample.patched.hbc 
[*] Assemble 'temp_dis/' to 'sample.patched.hbc' path
[*] Hermes Bytecode [ Source Hash: 25714b72e8baee06b631e5ae48fb5663c0016678, HBC Version: 84 ]
[*] Done

$ hermes sample.patched.hbc 
Is user 0 premium? true
Is user 1 premium? true
```


### Some jumps, as a treat

So far, the programs have been fairly straightforward, with almost no
branching. Whenever we have branching, we will start running into different
jump instructions. There is obviously `Jmp`, which goes to a specific
instruction. But instructions like `JStrictEqual` will also cause a jump.

```js
function jumping(x) {
  if (x === 1) return 10;
  if (x === 2) return 20;
  if (x === 3) return 30;
  return 40;
}

var result = jumping(2);
print(result);
```

I will leave out the compilation and disassembly steps, and just focus on the
`jumping` instructions, ignoring the globals:

```text
Function<jumping>1(2 params, 2 registers, 0 symbols):
    LoadParam           	Reg8:1, UInt8:1
    LoadConstUInt8      	Reg8:0, UInt8:1
    JStrictEqual        	Addr8:33, Reg8:1, Reg8:0
    LoadConstUInt8      	Reg8:0, UInt8:2
    JStrictEqual        	Addr8:21, Reg8:1, Reg8:0
    LoadConstUInt8      	Reg8:0, UInt8:3
    JStrictEqual        	Addr8:9, Reg8:1, Reg8:0
    LoadConstUInt8      	Reg8:0, UInt8:40
    Ret                 	Reg8:0
    LoadConstUInt8      	Reg8:0, UInt8:30
    Ret                 	Reg8:0
    LoadConstUInt8      	Reg8:0, UInt8:20
    Ret                 	Reg8:0
    LoadConstUInt8      	Reg8:0, UInt8:10
    Ret                 	Reg8:0
EndFunction
```

Whenever you see `Addr8`, you should assume it is pointing to _some_ other
instruction. Which one exactly? That is the tricky part. The instruction
itself is one byte—there is no `JStrictEqual` string in the assembly, there is
just the opcode `181`, which is one byte.

How many bytes does then an opcode use? Generally, for any opcodes that don't
use strings, each argument will be 1 byte, but even this is not always
certain, as `UInt16` arguments will take up two bytes.

{{< figure
    src="./JStrictEqual-docs.webp"
    alt="Documentation for the JStrictEqual instruction"
    attr="From P1 Security's Hermes opcodes table"
    attrlink="https://p1sec.github.io/hermes-dec/opcodes_table.html"
>}}

You will have to reference the opcode documentation and look for the
`total_size` indicator. In the case of `JStrictEqual`, since it is using
one-byte arguments, the total size of its arguments is 3. So for the whole
instruction—opcode and its arguments—it will use 4 bytes.

```text
; 3 bytes
LoadParam           	Reg8:1, UInt8:1
; 3 bytes
LoadConstUInt8      	Reg8:0, UInt8:1
; 4 bytes
JStrictEqual        	Addr8:33, Reg8:1, Reg8:0
; 3 bytes
LoadConstUInt8      	Reg8:0, UInt8:2
; 4 bytes
JStrictEqual        	Addr8:21, Reg8:1, Reg8:0
; 3 bytes
LoadConstUInt8      	Reg8:0, UInt8:3
; 4 bytes
JStrictEqual        	Addr8:9, Reg8:1, Reg8:0
; 3 bytes
LoadConstUInt8      	Reg8:0, UInt8:40
; 2 bytes
Ret                 	Reg8:0
; 3 bytes
LoadConstUInt8      	Reg8:0, UInt8:30
; 2 bytes
Ret                 	Reg8:0
; 3 bytes
LoadConstUInt8      	Reg8:0, UInt8:20
; 2 bytes
Ret                 	Reg8:0
; 3 bytes
LoadConstUInt8      	Reg8:0, UInt8:10
; 2 bytes
Ret                 	Reg8:0
```

Let us focus on the `if (x === 3) return 30;` branch, since it will be the
closest jump. The jump offset is from the instruction's beginning. In the
assembly, `LoadConstUInt8 Reg8:0, UInt8:3` is where the 3 gets loaded for the
comparison. Then the next instruction, `JStrictEqual Addr8:9, Reg8:1, Reg8:0`
will compare the function parameter against that loaded `3`. If this
comparison is `true`, it skips 9 bytes forward.

Again, the jump offset starts from the instruction's beginning. Meaning,
`JStrictEqual` takes up 4 bytes, the next instruction `LoadConstUInt8` takes
up 3—up to 7 bytes now, then `Ret` takes up 2 bytes—we are now at 9 bytes. And
what are the next instructions after `Ret`? `LoadConstUInt8 Reg8:0, UInt8:30`
and `Ret Reg8:0`. If the `x === 30` comparison was true, it skips to the two
instructions loading the integer `30`, and immediately returning that integer.

You can follow these same steps for the `x === 2` and `x === 1` paths. You
will find that its `Addr8:21` and `Addr8:33` offsets will jump you to the
`LoadConstUInt8` and `Ret` instructions that load either `20` or `10`.

The current implementation is pretty simple, it just uses 2 for the input, and
so the output will be 20:

```sh
$ hermes sample-jumps.js.hbc
20
```

We could patch the input, provide a different value so we get a different
output. But here I want to patch exclusively the jumps. So now, when I pass
`2` as the input, I want to get `40` as the output:

```diff
--- a/temp_jumps/instruction.hasm
+++ b/temp_jumps/instruction.hasm
@@ -35,7 +35,7 @@ Function<jumping>1(2 params, 2 registers, 0 symbols):
     LoadConstUInt8          Reg8:0, UInt8:1
     JStrictEqual            Addr8:33, Reg8:1, Reg8:0
     LoadConstUInt8          Reg8:0, UInt8:2
-    JStrictEqual            Addr8:21, Reg8:1, Reg8:0
+    JStrictEqual            Addr8:11, Reg8:1, Reg8:0
     LoadConstUInt8          Reg8:0, UInt8:3
     JStrictEqual            Addr8:9, Reg8:1, Reg8:0
     LoadConstUInt8          Reg8:0, UInt8:40
```

If we then reassemble it and run it:

```sh
$ hbctool asm temp_jumps/ sample-jumps.patched.hbc
[*] Assemble 'temp_jumps/' to 'sample-jumps.patched.hbc' path
[*] Hermes Bytecode [ Source Hash: 55191b1ca2b34980679146314341441a1ee56931, HBC Version: 84 ]
[*] Done

$ hermes sample-jumps.patched.hbc
40
```


### Programmatically applying patches

Coming back to the `isPremium` example, we could always try to automate our
text changes, but `hbctool` provides a Python API, so I will show how to make
that patch programmatically:

```python
from pprint import pprint
from typing import BinaryIO

from hbctool import hbc


ALWAYS_TRUE = [
    ("LoadConstTrue", [("Reg8", False, 0)]),
    ("Ret", [("Reg8", False, 0)]),
]


# When using the CLI flow, hbctool keeps all data about the Hermes bytecode
# in metadata.json. With the programmatic flow, it keeps the contents in
# memory, and runs against that.
def find_func_by_name(app, name: str) -> tuple:
    for fid in range(app.getFunctionCount()):
        fnName = app.getString(
            app.getObj()["functionHeaders"][fid]["functionName"]
        )[0]

        if name in fnName:
            return (fid, app.getFunction(fid))

    raise Exception("Function not found!")


def patch_premium_func(bytecode: BinaryIO) -> None:
    app = hbc.load(bytecode)
    print(f"Hermes bytecode version {app.getVersion()}")

    func_id, func_data = find_func_by_name(app, "isPremium")
    print("Original isPremium func_data is")
    pprint(func_data)
    func_new = list(func_data)
    # func_data[4] are the instructions for this function
    func_new[4] = ALWAYS_TRUE

    app.setFunction(func_id, func_new)

    with open("patched.hbc", "wb+") as f:
        hbc.dump(app, f)

    print("Program patched! Run patched.hbc now!")


if __name__ == "__main__":
    with open("sample.hbc", "rb") as f:
        patch_premium_func(f)
```

Sadly the `hbctool` API is not documented. It also only has the partial type
hints I have added so far. That being said,
[the code is not that complex][hbctool API].

I skipped showing `metadata.json` earlier as it is quite big and I will not go
into details into any particular fields, but here it will be helpful to see,
as most of the API operations will run against this exact data:

```json
{
  "header": {
    "magic"              : 2240826417119764422,
    "version"            : 84,
    "sourceHash"         : [
       37, 113,  75, 114, 232, 186, 238,   6, 182,  49, 229, 174,  72, 251,
       86,  99, 192,   1, 102, 120
    ],
    "fileLength"         : 622,
    "globalCodeIndex"    : 0,
    "functionCount"      : 2,
    "stringKindCount"    : 2,
    "identifierCount"    : 5,
    "stringCount"        : 8,
    "overflowStringCount": 0,
    "stringStorageSize"  : 63,
    "regExpCount"        : 0,
    "regExpStorageSize"  : 0,
    "arrayBufferSize"    : 0,
    "objKeyBufferSize"   : 0,
    "objValueBufferSize" : 0,
    "segmentID"          : 0,
    "cjsModuleCount"     : 0,
    "functionSourceCount": 0,
    "debugInfoOffset"    : 472,
    "option"             : 0,
    "padding"            : [
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0
    ]
  },
  "functionHeaders": [
    {
      "offset"                : 284,
      "paramCount"            :   1,
      "bytecodeSizeInBytes"   : 138,
      "functionName"          :   2,
      "infoOffset"            : 440,
      "frameSize"             :  21,
      "environmentSize"       :   0,
      "highestReadCacheIndex" :   5,
      "highestWriteCacheIndex":   1,
      "flags"                 :  26
    },
    {
      "offset"                : 422,
      "paramCount"            :   2,
      "bytecodeSizeInBytes"   :  18,
      "functionName"          :   5,
      "infoOffset"            : 464,
      "frameSize"             :   2,
      "environmentSize"       :   0,
      "highestReadCacheIndex" :   0,
      "highestWriteCacheIndex":   0,
      "flags"                 :  18
    }
  ],
  "stringKinds": [3, 2147483653],
  "identifierHashes": [
    2243688185, 3415079525, 4108536625, 2794059355, 1877286100
  ],
  "stringTableEntries": [
    {"isUTF16": 0, "offset":  0, "length":  8},
    {"isUTF16": 0, "offset":  7, "length": 10},
    {"isUTF16": 0, "offset": 17, "length":  6},
    {"isUTF16": 0, "offset": 23, "length": 14},
    {"isUTF16": 0, "offset": 37, "length":  6},
    {"isUTF16": 0, "offset": 43, "length":  9},
    {"isUTF16": 0, "offset": 52, "length":  5},
    {"isUTF16": 0, "offset": 57, "length":  6}
  ],
  "stringTableOverflowEntries": [],
  "stringStorage": [
     73, 115,  32, 117, 115, 101, 114,  32, 112, 114, 101, 109, 105, 117, 109,
     63,  32, 103, 108, 111,  98,  97, 108,  72, 101, 114, 109, 101, 115,  73,
    110, 116, 101, 114, 110,  97, 108,  99, 111, 110,  99,  97, 116, 105, 115,
     80, 114, 101, 109, 105, 117, 109, 112, 114, 105, 110, 116, 117, 115, 101,
    114,  73, 100
  ],
  "arrayBuffer": [],
  "objKeyBuffer": [],
  "objValueBuffer": [],
  "regExpTable": [],
  "regExpStorage": [],
  "cjsModuleTable": [],
  "instOffset": 284,
  "inst": [
     49,   5,   0,   0,   0, 112,   6,  46,   5, 109,   4,   0,   0, 109,   3,
      1,   0,  48,   0,  96,   0,   0,   1,   0,  55,   5,   0,   1,   5,   0,
    112,   0,   3,   1, 116,   2,  59,   1,   2,   7,   7,   7,   2,   0,  64,
      7,   1,   0,   3,   1, 106,   2,   1,  59,   1,   2,   7,  64,   7,   1,
      1,   8,   1,   7, 132,   2,   1, 133,   7,   2,   1,   8,   8,   2, 181,
     62,   8,   6,  53,   8,   5,   1,   6,   0,  50,  10,   7,   2,   7,  50,
      9,   5,   3,   5,  50,   7,   7,   2,   7,  79,   9,   9,   6,   7,  53,
      7,   5,   4,   3,   0,  50,   7,   7,   5,   4,  81,   7,   7,   4,  10,
      3,   9,  79,   0,   8,   6,   7, 135, 196,  89,   1, 134,   2,   1,  91,
      1,  88,   0, 104,   1,   1, 106,   0,   2,  28,   1,   1,   0, 116,   0,
     15,   0,   1,   0,  88,   0,   1,   0,   0,   0,  78,   0,   0,   0, 127,
      0,   0,   0, 129,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
     64,   0,   0,   0,   0,   0,   0,   0,   1,   0,   0,   0,  17,   0,   0,
      0,   1,   0,   0,   0,  71,   0,   0,   0,  73,   0,   0,   0,   0,   0,
      0,   0,  17,   0,   0,   0, 115,  97, 109, 112, 108, 101,  45,  99, 111,
    109, 112, 108, 101, 120,  46, 106, 115,   0,   0,   0,   0,   0,   0,   0,
      0,   0,   0,   0,   0,   0,   1,   1,  24,   0,   0,  12,  10,   2,   8,
    126,  12,   9,   4, 116,   4, 124,  12,   7,  12, 114,   3,   0,   0,  11,
      2,   2,   6,   0,  21,   5,   0,  20,   5,   0,  14,   5,   0, 123,   5,
      0,  84,   6,   0,   0,   5,   0,   0,   7,   0, 127,   5,   2, 121,   2,
      0,   0,   2,   0,   0,   3,   0,   0, 127,   1,   1,   1,   6,   2,   9,
    127, 127,   0,  37, 183, 214,  68, 245, 247, 147,  55, 210, 245, 118, 196,
    157, 232, 159, 208, 130, 136,  53, 160
  ]
}
```

When you call the `getObj` method, the API will simply give you this JSON.
When you call `getHeader`, it will give you `getObj()["header"]`. When calling
`getFunctionCount`, it will give you `getObj()["header"]["functionCount"]`,
and so on. In the programmatic approach there is no `metadata.json` file on
disk, but it is exactly the same data inside the program's memory.

Now that I have explained this, let me quickly walk through the most important
parts of the code.

```python
ALWAYS_TRUE = [
    ("LoadConstTrue", [("Reg8", False, 0)]),
    ("Ret", [("Reg8", False, 0)]),
]
```

This one is pretty self-explanatory. These are a series of individual
instructions. If you remember from the previous text-based patch, I made it so
the `isPremium` function contents were just a single `LoadConstTrue` and `Ret`
instructions. This will do the same. If we have a function that we want to
patch to always return `True`, we just need to replace the function's existing
instructions for this `ALWAYS_TRUE` instruction block.

You can also do this for `False`, through `LoadConstFalse`; `undefined`,
through `LoadConstUndefined`; specific numbers through `LoadConstUInt8`; and
so on.

```python
def find_func_by_name(app, name: str) -> tuple:
    for fid in range(app.getFunctionCount()):
        fnName = app.getString(
            app.getObj()["functionHeaders"][fid]["functionName"]
        )[0]

        if name in fnName:
            return (fid, app.getFunction(fid))

    raise Exception("Function not found!")
```

`find_func_by_name` might look a bit complex, but while it requires a few more
operations, it is fairly simple to understand. First, `getFunctionCount` will
return the number in `header.functionCount`, which in this case is `2`.

The `metadata.json` has this block of function declarations:

```json
{"functionHeaders": [
  {
    "offset"                : 284,
    "paramCount"            :   1,
    "bytecodeSizeInBytes"   : 138,
    "functionName"          :   2,
    "infoOffset"            : 440,
    "frameSize"             :  21,
    "environmentSize"       :   0,
    "highestReadCacheIndex" :   5,
    "highestWriteCacheIndex":   1,
    "flags"                 :  26
  },
  {
    "offset"                : 422,
    "paramCount"            :   2,
    "bytecodeSizeInBytes"   :  18,
    "functionName"          :   5,
    "infoOffset"            : 464,
    "frameSize"             :   2,
    "environmentSize"       :   0,
    "highestReadCacheIndex" :   0,
    "highestWriteCacheIndex":   0,
    "flags"                 :  18
  }
]}
```

As you can see, the function's name is not stored here, but rather the
string's ID is. That means that to match a function by name, we need to
iterate first over `functionHeaders`, fetch the string from the string table,
and then compare against our target name.

`hbctool` wants to work with "function IDs". There is no associated ID to
functions in the bytecode, but `hbctool` will use the numerical index inside
`functionHeaders` as the ID. Meaning that the `isPremium` function will have
function ID `1`.

`getFunction` is quite complex and it does a lot of things. I will paste here
the [full definition from the API][hbctool API getFunction], but I will not go
over every line. I will only point out to the final return which is a tuple
of 6 elements. The relevant one is `insts`—index `4`—that contains the full
instruction block of this function, which we will replace in full.

Technically this is a `NamedTuple`, two of them. When we see instructions
like `LoadConstString` in lists and tuples, these are disassembled by
`hbctool`, as the bytecode operates directly on bytes. The `Function` return
type contains those bytes, while `FunctionDisassembled` offers the more
human-friendly Hermes Assembly.
{ class = "aside" }

```python
def getFunction(self, fid: int, disasm: bool = True) -> FuncUnion:
    assert fid >= 0 and fid < self.getFunctionCount(), "Invalid function ID"

    functionHeader = self.getObj()["functionHeaders"][fid]
    offset = functionHeader["offset"]
    paramCount = functionHeader["paramCount"]
    registerCount = functionHeader["frameSize"]
    symbolCount = functionHeader["environmentSize"]
    bytecodeSizeInBytes = functionHeader["bytecodeSizeInBytes"]
    functionName = functionHeader["functionName"]

    instOffset = self.getObj()["instOffset"]
    start = offset - instOffset
    end = start + bytecodeSizeInBytes
    bc = self.getObj()["inst"][start:end]

    functionNameStr, _ = self.getString(functionName)

    if not disasm:
        return Function(
            functionNameStr,
            paramCount,
            registerCount,
            symbolCount,
            bc,
            functionHeader,
        )
    else:
        return FunctionDisassembled(
            functionNameStr,
            paramCount,
            registerCount,
            symbolCount,
            list(wrapped_disassemble(bc)),
            functionHeader,
        )
```

The rest of the code is then quite simple. Here I will post a slightly edited,
more imperative excerpt for the sake of reducing boilerplate and showcasing
the overall flow of the program:

```python
with open("sample.hbc", "rb") as f:
    app = hbc.load(f)

func_id, func_data = find_func_by_name(app, "isPremium")
func_new = list(func_data)
func_new[4] = ALWAYS_TRUE
app.setFunction(func_id, func_new)

with open("patched.hbc", "wb+") as f:
    hbc.dump(app, f)
```

So then, all that remains is patching the file and running it:

```sh { class = "code-wrap" }
$ python premium_patcher.py
Hermes bytecode version 84
Original isPremium func_data is
FunctionDisassembled(name='isPremium', param_count=2, register_count=2, symbol_count=0, instructions=[InstructionDisassembled(instruction='LoadParam', arguments=[InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=1), InstructionArgumentDisassembled(arg_type='UInt8', is_string=False, arg_value=1)]), InstructionDisassembled(instruction='LoadConstUInt8', arguments=[InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=0), InstructionArgumentDisassembled(arg_type='UInt8', is_string=False, arg_value=2)]), InstructionDisassembled(instruction='Mod', arguments=[InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=1), InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=1), InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=0)]), InstructionDisassembled(instruction='LoadConstZero', arguments=[InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=0)]), InstructionDisassembled(instruction='StrictEq', arguments=[InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=0), InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=1), InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=0)]), InstructionDisassembled(instruction='Ret', arguments=[InstructionArgumentDisassembled(arg_type='Reg8', is_string=False, arg_value=0)])], header={'offset': 422, 'paramCount': 2, 'bytecodeSizeInBytes': 18, 'functionName': 5, 'infoOffset': 464, 'frameSize': 2, 'environmentSize': 0, 'highestReadCacheIndex': 0, 'highestWriteCacheIndex': 0, 'flags': 18})
Program patched! Run patched.hbc now!

$ hermes patched.hbc
Is user 0 premium? true
Is user 1 premium? true
```

While text-based patching is feasible with very simple programs, it quickly
gets overwhelming with bigger programs. The programmatic way, while more
complex to start with, also offers much greater flexibility.


## Automating Kindle patches

So far I have been talking about Hermes bytecode and how to patch it by
showing some simple JavaScript applications. The Kindle's homepage app, KPP—we
think it stands for Kindle Plus Plus—also uses React Native and Hermes
bytecode. This is where [KPP_Patch][] comes in.

Right now it offers a small set of patches, as creating patches for the Kindle
is quite involved. I would like to change this however, so this article also
serves as reference on how to go about locating annoyances in the Kindle
homepage app, and how to patch them out.


### Locating an annoyance

I really want to get rid of the annoying ad shelves on my home page, those
_Discover Books_, _New Releases in Kindle Store_, etc. There is already a
patch to do so, `patch_homepage`, but it won't work on my Kindle Paperwhite
11th-generation. So I will walk you through the discovery and implementation
of a new patch that removes this annoyance on my older Kindle.

First off, disassemble and just look for these strings:

```sh
$ hbctool disasm KPPMainApp.js.hbc temp_pw5_homepage
[*] Disassemble 'KPPMainApp.js.hbc' to 'temp_pw5_homepage' path
[*] Hermes Bytecode [ Source Hash: fb8307cef3406b6566e7e50a52b1b8f2e5b1fcda, HBC Version: 84 ]
[*] Done

$ rg -i 'Discover Books' temp_pw5_homepage/.
```

No luck. Probably because these are localised strings, so we would need to
know what the identifier is. Let us try some related words then:

```sh
$ rg -i 'discover' temp_pw5_homepage/.
temp_pw5_homepage/./string.json
12715:        "value": "app://com.lab126.booklet.discovery"
44115:        "value": "com.lab126.booklet.discovery"
60700:        "value": "DISCOVERY"

temp_pw5_homepage/./instruction.hasm
473605:	; Oper[3]: String(12139) 'DISCOVERY'
473678:	; Oper[3]: String(12139) 'DISCOVERY'
474310:	; Oper[3]: String(12139) 'DISCOVERY'
474313:	; Oper[1]: String(12139) 'DISCOVERY'
515280:	; Oper[3]: String(12139) 'DISCOVERY'
```

There is _something_ about discovery, but at this point I am unsure if it is
even what I am looking for. When I get to this stage, I tend to just rely on
[screenControl][]. This is a remote screen control utility, that also hooks
into the Kindle's accessibility layer, so we can see some of the strings and
identifiers for the UI.

The instructions are already written down in the Archive page.
[Direct download is here][screenControl download].

{{< figure
	src="./screencontrol-intro.webp"
	alt="Screenshot of the screenControl utility to access accessibility data"
	caption="The utility is very janky, but it works"
>}}

Once you run `screenControl` in the Kindle, and connect to the provided
IP/port through your browser, you can click on the _KIWI_ checkbox at the top
to enable the accessibility data.

On my setup, the UI is huge. You might want to zoom out in your browser to get
a decent view of the Kindle screen.
{ class = "aside" }

Here, the accessibility data is not giving us much. `value` is
`Discover Books`, which we knew already, we can see it. But the `name` looks
interesting. The whole name will likely not show up in the bytecode, as it
just has a seemingly random UUID in the middle, but perhaps some of the prefix
or suffix will show up in the bytecode:

```sh
$ rg -i 'Card_496efea0-8867-4b1d-bdfc-c28a6646f599_template_49_header_text' temp_pw5_homepage/.

$ rg -i 'template_49' temp_pw5_homepage/.
temp_pw5_homepage/./string.json
26465:        "value": "_template_49_recommended_asin_"
26985:        "value": "_template_49_category_"
26990:        "value": "_template_49_category_container"
26995:        "value": "_template_49_category_pagination_widget-"
27000:        "value": "_template_49_category_text"
27015:        "value": "_template_49_header"
27020:        "value": "_template_49_header_text"
27030:        "value": "_template_49_recommendations"
27035:        "value": "_template_49_recommendations_pagination_widget"

temp_pw5_homepage/./instruction.hasm
373251:	; Oper[1]: String(5397) '_template_49_category_container'
373534:	; Oper[1]: String(5396) '_template_49_category_'
373621:	; Oper[1]: String(5399) '_template_49_category_text'
373672:	; Oper[1]: String(5396) '_template_49_category_'
373755:	; Oper[1]: String(5399) '_template_49_category_text'
373854:	; Oper[1]: String(5292) '_template_49_recommended_asin_'
374368:	; Oper[1]: String(5398) '_template_49_category_pagination_widget-'
374503:	; Oper[1]: String(5405) '_template_49_recommendations'
374569:	; Oper[1]: String(5406) '_template_49_recommendations_pagination_widget'
375057:	; Oper[1]: String(5402) '_template_49_header'
375113:	; Oper[1]: String(5403) '_template_49_header_text'
```

And that is indeed the case. We can then look at the lines that `ripgrep`
found for us in the `instruction.hasm` file, see if the functions that contain
these strings are named, and if they have any interesting names.

{{< figure
	src="./template49-render-function.webp"
	alt="Finding _template_49_header_text inside a function called render in the assembly"
	caption="Many lines folded for brevity"
>}}

There is a `render` function that ends up putting this text in the screen.
Meaning there is probably a function or class for this whole thing, to which
this `render` is a method for. That `Template49Card` seems like the kind of
PascalCase I would expect for classes, so let us search for it:

{{< figure
	src="./function-for-all-cards.webp"
	alt="Function in bytecode that fetches a lot of Template Cards"
	caption="Lines again folded for brevity"
>}}

Here we find a very interesting function. It has no name, but it seems to be
loading all kinds of cards, so perhaps it was using a loop in the original
code. From here we also notice another interesting thing: while there is the
`Template49Card` string we were looking for, there is also another
`Template49` string. What could this be?

{{< figure
	src="./template49-function.webp"
	alt="Function in bytecode for Template49"
	caption="You know the drill"
>}}

Turns out there is a whole function for it. Judging by the instruction order
on the previous anonymous function we found, it might be loading
`Template49Card`, and then calling the `Template49` function with that as an
argument.

My initial attempt was to patch out this `Template49` function and make it
return `False`. Basically, we take all the existing instructions of the
function body, and replace them with `LoadConstFalse Reg8:0` and `Ret Reg:0`.
I tried a few different variations of this, returning `null`, `undefined`, and
a few other such falsy constants. But none of them worked on my PW5 with Soft
Float (`< 5.16.3`) firmware.

{{< figure
	src="./bad-patch-whitescreen.webp"
	alt="Kindle homepage showing a white screen after a non-working patch"
	caption="It just causes a literal white screen homepage"
>}}


### Trying a different approach

Patching the `Template49` function directly is clearly not working. But there
is that one `render` function I found, what happens if I patch that?

```python
# Card 49 (Discover Books Shelf) render function

# Patching Template49 directly does NOT work, causes a white screen
# result = khbc.patch_func(name="Template49", patch=ALWAYS_FALSE)

result = khbc.patch_func_by_id(fid=6871, patch=ALWAYS_FALSE)
if not result:
    raise PatchError("Patching Card49 render function failed!")
```

{{< figure
	src="./template49-render-patched.webp"
	alt="Kindle homepage with the Discover Books shelf hidden"
	caption="It works!"
>}}

You might have noticed here I am hardcoding the function ID rather than
searching the function by name. It will be addressed in the next section.
{ class = "aside" }


### Going down the chain

This approach means we need to look at the assembly, figure out exactly what
each shelf is, what their related render code is, and then target specifically
those functions. Repeating the previous `screenControl` and `KIWI` steps, I
can see the next annoyance, _Top Reads With Prime_, is Card 18:

{{< figure
	src="./screencontrol-card18.webp"
	alt="Using screenControl to figure out the card ID of the Top Reads With Prime shelf"
>}}

If I then go look at the assembly code, and search for `Template18`, or
`Template18Card`, I can find both a `Template18` function, as well as another
`render` function that uses `Template18`:

{{< figure
	src="./template18-functions.webp"
	alt="Template18 and its render function in the disassembled code"
	caption="Same thing as with Card 49"
>}}

Here we already run into the first issue. Relying on function IDs is a bad
idea. Even if we assume these functions will still exist in newer firmware
versions, the order might not be the same, and so the ID would change. A naive
approach is to just rely on function names, so first we locate the function by
name, and then we operate on the ID attached to that name.

But what about when multiple functions have the same name? How do we figure
out which one of the many `render` function is the specific one used in Card
49, or Card 18? For now, I will just hardcode the specific function IDs and we
will come back to this:

```python
# Card 49 (Discover Books Shelf) render function

# Patching Template49 directly does NOT work, causes a white screen
# result = khbc.patch_func(name="Template49", patch=ALWAYS_FALSE)

result = khbc.patch_func_by_id(fid=6871, patch=ALWAYS_FALSE)
if not result:
    raise PatchError("Patching Card49 render function failed!")

# Card 18 (Multiple "with/in Prime" shelves) render function

# Patching Template18 directly does NOT work, also causes a white screen
# result = khbc.patch_func(name="Template18", patch=ALWAYS_FALSE)

result = khbc.patch_func_by_id(fid=6799, patch=ALWAYS_FALSE)
if not result:
    raise PatchError("Patching Card18 render function failed!")
```

{{< figure
	src="./kindle-cards-49-and-18-patched.webp"
	alt="Kindle PW5 homepage with cards 49 and 18 patched out"
	caption="Two down, however many to go"
>}}


### Yet more problems

I will spare you the tedious of going through `screenControl` and finding the
rest of the cards. What remains are Cards 5, 2, and 13. So then it is just a
matter of finding the relevant `render` functions, patching those out, and all
the ad shelves should be gone.

Turns out, these specific cards don't have `render` functions. There are still
`Template5`, `Template2` and `Template13` functions, and patching those out
directly works for these card shelves, unlike `Template49` and `Template18`.
Why this is, I know not enough React to tell. Perhaps there was a `render`
function but it got unrolled into these functions by Hermes. A React developer
might have a better idea.

```python
# Card 49 (Discover Books Shelf) render function
result = khbc.patch_func_by_id(fid=6871, patch=ALWAYS_FALSE)
if not result:
    raise PatchError("Patching Card49 render function failed!")

# Card 18 (Multiple "with/in Prime" shelves) render function
result = khbc.patch_func_by_id(fid=6799, patch=ALWAYS_FALSE)
if not result:
    raise PatchError("Patching Card18 render function failed!")

# "New Releases In Kindle Store" & "Best Sellers included with Prime" shelves
result = khbc.patch_func(name="Template5", patch=ALWAYS_FALSE)
if not result:
    raise PatchError("Patching Template5 function failed!")

# "Easily Add Titles To Your Kindle Library" shelf
result = khbc.patch_func(name="Template2", patch=ALWAYS_FALSE)
if not result:
    raise PatchError("Patching Template2 function failed!")

# "Try Unlimited Reading & Listening" shelf
result = khbc.patch_func(name="Template13", patch=ALWAYS_FALSE)
if not result:
    raise PatchError("Patching Template13 function failed!")
```

{{< figure
	src="./kpw5-homepage-ad-free.webp"
	alt="Kindle PW5 homepage without ad shelves"
	caption="All this effort to get rid of ads on a device I already paid money for"
>}}


### Another (still very naive) find function approach

A good solution would be something like the [Levenshtein distance][], but I am
too lazy to code it myself, and too stubborn to add a dependency for it. A
dumber implementation could be to just get all the `render` functions, and
then check certain strings are used within that function. Which is exactly
what I did:

```python
# Defined in hbctool.hbc, here as reference
class InstructionArgumentDisassembled(NamedTuple):
    arg_type: str
    is_string: bool
    arg_value: int


class InstructionDisassembled(NamedTuple):
    instruction: str
    arguments: list[InstructionArgumentDisassembled]


class FunctionDisassembled(NamedTuple):
    name: str
    param_count: int
    register_count: int
    symbol_count: int
    instructions: list[InstructionDisassembled]
    header: FunctionHeader


def are_sids_used_in_func(
    sids: list[int], func: hbc.FunctionDisassembled
) -> bool:
    seen = {sid: False for sid in sids}
    for inst in func.instructions:
        for argument in inst.arguments:
            if not argument.is_string:
                continue

            sid = argument.arg_value
            if sid not in seen:
                continue

            seen[sid] = True

    return all(seen.values())


card18_render_strings = [
    "Template18Card",
    "Template18Container",
    "Template18Title",
    "Template18Content",
]
card18_sids: list[int] = []

for string in card18_render_strings:
    sid = khbc.find_string(string)
    if sid == -1:
        raise PatchError(f"{base_err} Couldn't find string {string}!")
    card18_sids.append(sid)

all_render_functions = khbc.find_all_funcs_by_name(name="render", disasm=True)
for fid, func in all_render_functions:
    if khbc.are_sids_used_in_func(sids=card18_sids, func=func):
        card18_render_fid = fid

if not card18_render_fid:
    raise PatchError(f"{base_err} Failed to find Card18 render function!")
```

This is just joined excerpts, slightly edited so the flow is straightforward
to follow. If you want to see the actual code, you can check
[the implementation in KPP_Patch][patch_homepage_sf]. This approach—although
unsofisticated—works quite well to find the relevant `render` functions.


## Looking forward

I have only just scratched the surface of Hermes bytecode, but I am hoping it
will be a good resource for those interested in learning more about it. At the
very least, it could help someone wanting to create and contribute new patches
for the Kindle homepage.

With this homepage patch, plus the existing
`patch_collection_not_synced_popup` patch I contributed a while back, I solved
the things that annoyed me personally, so I might not be writing any more
patches.

That being said, I am a maintainer for [KPP_Patch][], so I will be there
reviewing and merging any PRs that show up. Even if I don't write any more
patches, I would like to go a bit deeper into Hermes bytecode. Perhaps I will
write another article at some point.



[New Homepage Article]: https://blog.the-ebook-reader.com/2022/02/09/kindle-software-update-5-14-2-released/
[React Native]: https://reactnative.dev/
[JBPatch]: https://wiki.mobileread.com/wiki/JBPatch
[hexpwn]: https://github.com/hexpwn
[Marek]: https://github.com/notmarek
[KPP_Patch]: https://github.com/KindleModding/KPP_Patch
[Community React Native platforms]: https://reactnative.dev/docs/next/out-of-tree-platforms
[React Native Skia]: https://github.com/react-native-skia/react-native-skia
[Lukas1h]: https://github.com/Lukas1h
[react-native-kindle]: https://github.com/Lukas1h/react-native-kindle
[Hermes]: https://engineering.fb.com/2019/07/12/android/hermes/
[React Native 0.70 announcement]: https://reactnative.dev/blog/2022/07/08/hermes-as-the-default
[Hermes bytecode v99]: https://github.com/facebook/hermes/blob/c6aa644f6c2768bbf8753e621c48c24fb5183a0d/include/hermes/BCGen/HBC/BytecodeVersion.h#L23
[Hermes build instructions]: https://github.com/facebook/hermes/blob/c6aa644f6c2768bbf8753e621c48c24fb5183a0d/doc/BuildingAndRunning.md
[Hermes v0.11.0]: https://github.com/facebook/hermes/blob/v0.11.0/include/hermes/BCGen/HBC/BytecodeVersion.h
[Hermes v0.11.0 build instructions]: https://github.com/facebook/hermes/blob/v0.11.0/doc/BuildingAndRunning.md
[hermes_84-nix]: https://github.com/Sighery/hermes_84-nix
[JSI]: https://dev.to/samuel_onireti_0e7ea18c79/cracking-open-the-magic-of-react-native-c-for-jsi-bindings-17i4
[Hermes current ECMAScript support]: https://github.com/facebook/hermes/blob/c6aa644f6c2768bbf8753e621c48c24fb5183a0d/doc/Features.md
[hermes-dec]: https://github.com/P1sec/hermes-dec/
[P1 Security]: https://www.p1sec.com/
[bongtrop/hbctool]: https://github.com/bongtrop/hbctool
[Sighery/hbctool]: https://github.com/Sighery/hbctool
[Hermes opcodes]: https://p1sec.github.io/hermes-dec/opcodes_table.html
[hbctool v84 branch]: https://github.com/bongtrop/hbctool/tree/add-hbc-83-89-and-improve-contribution
[KPP_Patch pyproject.toml]: https://github.com/KindleModding/KPP_Patch/blob/0ce89441732103f97aee66210d5a16a377f688cc/pyproject.toml#L18
[hbctool API]: https://github.com/Sighery/hbctool/blob/8f9bd718445abc4d1068f9cf9702f79f090fc74b/hbctool/hbc/hbcbase/__init__.py
[hbctool API getFunction]: https://github.com/Sighery/hbctool/blob/8f9bd718445abc4d1068f9cf9702f79f090fc74b/hbctool/hbc/hbc84/__init__.py#L55-L90
[screenControl]: https://archive.org/details/kindle-screenControl
[screenControl download]: https://archive.org/download/kindle-screenControl/screenControl.tar.gz
[Levenshtein distance]: https://en.wikipedia.org/wiki/Levenshtein_distance
[patch_homepage_sf]: https://github.com/KindleModding/KPP_Patch/blob/0ce89441732103f97aee66210d5a16a377f688cc/src/patcher/patches.py#L86-L171
