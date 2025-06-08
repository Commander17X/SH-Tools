# SH-Tools

Een verzameling handige shell scripts voor dagelijks gebruik.

## Beschikbare Tools

### 1. ClipMe - Clipboard Manager
Een krachtige clipboard manager voor de terminal met:
- Multi-platform ondersteuning (X11, Wayland, WSL)
- Fuzzy search functionaliteit
- Hotkey ondersteuning
- Geschiedenis beheer
- JSON-gebaseerde opslag

### 2. NetPeek - Netwerk Analyzer
Een minimalistische netwerk analyse tool met:
- Bandwidth monitoring
- Netwerk scanning
- Ping/latency tracking
- Connection drop logging
- CLI dashboard

### 3. LogSift - Smart Log File Filter
Een slimme log bestand filter met:
- Highlighting van errors, warnings, timestamps, IPs
- Aangepaste regex ondersteuning
- Gekleurde terminal output
- Interactieve modus voor navigatie
- Ondersteuning voor syslog, dmesg, journalctl exports

### 4. SnapShot - Instant Backup CLI
Een snelle backup tool met:
- Timestamped backups
- Preset ondersteuning (--home, --web)
- Compressie opties (zip, tar.gz)
- Rolling backup limiet
- Lokale en mounted drive ondersteuning

### 5. MountMate - Drive Mounter/Manager
Een eenvoudige schijf beheerder met:
- Device listing (lsblk, df -h)
- Mount/unmount functionaliteit
- Mount profielen
- Optionele UI met curses/rich
- Automatische mount detectie

### 6. SafePass - Encrypted Password CLI
Een veilige wachtwoord manager met:
- GPG/OpenSSL encryptie
- Lokale password vault
- Clipboard integratie
- Auto-lock timeout
- Export/import functionaliteit

### 7. LinkFixer - Broken Link Scanner
Een link validator met:
- Markdown, HTML, en plain text scanning
- URL validatie (HTTP HEAD)
- Samenvattings- en CSV output
- GitHub README.md scanning
- Rapport generatie

### 8. TreeDex - Terminal File Explorer
Een snelle bestandsverkenner met:
- Folder en bestandsgrootte weergave
- Type iconen (emoji/ascii)
- Duplicaat en groot bestand detectie
- Speciale modi (code, media, clean)
- Export als .txt of .md diagrammen

### 9. CachePurge - App Cache Cleaner
Een cache opruimer met:
- Ondersteuning voor populaire apps
- Dry run optie
- Schijfruimte besparing rapport
- Cron job integratie
- Veilige verwijdering

### 10. BootTrace - System Boot Time Analyzer
Een boottijd analyser met:
- Boot duur analyse
- Service vertraging detectie
- Optimalisatie suggesties
- Gekleurde output
- Gedetailleerde rapporten

### 11. FetchBox - Fast File Downloader
Een snelle bestandsdownloader met:
- Batch download ondersteuning
- Automatisch hernoemen
- Multi-threaded downloads
- Herstel van onderbroken downloads
- URL lijst ondersteuning

### 12. ProMan - Terminal Project Manager
Een project manager met:
- Project tracking
- Status updates
- Tag systeem
- Logboek functionaliteit
- JSON/YAML opslag

## Installatie

1. Clone de repository:
```bash
git clone https://github.com/Commander17X/SH-Tools.git
cd SH-Tools
```

2. Maak de scripts uitvoerbaar:
```bash
chmod +x tools/*.sh
```

3. Voeg de tools toe aan je PATH (optioneel):
```bash
echo 'export PATH="$PATH:$HOME/SH-Tools/tools"' >> ~/.bashrc
source ~/.bashrc
```

## Gebruik

### ClipMe
```bash
./tools/clipme.sh
```

### NetPeek
```bash
./tools/netpeek.sh
```

### LogSift
```bash
./tools/logsift.sh [bestand] [opties]
```

### SnapShot
```bash
./tools/snapshot.sh [--preset] [--compress]
```

### MountMate
```bash
./tools/mountmate.sh [--mount profiel] [--list]
```

### SafePass
```bash
./tools/safepass.sh [--add] [--get] [--export]
```

### LinkFixer
```bash
./tools/linkfixer.sh [bestand] [--github]
```

### TreeDex
```bash
./tools/treedex.sh [pad] [--mode]
```

### CachePurge
```bash
./tools/cachepurge.sh [--dry-run] [--schedule]
```

### BootTrace
```bash
./tools/boottrace.sh [--analyze] [--optimize]
```

### FetchBox
```bash
./tools/fetchbox.sh [url] [--threads] [--resume]
```

### ProMan
```bash
./tools/proman.sh [add|list|done|archive] [project]
```

## Vereisten

- Bash 4.0 of hoger
- jq (voor JSON verwerking)
- fzf (voor fuzzy search)
- xclip/wl-clipboard (voor clipboard beheer)
- nmap (voor netwerk scanning)
- GPG (voor SafePass)
- curl (voor LinkFixer)
- ncurses (voor MountMate UI)
- tar/gzip (voor SnapShot compressie)
- systemd-analyze (voor BootTrace)
- aiohttp (voor FetchBox)
- yq (voor YAML verwerking)

## Licentie

MIT License 