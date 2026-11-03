#!/bin/bash

# ==============================================================================
# Script d'installation automatique et IDEMPOTENT pour Linux Mint
# Objectif : Installer FreeOffice, Master PDF Editor et le pack visuel Windows 11
# ==============================================================================

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Pas de couleur

echo -e "${BLUE}=====================================================================${NC}"
echo -e "${BLUE}   Vérification et configuration de l'environnement Windows 11       ${NC}"
echo -e "${BLUE}=====================================================================${NC}"

# 1. Validation des droits administratifs
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Erreur : Veuillez exécuter ce script avec sudo : sudo bash $0${NC}"
  exit 1
fi

# Récupération de l'utilisateur réel
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Fonction utilitaire pour vérifier si une commande existe
commande_existe() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------------------------
# 2. Mise à jour des paquets et installation des prérequis
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[1/4] Vérification des outils système requis...${NC}"
apt update -qq

paquets_requis=(curl git wget tar)
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
# 3. Installation de SoftMaker FreeOffice 2024
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[2/4] Vérification de SoftMaker FreeOffice...${NC}"

if commande_existe textmaker2024 || dpkg -s softmaker-freeoffice-2024 >/dev/null 2>&1; then
    echo -e "${GREEN}SoftMaker FreeOffice 2024 est déjà installé. Étape ignorée.${NC}"
else
    echo -e "Téléchargement et installation de FreeOffice..."
    curl -fsSL https://softmaker.net | bash
fi

# ------------------------------------------------------------------------------
# 4. Installation de Master PDF Editor
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[3/4] Vérification de Master PDF Editor...${NC}"

if commande_existe masterpdfeditor4 || commande_existe masterpdfeditor5 || dpkg -s masterpdfeditor >/dev/null 2>&1; then
    echo -e "${GREEN}Master PDF Editor est déjà installé. Étape ignorée.${NC}"
else
    echo -e "Téléchargement de Master PDF Editor..."
    # Récupération sécurisée du paquet .deb officiel (URL générique de redirection SoftMaker/CodeIndustry)
    wget -q --show-progress -O /tmp/master-pdf-editor.deb "https://code-industry.net"
    
    if [ -f /tmp/master-pdf-editor.deb ]; then
        echo -e "Installation du paquet..."
        apt install -y /tmp/master-pdf-editor.deb
        rm -f /tmp/master-pdf-editor.deb
    else
        echo -e "${RED}Erreur : Impossible de télécharger Master PDF Editor.${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# 5. Installation des thèmes visuels Windows 11 (Fluent)
# ------------------------------------------------------------------------------
echo -e "\n${BLUE}[4/4] Vérification des thèmes et icônes style Windows 11...${NC}"

# Création sécurisée des dossiers thèmes s'ils n'existent pas
mkdir -p "$USER_HOME/.themes"
mkdir -p "$USER_HOME/.icons"

# --- THÈME GENTIL / FLUENT ---
if [ -d "$USER_HOME/.themes/Fluent-dark" ] || [ -d "$USER_HOME/.themes/Fluent" ]; then
    echo -e "${GREEN}Les thèmes d'interface Fluent sont déjà présents dans ~/.themes. Étape ignorée.${NC}"
else
    echo -e "Téléchargement et déploiement du thème de fenêtres Fluent-GTK..."
    rm -rf /tmp/Fluent-gtk-theme # Nettoyage préventif
    git clone -q https://github.com /tmp/Fluent-gtk-theme
    if [ -f /tmp/Fluent-gtk-theme/install.sh ]; then
        # Exécution du script de l'auteur directement vers le dossier de l'utilisateur
        bash /tmp/Fluent-gtk-theme/install.sh --dest "$USER_HOME/.themes" --theme default --blur
    fi
    rm -rf /tmp/Fluent-gtk-theme
fi

# --- PACK D'ICÔNES ---
if [ -d "$USER_HOME/.icons/Fluent" ] || [ -d "$USER_HOME/.icons/Fluent-dark" ]; then
    echo -e "${GREEN}Le pack d'icônes Fluent est déjà présent dans ~/.icons. Étape ignorée.${NC}"
else
    echo -e "Téléchargement et déploiement des icônes style Windows 11..."
    rm -rf /tmp/Fluent-icon-theme # Nettoyage préventif
    git clone -q https://github.com /tmp/Fluent-icon-theme
    if [ -f /tmp/Fluent-icon-theme/install.sh ]; then
        bash /tmp/Fluent-icon-theme/install.sh --dest "$USER_HOME/.icons"
    fi
    rm -rf /tmp/Fluent-icon-theme
fi

# Rétablir proprement la propriété des dossiers à l'utilisateur non-root
chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.themes" "$USER_HOME/.icons"

# ------------------------------------------------------------------------------
# Fin du script
# ------------------------------------------------------------------------------
echo -e "\n${GREEN}=====================================================================${NC}"
echo -e "${GREEN} Statut du système : À jour et configuré !                            ${NC}"
echo -e "${GREEN}=====================================================================${NC}"
echo -e "Vous pouvez relancer ce script à tout moment pour vérifier votre installation."
