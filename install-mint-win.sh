#!/bin/bash

# ==============================================================================
# Script d'installation automatique et IDEMPOTENT pour Linux Mint
# Objectif : Installer FreeOffice, Master PDF Editor et le pack visuel Windows 11
# ==============================================================================

set -euo pipefail

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ------------------------------------------------------------------------------
# 1. Validation des privilèges et prérequis d'affichage
# ------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Erreur : Veuillez exécuter ce script avec sudo : sudo bash $0${NC}"
  exit 1
fi

# Installation immédiate de dialog si absent pour afficher l'interface
if ! command -v dialog >/dev/null 2>&1; then
    echo -e "${BLUE}Installation du paquet prérequis 'dialog'...${NC}"
    apt-get update -qq && apt-get install -y -qq dialog
fi

# ------------------------------------------------------------------------------
# 2. Page d'avertissement et décharge de responsabilité (Disclaimer)
# ------------------------------------------------------------------------------
DISCLAIMER_TEXT="
AVERTISSEMENT ET DÉCHARGE DE RESPONSABILITÉ

Ce script apporte des modifications importantes à votre environnement :
- Ajout de dépôts logiciels tiers (SoftMaker FreeOffice)
- Téléchargement et installation de paquets .deb (Master PDF Editor)
- Modification des thèmes système et icônes utilisateur

CE SCRIPT EST FOURNI « EN L'ÉTAT », SANS AUCUNE GARANTIE EXPRESSE
OU IMPLICITE. L'AUTEUR DÉCLINE TOUTE RESPONSABILITÉ EN CAS DE
DYSFONCTIONNEMENT, INSTABILITÉ DU SYSTÈME OU PERTE DE DONNÉES.

L'exécution de ce script se fait sous votre entière responsabilité.

Acceptez-vous ces conditions et souhaitez-vous poursuivre ?"

if ! dialog --clear \
    --backtitle "Personnalisation Linux Mint - Style Windows 11" \
    --title " CLAUSE DE NON-RESPONSABILITÉ " \
    --yes-label "Accepter" \
    --no-label "Refuser" \
    --yesno "$DISCLAIMER_TEXT" 18 72; then
    clear
    echo -e "${YELLOW}Procédure interrompue : conditions de non-responsabilité refusées.${NC}"
    exit 0
fi

# ------------------------------------------------------------------------------
# 3. Sélection de l'utilisateur cible
# ------------------------------------------------------------------------------
DEFAULT_USER="${SUDO_USER:-$USER}"

EXEC_DIALOG_USER() {
    dialog --clear \
        --backtitle "Personnalisation Linux Mint - Style Windows 11" \
        --title " Utilisateur cible " \
        --inputbox "\nIndiquez le nom d'utilisateur pour lequel installer les thèmes :" 10 65 "$DEFAULT_USER" \
        2>&1 >/dev/tty
}

REAL_USER=$(EXEC_DIALOG_USER) || {
    clear
    echo -e "${YELLOW}Installation annulée par l'utilisateur.${NC}"
    exit 0
}

# Validation de l'existence du compte utilisateur
while ! id "$REAL_USER" >/dev/null 2>&1 || [ -z "$REAL_USER" ]; do
    dialog --backtitle "Personnalisation Linux Mint" \
           --msgbox "Erreur : Le compte '$REAL_USER' n'existe pas sur ce système. Veuillez réessayer." 8 60
    REAL_USER=$(EXEC_DIALOG_USER) || {
        clear
        echo -e "${YELLOW}Installation annulée par l'utilisateur.${NC}"
        exit 0
    }
done

clear

USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo -e "${BLUE}=====================================================================${NC}"
echo -e "${BLUE}   Configuration de l'environnement pour l'utilisateur : $REAL_USER   ${NC}"
echo -e "${BLUE}=====================================================================${NC}"

commande_existe() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# 4. Mise à jour des paquets et dépendances requises
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[1/4] Vérification des outils système requis...${NC}"
apt update -qq

paquets_requis=(curl git wget tar gpg sassc libglib2.0-dev-bin libxml2-utils)
pour_installer=()

for paquet in "${paquets_requis[@]}"; do
    if ! dpkg -s "$paquet" >/dev/null 2>&1; then
        pour_installer+=("$paquet")
    fi
done

if [ ${#pour_installer[@]} -ne 0 ]; then
    echo -e "Installation des outils manquants : ${pour_installer[*]}"
    apt install -y "${pour_installer[@]}"
else
    echo -e "${GREEN}Tous les outils de base requis sont déjà présents.${NC}"
fi

# ------------------------------------------------------------------------------
# 5. Installation de SoftMaker FreeOffice 2024
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[2/4] Vérification de SoftMaker FreeOffice...${NC}"

if commande_existe textmaker2024 || dpkg -s softmaker-freeoffice-2024 >/dev/null 2>&1; then
    echo -e "${GREEN}SoftMaker FreeOffice 2024 est déjà installé. Étape ignorée.${NC}"
else
    echo -e "Configuration du dépôt officiel SoftMaker..."
    install -m 0755 -d /etc/apt/keyrings
    wget -qO- https://shop.softmaker.com/repo/linux-repo-public.key | gpg --dearmor --yes -o /etc/apt/keyrings/softmaker.gpg
    echo "deb [signed-by=/etc/apt/keyrings/softmaker.gpg] https://shop.softmaker.com/repo/apt stable non-free" > /etc/apt/sources.list.d/softmaker.list
    
    apt update -qq
    apt install -y softmaker-freeoffice-2024
    echo -e "${GREEN}FreeOffice 2024 installé avec succès.${NC}"
fi

# ------------------------------------------------------------------------------
# 6. Installation de Master PDF Editor
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[3/4] Vérification de Master PDF Editor...${NC}"

if commande_existe masterpdfeditor5 || dpkg -s master-pdf-editor >/dev/null 2>&1; then
    echo -e "${GREEN}Master PDF Editor est déjà installé. Étape ignorée.${NC}"
else
    echo -e "Téléchargement de Master PDF Editor 5..."
    MASTER_PDF_URL="https://code-industry.net/public/master-pdf-editor-5.9.86-qt5.x86_64.deb"
    
    wget -q --show-progress -O /tmp/master-pdf-editor.deb "$MASTER_PDF_URL"
    
    if [ -s /tmp/master-pdf-editor.deb ]; then
        echo -e "Installation du paquet..."
        apt install -y /tmp/master-pdf-editor.deb
        rm -f /tmp/master-pdf-editor.deb
        echo -e "${GREEN}Master PDF Editor installé avec succès.${NC}"
    else
        echo -e "${RED}Erreur : Échec du téléchargement du paquet Master PDF Editor.${NC}"
        rm -f /tmp/master-pdf-editor.deb
    fi
fi

# ------------------------------------------------------------------------------
# 7. Installation des thèmes visuels Windows 11 (Fluent)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[4/4] Vérification des thèmes et icônes style Windows 11...${NC}"

sudo -u "$REAL_USER" mkdir -p "$USER_HOME/.themes" "$USER_HOME/.icons"

# --- THÈME GTK FLUENT ---
if [ -d "$USER_HOME/.themes/Fluent-dark" ] || [ -d "$USER_HOME/.themes/Fluent" ]; then
    echo -e "${GREEN}Les thèmes d'interface Fluent sont déjà présents. Étape ignorée.${NC}"
else
    echo -e "Téléchargement et compilation du thème Fluent-GTK..."
    rm -rf /tmp/Fluent-gtk-theme
    git clone -q --depth=1 https://github.com/vinceliuice/Fluent-gtk-theme.git /tmp/Fluent-gtk-theme
    
    if [ -f /tmp/Fluent-gtk-theme/install.sh ]; then
        sudo -u "$REAL_USER" bash /tmp/Fluent-gtk-theme/install.sh --dest "$USER_HOME/.themes" --theme default --blur
    fi
    rm -rf /tmp/Fluent-gtk-theme
fi

# --- PACK D'ICÔNES FLUENT ---
if [ -d "$USER_HOME/.icons/Fluent" ] || [ -d "$USER_HOME/.icons/Fluent-dark" ]; then
    echo -e "${GREEN}Le pack d'icônes Fluent est déjà présent. Étape ignorée.${NC}"
else
    echo -e "Téléchargement et installation des icônes Fluent..."
    rm -rf /tmp/Fluent-icon-theme
    git clone -q --depth=1 https://github.com/vinceliuice/Fluent-icon-theme.git /tmp/Fluent-icon-theme
    
    if [ -f /tmp/Fluent-icon-theme/install.sh ]; then
        sudo -u "$REAL_USER" bash /tmp/Fluent-icon-theme/install.sh --dest "$USER_HOME/.icons"
    fi
    rm -rf /tmp/Fluent-icon-theme
fi

# Rétablissement des droits complets
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.themes" "$USER_HOME/.icons"

echo -e "\n${GREEN}=====================================================================${NC}"
echo -e "${GREEN} Configuration terminée avec succès pour $REAL_USER !               ${NC}"
echo -e "${GREEN}=====================================================================${NC}"