---
title: "Configuring QMK firmware for your keyboard"
description: "Configuring the open-source keyboard firmware QMK on NixOS"
pubDate: "2024-07-23"
tags:
  - Tutorial
  - NixOS
  - Keyboards
---

Configuring QMK on linux is very easy, especially on NixOS. Here is a short guide showing the steps required to do so. As always, it's a good idea to read [the documentation](https://docs.qmk.fm/). This is just some of the snippets i found the most useful and a quick-start guide.

## Creating a fork

To configure your own keymaps, you need a fork of QMK. Head to [qmk/qmk_firmware](https://github.com/qmk/qmk_firmware) and create a fork, in my case called `LilleAila/qmk_firmware`, then clone it to your local machine and set up the upstream remote:

```bash
git clone git@github.com:LilleAila/qmk_firmware ~/qmk_firmware
cd ~/qmk_firmware
git remote add upstream https://github.com/qmk/qmk_firmware
git fetch upstream
git push -u origin master
```

## Setting up your environment

QMK requires some udev rules, which can be enabled in your NixOS configuration using

```nix
hardware.keyboard.qmk.enable = true;
```

Additionally, QMK provides a nix-shell, so all you need to do is use the included `shell.nix`, for example with direnv

```bash
echo "use nix" > .envrc && direnv allow
```

Now, run the following command to fetch all submodules and dependencies required by QMK.

```bash
qmk setup
```

That's it. Now you have a fully working environment for configuring your QMK keymaps. Keep reading if you want to learn how to keep it up to date and create your own keymap.

## Keeping your fork updated

You want to occasionally rebase your fork on `qmk/qmk_firmware` so that it stays up to date. To do that, run the following commands:

```bash
git fetch upstream
git merge upstream/master
git push
```

If you run into problems when compiling, you might have to run `qmk setup` again.

## Compiling and flashing a keyboard

Use the `qmk` command to compile a keymap for your keyboard. Replace `beekeeb/piantor_pro` with your keyboard, and `default` with your keymap.

```bash
qmk compile -kb beekeeb/piantor_pro -km default
```

The keyboard can also be flashed directly, using this command:

```bash
qmk flash -kb beekeeb/piantor_pro -km default
```

Make sure your keyboard is in DFU mode. There is usually a button somewhere on the keyboard, or you can use the `QK_BOOK` key.

## Adding your own keymap

Locate your keyboard in `keyboards/`, and create your own keymap in a subfolder with the name you want to give it. In my case, i used my name at `keyboards/beekeeb/piantor_pro/keymaps/olai/`. It can be beneficial to copy the default layout of your keyboard, then make the changes you want. The important files here are `keymap.c`, which is where you define your keymap, and `rules.mk`, which has extra settings.

### Keymap syntax

Keymaps are usually defined at the end of the file, using syntax similar to this:

```c
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [0] = LAYOUT_split_3x6_3( // split with 6 columns of 3 keys, plus 3 at the thump
        // First layer (default)
    ),
    [1] = LAYOUT_split_3x6_3(
        // Other layers
    )
}
```

Keys are under the `KC_` prefix, for example

```c
KC_A
KC_B
KC_C
KC_TAB
KC_LCTL
```

Home-row modifiers allow you to press the key regularly, but act as a modifier when held. They can be used like this:

```c
CTL_T(KC_A), OPT_T(KC_R), GUI_T(KC_S), SFT_T(KC_T)
```

Layers can be named using an enum, like this:

```c
enum layers {
    _MAIN,
    _QWERTY,
    _FN
}
```

The first layer in the enum becomes the default layout, and the names can be used instead of integers, like this:

```c
const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [_MAIN] = LAYOUT_split_3x6_3(),
    [_QWERTY] = LAYOUT_split_3x6_3(),
    [_FN] = LAYOUT_split_3x6_3()
}
```

Layers can be switched to when held using `MO(_FN)`, and set to default using `DF(_QWERTY)`. Layers should generally be in an order such that the main keyboard layout with alphabetical keys is the lowest, and layers stacked on top of it are higher.

### Auto-detection of operating system

MacOS uses a different layout than other systems, so a snippet like this can be used. Add this to `rules.mk`:

```mk
OS_DETECTION_ENABLE = yes
DEFERRED_EXEC_ENABLE = yes
```

And add this to `keymap.c`:

```c
#if defined(OS_DETECTION_ENABLE) && defined(DEFERRED_EXEC_ENABLE)
#include "os_detection.h"
os_variant_t os_type;

uint32_t detect_os(uint32_t trigger_time, void *cb_arg) {
    if (is_keyboard_master()) {
        os_type = detected_host_os();
        if (os_type) {
            switch (os_type) {
                case OS_MACOS:
                    layer_move(_MAIN_MAC);
                    break;
                case OS_IOS:
                    layer_move(_MAIN_MAC);
                    break;
                case OS_LINUX:
                    layer_move(_MAIN_LINUX);
                    break;
                case OS_WINDOWS:
                    layer_move(_MAIN_WINDOWS);
                    break;
                case OS_UNSURE:
                    layer_move(_MAIN_LINUX);
                    break;
                default:
                    layer_move(_MAIN_LINUX);
                    break;
            }
        }
    }

    return os_type ? 0 : 500;
}

void keyboard_post_init_user(void) {
    defer_exec(100, detect_os, NULL);
}
#endif
```

Linux and windows generally use the same layouts, so that can be used as the default if MacOS was not detected.
