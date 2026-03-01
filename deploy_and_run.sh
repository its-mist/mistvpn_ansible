#!/usr/bin/env bash
# Копирует плейбук на сервер и запускает ansible-playbook локально там.
# Использование: ./deploy_and_run.sh <IP или hostname> [теги через запятую]
#   Пример: ./deploy_and_run.sh 1.2.3.4
#   Пример: ./deploy_and_run.sh 1.2.3.4 hostname,bbr

set -euo pipefail

SERVER=${1:?Укажи IP сервера: ./deploy_and_run.sh <IP> [tags]}
TAGS=${2:-}
REMOTE_DIR="/tmp/mistvpn_ansible"

echo ">>> Копируем проект на $SERVER:$REMOTE_DIR"
ssh -o StrictHostKeyChecking=no root@"$SERVER" "rm -rf $REMOTE_DIR && mkdir -p $REMOTE_DIR"
scp -r -o StrictHostKeyChecking=no \
  site.yml inventory_local.ini requirements.yml group_vars roles \
  root@"$SERVER":"$REMOTE_DIR"/

echo ">>> Устанавливаем зависимости Ansible на сервере"
ssh -o StrictHostKeyChecking=no root@"$SERVER" bash <<'REMOTE'
  set -e
  if ! command -v ansible-playbook &>/dev/null; then
    apt-get update -qq
    apt-get install -y -qq ansible
  fi
  cd /tmp/mistvpn_ansible
  ansible-galaxy install -r requirements.yml --force -q 2>/dev/null || true
REMOTE

echo ">>> Запускаем плейбук на $SERVER"
TAG_OPT=""
[[ -n "$TAGS" ]] && TAG_OPT="--tags $TAGS"

ssh -o StrictHostKeyChecking=no root@"$SERVER" \
  "cd $REMOTE_DIR && ansible-playbook site.yml -i inventory_local.ini $TAG_OPT"

echo ">>> Готово!"
