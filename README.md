# hey

**hey** is a zero-trust, self-healing Linux environment manager.

It detects your system, understands your environment, fixes common issues, installs missing essentials, prepares privacy tooling, configures hardware drivers, and leaves your system in a clean, stable, ready state — **without asking questions and without breaking philosophy**.

Built for 2025–2030.

---

## Philosophy

`hey` follows five non‑negotiable principles:

1. **Do no harm** – no destructive changes, ever
2. **No assumptions** – detect, verify, then act
3. **Safe re‑run** – can be executed multiple times safely
4. **Offline‑first** – works without internet, improves with it
5. **Explainable** – everything logged, nothing hidden

---

## What hey does

### System

* Detects distribution (Kali, Parrot, Ubuntu/Debian, Arch)
* Detects environment (WSL, VM, bare metal)
* Fixes common system issues
* Repairs package manager state
* Cleans and stabilizes the system

### Network

* Fixes DNS issues
* Repairs NetworkManager state
* Fixes Wi‑Fi and wireless blocks
* Flushes caches safely

### Bluetooth

* Installs and enables Bluetooth stack
* Fixes common service issues

### Audio

* Configures PipeWire / ALSA stack
* Restarts audio services safely

### Display

* Fixes resolution issues
* Ensures Mesa / VAAPI / VDPAU availability

### GPU

* Detects NVIDIA / AMD / Intel
* Installs correct drivers only if available
* Avoids unsupported or deprecated drivers

### CUDA / ROCm

* Enables CUDA for NVIDIA when supported
* Enables ROCm for AMD when supported
* Skips safely if unsupported

### Privacy

* Installs and configures Tor
* Installs and configures ProxyChains
* Uses **dynamic chain** with DNS protection
* Never forces system‑wide proxy

### Security tooling (safe setup only)

* Installs widely used open‑source tools
* Updates GitHub repositories safely
* Never executes tools

### Intelligence

* Health score (0–100)
* State memory between runs
* Predictive checks

---

## What hey will NEVER do

* Never scan targets
* Never exploit systems
* Never phone home
* Never change system philosophy
* Never silently fail

---

## Usage

```bash
chmod +x hey
sudo ./hey
```

Logs are written to:

* `/var/log/hey/hey.log`
* or `~/.hey/logs/hey.log`

System state saved at:

```
~/.hey/state.json
```

---

## Supported systems

* Kali Linux
* Parrot OS
* Ubuntu / Debian
* Arch Linux

---

## Safety

* All configuration files are backed up before modification
* All packages are verified before installation
* All steps are logged

---

## License

MIT License

---

## Author

**ahmad-n00r**

---

## Status

Stable – v1.0.0
