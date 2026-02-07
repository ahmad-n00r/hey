#!/usr/bin/env bash
set -euo pipefail

AUTHOR="ahmad-n00r"
PROJECT="hey"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$HOME/.local/bin:$HOME/go/bin"

[ "$(id -u)" -ne 0 ] && echo "[HEY] must_run_as_root" && exit 1
[ -f /etc/os-release ] || echo "[HEY] os_release_missing" && exit 1

. /etc/os-release
OS_ID="$ID"

ENV_TYPE="bare"
grep -qi microsoft /proc/version && ENV_TYPE="wsl"
command -v systemd-detect-virt >/dev/null 2>&1 && {
  VIRT="$(systemd-detect-virt)"
  [ "$VIRT" != "none" ] && ENV_TYPE="vm"
}

HAS_SYSTEMD=false
SYSTEMD_ACTIVE=false
command -v systemctl >/dev/null && HAS_SYSTEMD=true
$HAS_SYSTEMD && systemctl is-system-running >/dev/null 2>&1 && SYSTEMD_ACTIVE=true

echo "[HEY] detect os=$OS_ID env=$ENV_TYPE systemd=$SYSTEMD_ACTIVE"

mount -o remount,rw / >/dev/null 2>&1 || true
df / | awk 'NR==2 {if ($5+0 > 95) exit 1}' || { echo "[HEY] disk_full"; exit 1; }

timedatectl set-ntp true >/dev/null 2>&1 || true
hwclock -w >/dev/null 2>&1 || true

pkg_install() {
  for p in "$@"; do
    if [ "$OS_ID" = "arch" ]; then
      pacman -S --noconfirm --needed "$p" && return 0 || true
    else
      DEBIAN_FRONTEND=noninteractive apt install -y "$p" && return 0 || true
    fi
  done
  return 1
}

if [ "$OS_ID" = "arch" ]; then
  pacman-key --init || true
  pacman-key --populate archlinux || true
  pacman -Sy --noconfirm archlinux-keyring || true
else
  rm -f /var/lib/dpkg/lock* || true
  dpkg --configure -a || true
  apt clean || true
  apt update || true
fi

pkg_install curl wget git ca-certificates iproute2 iputils net-tools rfkill

get_ifaces() {
  ip -o link show | awk -F': ' '{print $2}' | grep -Ev 'lo|docker|virbr'
}

net_ok() {
  ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || return 1
  ping -c1 -W2 google.com >/dev/null 2>&1 || return 2
  return 0
}

command -v rfkill >/dev/null && rfkill unblock all || true

if [ "$OS_ID" = "arch" ]; then
  pkg_install networkmanager dhcpcd
  $SYSTEMD_ACTIVE && systemctl unmask NetworkManager || true
  $SYSTEMD_ACTIVE && systemctl enable NetworkManager dhcpcd || true
  $SYSTEMD_ACTIVE && systemctl start NetworkManager dhcpcd || true
else
  pkg_install network-manager resolvconf
  $SYSTEMD_ACTIVE && systemctl unmask NetworkManager || true
  $SYSTEMD_ACTIVE && systemctl enable NetworkManager || true
  $SYSTEMD_ACTIVE && systemctl start NetworkManager || true
fi

if [ "$ENV_TYPE" = "vm" ]; then
  pkg_install open-vm-tools open-vm-tools-desktop virtualbox-guest-utils || true
  $SYSTEMD_ACTIVE && systemctl enable vboxservice vmtoolsd || true
  $SYSTEMD_ACTIVE && systemctl start vboxservice vmtoolsd || true
fi

rm -f /etc/resolv.conf
printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\noptions timeout:2 attempts:2\n" > /etc/resolv.conf
chattr -i /etc/resolv.conf >/dev/null 2>&1 || true

for i in $(get_ifaces); do
  ip link set "$i" up || true
  dhclient "$i" >/dev/null 2>&1 || dhcpcd "$i" >/dev/null 2>&1 || true
done

net_ok || { echo "[HEY] network_unrecoverable"; exit 1; }

if [ "$OS_ID" = "arch" ]; then
  pacman -Syu --noconfirm
else
  apt update -y && apt full-upgrade -y
fi

echo "[HEY] system_stable"

echo "1) Defense"
echo "2) Offense"
echo "3) CTF"
read -rp "Choice [1-3] (default Offense): " CHOICE || CHOICE=2

case "$CHOICE" in
  1) PROFILE="defense" ;;
  3) PROFILE="ctf" ;;
  *) PROFILE="offense" ;;
esac

provision_offense() {
  PKGS=(
    nmap masscan metasploit-framework wireshark tcpdump
    sqlmap nikto hydra john hashcat
    gobuster ffuf feroxbuster
    netcat socat responder smbclient enum4linux
  )
  for p in "${PKGS[@]}"; do pkg_install "$p"; done
  pkg_install golang python3 pipx
  export PATH="$PATH:$HOME/go/bin"
  GO_TOOLS=(
    github.com/projectdiscovery/nuclei/v3/cmd/nuclei
    github.com/projectdiscovery/httpx/cmd/httpx
    github.com/projectdiscovery/subfinder/v2/cmd/subfinder
    github.com/tomnomnom/assetfinder
    github.com/tomnomnom/waybackurls
    github.com/ffuf/ffuf
  )
  for t in "${GO_TOOLS[@]}"; do go install "$t@latest" || true; done
  mkdir -p "$HOME/tools"
  GIT_TOOLS=(
    https://github.com/carlospolop/PEASS-ng
    https://github.com/swisskyrepo/PayloadsAllTheThings
    https://github.com/BloodHoundAD/BloodHound
    https://github.com/fox-it/BloodHound.py
  )
  for r in "${GIT_TOOLS[@]}"; do
    d="$HOME/tools/$(basename "$r" .git)"
    [ -d "$d" ] || git clone --depth=1 "$r" "$d"
  done
}

provision_defense() {
  PKGS=(
    auditd fail2ban ufw nftables
    lynis rkhunter chkrootkit
    osquery htop btop sysstat
  )
  for p in "${PKGS[@]}"; do pkg_install "$p"; done
  $SYSTEMD_ACTIVE && systemctl enable auditd fail2ban || true
  ufw default deny incoming || true
  ufw default allow outgoing || true
  ufw enable || true
}

provision_ctf() {
  PKGS=(
    gdb radare2 ghidra
    strace ltrace
    binwalk foremost steghide
  )
  for p in "${PKGS[@]}"; do pkg_install "$p"; done
  pkg_install python3 pipx
  pipx install pwntools || true
}

provision_wordlists() {
  mkdir -p "$HOME/wordlists"
  REPOS=(
    https://github.com/danielmiessler/SecLists
    https://github.com/assetnote/wordlists
  )
  for r in "${REPOS[@]}"; do
    d="$HOME/wordlists/$(basename "$r" .git)"
    [ -d "$d" ] || git clone --depth=1 "$r" "$d"
  done
}

case "$PROFILE" in
  offense) provision_offense ;;
  defense) provision_defense ;;
  ctf) provision_ctf ;;
esac

provision_wordlists

echo "[HEY] done profile=$PROFILE author=ahmad-n00r"
