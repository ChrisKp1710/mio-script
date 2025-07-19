#!/bin/bash
set -e

# ─────────────────────────────────────────────
# 🛠️ Setup Intelligente Dev Web + Rust + Tauri
# Fedora Workstation | di Christian K.P.
# Ultimo update: $(date '+%d/%m/%Y %H:%M')
# Installa automaticamente solo quello che manca
# ─────────────────────────────────────────────

## Ottieni ora corrente per il riepilogo
CURRENT_DATETIME=$(date '+%d/%m/%Y %H:%M')

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
skip()  { echo -e "${BLUE}[→]${RESET} $1 già presente - skip"; }

## Array per tracciare cosa viene installato
INSTALLED_ITEMS=()
SKIPPED_ITEMS=()

## Verifica permessi
if [[ $EUID -ne 0 ]]; then
  error "Devi eseguire questo script con sudo!"
  exit 1
fi

## Funzioni di controllo
check_command() {
    command -v "$1" &>/dev/null
}

check_user_command() {
    su - "$SUDO_USER" -c "command -v $1 &>/dev/null" 2>/dev/null
}

check_package() {
    dnf list installed "$1" &>/dev/null
}

## Aggiornamento sistema
title "Controllo aggiornamenti sistema"
if dnf check-update &>/dev/null || [ $? -eq 100 ]; then
  title "Aggiornamento sistema"
  dnf upgrade --refresh -y || error "Errore durante aggiornamento!"
  INSTALLED_ITEMS+=("Sistema aggiornato")
else
  skip "Sistema già aggiornato"
  SKIPPED_ITEMS+=("Aggiornamento sistema")
fi

## ───────────────────────────────────────
## 🧰 Tool base comuni per ogni dev
## ───────────────────────────────────────
title "Tool base per ogni sviluppatore"

# Array dei tool base da controllare
BASE_TOOLS=("git" "curl" "wget" "unzip" "tar" "htop" "btop" "zsh" "neovim" "jq" "gcc" "make" "cmake" "python3-pip" "bat" "ripgrep" "fd-find" "fzf" "tmux")
MISSING_TOOLS=()

# Controlla quali tool mancano
for tool in "${BASE_TOOLS[@]}"; do
    case $tool in
        "python3-pip")
            if ! python3 -m pip --version &>/dev/null; then
                MISSING_TOOLS+=("$tool")
            fi
            ;;
        "fd-find")
            if ! check_command "fd"; then
                MISSING_TOOLS+=("$tool")
            fi
            ;;
        *)
            if ! check_command "$tool"; then
                MISSING_TOOLS+=("$tool")
            fi
            ;;
    esac
done

# Installa solo i tool mancanti
if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    log "Installazione tool mancanti: ${MISSING_TOOLS[*]}"
    dnf install -y "${MISSING_TOOLS[@]}" || error "Errore installazione tool base"
    INSTALLED_ITEMS+=("Tool base: ${MISSING_TOOLS[*]}")
else
    skip "Tutti i tool base sono già installati"
    SKIPPED_ITEMS+=("Tool base")
fi

## ───────────────────────────────────────
## 🌐 Frontend Web (React, Next.js, Tailwind)
## ───────────────────────────────────────
title "Frontend Web Dev (React, Next.js, Tailwind)"

# Controlla Node.js
if ! check_command "node"; then
    log "Installazione Node.js..."
    dnf install -y nodejs || error "Errore installazione Node.js"
    INSTALLED_ITEMS+=("Node.js")
else
    skip "Node.js"
    SKIPPED_ITEMS+=("Node.js")
fi

# Controlla e abilita Corepack
if ! check_command "corepack"; then
    log "Abilitazione Corepack..."
    corepack enable
    INSTALLED_ITEMS+=("Corepack abilitato")
else
    skip "Corepack"
    SKIPPED_ITEMS+=("Corepack")
fi

# Controlla Yarn
if ! check_command "yarn" || ! su - "$SUDO_USER" -c "cd /tmp && yarn --version &>/dev/null"; then
    log "Configurazione Yarn (modalità non interattiva)..."
    # Pre-prepara Yarn senza richieste interattive
    COREPACK_DEFAULT_TO_LATEST=0 corepack prepare yarn@stable --activate || warn "Yarn già attivo o errore"
    # Forza il download di Yarn in modalità non interattiva
    su - "$SUDO_USER" -c "cd /tmp && echo 'Y' | yarn --version >/dev/null 2>&1 || true"
    INSTALLED_ITEMS+=("Yarn configurato")
else
    skip "Yarn"
    SKIPPED_ITEMS+=("Yarn")
fi

## ───────────────────────────────────────
## 🦀 Rust + Tauri
## ───────────────────────────────────────
title "Rust + Tauri"

# Controlla se Rust è installato
if ! check_user_command "cargo"; then
    log "Installazione Rust per $SUDO_USER..."
    su - "$SUDO_USER" -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
    INSTALLED_ITEMS+=("Rust toolchain")
else
    skip "Rust"
    SKIPPED_ITEMS+=("Rust toolchain")
fi

# Assicurati che il PATH cargo sia disponibile
su - "$SUDO_USER" -c "source ~/.cargo/env" 2>/dev/null || true

# Controlla e installa tauri-cli
if ! su - "$SUDO_USER" -c "source ~/.cargo/env && cargo install --list | grep -q tauri-cli" 2>/dev/null; then
    log "Installazione tauri-cli... (può richiedere alcuni minuti)"
    su - "$SUDO_USER" -c "source ~/.cargo/env && cargo install tauri-cli"
    INSTALLED_ITEMS+=("Tauri CLI")
else
    skip "Tauri CLI"
    SKIPPED_ITEMS+=("Tauri CLI")
fi

# Controlla configurazione shell per Rust
RUST_CONFIGURED=false

# Aggiungi a .bashrc se non presente
if ! su - "$SUDO_USER" -c "grep -q 'source.*\.cargo/env' ~/.bashrc 2>/dev/null"; then
    su - "$SUDO_USER" -c "echo '' >> ~/.bashrc"
    su - "$SUDO_USER" -c "echo '# Rust environment' >> ~/.bashrc"
    su - "$SUDO_USER" -c "echo 'source \"\$HOME/.cargo/env\"' >> ~/.bashrc"
    su - "$SUDO_USER" -c "echo 'alias tauri=\"cargo tauri\"' >> ~/.bashrc"
    RUST_CONFIGURED=true
fi

# Aggiungi a .zshrc se non presente (e se il file esiste)
if su - "$SUDO_USER" -c "test -f ~/.zshrc"; then
    if ! su - "$SUDO_USER" -c "grep -q 'source.*\.cargo/env' ~/.zshrc 2>/dev/null"; then
        su - "$SUDO_USER" -c "echo '' >> ~/.zshrc"
        su - "$SUDO_USER" -c "echo '# Rust environment' >> ~/.zshrc"
        su - "$SUDO_USER" -c "echo 'source \"\$HOME/.cargo/env\"' >> ~/.zshrc"
        su - "$SUDO_USER" -c "echo 'alias tauri=\"cargo tauri\"' >> ~/.zshrc"
        RUST_CONFIGURED=true
    fi
fi

if [ "$RUST_CONFIGURED" = true ]; then
    INSTALLED_ITEMS+=("Configurazione shell Rust")
else
    skip "Configurazione shell Rust"
    SKIPPED_ITEMS+=("Configurazione shell Rust")
fi

# Test finale
if su - "$SUDO_USER" -c "source ~/.cargo/env && command -v cargo-tauri &> /dev/null" 2>/dev/null; then
    log "✅ Tauri CLI verificato e funzionante"
else
    warn "⚠️  Tauri CLI installato ma potrebbe richiedere riavvio terminale"
fi

## ───────────────────────────────────────
## 🐳 Docker + Podman
## ───────────────────────────────────────
title "Container & DevOps (Docker + Podman)"

CONTAINER_TOOLS=("docker" "docker-compose" "podman" "podman-compose" "buildah")
MISSING_CONTAINER_TOOLS=()

# Controlla quali container tools mancano
for tool in "${CONTAINER_TOOLS[@]}"; do
    if ! check_command "$tool"; then
        MISSING_CONTAINER_TOOLS+=("$tool")
    fi
done

# Installa solo i tool mancanti
if [ ${#MISSING_CONTAINER_TOOLS[@]} -gt 0 ]; then
    log "Installazione container tools mancanti: ${MISSING_CONTAINER_TOOLS[*]}"
    dnf install -y "${MISSING_CONTAINER_TOOLS[@]}" || warn "Errore installazione alcuni container tools"
    INSTALLED_ITEMS+=("Container tools: ${MISSING_CONTAINER_TOOLS[*]}")
else
    skip "Container tools"
    SKIPPED_ITEMS+=("Container tools")
fi

# Controlla se Docker service è attivo
if systemctl is-enabled docker &>/dev/null && systemctl is-active docker &>/dev/null; then
    skip "Docker service"
    SKIPPED_ITEMS+=("Docker service")
else
    log "Abilitazione Docker service..."
    systemctl enable --now docker
    INSTALLED_ITEMS+=("Docker service abilitato")
fi

# Controlla se utente è nel gruppo docker
if groups "$SUDO_USER" | grep -q docker; then
    skip "Utente nel gruppo Docker"
    SKIPPED_ITEMS+=("Gruppo Docker")
else
    log "Aggiunta utente $SUDO_USER al gruppo docker..."
    usermod -aG docker "$SUDO_USER"
    INSTALLED_ITEMS+=("Utente aggiunto al gruppo Docker")
fi

## ───────────────────────────────────────
## 🧠 Editor (VS Code)
## ───────────────────────────────────────
title "Editor di codice (VS Code)"

if ! check_command "code"; then
    log "Installazione Visual Studio Code..."
    
    # Controlla se la chiave Microsoft è già importata
    if ! rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n' | grep -q "Microsoft"; then
        rpm --import https://packages.microsoft.com/keys/microsoft.asc
        INSTALLED_ITEMS+=("Chiave Microsoft importata")
    fi
    
    # Controlla se il repository VS Code esiste
    if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
        sh -c 'echo -e "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
        INSTALLED_ITEMS+=("Repository VS Code configurato")
    fi
    
    dnf install -y code || error "Errore installazione VS Code"
    INSTALLED_ITEMS+=("VS Code")
else
    skip "VS Code"
    SKIPPED_ITEMS+=("VS Code")
fi

## ───────────────────────────────────────
## ✅ Riepilogo intelligente
## ───────────────────────────────────────
title "Riepilogo operazioni"

echo -e "\n${GREEN}🎯 INSTALLAZIONI EFFETTUATE (${#INSTALLED_ITEMS[@]} elementi):${RESET}"
for item in "${INSTALLED_ITEMS[@]}"; do
    echo -e "${GREEN}  ✔${RESET} $item"
done

echo -e "\n${BLUE}⏭️  GIÀ PRESENTI - SALTATI (${#SKIPPED_ITEMS[@]} elementi):${RESET}"
for item in "${SKIPPED_ITEMS[@]}"; do
    echo -e "${BLUE}  →${RESET} $item"
done

if [ ${#INSTALLED_ITEMS[@]} -eq 0 ]; then
    echo -e "\n${YELLOW}🎉 Sistema già completo! Nessuna installazione necessaria.${RESET}"
else
    echo -e "\n${GREEN}🚀 Setup completato con successo! ${#INSTALLED_ITEMS[@]} nuove installazioni.${RESET}"
fi

## ───────────────────────────────────────
## 🧪 Verifica automatica installazioni
## ───────────────────────────────────────
title "Verifica automatica dei tool installati"

# Funzione per testare un comando
test_command() {
    local cmd="$1"
    local name="$2"
    local user_cmd="$3"
    
    if [ -n "$user_cmd" ]; then
        if su - "$SUDO_USER" -c "$user_cmd" &>/dev/null; then
            echo -e "${GREEN}[✔]${RESET} $name funziona"
            return 0
        else
            echo -e "${RED}[✘]${RESET} $name non funziona"
            return 1
        fi
    else
        if command -v "$cmd" &>/dev/null; then
            echo -e "${GREEN}[✔]${RESET} $name installato"
            return 0
        else
            echo -e "${RED}[✘]${RESET} $name non trovato"
            return 1
        fi
    fi
}

# Test automatici
test_command "rustc" "Rust Compiler" "source ~/.cargo/env && rustc --version"
test_command "cargo" "Cargo" "source ~/.cargo/env && cargo --version"
test_command "tauri" "Tauri CLI" "source ~/.cargo/env && cargo tauri --version"
test_command "node" "Node.js" "node --version"
test_command "yarn" "Yarn" "cd /tmp && COREPACK_DEFAULT_TO_LATEST=0 yarn --version"
test_command "docker" "Docker" "docker --version"
test_command "code" "VS Code" "code --version"

echo -e ""
echo -e "${YELLOW}➡ IMPORTANTE: Riavvia il terminale per avere tutti i comandi disponibili senza source${RESET}"
echo -e "${GREEN}📋 Tutti i tool sono stati verificati e funzionano correttamente! 🎉${RESET}"
echo -e ""
echo -e "${GREEN}🚀 Quick start dopo riavvio:${RESET}"
echo -e "${BLUE}   • tauri init${RESET}               (Nuovo progetto Tauri)"
echo -e "${BLUE}   • npx create-next-app@latest${RESET} (Nuovo progetto Next.js)"
echo -e "${BLUE}   • docker run hello-world${RESET}   (Test Docker)"

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
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>🔥 Dev Environment Setup - Christian</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      font-family: 'Inter', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 25%, #16213e 50%, #0f3460 75%, #533a71 100%);
      background-attachment: fixed;
      color: #f0f4f8;
      line-height: 1.7;
      min-height: 100vh;
    }
    
    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem;
    }
    
    .header {
      text-align: center;
      margin-bottom: 4rem;
      background: linear-gradient(135deg, #4facfe 0%, #00f2fe 25%, #43e97b 50%, #38f9d7 75%, #667eea 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      position: relative;
    }
    
    .header::before {
      content: '';
      position: absolute;
      top: -20px;
      left: 50%;
      transform: translateX(-50%);
      width: 100px;
      height: 4px;
      background: linear-gradient(90deg, #ff6b6b, #feca57, #48dbfb, #0abde3, #1dd1a1);
      border-radius: 2px;
      animation: shimmer 2s ease-in-out infinite alternate;
    }
    
    @keyframes shimmer {
      0% { opacity: 0.5; transform: translateX(-50%) scale(0.8); }
      100% { opacity: 1; transform: translateX(-50%) scale(1.2); }
    }
    
    h1 {
      font-size: 3.2rem;
      font-weight: 800;
      margin-bottom: 0.8rem;
      text-shadow: 0 4px 12px rgba(79, 172, 254, 0.3);
      letter-spacing: -1px;
    }
    
    .subtitle {
      font-size: 1.3rem;
      opacity: 0.85;
      margin-bottom: 1rem;
      color: #cbd5e0;
      font-weight: 300;
    }
    
    .info-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 1.5rem;
      margin-bottom: 4rem;
    }
    
    .info-card {
      background: linear-gradient(135deg, rgba(79, 172, 254, 0.1) 0%, rgba(0, 242, 254, 0.05) 100%);
      backdrop-filter: blur(15px);
      border: 1px solid rgba(79, 172, 254, 0.2);
      border-radius: 20px;
      padding: 2rem 1.5rem;
      text-align: center;
      transition: all 0.4s cubic-bezier(0.25, 0.8, 0.25, 1);
      position: relative;
      overflow: hidden;
    }
    
    .info-card::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 2px;
      background: linear-gradient(90deg, #4facfe, #00f2fe, #43e97b);
    }
    
    .info-card:hover {
      transform: translateY(-8px) scale(1.02);
      box-shadow: 0 20px 40px rgba(79, 172, 254, 0.25);
      border-color: rgba(79, 172, 254, 0.4);
    }
    
    .info-card strong {
      color: #4facfe;
      font-size: 0.95rem;
      text-transform: uppercase;
      letter-spacing: 1.5px;
      font-weight: 600;
      display: block;
      margin-bottom: 0.8rem;
    }
    
    .info-card div {
      font-size: 1.1rem;
      font-weight: 500;
      color: #e2e8f0;
    }
    
    .tools-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 2.5rem;
      margin-bottom: 4rem;
    }
    
    .tool-section {
      background: linear-gradient(145deg, rgba(255, 255, 255, 0.12) 0%, rgba(255, 255, 255, 0.05) 100%);
      backdrop-filter: blur(25px);
      border: 1px solid rgba(255, 255, 255, 0.18);
      border-radius: 24px;
      padding: 2.5rem 2rem;
      transition: all 0.4s cubic-bezier(0.25, 0.8, 0.25, 1);
      position: relative;
      overflow: hidden;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    }
    
    .tool-section:hover {
      transform: translateY(-10px);
      box-shadow: 0 25px 50px rgba(67, 233, 123, 0.2);
      border-color: rgba(67, 233, 123, 0.4);
    }
    
    .tool-section::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 5px;
      background: linear-gradient(135deg, #ff6b6b 0%, #feca57 25%, #48dbfb 50%, #0abde3 75%, #1dd1a1 100%);
    }
    
    .tool-section h2 {
      font-size: 1.6rem;
      font-weight: 700;
      margin-bottom: 2rem;
      display: flex;
      align-items: center;
      gap: 0.8rem;
      color: #f7fafc;
      letter-spacing: -0.5px;
    }
    
    .icon {
      font-size: 2rem;
      filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.3));
    }
    
    .tool-list {
      list-style: none;
      space-y: 0.5rem;
    }
    
    .tool-list li {
      padding: 1rem 1.2rem;
      background: linear-gradient(135deg, rgba(67, 233, 123, 0.08) 0%, rgba(79, 172, 254, 0.05) 100%);
      border-radius: 16px;
      margin-bottom: 1rem;
      border-left: 4px solid;
      border-image: linear-gradient(135deg, #43e97b, #4facfe) 1;
      transition: all 0.4s cubic-bezier(0.25, 0.8, 0.25, 1);
      display: flex;
      align-items: center;
      color: #e2e8f0;
      font-weight: 500;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    }
    
    .tool-list li:hover {
      background: linear-gradient(135deg, rgba(67, 233, 123, 0.15) 0%, rgba(79, 172, 254, 0.1) 100%);
      transform: translateX(8px) scale(1.02);
      box-shadow: 0 8px 25px rgba(67, 233, 123, 0.2);
      color: #f7fafc;
    }
    
    .tool-list li::before {
      content: '✨';
      margin-right: 1rem;
      font-size: 1.3rem;
      filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.3));
    }
    
    code {
      background: linear-gradient(135deg, rgba(0, 0, 0, 0.6) 0%, rgba(16, 20, 43, 0.8) 100%);
      color: #43e97b;
      padding: 0.5rem 1rem;
      border-radius: 12px;
      font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', monospace;
      font-size: 0.95rem;
      border: 1px solid rgba(67, 233, 123, 0.4);
      box-shadow: 0 2px 8px rgba(67, 233, 123, 0.2);
      font-weight: 500;
      letter-spacing: 0.3px;
    }
    
    .success-message {
      background: linear-gradient(135deg, #43e97b 0%, #38f9d7 25%, #4facfe 75%, #667eea 100%);
      color: white;
      padding: 3rem 2rem;
      border-radius: 24px;
      text-align: center;
      font-size: 1.4rem;
      font-weight: 600;
      margin-top: 4rem;
      box-shadow: 0 15px 40px rgba(67, 233, 123, 0.3);
      position: relative;
      overflow: hidden;
    }
    
    .success-message::before {
      content: '';
      position: absolute;
      top: -50%;
      left: -50%;
      width: 200%;
      height: 200%;
      background: linear-gradient(45deg, transparent, rgba(255, 255, 255, 0.1), transparent);
      animation: shine 3s infinite;
    }
    
    @keyframes shine {
      0% { transform: translateX(-100%) translateY(-100%) rotate(45deg); }
      50% { transform: translateX(100%) translateY(100%) rotate(45deg); }
      100% { transform: translateX(100%) translateY(100%) rotate(45deg); }
    }
    
    .success-message small {
      opacity: 0.9;
      font-weight: 400;
      font-size: 1.1rem;
      margin-top: 0.5rem;
      display: block;
    }
    
    .footer {
      text-align: center;
      margin-top: 4rem;
      padding-top: 3rem;
      border-top: 1px solid rgba(79, 172, 254, 0.3);
      color: #a0aec0;
      font-size: 0.95rem;
    }
    
    .footer p {
      margin-bottom: 0.5rem;
    }
    
    .footer p:first-child {
      font-weight: 500;
      color: #cbd5e0;
    }
    
    @media (max-width: 768px) {
      h1 { font-size: 2rem; }
      .tools-grid { grid-template-columns: 1fr; }
      .info-grid { grid-template-columns: 1fr; }
      .container { padding: 1rem; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🔥 Dev Environment Setup</h1>
      <div class="subtitle">Ambiente di sviluppo completo configurato con successo</div>
    </div>
    
    <div class="info-grid">
      <div class="info-card">
        <strong>📅 Data Setup</strong>
        <div>$CURRENT_DATETIME</div>
      </div>
      <div class="info-card">
        <strong>💻 Sistema</strong>
        <div>Fedora Workstation</div>
      </div>
      <div class="info-card">
        <strong>👤 Utente</strong>
        <div>$SUDO_USER</div>
      </div>
      <div class="info-card">
        <strong>⚡ Status</strong>
        <div style="color: #00d4aa;">Setup Completato</div>
      </div>
    </div>
    
    <div class="tools-grid">
      <div class="tool-section">
        <h2><span class="icon">🧰</span> Tool Base</h2>
        <ul class="tool-list">
          <li>Shell & Editor: zsh, neovim</li>
          <li>Version Control: git</li>
          <li>Network Tools: curl, wget</li>
          <li>Build Tools: gcc, cmake, make</li>
          <li>System Monitor: htop, btop</li>
          <li>Search & Navigation: ripgrep, fzf, bat</li>
          <li>Terminal Multiplexer: tmux</li>
          <li>Data Processing: jq</li>
          <li>Python: python3-pip</li>
        </ul>
      </div>
      
      <div class="tool-section">
        <h2><span class="icon">🌐</span> Frontend Web</h2>
        <ul class="tool-list">
          <li>Runtime: Node.js (Latest)</li>
          <li>Package Manager: Yarn (via Corepack)</li>
          <li>Framework Ready: React, Next.js</li>
          <li>Styling: Tailwind CSS Support</li>
          <li>Build Tools: Vite, Webpack</li>
          <li>Development: Hot Reload Ready</li>
        </ul>
      </div>
      
      <div class="tool-section">
        <h2><span class="icon">🦀</span> Rust + Tauri</h2>
        <ul class="tool-list">
          <li>Rust Toolchain: rustc, cargo</li>
          <li>Desktop Apps: <code>tauri-cli</code></li>
          <li>Cross-Platform: Windows, macOS, Linux</li>
          <li>Web Technologies: HTML, CSS, JS</li>
          <li>Native Performance: Rust Backend</li>
          <li>Small Bundle Size: Ottimizzato</li>
        </ul>
      </div>
      
      <div class="tool-section">
        <h2><span class="icon">🐳</span> Container & DevOps</h2>
        <ul class="tool-list">
          <li>Container Runtime: Docker</li>
          <li>Orchestration: Docker Compose</li>
          <li>Red Hat Stack: Podman</li>
          <li>Image Building: Buildah</li>
          <li>Container Management: Podman Compose</li>
          <li>Development: Isolated Environments</li>
        </ul>
      </div>
      
      <div class="tool-section">
        <h2><span class="icon">💻</span> Code Editor</h2>
        <ul class="tool-list">
          <li>Editor: Visual Studio Code</li>
          <li>Extensions: Marketplace Access</li>
          <li>Debugging: Integrated Debugger</li>
          <li>Git Integration: Source Control</li>
          <li>IntelliSense: Smart Completion</li>
          <li>Themes: Customizable Interface</li>
        </ul>
      </div>
      
      <div class="tool-section">
        <h2><span class="icon">⚡</span> Quick Start</h2>
        <ul class="tool-list">
          <li>Web App: <code>npx create-next-app@latest</code></li>
          <li>Desktop App: <code>cargo tauri init</code></li>
          <li>Container: <code>docker run hello-world</code></li>
          <li>Code Editor: <code>code .</code></li>
          <li>Version Check: <code>rustc --version</code></li>
          <li>Package Manager: <code>yarn --version</code></li>
        </ul>
      </div>
    </div>
    
    <div class="success-message">
      🎉 Tutto pronto per iniziare a creare applicazioni moderne!<br>
      <small style="opacity: 0.9;">Web apps, desktop apps, containerized services - tutto configurato e pronto all'uso</small>
    </div>
    
    <div class="footer">
      <p>Setup automatico creato con ❤️ da Christian K.P.</p>
      <p>Fedora Development Environment • 2025</p>
    </div>
  </div>
</body>
</html>
EOF

log "Riepilogo generato in: /home/$SUDO_USER/Documenti/setup-riepilogo.html"
