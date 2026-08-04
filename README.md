<body>
  <p align="center">
    <a href="https://melonx.org">
      <img src="https://git.ryujinx.app/MeloNX/MeloNX-Legacy/raw/branch/XC-ios-ht/src/MeloNX/MeloNX/Assets/Assets.xcassets/AppIcon.appiconset/nxgradientpng.png" alt="MeloNX Logo" width="120">
    </a>
  </p>

# ⚠️ Experimental Fork Notice

This repository is **not the official MeloNX project**. It is an **experimental fork** of MeloNX created to evaluate an alternative **ARMeilleure JIT virtual memory reservation strategy** on iOS.

#### **🚧 Status**

> **In Progress** 🛠️
>
> This fork is currently under active development. While the project builds successfully, the modified version of MeloNX is **not yet usable**. Several critical bugs still affect stability and functionality, and the fork should be considered **unusable in its current state**.

### What changed?

The primary modification is an experimental rework of how the JIT reserves virtual memory. Instead of attempting to reserve very large virtual memory regions during initialization, this fork attempts to reserve memory **progressively and on demand** wherever possible.

**This change does not aim to reduce the emulator's overall memory usage.** Games are expected to consume approximately the same amount of memory once running. The experiment focuses solely on changing **when and how virtual memory is reserved**.

### Purpose

The objective of this project is to determine whether progressively reserving JIT virtual memory, rather than reserving large virtual memory regions upfront, can:

- Reduce or eliminate **"Cannot allocate memory"** errors on iOS.
- Reduce allocation failures caused by large upfront virtual memory reservation requests.
- Improve our understanding of how iOS handles progressive JIT virtual memory reservation compared to large upfront reservations.

### Important

This repository is **not affiliated with or endorsed by the MeloNX developers**.

This fork was **developed with assistance from Claude AI**. While every effort has been made to review and validate the implementation, the changes may contain implementation mistakes, regressions, unexpected behavior, or compatibility issues that are **not present in the official MeloNX project**.

The modified JIT memory reservation strategy is **highly experimental** and is being tested gradually. It is **not intended to be considered a stable replacement for the official build**, and **no guarantee is made that this version will function correctly for normal day-to-day use**.

Results will vary depending on the device model, iOS version, available RAM, and enabled entitlements.

Please **do not report issues from this fork to the official MeloNX project** unless the same issue can also be reproduced on an unmodified official build.

Feedback from users testing different iPhone and iPad models is welcome, particularly regarding memory reservation failures, stability, compatibility, and any regressions introduced by this experimental implementation.

  <h1 align="center">MeloNX Progressive Memory Fork</h1>

  <p align="center">
    Experimental MeloNX fork investigating progressive JIT virtual memory reservation on iOS.
  </p>

  <p align="center">
    Based on the original MeloNX project, this fork modifies the JIT virtual memory reservation strategy while preserving the emulator's overall architecture and functionality. The project remains open-source and continues to follow the original licensing terms.
  </p>
</body>

# FAQ

#### **Where's the prod.keys file?/Where can I download \[game]?**
**We do not support piracy**, It is forbidden to request copyrighted content 
(Firmware/Games/Keys/Shaders) on our repositories or on the MeloNX Discord.

#### **Do I need a Switch to use this emulator?**
MeloNX emulator is capable of running many homebrew applications, and can be a crucial tool in the development and debugging of homebrew applications and games. To play commercial games, you will need access to a Switch compatible with custom firmware (CFW), which will enable you to dump your system firmware, keys and legally purchased games.

#### **How can I dump my firmware/games/keys?**
First, you need to hack your Nintendo Switch, which you can learn how to do here: [https://nh-server.github.io/switch-guide/](https://nh-server.github.io/switch-guide/).

Once you have hacked your Switch, backed up your keys and dumped your firmware, you may follow these guides to dump keys, updates and DLC, firmware and games:

[Keys](https://docs.ryujinx.app/guides/dumping/keys/)<br>
[Games, Updates and DLC](https://docs.ryujinx.app/guides/dumping/game-content/)<br>
[Firmware](https://docs.ryujinx.app/guides/dumping/fw/)

# Info
- A Paid Developer account or [TrollStore](https://github.com/opa334/TrollStore) may be needed for specific devices (Read about Entitlements below)
- MeloNX **REQUIRES** JIT and CANNOT run without it.
- Recommended iPhone: iPhone 15 Pro+ (8/12GB RAM both have the same memory limit of 6GB)
- Recommended iPad: iPad Pro 5th+ 128GB+ (8GB RAM) / 1TB+ (16GB RAM) or iPad Air 5+ (8GB RAM)
- Lowest Compatible Device (Paid Developer Account): iPhone 6s (iOS 15)
- Lowest Compatible Device (Free Developer Account): iPhone 12

# Entitlements

> **Entitlements** are the underlying security permissions that allow an app to access specific features of your device

MeloNX can use **2** Entitlements:

**Increased Memory Limit:**<br>
\- This allows MeloNX to be able to use the most amount of ram apple lets us.

**Extended Virtual Addressing**:<br>
\- This allows MeloNX to be able to ask iOS for more memory / RAM then actually available.<br>
\- Extended Virtual Addressing is a **PAID** entitlement, [TrollStore](https://github.com/opa334/TrollStore) also gives this entitlement.

Increased Memory Limit is required for **all devices**.

Extended Virtual Addressing is required for *specific devices* which don't allow us to ask the RAM we need without the Extended Virtual Addressing entitlement.

Those Devices include:<br>
iPads with less than 8GB of RAM.<br>
iPhones with less than 4GB of RAM.

## Discord Server
We have a discord server!
- https://discord.gg/HjCDPTpC3W

## How to install

### Recommended Guide (Plumeimpactor)

> [SideStore](https://sidestore.io/) is recommended (optional) for an on-device Sideloader, and should be installed prior performing this install.

#### **Make sure to read the FAQ and Info before continuing.**

#### 1. Sideload Application
Download and install MeloNX using [PlumeImpactor](https://github.com/claration/Impactor/releases) on a computer.
- [Download **MeloNX** From Releases](https://git.ryujinx.app/projects/MeloNX/releases)
- Open PlumeImpactor > Click Settings > Click Login
- Login with the same Apple ID you are using for SideStore (or AltStore).
- Import the MeloNX .ipa you downloaded earlier.
- Plug in your iDevice.
- Select your iDevice from the dropdown at the top of the window.
- Click Install.

#### 2. Load Into SideStore (Optional)
To have MeloNX show inside SideStore (or AltStore), You must re-install it:
- Open **SideStore** on your iDevice
- Select the **My Apps** tab > Tap the **+** button.
- Select the **MeloNX** .ipa (You may need to download it again.)
- Wait for it to Sideload, then it should show up Inside **SideStore**.
- Now You can Refresh **MeloNX** and Update it without needing a computer.

#### 4. Setup Files
- Add Encryption Keys and Firmware using the file picker inside MeloNX,
- Information for where to get these files are [here](#how-can-i-dump-my-firmwaregameskeys)

#### 5. Enable JIT
- Enable JIT using your preferred method, on iOS 26 [StikDebug](https://github.com/StephenDev0/StikDebug) is required.
  

### Paid Developer Account (Legacy)

#### **Make sure to read the FAQ and Info before continuing.**

#### 1. Sideload MeloNX
Download and install MeloNX using your preferred Apple ID (NOT CERT) sideloader:
- [Download MeloNX from Releases](https://git.ryujinx.app/projects/MeloNX/releases)

#### 2. Enable Memory Entitlement
- Visit [Apple Developer Identifiers](https://developer.apple.com/account/resources/identifiers).
- Locate **MeloNX** and enable the following entitlements:
- `Increased Memory Limit`
- `Extended Virtual Addressing`
- `Increased Debugging Memory Limit`

#### 3. Reinstall MeloNX
- Delete existing MeloNX installation
- Sideload MeloNX again
- Verify **Increased Memory Limit** is enabled in app

#### 4. Setup Files
- Add Encryption Keys and Firmware using the file picker inside MeloNX
- Information for where to get these files are [here](#how-can-i-dump-my-firmwaregameskeys)

#### 5. Enable JIT
- Enable JIT using your preferred method, on iOS 26 [StikDebug](https://github.com/StephenDev0/StikDebug) is required.

### Free Developer Account (Legacy, On-Device)

> This Guide is out of date and not recommended unless REQUIRED. Please follow the recommended guide [here](#recommended-guide-(plumeimpactor)).

> [SideStore](https://sidestore.io/) is recommended to Sideload MeloNX.

#### **Make sure to read the FAQ and Info before continuing.**

***The Entitlement App is **NOT** needed for AltStore Classic***
- You may skip Step 2 and Step 3
#### 1. Sideload Applications

Download and install both apps using your preferred **APPLE ID** sideloader:
- **MeloNX**: [Download from Releases](https://git.ryujinx.app/projects/MeloNX/releases)
- **Entitlement App**: [Download IPA](https://github.com/hugeBlack/GetMoreRam/releases/download/nightly/GetMoreRam.ipa)
#### 2. Enable Memory Entitlement

> If the Entitlement / GetMoreRam app isn't working correctly, then try the new Plumeimpactor method.
- Open the **Entitlement app** > **Settings**
- Sign in with the same Apple ID you used to Sideload MeloNX.
- Go to **App IDs** > tap **Refresh**
- Select **MeloNX** (e.g., "com.stossy11.MeloNX.XXXXXX")
- Tap **Add Increased Memory Limit**

#### 3. Reinstall MeloNX
- Delete existing MeloNX installation
- Sideload MeloNX again
- Verify **Increased Memory Limit** is enabled in app

#### 4. Setup Files
- Add Encryption Keys and Firmware using the file picker inside MeloNX
- Information for where to get these files are [here](#how-can-i-dump-my-firmwaregameskeys)

#### 5. Enable JIT
- Enable JIT using your preferred method. We recommend [StikDebug](https://apps.apple.com/us/app/stikdebug/id6744045754).

## Features

\- **Audio**<br>
Audio output is entirely supported, audio input (microphone) isn't supported.
We use C# wrappers for [OpenAL](https://openal-soft.org/), and [SDL2](https://www.libsdl.org/) & [libsoundio](http://libsound.io/) as fallbacks.


\- **CPU**<br>
The CPU emulator, ARMeilleure, emulates an ARMv8 CPU and currently has support for most 64-bit ARMv8 and some of the ARMv7 (and older) instructions, including partial 32-bit support.
It translates the ARM code to a custom IR, performs a few optimizations, and turns that into x86 code.
There are three memory manager options available depending on the user's preference, leveraging both software-based (slower) and host-mapped modes (much faster).
The fastest option (host, unchecked) is set by default.
Ryujinx also features an optional Profiled Persistent Translation Cache, which essentially caches translated functions so that they do not need to be translated every time the game loads.
The net result is a significant reduction in load times (the amount of time between launching a game and arriving at the title screen) for nearly every game.
NOTE: This feature is enabled by default, You must launch the game at least twice to the title screen or beyond before performance improvements are unlocked on the third launch!
These improvements are permanent and do not require any extra launches going forward.


\- **GPU**<br>
The GPU emulator emulates the Switch's Maxwell GPU using Metal (via MoltenVK) APIs through a custom build of Silk.NET.


\- **Input**<br>
We currently have support for keyboard, touch input, JoyCon input support, and nearly all MFI controllers.

Motion controls are natively supported in most cases, however JoyCons do not have motion support due to an iOS limitation.

Rumble is also natively supported in most cases.


\- **DLC & Modifications**<br>
MeloNX supports DLC + Game Update Add-ons.<br>
Mods (romfs, exefs, and runtime mods such as cheats) are unsupported; but may work. 


\- **Configuration**<br>
The emulator has settings for enabling or disabling logging, remapping controllers, resolution settings, Shader Cache and more.

# Notice
This project does not distribute, include, or endorse any copyrighted or pirated content. The software is provided for legitimate and lawful use.

Users are solely responsible for ensuring that any copyrighted material they use with this software (including, but not limited to, ROMs, cryptographic keys, and firmware) is obtained legally and in accordance with applicable law. The developers disclaim all responsibility for any misuse of the software or for any legal consequences resulting from the use of illegally obtained content.

Any third-party distribution of this emulator bundled with copyrighted content (including, but not limited to, ROMs, cryptographic keys, and firmware) is done without permission and is not associated with orendorsed by this project.

Nintendo Switch is a trademark of Nintendo Co., Ltd.
Nintendo is a trademark of Nintendo Co., Ltd.
Pokémon is a trademark of Nintendo/Creatures Inc./Game Freak Inc.
Animal Crossing is a trademark of Nintendo Co., Ltd.

This project is an independent, third-party work and is not affiliated with, endorsed by, or associated with Nintendo Co., Ltd., any of its subsidiaries, or any other console manufacturer or game and/or game publisher.

# License
This software is licensed under the terms of the [GPLv3 license](LICENSE.txt).

This project makes use of code authored by the libvpx project, licensed under BSD and the ffmpeg project, licensed under LGPLv3.

See [LICENSE.txt](LICENSE.txt) and [THIRDPARTY.md](distribution/legal/THIRDPARTY.md) for more details.

# Credits
- [Ryujinx](https://git.ryujinx.app/ryubing/ryujinx) the base of MeloNX (Thank you Ryubing!)
- [LibHac](https://github.com/Thealexbarney/LibHac) is used for our file-system.
- [AmiiboAPI](https://www.amiiboapi.com) is used in our Amiibo emulation.
- [ldn_mitm](https://github.com/spacemeowx2/ldn_mitm) is used for one of our available multiplayer modes.
- [ShellLink](https://github.com/securifybv/ShellLink) is used for Windows shortcut generation.