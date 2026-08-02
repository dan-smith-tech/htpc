# Home Theatre PC

## Overview

[My homelab server](https://github.com/dan-smith-tech/homelab) hosts services that run 24/7 on the machine. On the same machine, when I press a button in Home Assistant, it will turn on the TV and needs to boot the homelab into a barebones Plasma session where the media watching player will operate. Then when the power off button is pressed in Home Assistant, all GUI sessions and anything related to media watching must be fully shut down to save on resources an energy consumption. The specific requirements are the following:

- Home Assistant dashboard with:
  - Power on/off (which will activate both an IR blaster for the TV as well as causes the media GUI session to start/stop).
  - Up/Down/Left/Right buttons to navigate video selections.
  - Enter button to select videos.
  - Shortcuts for YouTube and Netflix.
- Plasma session
  - When the media player service is activated (see the Home Assistant interface section above), a minimal Plasma session must start on the server so that it renders on the display conencted with HDMI to the homelab server.
  - When the media player is turned off (see the Home Assistant interface section above), the Plasma session and any services/software associated with with watching media is fully terminated to save on resources and electricity.
  - The plasma session should not have anything installed/loaded that isn't essential:
    - We do not need the typical drag n' drop if possible;
    - No taskbar;
    - No software outside of libraries/packages required for media viewing.
- Brave player
  - All media applications (YouTube and Netflix) should be accessed and viewed through Brave.
  - We do not need the standard Brave interface with the title bar (url field, bookmarks, tabs, etc.) - we can likely just launch in the kiosk type mode with just the site we want.
  - When a different media player is launched (such as YouTube when Netflix is launched, and vice versa - see the Home Assistant interface section above) it should fully close the previous and open the new one (i.e., not a new tab, but replacement).
  - We need some kind of Brave wrapper (or potentially plugin - which ever is the most robust) that allows for smooth navigation with the navigation buttons detailed in the Home Assistant interface section above, so for example in YouTube a clean way of - on the Subscriptions page (the reccomended will be blocked) - navigating up, down, left, and right on the grid of displayed videos, with the ability to then press enter on the highlighted one. Then the same for Netflix of course.
  - When the Plasma session is open it should either just be a fullscreen YouTube or Netflix page, never the desktop, or any minimised other software. It should just look like a YouTube or Netflix app.
- Home Assistant interface between the HAOS running on the server (see [README](../README.md) and [configure](../configure.sh)) and the media player Plasma session that does the following:
  - Allows the UI described in the Home Assistant dashboard described above to talk to the Plasma session and carry out the actions;
  - Turn on and off the media player / Plasma session with required software etc. as described above
  - Reports when media is playing on YouTube or Netflix or not - a live always-up-to-date state (to be used in other Home Assistant automations)

## Setup

Install dependencies:

```bash
sudo pacman -S qemu virt-install virt-viewer dnsmasq
```

Add user to the virtualisation daemon group so root isn't needed to run it:

```bash
sudo usermod -aG libvirt "$USER"
```

## Installation

Run the installation script to create and prepare the VM:

```bash
bash install.sh
```

This enables libvirt, sets up an isolated NAT network for the VM, downloads the Arch Linux ISO, creates a disk image, and registers the VM.

## Booting the VM

Start the VM (it will boot from the installation ISO):

```bash
sudo virsh start htpcos
```

Connect to the VNC display to complete the Arch Linux installation:

```bash
vncviewer "$(virsh vncdisplay htpcos)"
```

Once installed, shutdown and reconfigure the VM to boot from disk instead of the ISO:

```bash
sudo virsh destroy htpcos
sudo virsh edit htpcos  # remove the <boot dev='cdrom'/> line or change order
sudo virsh start htpcos
```
