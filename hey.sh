detect_capabilities() {
  HAS_SYSTEMD=false
  HAS_GUI=false
  HAS_WIFI=false

  command -v systemctl >/dev/null && HAS_SYSTEMD=true
  command -v xrandr >/dev/null && HAS_GUI=true
  command -v iw >/dev/null && HAS_WIFI=true

  echo "[HEY] caps systemd=$HAS_SYSTEMD gui=$HAS_GUI wifi=$HAS_WIFI"
}

net_ok() {
  ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 || return 1
  ping -c1 -W2 google.com >/dev/null 2>&1 || return 2
  return 0
}

auto_fix_network() {
  net_ok && return 0

  echo "[HEY] network_fix"

  command -v rfkill >/dev/null && rfkill unblock all || true

  $HAS_SYSTEMD && systemctl restart NetworkManager 2>/dev/null || true
  $HAS_SYSTEMD && systemctl restart systemd-resolved 2>/dev/null || true

  rm -f /etc/resolv.conf
  printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\n" > /etc/resolv.conf

  for i in $(ip -o link show | awk -F': ' '{print $2}'); do
    dhclient "$i" >/dev/null 2>&1 || true
  done
}

phase_update() {
  echo "[HEY] update_start"
  if [ "$PKG_MGR" = "apt" ]; then
    apt update -y && apt upgrade -y
  else
    pacman -Syu --noconfirm
  fi
}

ask_user_profile() {
  echo
  echo "System is stable."
  echo "Select provisioning profile:"
  echo "1) Defense"
  echo "2) Offense"
  echo "3) CTF"

  read -rp "Choice [1-3] (default Offense): " CHOICE || CHOICE=2

  case "$CHOICE" in
    1) USER_PROFILE="defense" ;;
    2) USER_PROFILE="offense" ;;
    3) USER_PROFILE="ctf" ;;
    *) USER_PROFILE="offense" ;;
  esac

  echo "[HEY] profile=$USER_PROFILE"
}

provision_offense() {
  OFFENSE_PKGS=(
    nmap masscan metasploit-framework wireshark tcpdump
    sqlmap nikto hydra john hashcat
    gobuster ffuf feroxbuster
    netcat socat responder smbclient enum4linux
  )

  for p in "${OFFENSE_PKGS[@]}"; do install_pkg "$p"; done

  install_pkg golang python3 pipx
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

  GIT_TOOLS=(
    https://github.com/carlospolop/PEASS-ng
    https://github.com/swisskyrepo/PayloadsAllTheThings
    https://github.com/BloodHoundAD/BloodHound
    https://github.com/fox-it/BloodHound.py
  )

  for r in "${GIT_TOOLS[@]}"; do
    d="$TOOLS_DIR/$(basename "$r" .git)"
    [ -d "$d" ] || git clone --depth=1 "$r" "$d"
  done
}

provision_defense() {
  DEFENSE_PKGS=(
    auditd fail2ban ufw nftables
    lynis rkhunter chkrootkit
    osquery htop btop sysstat
  )

  for p in "${DEFENSE_PKGS[@]}"; do install_pkg "$p"; done

  $HAS_SYSTEMD && systemctl enable auditd fail2ban || true

  ufw default deny incoming || true
  ufw default allow outgoing || true
  ufw enable || true
}

provision_ctf() {
  CTF_PKGS=(
    gdb radare2 ghidra
    strace ltrace
    binwalk foremost steghide
  )

  for p in "${CTF_PKGS[@]}"; do install_pkg "$p"; done

  install_pkg python3 pipx
  pipx install pwntools || true
}

provision_wordlists() {
  WORDLIST_REPOS=(
    https://github.com/danielmiessler/SecLists
    https://github.com/assetnote/wordlists
  )

  for r in "${WORDLIST_REPOS[@]}"; do
    d="$WL_DIR/$(basename "$r" .git)"
    [ -d "$d" ] || git clone --depth=1 "$r" "$d"
  done
}
