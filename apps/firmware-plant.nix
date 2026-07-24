# macOS companion to the firmwareProvisioning NixOS module: plant operator files
# onto a device's mounted FAT firmware partition. Generic -- no device/repo/secret
# names baked in.
#
#   firmware-plant [--volume NAME] NAME=localfile [NAME=localfile ...]
#
# Each localfile is copied onto the mounted FAT volume (default label: FIRMWARE)
# as basename NAME. Match each NAME to a
# `services.firmwareProvisioning.files.<x>.source` on the device.
{ writeShellApplication, coreutils }:
writeShellApplication {
  name = "firmware-plant";
  runtimeInputs = [ coreutils ];
  text = ''
    vol=FIRMWARE
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --volume) vol="$2"; shift 2 ;;
        --volume=*) vol="''${1#*=}"; shift ;;
        -h|--help)
          printf '%s\n' \
            "usage: firmware-plant [--volume NAME] NAME=localfile ..." \
            "  Copies each localfile onto the mounted FAT volume (default: FIRMWARE)" \
            "  as basename NAME. Pair each NAME with a" \
            "  services.firmwareProvisioning.files.<x>.source on the device." >&2
          exit 0 ;;
        *) args+=("$1"); shift ;;
      esac
    done
    if [ ''${#args[@]} -eq 0 ]; then
      echo "firmware-plant: no NAME=file pairs given (see --help)" >&2
      exit 2
    fi

    # Resolve the mount point of the FAT volume by label (macOS).
    mp=$(/usr/sbin/diskutil info -plist "$vol" 2>/dev/null \
      | /usr/bin/plutil -extract MountPoint raw - 2>/dev/null || true)
    if [ -z "$mp" ] || [ ! -d "$mp" ]; then
      echo "firmware-plant: FAT volume '$vol' not mounted -- insert a freshly-flashed card." >&2
      exit 1
    fi

    for pair in "''${args[@]}"; do
      name="''${pair%%=*}"
      src="''${pair#*=}"
      if [ "$name" = "$pair" ] || [ -z "$name" ]; then
        echo "firmware-plant: bad pair '$pair' (want NAME=file)" >&2
        exit 2
      fi
      if [ ! -f "$src" ]; then
        echo "firmware-plant: source '$src' not found" >&2
        exit 2
      fi
      cp "$src" "$mp/$name"
      echo "planted $src -> $mp/$name  (volume $vol)"
    done

    /usr/bin/osascript -e 'display notification "firmware partition provisioned" with title "firmware-plant"' >/dev/null 2>&1 || true
  '';
}
