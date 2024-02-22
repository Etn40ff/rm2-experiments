# Install alpine linux on rm2

**WARNING:** these instructions are very experimental, if something goes wrong
it is easy to end up in a bootloop. You are advised to have a recovery cable
handy just in case and to be familiar with
[remarkable2-recovery](https://github.com/ddvk/remarkable2-recovery).
Follow these instruction at your own risk.
Should you get stuck please seek advice on
[Discord](https://discord.com/channels/385916768696139794/385922887812513823).

These notes are for the moment only a draft; be on the lookout for typos.

We are going to assume that you are currently running Codex from
`/dev/mmcblk2p2` if not adapt the commands accordingly. 

We are also assuming that you are running version 3.x. This is not strictly
necessary but, since we are going to use
[linux-stracciatella](https://github.com/Etn40ff/linux-remarkable), you will need
to extract firmware blobs from an update image otherwise.

- Format and mount the partition
```
# mkfs.ext4 /dev/mmcblk2p3
# mkdir /mnt/alpine
# mount /dev/mmcblk2p3 /mnt/alpine
```

- Obtain a statically linked version of apk
```
# cd /tmp/
# wget https://nl.alpinelinux.org/alpine/edge/main/armhf/apk-tools-static-2.14.0-r5.apk
# tar xf apk-tools-static-2.14.0-r5.apk
```

- Install the base
```
# /tmp/sbin/apk.static add --update-cache --root /mnt/alpine/ --repository http://dl-cdn.alpinelinux.org/alpine/edge/main --initdb --arch armhf --allow-untrusted alpine-base 
```

- Chroot
```
# mount -t proc none /mnt/alpine/proc
# mount -o bind /sys /mnt/alpine/sys
# mount -o bind /dev /mnt/alpine/dev
# cp /etc/resolv.conf /mnt/alpine/etc/resolv.conf
# chroot /mnt/alpine /bin/ash
```

- Configure repository
```
# cat > /etc/apk/repositories << EOF
http://dl-cdn.alpinelinux.org/alpine/edge/main
EOF
# apk update
```

- Add some software
```
# apk add openssh wpa_supplicant u-boot-tools busybox-extras busybox-extras-openrc
```

- Configure interfaces
```
# cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback

auto wlan0
iface wlan0 inet dhcp

auto usb1
iface usb1 inet static
address 10.11.99.1/29
EOF

# cat > /etc/local.d/10-usb-ether.start << EOF
#!/bin/sh

modprobe libcomposite

mkdir -p /run/gadget-cfg
export CONFIGFS_HOME=/run/gadget-cfg
cd $CONFIGFS_HOME
mount none $CONFIGFS_HOME -t configfs

mkdir -p $CONFIGFS_HOME/usb_gadget/g_ether
cd $CONFIGFS_HOME/usb_gadget/g_ether

echo 0x04b3 > idVendor
echo 0x4010 > idProduct
mkdir -p strings/0x409
echo 0 > strings/0x409/serialnumber
echo "reMarkable" > strings/0x409/manufacturer
echo "RNDIS/Ethernet Gadget" > strings/0x409/product

mkdir configs/c.1
echo 2 > configs/c.1/MaxPower
mkdir configs/c.1/strings/0x409
echo "RNDIS" > configs/c.1/strings/0x409/configuration

mkdir configs/c.2
echo 2 > configs/c.2/MaxPower
mkdir configs/c.2/strings/0x409
echo "ECM" > configs/c.2/strings/0x409/configuration

mkdir -p functions/rndis.usb0
mkdir -p functions/ecm.usb1

ln -s functions/rndis.usb0 configs/c.1
ln -s functions/ecm.usb1 configs/c.2

echo ci_hdrc.0 > UDC
EOF

# chmod a+x /etc/local.d/10-usb-ether.start

# cat > /etc/udhcpd.conf << EOF
interface       usb1

# Based on our USB VID (11997), to try to do something original
start           10.11.99.2
end             10.11.99.6
# We only want one, but sometimes the device is reconnected before the lease expires
max_leases      4

# never write to the lease file
auto_time       0

# The amount of time that an IP will be reserved (leased) for if a
# DHCP decline message is received (seconds).
decline_time    60

# The amount of time that an IP will be reserved (leased) for if an
# ARP conflct occurs. (seconds)
conflict_time   60

# How long an offered address is reserved (leased) in seconds
offer_time      60

# What we send in the answer
option          lease       60 # seconds
option          subnet      255.255.255.248
option          broadcast   10.11.99.7
#option          router      10.11.99.1
EOF
```
`/etc/local.d/10-usb-ether.start` and `/etc/udhcpd.conf` are basically taken from Codex. 


- Change root password
```
# passwd
```
Optionally copy over your ssh key

- Setup hostname
```
# setup-hostname
```

- Setup u-boot tools
```
# cat > /etc/fw_env.config << EOF
/var/lib/uboot/uboot.env 0x0000          0x2000
EOF
# mkdir /var/lib/uboot/
# echo "/dev/mmcblk2p1       /var/lib/uboot/      vfat       defaults,nofail 0  2" >> /etc/fstab
```




- Setup services
```
reMarkable: // rc-update add bootmisc boot
reMarkable: // rc-update add hostname boot
reMarkable: // rc-update add hwclock boot
reMarkable: // rc-update add modules boot
reMarkable: // rc-update add sysctl boot
reMarkable: // rc-update add syslog boot
reMarkable: // rc-update add local boot
reMarkable: // rc-update add networking default
reMarkable: // rc-update add killprocs shutdown
reMarkable: // rc-update add mount-ro shutdown
reMarkable: // rc-update add savecache shutdown
reMarkable: // rc-update add devfs sysinit
reMarkable: // rc-update add dmesg sysinit
reMarkable: // rc-update add hwdrivers sysinit
reMarkable: // rc-update add mdev sysinit
```
Note that `local` is in the runlevel `boot` and `networking` is in `default`
because we need to setup usb1 before `networking` is run. This is a
stopgap solution before I find the time to write a proper boot service.


openssh
reMarkable: // rc-update add sshd default
reMarkable: // setup-sshd

