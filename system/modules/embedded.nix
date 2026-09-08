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
  '';

  # Standalone uploader (flash a prebuilt .hex, or sanity-check the port).
  # PlatformIO bundles its own copy inside the dev shell, so this is just a
  # convenience on the host.
  environment.systemPackages = [ pkgs.teensy-loader-cli ];
}
