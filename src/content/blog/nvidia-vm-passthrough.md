---
title: "Setting up a virtual machine with GPU passthrough"
description: "A guide for configuring NixOS with nvidia GPU passthrough to a virtual machine in virt-manager."
pubDate: "2024-07-02"
tags:
  - Tutorial
  - NixOS
---

In this guide, I will show you how to configure a virtual machine on NixOS, with good performance and passing through a discrete nvidia gpu in a dual gpu system.

## Configuring your system

Firstly, you need to enable the tools that are used for virtualisation. Check in your computer's UEFI settings that hardware virtualisation is enabled. This setting can have different names depending on your motherboard, but is often called something similar to "Intel VT-X" "Intel VT-D", "AMD-SVM" or "AMD-IOMMU". You can run the following command to verify that it is enabled:

```
dmesg | grep -i -e DMAR -e IOMMU
```

Afterwards, add this snippet to your NixOS configuration:

```nix
virtualisation.libvirtd = {
    enable = true;
    qemu.ovmf.enable = true;
    onBoot = "ignore";
    onShutdown = "shutdown";
};

users.users.your-username.extraGroups = [ "libvirtd" ];
environment.systemPackages = [ pkgs.virt-manager ];

boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
];
```

## Locate your GPU

After building and rebooting, you can use this script from [the arch wiki](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF) to list your IOMMU groups.

```bash
#!/usr/bin/env bash
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```

From the output of this script, locate your GPU. Ideally, you want your GPU to be the only item in its group. In my case, i was not so lucky. This was the relevant output when running the script on my computer:

```
IOMMU Group 2:
    00:01.0 PCI bridge [0604]: Intel Corporation 6th-10th Gen Core Processor PCIe Controller (x16) [8086:1901] (rev 07)
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU106M [GeForce RTX 2060 Mobile] [10de:1f11] (rev a1)
    01:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:10f9] (rev a1)
    01:00.2 USB controller [0c03]: NVIDIA Corporation TU106 USB 3.1 Host Controller [10de:1ada] (rev a1)
    01:00.3 Serial bus controller [0c80]: NVIDIA Corporation TU106 USB Type-C UCSI Controller [10de:1adb] (rev a1)
```

Fortunately, there is a way to separate the devices into more groups, using the zen kernel and some kernel parameters. Add the following to your NixOS configuration if that is the case

```nix
boot.kernelPackages = pkgs.linuxPackages_zen;
boot.kernelParams = [
    "pcie_acs_override=downstream,multifunction"
];
```

Keep in mind that this is only necessary if the GPU was not already in a separate IOMMU group. After adding that, this was my output:

```
IOMMU Group 15:
    01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU106M [GeForce RTX 2060 Mobile] [10de:1f11] (rev a1)
IOMMU Group 16:
    01:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:10f9] (rev a1)
```

Now, the devices i'm planning to pass through are in their own IOMMU groups, which is important, because i must pass through the entire group. Take a note of the device IDs between the `[]`, because you're going to need it later.

## Pass through the devices

Make sure nvidia drivers are not enabled in your configuration, and add this to your configuration:

```nix
let
    devices = [
        "10de:1f11" # Nvidia 2060 mobile GPU
        "10de:10f9" # Nvidia audio controller
    ];
in {
    # Make the devices bind to VFIO
    boot.kernelParams = [
        "vfio-pci.ids=${lib.concatStringsSep "," devices}"
    ];
    boot.initrd.kernelModules = [
        "vfio_pci"
        "vfio"
        "vfio_iommu_type1"
    ];

    # Blacklist the nvidia drivers to make sure they don't get loaded
    boot.extraModprobeConfig = ''
        softdep nvidia pre: vfio-pci
        softdep drm pre: vfio-pci
        softdep nouveau pre: vfio-pci
    '';
    boot.blacklistedKernelModules = [
        "nouveau"
        "nvidia"
        "nvidia_drm"
        "nvidia_modeset"
        "i2c_nvidia_gpu"
    ];
    virtualisation.spiceUSBRedirection.enable = true;
}
```

[Here](https://github.com/LilleAila/dotfiles/blob/644ec8094f67dc61291910ef44a112c857d531e9/nixosModules/virtualisation.nix) is my own full configuration. Once you've done this and rebooted once again, you should be ready to set up the virtual machine!

## Setting up the virtual machine

It is possible to install any operatig system in the virtual machine, but for this guide, I will be focusing on windows, specifically windows 10. Downloads the ISO from [microsoft](https://www.microsoft.com/en-us/software-download/windows10ISO). Then, open `virt-manager` and create a new VM.

Follow the prompts, and check `Customize configuration before install`. From here, go to the `CPUs` tab, check `Manually set CPU topology`, and make sure you only have a single socket configured. For my computer with 4 cores / 8 threads, i gave the VM the following;

```
Sockets: 1
Cores: 6
Threads: 1
```

You also have to set the firmwate in the `Overview` section to `UEFI`. Once booted, install windows and find the drivers for your GPU, and the [looking glass host](https://looking-glass.io/downloads). You also want to install [virtio drivers](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.240-1/), [SPICE guest tools](https://www.spice-space.org/download.html#windows-binaries), and a [Virtual display](https://github.com/itsmikethetech/Virtual-Display-Driver).

## Set up looking glass

Looking glass is a program that functions similarly to a remote desktop program. It captures the video from your virtual machine, and shows it in a client application. To configure it, add the following to your NixOS configuration:

```nix
environment.systemPackages = [ pkgs.looking-glass-client ];
systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 ${config.settings.user.name} libvirtd -"
];
```

Then, follow the steps described in the [installation guide](https://looking-glass.io/docs/B6/install/). To summarize, you want to open the XML tab in `virt-manager` (after enabling it under `Edit > Preferences`), then do the following:

- Set the video model to `"none"`
- Remove `<input type='tablet'/>`, if it exists
- Create `<input type='mouse' bus='virtio'/>`, if it's missing
- Create `<input type='keyboard' bus='virtio'/>`, if it's missing
- Add these snippets:

```xml
<shmem name='looking-glass'>
  <model type='ivshmem-plain'/>
  <size unit='M'>32</size>
</shmem>
```

```xml
<sound model='ich9'>
  <audio id='1'/>
</sound>
<audio id='1' type='spice'/>
```

```xml
<channel type="spicevmc">
  <target type="virtio" name="com.redhat.spice.0"/>
  <address type="virtio-serial" controller="0" bus="0" port="1"/>
</channel>
```

## Final setup

Press `Add Hardware`, then choose `PCI Host Device`, and choose the GPU you want to pass through. Do the same for any other hardware you want to pass through.

If everything is set up correctly, you should now be able to start the virtual machine and open the looking glass client to use your virtual machine. For installing apps, i recommend using the [ctt windows utility](https://christitus.com/windows-tool/), by running the following command from an administrator PowerShell prompt: `iwr -useb https://christitus.com/win | iex`.
