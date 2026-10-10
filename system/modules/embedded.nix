{ pkgs, ... }:

{
  # ── Teensy (PJRC) ────────────────────────────────────────────────────
  # Uploading uses the HalfKay HID bootloader (raw USB, vendor 16c0) — the
  # `dialout` group only covers the /dev/ttyACM* serial side, so a udev rule
  # is needed to flash without root. `ID_MM_DEVICE_IGNORE` keeps ModemManager
  # off the port. Rules verbatim from https://www.pjrc.com/teensy/00-teensy.rules
  services.udev.extraRules = ''
    ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
    ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
    KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"

    # ── Arduino (vendor 2341, e.g. Nicla Vision) ──
    # Mbed boards flash via dfu-util against the DFU bootloader (2341:035f),
    # which is raw USB — same story as HalfKay, `dialout` isn't enough.
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="2341", MODE:="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
  '';

  # Standalone uploader (flash a prebuilt .hex, or sanity-check the port).
  # PlatformIO bundles its own copy inside the dev shell, so this is just a
  # convenience on the host. arduino-cli's downloaded tools (dfu-util etc.)
  # are unpatched binaries and run via nix-ld (see profiles/desktop.nix).
  environment.systemPackages = [ pkgs.teensy-loader-cli pkgs.arduino-cli ];
}
