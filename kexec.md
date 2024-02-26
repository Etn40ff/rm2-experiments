# Booting a different linux version using kexec

It looks like on Codex, because of systemd, kexec only works if activated via
systemctl. Something like this works

```
reMarkable: ~/ kexec -l /boot/zImage --command-line="console=ttymxc0,115200 root=/dev/mmcblk2p3 rootwait rootfstype=ext4 rw quiet panic=20 systemd.crash_reboot systemd.show_status=0 loglevel=0 crashkernel=32M"
reMarkable: ~/ /bin/sync
reMarkable: ~/ systemctl kexec
```
