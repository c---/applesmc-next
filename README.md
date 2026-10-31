# applesmc-next
Patches to the Linux kernel that allow setting battery charge thresholds on
Intel Apple devices.

This includes battery plugins for [TLP](https://linrunner.de/en/tlp/tlp.html).
For TLP 1.10, see the adapter instructions below. The legacy `45-apple` plugin
targets older TLP releases and is installed at `/usr/share/tlp/bat.d/45-apple`.
The interface can also be accessed directly via sysfs:
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

### TLP 1.10 adapter

With the applesmc-next modules loaded and the end-threshold sysfs attribute
available, install the adapter from this checkout:

```sh
sudo install -m 0644 tlp/62-applesmc-next /usr/share/tlp/bat.d/62-applesmc-next
```

If the legacy `45-apple` plugin was installed previously, move it out of
`/usr/share/tlp/bat.d/` first so it cannot take precedence. Configure, for example,
`STOP_CHARGE_THRESH_BAT0=80` in `/etc/tlp.conf`, then run `sudo tlp start` and
check `sudo tlp-stat -b` for `Plugin: applesmc` and the stop threshold.

The adapter claims Intel Apple hardware when the
`charge_control_end_threshold` attribute exists; otherwise TLP can select its
generic plugin. An existing attribute with a failed SMC read keeps this adapter
selected so TLP reports a read error and skips the write. `NATACPI_ENABLE=0`
keeps threshold control disabled. The adapter accepts stop thresholds **10..100**,
matching the current driver.
`START_CHARGE_THRESH_BAT0` is ignored and the placeholder start attribute is
never written. Force discharge and a configurable start threshold are unsupported.
The adapter does not change the full/LED threshold.

Run the offline checks with `sh tlp/test-62-applesmc-next.sh`. They use simulated
sysfs and helper functions without touching real hardware.

#### Validation and limits

Tested on one MacBookPro12,1 (Europa), Kali Linux Rolling 2026.3,
`7.1.5+kali-amd64`, TLP `1.10.2-2`:

| Check | Result |
| --- | --- |
| Offline adapter checks after review fixes | 53 passed: deterministic hardware detection/fallback, write-attempt checks for stop-only operation, limits/defaults, read/write failures, disabled configuration and BAT1 selection |
| Original adapter: live TLP detection and charging | Adapter selected; at 89% on AC, restoring the saved 100% limit resumed charging at 1536 mA; applying 80% stopped charging at 0 mA |
| Original adapter: one reboot | Custom modules and adapter loaded automatically; 80% limit retained, charging remained stopped at 89% on AC |
| Original adapter: one short deep S3 cycle | Modules and 80% limit retained; Wi-Fi and SSH returned with a separate Wi-Fi workaround |
| Reviewed adapter: deployment and charging cutoff | TLP wrote 79% then restored 80%, both read back correctly; charging at ~2.75 A stopped at reported 80% (TLP 79.8%), 0 mA / Full, with AC still connected |
| Reviewed adapter: one reboot | Wi-Fi/key SSH returned after ~117 seconds; adapter/modules loaded, Wi-Fi D3cold rule applied, 80% retained and AC charging stopped (0 mA / Full) |
| Reviewed adapter: subsequent suspend attempt on AC | One 75-second RTC wake was armed, but SSH/Wi-Fi reachability did not return within four minutes; actual wake state and post-wake threshold are awaiting local inspection |

The original-adapter rows predate the review fixes to detection/error reporting
and its tests. The reviewed adapter was then deployed separately, retaining the
existing driver fixes, TLP configuration and rollback state. Its reboot passed;
the subsequent suspend attempt remains unverified pending local recovery. Both
deployments used the host-controller
fix from [PR #15](https://github.com/c---/applesmc-next/pull/15) and the read-lock
and sysfs-error-propagation subset of
[PR #12](https://github.com/c---/applesmc-next/pull/12). Those driver changes and
local DKMS packaging adjustments are separate from this adapter. This does not
establish that the unpatched drivers work on that kernel.

The S3 retest used a host-specific `d3cold_allowed=0` setting on the Broadcom
BCM43602 Wi-Fi controller after earlier resume attempts lost Wi-Fi. That workaround
is separate from applesmc-next. The retest was on battery, so it verified threshold
retention without re-exercising charging cutoff. Repeated/long sleep cycles, other
machines, kernels and TLP versions have not been tested.

To remove the adapter, first restore the recorded original stop threshold while
the driver still exposes it, verify readback, remove the installed adapter and
undo its TLP configuration. Removing the plugin alone does not reset the SMC's
persistent limit. Retain the original module/configuration backups for any driver
rollback.

[Arch Linux AUR package](https://aur.archlinux.org/packages/applesmc-next-dkms)

To build on other distributions install the `dkms` package then run something like the following:
```
#!/bin/sh
TAG="$(git ls-remote --tags https://github.com/c---/applesmc-next | grep -oP 'tags/\K[0-9.]+' | tail -n1)"
git clone --depth 1 --branch "$TAG" https://github.com/c---/applesmc-next "/usr/src/applesmc-next-$TAG"
dkms install "applesmc-next/$TAG"
```
