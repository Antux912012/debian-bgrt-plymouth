# Debian BGRT Plymouth Boot Theme (Fedora Style)

[![Debian](https://img.shields.io/badge/Debian-Forky%20%7C%20Trixie%20%7C%20Bookworm-D70A53?logo=debian&logoColor=white)](https://www.debian.org)
[![Plymouth](https://img.shields.io/badge/Plymouth-BGRT%20Theme-blue?logo=linux&logoColor=white)](https://gitlab.freedesktop.org/plymouth/plymouth)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Status: Experimental](https://img.shields.io/badge/Status-Experimental-orange.svg)](#-experimental-status--disclaimer-of-liability)

Bring the seamless, flicker-free **Fedora boot experience** to **Debian**:
1. Displays your computer manufacturer logo (Lenovo, Dell, HP, ASUS, Acer, Framework, etc.) preserved from the **UEFI ACPI BGRT** table.
2. Smooth spinner loader animation directly below the OEM logo.
3. At the bottom center, the colored **Debian logo** taken from the [**Papirus Icon Theme**](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme).
4. **Seamless, Silent Boot Transition:** Suppresses GRUB menu flicker, hides `"Loading Linux..."` text, disables console blinking cursors, and enables Early KMS for zero-flicker graphics handover.
5. Includes full **one-command rollback/revert** to restore your original Debian theme and boot configuration at any time.

---

> [!WARNING]
> ### ⚠️ EXPERIMENTAL STATUS & DISCLAIMER OF LIABILITY
>
> **Please read carefully before using this software:**
>
> 1. **Experimental Software:** This repository and the included scripts modify core system startup assets, Plymouth configuration files, GRUB boot loader settings, and rebuild the initial RAM file system (`initramfs`). This software is provided in an **experimental status**.
> 2. **No Warranty / Use at Your Own Risk:** The software is provided **"AS IS"**, without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement.
> 3. **Non-Liability for Damages:** Under no circumstances shall the author(s), maintainer(s) (including **Antonio De Gaetano / @Antux912012**), or contributors be held liable for any claim, loss, or damages whatsoever—including but not limited to direct, indirect, incidental, special, punitive, or consequential damages, system inoperability, boot failures, data corruption, hardware issues, or downtime—arising out of or in connection with the use, misuse, or execution of this script or associated theme files.
> 4. **Prudence:** Always ensure you have backups of important data and know how to boot into your system's recovery mode or kernel fallback options before applying modifications to the boot splash or initramfs.

---

## 🎨 Watermark Variants

| Variant | Preview | Description |
| :--- | :---: | :--- |
| **`text`** *(Default)* | `[ Papirus Badge ] debian` | **Fedora style:** Papirus circular Debian badge + white `debian` typography (`180x48px`). |
| **`badge`** | `[ Papirus Badge ]` | **Minimalist:** The iconic Papirus circular badge alone (`64x64px`). |
| **`swirl`** | `[ Debian Swirl ]` | **Swirl only:** Standalone Debian swirl path colored in Papirus `#f9548f` (`64x64px`). |

---

## ⚡ Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/Antux912012/debian-bgrt-plymouth.git
cd debian-bgrt-plymouth
```

### 2. Apply the theme & seamless boot

Apply the default Fedora-style theme (`text`) with silent boot:

```bash
sudo ./install.sh
```

Or choose a specific watermark variant:

```bash
# Minimalist badge alone
sudo ./install.sh badge

# Standalone swirl alone
sudo ./install.sh swirl
```

The script will automatically:
* Back up your current Plymouth theme and any existing watermarks to `/var/lib/plymouth-debian-bgrt/state.env`.
* Copy the selected watermark into Plymouth's theme directories (`spinner` & `bgrt`).
* Set Plymouth's default theme to `bgrt`.
* Configure seamless, silent boot (hiding the GRUB menu, silencing `"Loading Linux..."`, and enabling Early KMS).
* Rebuild the `initramfs` for all installed kernels (`update-initramfs -u -k all`).

Reboot your machine to enjoy a completely flicker-free boot! 🚀

---

## 🤫 Seamless Flicker-Free Boot (Fixing GRUB Loading)

By default on Debian, turning on the computer displays a text GRUB menu, prints `Loading Linux...` and `Loading initial ramdisk...`, and flashes the screen before Plymouth loads. 

This project solves all four causes of boot flicker:

| Issue | Default Debian Behavior | Our Fix |
| :--- | :--- | :--- |
| **GRUB Menu Flash** | Displays menu box / clears screen | Sets `GRUB_TIMEOUT=0` & `GRUB_TIMEOUT_STYLE=hidden` via `/etc/default/grub.d/99-bgrt-silent.cfg` |
| **Loader Text** | Prints `Loading Linux...` & `Loading initial ramdisk...` | Sets `quiet_boot="1"` in `/etc/grub.d/10_linux` |
| **Blinking Cursor** | White blinking underscore `_` in top-left | Adds `vt.global_cursor_default=0 loglevel=3 systemd.show_status=auto rd.udev.log_level=3` |
| **GPU Re-probing Flash** | Kernel resets video pipeline when GPU driver loads late | Adds your GPU driver (`i915`, `amdgpu`, etc.) to `/etc/initramfs-tools/modules` (Early KMS) |

If you already applied the theme and only want to apply the silent boot optimizations:
```bash
sudo ./debian-bgrt.sh silent-boot
```

> [!TIP]
> **Need to access GRUB?** Even with `GRUB_TIMEOUT_STYLE=hidden`, you can press or hold **`Esc`** (or `Shift`) repeatedly during power-on to show the GRUB menu whenever needed.

---

## 🔄 Reverting / Rollback

If you ever want to return to your original system status, run:

```bash
sudo ./uninstall.sh
```
*(or `sudo ./debian-bgrt.sh revert`)*

This safely:
1. Restores your original theme recorded in `/var/lib/plymouth-debian-bgrt/state.env` (e.g. `ceratopsian`, `emerald`, or your previous custom theme).
2. Restores or removes the installed watermark files.
3. Reverts all silent boot changes: removes `/etc/default/grub.d/99-bgrt-silent.cfg`, restores `/etc/grub.d/10_linux`, and restores `/etc/initramfs-tools/modules`.
4. Runs `update-grub` and rebuilds the `initramfs`.
5. Removes the backup state directory.

---

## 🔍 Checking Current Status

You can inspect whether BGRT, silent boot, and watermarks are active at any time without `sudo`:

```bash
./debian-bgrt.sh status
```

Example output:
```text
=== Plymouth Debian BGRT Status ===
Current Active Theme:    bgrt
Theme State:             Managed by debian-bgrt.sh
Original Theme:          ceratopsian
Applied Variant:         text
Applied Date:            2026-10-26T22:45:00+02:00
Spinner Watermark:       Present (/usr/share/plymouth/themes/spinner/watermark.png)
BGRT Watermark:          Present (/usr/share/plymouth/themes/bgrt/watermark.png)
GRUB Silent Drop-in:     Active (/etc/default/grub.d/99-bgrt-silent.cfg)
GRUB Loader Text:        Silenced (No 'Loading Linux...' text)
Early KMS (GPU Module):  Enabled (i915 in /etc/initramfs-tools/modules)
UEFI BGRT OEM Support:   Active & Valid (OEM logo retained during boot)
```

---

## 🛠️ How It Works

1. **Firmware BGRT Retention:**
   Modern UEFI motherboards store the OEM boot splash logo in the ACPI Boot Graphics Resource Table (`/sys/firmware/acpi/bgrt/image`). Plymouth's `two-step` module (`UseFirmwareBackground=true`) keeps this graphic on the screen throughout the kernel boot process without flicker.

2. **Watermark Alignment:**
   In Fedora, `fedora-logos` supplies `watermark.png` in `/usr/share/plymouth/themes/spinner/watermark.png`. The `bgrt.plymouth` profile positions it with:
   ```ini
   WatermarkHorizontalAlignment=.5
   WatermarkVerticalAlignment=.96
   ```
   Centering it horizontally and aligning it neatly at the bottom of the screen.

3. **Debian Integration:**
   Debian ships the exact same `bgrt` Plymouth engine, but omits a default distribution watermark. By generating the PNG asset from Papirus's SVG and installing it in `/usr/share/plymouth/themes/spinner/watermark.png`, Debian displays the identical layout to Fedora.

---

## 📋 Requirements & Recommendations

### Requirements
- **Debian** 12 (Bookworm), 13 (Trixie), or Sid/Forky
- Packages: `plymouth`, `plymouth-themes`, `initramfs-tools`
  ```bash
  sudo apt install plymouth plymouth-themes
  ```
- UEFI boot mode with ACPI BGRT support enabled in motherboard settings.

### Recommended GRUB settings (`/etc/default/grub`)
Ensure `GRUB_GFXPAYLOAD_LINUX=keep` is set to prevent GRUB from dropping the UEFI display mode:
```text
GRUB_GFXPAYLOAD_LINUX=keep
```

---

## 📜 Credits & License

- **Author / Maintainer**: [Antonio De Gaetano](https://github.com/Antux912012)
- **Debian**: [debian.org](https://www.debian.org)
- **Papirus Icon Theme**: [PapirusDevelopmentTeam](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) (GPL-3.0)
- **Plymouth**: [freedesktop.org](https://gitlab.freedesktop.org/plymouth/plymouth)
- **License**: [GNU General Public License v3.0](LICENSE)
