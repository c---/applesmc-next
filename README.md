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
