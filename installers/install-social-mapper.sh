#!/usr/bin/env bash
set -euo pipefail

# =========================
# WOLFPACK SOCMINT - Social Mapper Installer (Experimental/Legacy)
# =========================

BASE="${HOME}/wolfpack-socmint"
TOOLS_DIR="${BASE}/tools"
VENVS_DIR="${BASE}/venvs"
BIN_DIR="${BASE}/bin"
LOGS_DIR="${BASE}/logs"
INSTALLERS_DIR="${BASE}/installers"

TOOL_NAME="social_mapper"
TOOL_DIR="${TOOLS_DIR}/${TOOL_NAME}"
VENV_DIR="${VENVS_DIR}/social-mapper"
WRAPPER="${BIN_DIR}/social-mapper"
LOGFILE="${LOGS_DIR}/install-social-mapper-$(date +%F_%H%M%S).log"

REPO_URL="https://github.com/Greenwolf/social_mapper.git"
REPO_BRANCH="master"

mkdir -p "$TOOLS_DIR" "$VENVS_DIR" "$BIN_DIR" "$LOGS_DIR" "$INSTALLERS_DIR"

# Tee log to file + screen
exec > >(tee -a "$LOGFILE") 2>&1

echo "==============================================="
echo "[*] WOLFPACK SOCMINT - Instalación Social Mapper"
echo "[*] Fecha: $(date)"
echo "[*] Log: $LOGFILE"
echo "==============================================="

# --- Helpers ---
have_cmd() { command -v "$1" >/dev/null 2>&1; }

detect_python() {
  if have_cmd python3; then
    echo "python3"
  else
    echo ""
  fi
}

PYTHON_BIN="$(detect_python)"
if [[ -z "$PYTHON_BIN" ]]; then
  echo "[!] No se encontró python3."
  exit 1
fi

echo "[*] Python detectado: $PYTHON_BIN"
"$PYTHON_BIN" --version || true

# --- Dependencias de sistema mínimas ---
APT_PKGS=()
have_cmd git || APT_PKGS+=("git")
dpkg -s python3-venv >/dev/null 2>&1 || APT_PKGS+=("python3-venv")
dpkg -s python3-pip >/dev/null 2>&1 || APT_PKGS+=("python3-pip")

if (( ${#APT_PKGS[@]} > 0 )); then
  echo "[*] Instalando dependencias del sistema: ${APT_PKGS[*]}"
  sudo apt-get update
  sudo apt-get install -y "${APT_PKGS[@]}"
else
  echo "[*] Dependencias base ya presentes."
fi

# --- Clonar/actualizar repo ---
if [[ -d "${TOOL_DIR}/.git" ]]; then
  echo "[*] Repo ya existe. Actualizando..."
  git -C "$TOOL_DIR" fetch --all --prune
  git -C "$TOOL_DIR" checkout "$REPO_BRANCH"
  git -C "$TOOL_DIR" pull --ff-only || {
    echo "[!] No se pudo hacer pull limpio. Continúo con la copia existente."
  }
else
  echo "[*] Clonando repo en: $TOOL_DIR"
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$TOOL_DIR"
fi

# --- Crear venv ---
if [[ ! -d "$VENV_DIR" ]]; then
  echo "[*] Creando entorno virtual: $VENV_DIR"
  "$PYTHON_BIN" -m venv "$VENV_DIR"
else
  echo "[*] venv ya existe: $VENV_DIR"
fi

# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

echo "[*] Actualizando pip/setuptools/wheel en venv..."
python -m pip install --upgrade pip setuptools wheel

# --- Instalar requirements (si existen) ---
REQ_FILE=""
if [[ -f "${TOOL_DIR}/setup/requirements.txt" ]]; then
  REQ_FILE="${TOOL_DIR}/setup/requirements.txt"
elif [[ -f "${TOOL_DIR}/requirements.txt" ]]; then
  REQ_FILE="${TOOL_DIR}/requirements.txt"
fi

if [[ -n "$REQ_FILE" ]]; then
  echo "[*] Instalando requirements desde: $REQ_FILE"
  set +e
  python -m pip install -r "$REQ_FILE"
  PIP_REQ_RC=$?
  set -e
  if [[ $PIP_REQ_RC -ne 0 ]]; then
    echo "[!] Algunas dependencias fallaron (normal en herramientas legacy)."
    echo "[!] Continuamos y dejamos integrado para pruebas manuales."
  fi
else
  echo "[!] No se encontró requirements.txt. Continuamos."
fi

# --- Intento opcional de instalar common deps útiles (sin abortar) ---
echo "[*] Intentando instalar dependencias comunes opcionales (best effort)..."
set +e
python -m pip install requests beautifulsoup4 lxml tqdm
set -e

# --- Crear wrapper en bin/ ---
echo "[*] Creando wrapper: $WRAPPER"
cat > "$WRAPPER" <<'EOF_WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

BASE="${HOME}/wolfpack-socmint"
TOOL_DIR="${BASE}/tools/social_mapper"
VENV="${BASE}/venvs/social-mapper"
LOGS="${BASE}/logs"

mkdir -p "$LOGS"

if [[ ! -d "$TOOL_DIR" ]]; then
  echo "[!] Social Mapper no está instalado en: $TOOL_DIR"
  echo "[i] Ejecuta el instalador primero."
  exit 1
fi

if [[ ! -f "$VENV/bin/activate" ]]; then
  echo "[!] venv no encontrado en: $VENV"
  echo "[i] Ejecuta el instalador primero."
  exit 1
fi

# shellcheck disable=SC1090
source "$VENV/bin/activate"
cd "$TOOL_DIR"

if [[ ! -f "social_mapper.py" ]]; then
  echo "[!] No se encontró social_mapper.py en $TOOL_DIR"
  exit 1
fi

echo "[*] Ejecutando Social Mapper (Experimental/Legacy)"
echo "[*] Directorio: $TOOL_DIR"
echo "[*] Python: $(python --version 2>&1)"
echo "[*] Log runtime: $LOGS/social-mapper-runtime.log"
echo

python social_mapper.py "$@" 2>&1 | tee -a "$LOGS/social-mapper-runtime.log"
EOF_WRAPPER

chmod +x "$WRAPPER"

# --- Prueba rápida de integración ---
echo "[*] Prueba de wrapper (help/version tentativa)..."
set +e
"$WRAPPER" --help >/dev/null 2>&1
TEST_RC=$?
set -e

if [[ $TEST_RC -eq 0 ]]; then
  echo "[+] Prueba OK: el wrapper responde a --help."
else
  echo "[!] La prueba --help no respondió correctamente (esperable en algunos forks legacy)."
  echo "[!] Aun así, la integración quedó instalada. Revisa logs y prueba manual."
fi

# --- Resumen ---
echo
echo "==============================================="
echo "[+] Instalación/integración completada (modo experimental)"
echo "[+] Repo:    $TOOL_DIR"
echo "[+] venv:    $VENV_DIR"
echo "[+] Wrapper: $WRAPPER"
echo "[+] Log:     $LOGFILE"
echo "==============================================="
echo
echo "Uso manual:"
echo "  $WRAPPER --help"
echo
echo "Sugerencia para launcher:"
echo "  x-terminal-emulator -e bash -lc '\$HOME/wolfpack-socmint/bin/social-mapper --help; exec bash'"
