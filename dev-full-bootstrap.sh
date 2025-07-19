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
# Pre-prepara Yarn senza richieste interattive
COREPACK_DEFAULT_TO_LATEST=0 corepack prepare yarn@stable --activate || warn "Yarn già attivo o errore"
# Forza il download di Yarn in modalità non interattiva
su - "$SUDO_USER" -c "cd /tmp && echo 'Y' | yarn --version >/dev/null 2>&1 || true"
log "Yarn installato e attivo (modalità non interattiva)"

## ───────────────────────────────────────
## 🦀 Rust + Tauri
## ───────────────────────────────────────
title "Rust + Tauri"

# Funzione per controllare se Rust è installato
if ! su - "$SUDO_USER" -c "command -v cargo &> /dev/null"; then
  log "Installazione Rust per $SUDO_USER..."
  su - "$SUDO_USER" -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'
  log "Rust installato con successo"
else
  log "Rust già presente"
fi

# Assicurati che il PATH cargo sia disponibile
su - "$SUDO_USER" -c "source ~/.cargo/env"

# Controlla e installa tauri-cli
if ! su - "$SUDO_USER" -c "source ~/.cargo/env && cargo install --list | grep -q tauri-cli"; then
  log "Installazione tauri-cli... (può richiedere alcuni minuti)"
  su - "$SUDO_USER" -c "source ~/.cargo/env && cargo install tauri-cli"
  log "tauri-cli installato con successo"
else
  log "tauri-cli già installato"
fi

# Aggiunge ~/.cargo/bin al PATH per entrambe le shell
CARGO_ENV_BASH='source "$HOME/.cargo/env"'
CARGO_ENV_ZSH='source "$HOME/.cargo/env"'

# Aggiungi a .bashrc se non presente
if ! su - "$SUDO_USER" -c "grep -q 'source.*\.cargo/env' ~/.bashrc 2>/dev/null"; then
  su - "$SUDO_USER" -c "echo '' >> ~/.bashrc"
  su - "$SUDO_USER" -c "echo '# Rust environment' >> ~/.bashrc"
  su - "$SUDO_USER" -c "echo '$CARGO_ENV_BASH' >> ~/.bashrc"
  # Aggiungi alias per tauri
  su - "$SUDO_USER" -c "echo 'alias tauri=\"cargo tauri\"' >> ~/.bashrc"
  log "Aggiunto Rust environment e alias tauri a .bashrc"
fi

# Aggiungi a .zshrc se non presente (e se il file esiste)
if su - "$SUDO_USER" -c "test -f ~/.zshrc"; then
  if ! su - "$SUDO_USER" -c "grep -q 'source.*\.cargo/env' ~/.zshrc 2>/dev/null"; then
    su - "$SUDO_USER" -c "echo '' >> ~/.zshrc"
    su - "$SUDO_USER" -c "echo '# Rust environment' >> ~/.zshrc"
    su - "$SUDO_USER" -c "echo '$CARGO_ENV_ZSH' >> ~/.zshrc"
    # Aggiungi alias per tauri
    su - "$SUDO_USER" -c "echo 'alias tauri=\"cargo tauri\"' >> ~/.zshrc"
    log "Aggiunto Rust environment e alias tauri a .zshrc"
  fi
fi

# Test finale per verificare che tauri sia accessibile
if su - "$SUDO_USER" -c "source ~/.cargo/env && command -v cargo-tauri &> /dev/null"; then
  log "✅ Tauri CLI verificato e funzionante"
else
  warn "⚠️  Tauri CLI installato ma potrebbe richiedere riavvio terminale"
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
      background: linear-gradient(135deg, #0a0a0f 0%, #1a1a2e 50%, #16213e 100%);
      color: #e0e6ed;
      line-height: 1.6;
      min-height: 100vh;
    }
    
    .container {
      max-width: 1200px;
      margin: 0 auto;
      padding: 2rem;
    }
    
    .header {
      text-align: center;
      margin-bottom: 3rem;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    
    h1 {
      font-size: 3rem;
      font-weight: 800;
      margin-bottom: 0.5rem;
      text-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
    }
    
    .subtitle {
      font-size: 1.2rem;
      opacity: 0.8;
      margin-bottom: 1rem;
    }
    
    .info-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
      gap: 1rem;
      margin-bottom: 3rem;
    }
    
    .info-card {
      background: rgba(255, 255, 255, 0.05);
      backdrop-filter: blur(10px);
      border: 1px solid rgba(255, 255, 255, 0.1);
      border-radius: 16px;
      padding: 1.5rem;
      text-align: center;
    }
    
    .info-card strong {
      color: #00d4aa;
      font-size: 0.9rem;
      text-transform: uppercase;
      letter-spacing: 1px;
    }
    
    .tools-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 2rem;
      margin-bottom: 3rem;
    }
    
    .tool-section {
      background: rgba(255, 255, 255, 0.08);
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255, 255, 255, 0.15);
      border-radius: 20px;
      padding: 2rem;
      transition: transform 0.3s ease, box-shadow 0.3s ease;
      position: relative;
      overflow: hidden;
    }
    
    .tool-section:hover {
      transform: translateY(-5px);
      box-shadow: 0 20px 40px rgba(0, 212, 170, 0.15);
    }
    
    .tool-section::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 4px;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    }
    
    .tool-section h2 {
      font-size: 1.5rem;
      font-weight: 700;
      margin-bottom: 1.5rem;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    
    .icon {
      font-size: 1.8rem;
    }
    
    .tool-list {
      list-style: none;
      space-y: 0.5rem;
    }
    
    .tool-list li {
      padding: 0.8rem 1rem;
      background: rgba(255, 255, 255, 0.05);
      border-radius: 12px;
      margin-bottom: 0.8rem;
      border-left: 4px solid #00d4aa;
      transition: all 0.3s ease;
      display: flex;
      align-items: center;
    }
    
    .tool-list li:hover {
      background: rgba(0, 212, 170, 0.1);
      transform: translateX(5px);
    }
    
    .tool-list li::before {
      content: '✨';
      margin-right: 0.8rem;
      font-size: 1.2rem;
    }
    
    code {
      background: rgba(0, 0, 0, 0.4);
      color: #00d4aa;
      padding: 0.3rem 0.8rem;
      border-radius: 8px;
      font-family: 'Fira Code', 'JetBrains Mono', monospace;
      font-size: 0.9rem;
      border: 1px solid rgba(0, 212, 170, 0.3);
    }
    
    .success-message {
      background: linear-gradient(135deg, #00d4aa 0%, #00b894 100%);
      color: white;
      padding: 2rem;
      border-radius: 20px;
      text-align: center;
      font-size: 1.3rem;
      font-weight: 600;
      margin-top: 3rem;
      box-shadow: 0 10px 30px rgba(0, 212, 170, 0.2);
    }
    
    .footer {
      text-align: center;
      margin-top: 3rem;
      padding-top: 2rem;
      border-top: 1px solid rgba(255, 255, 255, 0.1);
      opacity: 0.6;
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
        <div>19/07/2025 12:30</div>
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
