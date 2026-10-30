#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site/"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
REPO_ROOT="$(git rev-parse --show-toplevel)"
LOCAL_DIR="${REPO_ROOT}/site/"

DRY_RUN=""
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN="--dry-run"
elif [ -n "${1:-}" ]; then
    echo "Ошибка: Неизвестный аргумент '${1}'" >&2
    echo "Использование: $0 [--dry-run]" >&2
    exit 1
fi

# Проверка требования 4: наличие главного файла index.html
if [ ! -f "${LOCAL_DIR}index.html" ]; then
    echo "Ошибка: Файл ${LOCAL_DIR}index.html отсутствует!" >&2
    exit 1
fi

# Проверка требования 5: отсутствие незафиксированных изменений
if [ -n "$(git status --porcelain)" ]; then
    echo "Ошибка: В репозитории обнаружены незафиксированные изменения!" >&2
    exit 1
fi

# Требования 3, 8, 9: Синхронизация rsync за одно SSH-соединение
rsync -avz --delete --chmod=D755,F644 ${DRY_RUN} \
  -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
  "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}"

# Требование 1: Завершение при --dry-run без проверки URL
if [ -n "${DRY_RUN}" ]; then
    echo "Режим dry-run успешно завершен."
    exit 0
fi

# Требование 6: Проверка доступности ресурса по HTTPS
if ! curl -f -s --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: Ресурс ${SITE_URL} недоступен или сертификат не прошел проверку!" >&2
    exit 1
fi

# Требование 7: Успешный выход с выводом короткого хеша коммита
COMMIT_HASH="$(git rev-parse --short HEAD)"
echo "Деплой успешно завершен. Версия коммита: ${COMMIT_HASH}"
exit 0
