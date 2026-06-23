#!/usr/bin/env bash
# archiso profile definition for promptOS

iso_name="promptos"
iso_label="PROMPTOS_$(date +%Y%m)"
iso_publisher="promptOS <https://github.com/TheStoneRabbit/promptOS>"
iso_application="promptOS — AI-Native Linux"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/promptsh"]="0:0:755"
  ["/usr/local/bin/promptos-warmup"]="0:0:755"
  ["/usr/local/bin/promptos-install"]="0:0:755"
  ["/usr/local/bin/promptos-keys"]="0:0:755"
  ["/usr/local/bin/promptos-wifi"]="0:0:755"
  ["/usr/local/bin/promptos-model"]="0:0:755"
  ["/usr/local/bin/promptos-web"]="0:0:755"
  ["/usr/local/bin/promptos-gui"]="0:0:755"
  ["/usr/local/bin/promptos-firstboot"]="0:0:755"
  ["/usr/local/bin/promptos-wallpaper"]="0:0:755"
  ["/etc/promptos/keys"]="0:0:644"
  ["/etc/promptos/config"]="0:0:644"
  ["/root/.xinitrc"]="0:0:755"
  ["/etc/xdg/openbox/autostart"]="0:0:755"
  ["/etc/xdg/openbox/rc.xml"]="0:0:644"
  ["/etc/promptos/picom.conf"]="0:0:644"
  ["/usr/share/promptos/wallpaper.png"]="0:0:644"
  ["/etc/profile.d/00-promptos-x.sh"]="0:0:644"
)
