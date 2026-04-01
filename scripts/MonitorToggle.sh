#!/usr/bin/env bash

# --- FUNÇÕES ---
move_all_workspaces_to_monitor() {
  TARGET_MONITOR="$1"
  # Verifica se o monitor alvo existe para evitar erros
  if [ -n "$TARGET_MONITOR" ]; then
    hyprctl workspaces | grep ^workspace | cut --delimiter ' ' --fields 3 |
      xargs -I '{}' hyprctl dispatch moveworkspacetomonitor '{}' "$TARGET_MONITOR"
  fi
}

# --- DETECÇÃO AUTOMÁTICA ---

# 1. Detectar Monitor Interno
# Procura por um monitor que comece com "eDP" (padrão para Embedded DisplayPort em laptops)
INTERNAL_MONITOR=$(hyprctl monitors all | grep "Monitor" | awk '{print $2}' | grep "^eDP" | head -n 1)

# Fallback: Se não achar nada com eDP, assume eDP-1 ou tenta pegar o primeiro da lista se for um desktop sem eDP
if [ -z "$INTERNAL_MONITOR" ]; then
  INTERNAL_MONITOR="eDP-1"
fi

# 2. Detectar Monitor Externo
# Lista todos os monitores, remove o interno da lista, e pega o primeiro que sobrar
EXTERNAL_MONITOR=$(hyprctl monitors all | grep "Monitor" | awk '{print $2}' | grep -v "$INTERNAL_MONITOR" | head -n 1)

# Contagem de monitores conectados
NUM_MONITORS_CONNECTED=$(hyprctl monitors all | grep --count Monitor)

# --- LÓGICA ---

# Modo Toggle (acionado manualmente via atalho)
if [ "$1" = "toggle" ]; then
  # Verifica se o monitor externo existe
  if [ -n "$EXTERNAL_MONITOR" ]; then
    # Checa se o externo já está ATIVO no momento
    if hyprctl monitors | grep -q "$EXTERNAL_MONITOR"; then
      # Externo está ativo -> Vai para o Interno
      echo "Alternando para monitor interno ($INTERNAL_MONITOR)..."
      hyprctl keyword monitor "$INTERNAL_MONITOR, preferred, auto, 1"
      move_all_workspaces_to_monitor "$INTERNAL_MONITOR"
      hyprctl keyword monitor "$EXTERNAL_MONITOR, disable"
    else
      # Interno está ativo -> Vai para o Externo
      echo "Alternando para monitor externo ($EXTERNAL_MONITOR)..."
      hyprctl keyword monitor "$EXTERNAL_MONITOR, preferred, auto, 1"
      move_all_workspaces_to_monitor "$EXTERNAL_MONITOR"
      hyprctl keyword monitor "$INTERNAL_MONITOR, disable"
    fi
  else
    echo "Nenhum monitor externo detectado para alternar."
  fi
  exit 0
fi

# Modo Automático (acionado no startup)
if [ -n "$EXTERNAL_MONITOR" ]; then
  # Se existe externo conectado, usa ele e desliga o note
  echo "Monitor externo detectado ($EXTERNAL_MONITOR). Configurando..."
  hyprctl keyword monitor "$EXTERNAL_MONITOR, preferred, auto, 1"
  move_all_workspaces_to_monitor "$EXTERNAL_MONITOR"
  hyprctl keyword monitor "$INTERNAL_MONITOR, disable"
else
  # Se não existe externo, garante que o do note está ligado
  echo "Apenas monitor interno detectado ($INTERNAL_MONITOR)."
  hyprctl keyword monitor "$INTERNAL_MONITOR, preferred, auto, 1"
  move_all_workspaces_to_monitor "$INTERNAL_MONITOR"
fi
