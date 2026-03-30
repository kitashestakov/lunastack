#!/bin/bash
set -euo pipefail

# Luna Stack — Quick Setup
# Usage: curl -sL <raw-url>/setup.sh | bash

REPO_URL="git@github.com:luna-pastel/luna-stack.git"
INSTALL_DIR="$HOME/luna-stack"

echo "🌙 Установка Luna Stack..."

if [ -d "$INSTALL_DIR" ]; then
  echo "Папка $INSTALL_DIR уже существует. Обновляю..."
  cd "$INSTALL_DIR"
  git pull
else
  echo "Клонирую репозиторий..."
  git clone "$REPO_URL" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

echo ""
echo "✅ Готово!"
echo ""
echo "Следующие шаги:"
echo "1. Открой Claude Desktop"
echo "2. Нажми File → Open Folder → выбери $INSTALL_DIR"
echo "3. Набери /onboarding и следуй инструкциям"
echo ""
