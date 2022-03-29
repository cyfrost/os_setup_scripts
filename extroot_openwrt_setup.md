### Extroot setup guide for USB-Enabled OpenWrt devices

Prior reading: https://openwrt.org/docs/guide-user/additional-software/extroot_configuration
Additional readings:
1. https://gist.github.com/nikescar/87469582f68a635b596420d2301f34d2
2. https://www.pcsuggest.com/configuring-extroot-with-openwrt-on-tp-link-mr-3220/

Hardware tested on: Archer C7 AC1750 (flashed with OpenWrt 21.02.2 r16495-bf0c965af0 git-22.052.50801-31a27f3)
Storage & RAM: 32MB storage and 128MB RAM
Kernel: 5.4.179
USB stick: cheap-ass 32GB Class 10 HP v165w
Arch: QCA956X v1 r0


### 0. Use another box to ready the USB drive for extroot
This step can also be done using `fdisk` or `sfdisk` on the openwrt router terminal itself but I prefer using `gparted`/`cfdisk` or friends on another computer and having the USB ready to plug in for extroot configuration.

Use `gparted` to wipe all partitions, setup a `GPT` partition table, create partitions as seen below, make filesystems. The desired partition layout is something similar to:

```
Disk /dev/sda: 30.05 GiB, 32262586368 bytes, 63012864 sectors
Disk model: v165w           
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 4E04FDBF-9120-4B2B-93A6-6118657A5448

Device       Start      End  Sectors Size Type
/dev/sda1     2048  4196351  4194304   2G Linux filesystem (This is for the main extroot-rootfs storage)
/dev/sda2  4196352 63012830 58816479  28G Linux filesystem (This is for samba/nfs shares or personal storage or whatever)
```

Note 0: Ensure the partiton table is `GPT`
Note 1: All partitions are primary typed, none secondary.
Note 2: All partitions are `ext4` regardless.
Note 4: the above is a final snapshot of current setup, use whatever sizes you like for the partitions.

Once done, umount the USB stick, unplug, replug-in, verify that the setup is intact.

#### 0.1 Upgrade all current packages using `opkg update && for a in "" ; do opkg upgrade "" ; done` and religiously reboot.

### 1. USB devices configuration & Setup

SSH into OpenWrt and install the USB stack like so:

1. Run `opkg install kmod-usb-storage kmod-usb-storage-uas usbutils block-mount libblkid gdisk e2fsprogs kmod-fs-ext4`. This installs all the packages necessary to recognize and work with usb drives and their mounting procedures.
2. Reboot device or load kernel modules on-the-fly with `modprobe sd_mod; modprobe usb-storage; modprobe ext4`.
3. Plug in the USB drive and run `dmesg | tail`, check if kernel detects it, also verify using `lsusb` and `block info`.
4. If the partition layout and filesystems aren't setup or reported the way you assumed, Stop and redo everything correctly.

### 2. Ensure mounting and unmount the USB drive works

1. Create mountpoints `mkdir -p /mnt/sda1` and `mkdir -p /mnt/sda2` (likeso for all partitions you created)
2. Ensure the device is plugged in and do `mount /dev/sda1 /mnt/sda1` (try mounting all partitions this way)

if mounting fails with error "invalid argument" or similar, something's wrong with USB partiton table, go back and setup everything properly.

### 3. Finally, Setup extroot
Unmount all USB partitions, unplug, replug again and start:

```
#### first remove any previous mountpoints directories: `rm /mnt/sda1; rm /mnt/sda2;`

#### Setup variables and mount the device.
DEV_PARTITION="$(sed -n -e "/\s\/overlay\s.*$/s///p" /etc/mtab)" (The output of this should be `/dev/sda1` or similar)
MOUNT_POINT="/mnt"
mount "$DEV_PARTITION" "$MOUNT_POINT"

#### Setup fstab to auto mount the USB disk on boot using UCI
uci -q delete fstab.rwm
uci set fstab.rwm="mount"
uci set fstab.rwm.device="${DEV_PARTITION}"
uci set fstab.rwm.target="/rwm"
uci commit fstab

#### Extract part UUID of device, configure overlayfs to its new mountpoint.
eval $(block info ${DEV_PARTITION} | grep -o -e "UUID=\S*")
uci -q delete fstab.overlay
uci set fstab.overlay="mount"
uci set fstab.overlay.uuid="${UUID}"
uci set fstab.overlay.target="/overlay"
uci commit fstab

### Make temp directory, bind overlayfs to it as a mountpoint, copy it over to the new rootfs and unmount.
mkdir -p /tmp/cproot
mount --bind /overlay /tmp/cproot
tar -C /tmp/cproot -cvf - . | tar -C "$MOUNT_POINT" -xf - 
umount /tmp/cproot "$MOUNT_POINT"
```

If it's succeeds without errors you can reboot the router, else the errors might be becuase you probably already ran out of storage or are close to. In such case, the best idea is to backup config, do hard reset on the router, restore config. That way you regain most space, you can proceed with extroot now and install tons of packages after it's done.

You should see that the free space for instaling software (LuCi -> System -> Software) should indicate the amonut of space you have assigned to the /dev/sda1 partition.


## (Optional) Swap Setup

Also a good idea to setup swapfile, useful for torrenting over the network.

Instructions lifted directly from: https://www.pcsuggest.com/transmission-openwrt-torrent-downloader/


Adding swap space may not be necessary for routers with 128 MB or more RAM. Although, due to high memory usage, Transmission performs better when a little swap space is available. In fact on routers with 32 MB of RAM, running the transmission deamon will result in utterly laggy performance, but adding as little as 4 MB of swap space will improve the scenario a lot. You can use a dedicated swap partition on the USB drive or use a swap file, there is no significant performance difference between them. I'm going with the swap file approach here, assuming you are using extroot and have enough free space on the extroot partition.

0. `cd /root && pwd`
1. Create a 16 MB blank file: `dd if=/dev/zero of=swap-file bs=1M count=16`
2. Format it as swap file: `mkswap swap-file`
3. Turn on the swap space: `swapon swap-file`
4. To mount the swap space automatically at every boot, add this line bellow to the `/etc/rc.local` file before the exit 0 line: `swapon /root/swap-file`
5. Add few kernel parameters listed bellow to the /etc/sysctl.conf file and run sysctl -p, this will result in more effective use of the swap space.
```
vm.vfs_cache_pressure=200
vm.min_free_kbytes=4096
vm.overcommit_memory=2
vm.overcommit_ratio=60
vm.swappiness=95
```
6. Reboot device, you can check if swap space is working directly in `LuCI -> Home -> Status -> Storage`, swap should be visible there.
