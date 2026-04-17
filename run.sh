#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$BASE_DIR/bin"

# Activa venv si existe (para que encuentre comandos pip)
if [[ -f "$BASE_DIR/.venv/bin/activate" ]]; then
  source "$BASE_DIR/.venv/bin/activate"
fi

pause(){ read -r -p "Enter para volver al menu..." _; }

tool_desc() {
  local f="$1"
  local d
  d="$(grep -m1 '^# WOLF_DESC:' "$f" 2>/dev/null | sed 's/^# WOLF_DESC:[[:space:]]*//')"
  echo "${d:-Sin descripcion}"
}

while true; do
  clear
  echo "WOLFPACK SOCMINT - Launcher"
  echo
  echo "TOOL           DESCRIPCION"
  echo "-----------------------------------------------"

  mapfile -t TOOLS < <(find "$BIN_DIR" -maxdepth 1 -type f -executable -printf "%f\n" | sort)
  [[ ${#TOOLS[@]} -gt 0 ]] || { echo "[!] No hay herramientas en $BIN_DIR"; exit 1; }

  i=1
  for t in "${TOOLS[@]}"; do
    printf "%2d) %-12s %s\n" "$i" "$t" "$(tool_desc "$BIN_DIR/$t")"
    ((i++))
  done
  echo " 0) Salir"
  echo
echo " [SM] Social Mapper (Experimental)"
  read -r -p "Elige numero: " opt
  [[ "$opt" == "0" ]] && exit 0
  [[ "$opt" =~ ^[0-9]+$ ]] || { echo "[!] Opcion invalida"; pause; continue; }
  (( opt>=1 && opt<=${#TOOLS[@]} )) || { echo "[!] Fuera de rango"; pause; continue; }

  tool="${TOOLS[$((opt-1))]}"
  echo
  read -r -p "Args (opcional, Enter para ninguno): " argsline
  read -r -a args_arr <<< "$argsline"

  echo
  echo "[*] Ejecutando: $tool ${args_arr[*]}"
  echo "-----------------------------------------------"
  set +e
  "$BIN_DIR/$tool" "${args_arr[@]}"
  code=$?
  set -e
  echo "-----------------------------------------------"
  echo "[*] Exit code: $code"
  pause
done


SM|sm)
  x-terminal-emulator -e bash -lc '$HOME/wolfpack-socmint/bin/social-mapper --help; echo; echo "Pulsa Enter para cerrar..."; read'
  ;;
