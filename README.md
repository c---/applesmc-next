# applesmc-next
Patches to the Linux kernel that allow setting battery charge thresholds on
Intel Apple devices.

This includes a [TLP](https://linrunner.de/en/tlp/tlp.html) script for use with
that system. The file should be placed at `/usr/share/tlp/bat.d/45-apple`.
Otherwise the interface can be accessed directly via sysfs:
```
/sys/class/power_supply/BAT0/charge_control_end_threshold
/sys/class/power_supply/BAT0/charge_control_full_threshold
/sys/class/power_supply/BAT0/charge_control_start_threshold
```

Note `charge_control_start_threshold` is not currently implemented.

Example:
```
# echo 80 > /sys/class/power_supply/BAT0/charge_control_end_threshold
```

This will cause charging to stop at 80% charge. Note this change is persistent
across power cycles and operating systems unless the SMC is reset.

Setting `charge_control_full_threshold` controls when the charging LED turns
green and is cosmetic only. Generally it doesn't need to be set.

Note that for `charge_control_full_threshold` to work it needs to be set to a
value less than than the end threshold because the battery will tend to float
slightly under the maximum. Subtract at least 2% or more from the end
threshold.

[Arch Linux AUR package](https://aur.archlinux.org/packages/applesmc-next-dkms)

To build on other distributions install the `dkms` package then run something like the following:
```
#!/bin/sh
TAG="$(git ls-remote --tags https://github.com/c---/applesmc-next | grep -oP 'tags/\K[0-9.]+' | tail -n1)"
git clone --depth 1 --branch "$TAG" https://github.com/c---/applesmc-next "/usr/src/applesmc-next-$TAG"
dkms install "applesmc-next/$TAG"
```
