#!/bin/bash
set -e

# ─────────────────────────────────────────────
# 🛠️ Setup Completo Dev Web + Rust + Tauri
# Fedora Workstation | di Christian K.P.
# Ultimo update: 19/07/2025 12:30
# ─────────────────────────────────────────────

## Colori & icone
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BLUE='\033[1;34m'
BOLD='\033[1m'
RESET='\033[0m'

## Logger
log()   { echo -e "${GREEN}[✔]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[⚠]${RESET} $1"; }
error() { echo -e "${RED}[✘]${RESET} $1"; }
title() { echo -e "\n${BLUE}🔹 ${BOLD}$1${RESET}"; }

## Verifica permessi
if [[ $EUID -ne 0 ]]; then
  error "Devi eseguire questo script con sudo!"
  exit 1
fi

## Aggiornamento sistema
title "Aggiornamento sistema"
dnf upgrade --refresh -y || error "Errore durante aggiornamento!"

## ───────────────────────────────────────
## 🧰 Tool base comuni per ogni dev
## ───────────────────────────────────────
title "Tool base per ogni sviluppatore"

dnf install -y git curl wget unzip tar htop btop zsh neovim jq gcc make cmake \
  python3-pip bat ripgrep fd-find fzf tmux || error "Errore installazione tool base"

log "Tool base installati"

## ───────────────────────────────────────
## 🌐 Frontend Web (React, Next.js, Tailwind)
## ───────────────────────────────────────
title "Frontend Web Dev (React, Next.js, Tailwind)"

dnf install -y nodejs
corepack enable
corepack prepare yarn@stable --activate || warn "Yarn già attivo o errore"
log "Yarn installato e attivo"

## ───────────────────────────────────────
## 🦀 Rust + Tauri
## ───────────────────────────────────────
title "Rust + Tauri"

if ! su - "$SUDO_USER" -c "command -v cargo &> /dev/null"; then
  log "Installazione Rust per $SUDO_USER..."
  su - "$SUDO_USER" -c 'curl https://sh.rustup.rs -sSf | sh -s -- -y && source "$HOME/.cargo/env"'
else
  log "Rust già presente"
fi

if ! su - "$SUDO_USER" -c "cargo install --list | grep -q tauri-cli"; then
  log "Installazione tauri-cli..."
  su - "$SUDO_USER" -c "source ~/.cargo/env && cargo install tauri-cli"
else
  log "tauri-cli già installato"
fi

## ───────────────────────────────────────
## 🐳 Docker + Podman
## ───────────────────────────────────────
title "Container & DevOps (Docker + Podman)"

dnf install -y docker docker-compose podman podman-compose buildah || warn "Errore installazione container tools"
systemctl enable --now docker
usermod -aG docker "$SUDO_USER"
log "Docker abilitato"

## ───────────────────────────────────────
## 🧠 Editor (VS Code)
## ───────────────────────────────────────
title "Editor di codice (VS Code)"

if ! command -v code &> /dev/null; then
  log "Installazione Visual Studio Code..."
  rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sh -c 'echo -e "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
  dnf install -y code || error "Errore installazione VS Code"
else
  log "VS Code già installato"
fi

## ───────────────────────────────────────
## ✅ Fine
## ───────────────────────────────────────
log "Setup completato con successo! 🔥"
echo -e "${YELLOW}➡ Riavvia il terminale per applicare i gruppi Docker${RESET}"

## ───────────────────────────────────────
## 📄 Riepilogo visivo in HTML
## ───────────────────────────────────────
title "Generazione riepilogo HTML"

mkdir -p "/home/$SUDO_USER/Documenti"

cat <<EOF > "/home/$SUDO_USER/Documenti/setup-riepilogo.html"
<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <title>Setup Dev - Christian</title>
  <style>
    body { font-family: sans-serif; background: #0e0e17; color: #eee; padding: 2rem; }
    h1, h2 { color: #00f2ff; }
    ul { line-height: 1.7; }
    li::before { content: "🔸 "; color: orange; }
    .section { margin-bottom: 2rem; }
    code { background: #222; padding: 2px 6px; border-radius: 5px; }
  </style>
</head>
<body>
  <h1>Setup Ambiente Sviluppo - Christian</h1>
  <p><strong>Ultimo aggiornamento:</strong> 19/07/2025 12:30</p>
  <p><strong>Distribuzione:</strong> Fedora Workstation</p>
  <p><strong>Utente:</strong> $SUDO_USER</p>

  <div class="section">
    <h2>Tool Base</h2>
    <ul>
      <li>zsh, neovim, git, curl, wget</li>
      <li>gcc, cmake, python3-pip, bat</li>
      <li>htop, btop, jq, ripgrep, fzf, tmux</li>
    </ul>
  </div>

  <div class="section">
    <h2>Frontend Web</h2>
    <ul>
      <li>Node.js + Yarn (con Corepack)</li>
      <li>Pronto per React, Next.js, Tailwind CSS</li>
    </ul>
  </div>

  <div class="section">
    <h2>Rust + Tauri</h2>
    <ul>
      <li>Rust Toolchain</li>
      <li><code>tauri-cli</code> per desktop app</li>
    </ul>
  </div>

  <div class="section">
    <h2>Container & DevOps</h2>
    <ul>
      <li>Docker + Docker Compose</li>
      <li>Podman + Buildah</li>
    </ul>
  </div>

  <div class="section">
    <h2>Editor</h2>
    <ul>
      <li>Visual Studio Code</li>
    </ul>
  </div>

  <p>✅ Tutto pronto per iniziare a creare il tuo sito e la tua app desktop!</p>
</body>
</html>
EOF

log "Riepilogo generato in: /home/$SUDO_USER/Documenti/setup-riepilogo.html"
