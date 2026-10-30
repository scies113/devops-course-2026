#!/usr/bin/env bash
# Сценарий аудита конфигурации devops-vm
set -uo pipefail

FAILED=0

# Функция проверки условия
check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf "[\033[32mOK\033[0m] %s\n" "$desc"
    else
        printf "[\033[31mFAIL\033[0m] %s\n" "$desc"
        FAILED=1
    fi
}

echo "=== [1] Базовая система ==="
check "Имя хоста devops-vm" bash -c '[ "$(hostname)" = "devops-vm" ]'
check "Пользователь devops присутствует" id devops
check "Sudo без пароля для пользователя devops" sudo -n true

echo "=== [2] Служба SSH ==="
check "Служба SSH активна" systemctl is-active ssh
check "Порт 2222 слушается" bash -c 'ss -tln | grep -q :2222'

echo "=== [3] Межсетевой экран UFW ==="
check "Межсетевой экран UFW активен" sudo ufw status
check "Порт 2222 разрешен" bash -c 'sudo ufw status | grep -q "2222/tcp"'
check "Порты веб-сервера 80 и 443 разрешены" bash -c 'sudo ufw status | grep -q "80/tcp" && sudo ufw status | grep -q "443/tcp"'

echo "=== [4] Веб-сервер ==="
check "Служба Nginx активна" systemctl is-active nginx
check "Конфигурация Nginx синтаксически корректна" sudo nginx -t
check "Сертификат валиден минимум 30 дней" openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt
check "Безопасность прав: отсутствие o+w файлов и права 600 на ключ" bash -c '[ -z "$(find /var/www/devops-site -perm -o+w)" ] && [ "$(sudo stat -c "%a" /etc/ssl/private/devops.key)" = "600" ]'

exit $FAILED
