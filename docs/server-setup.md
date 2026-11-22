* **Устанавливаемый пакет:** nginx
* **Конфигурация ресурса:** /etc/nginx/sites-available/devops-site (активирована символической ссылкой в /etc/nginx/sites-enabled/devops-site, стандартная конфигурация default удалена)
* **Каталог ресурса:** /var/www/devops-site, владелец devops:devops, права 755 (каталоги) и 644 (файлы)
* **TLS-сертификат:** /etc/ssl/certs/devops.crt (права 644, владелец root:root, срок действия 365 дней)
* **Закрытый ключ TLS:** /etc/ssl/private/devops.key (права 600, владелец root:root)
* **Команда выпуска сертификата:**
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"

## 10. Ansible

### 10.1. Общие сведения и архитектура
* **Расположение проекта Ansible:** каталог `ansible/` в корне репозитория.
* **Управляющий узел (Control Node):** рабочая станция администратора / среда WSL2 Ubuntu 24.04 LTS c установленным `ansible-core` (версии 2.16+) и коллекциями `ansible.posix:1.6.2`, `community.docker:4.5.0`, `community.general:9.5.0`.
* **Управляемый узел (Managed Node):** виртуальная машина `devops-vm` (ОС Ubuntu Server 24.04 LTS amd64, сетевой адрес Host-Only: `192.168.56.101`).

### 10.2. Инвентарь и учётные записи
* **Инвентарный файл первичного ввода (`ansible/inventory/bootstrap.ini`):**
  * Хост: `devops-vm`
  * Параметры: `ansible_host=192.168.56.101 ansible_port=22 ansible_user=student`
  * Назначение: первичное подключение к свежеустановленной или сброшенной ОС с использованием временного парольного доступа учётной записи `student`.
* **Инвентарный файл промышленной эксплуатации (`ansible/inventory/prod.ini`):**
  * Хост: `devops-vm`
  * Параметры: `ansible_host=192.168.56.101 ansible_port=22 ansible_user=devops ansible_private_key_file=~/.ssh/devops_vm`
  * Назначение: штатное неинтерактивное управление через выделенную сервисную учётную запись автоматизации `devops` с аутентификацией исключительно по асимметричному ключу (права 0600) и правами беспарольного вызова `sudo` (`NOPASSWD:ALL`).
* *Безопасность:* пароли и закрытые ключи в конфигурационные файлы и систему контроля версий не включаются.

### 10.3. Модульные роли и разделение ответственности
* **`base` (Базовая инфраструктура платформы):**
  * Проверка соответствия целевой платформы (`Ubuntu 24.04 x86_64`).
  * Установка системных утилит и зависимостей модулей Ansible (`ca-certificates`, `curl`, `gnupg`, `openssh-server`, `ufw`, `python3-debian`, `python3-requests`).
  * Добавление официального репозитория Docker в формате Deb822 (`/etc/apt/sources.list.d/docker.sources`).
  * Установка пакетов Docker Engine (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`).
  * Активация и запуск системной службы `docker`.
* **`ssh` (Безопасность доступа и межсетевой экран):**
  * Создание системного пользователя `devops` с добавлением в группу `sudo`.
  * Установка открытого ключа в `/home/devops/.ssh/authorized_keys` (права 0600/0700).
  * Настройка правила sudoers в `/etc/sudoers.d/devops` с валидацией `visudo`.
  * Харденинг SSH через `/etc/ssh/sshd_config.d/00-ansible-hardening.conf` (запрет паролей `PasswordAuthentication no`, запрет root `PermitRootLogin no`, ограничение `AllowUsers student devops`, валидация `sshd -t`).
  * Обработчик (handler): безопасный перезапуск службы `ssh` при изменении конфигурации.
  * Настройка межсетевого экрана UFW: открытие портов 22/tcp и 80/tcp, установка политики `deny incoming` и `allow outgoing`, включение экрана `state: enabled`.
* **`nginx` (Обратный прокси-сервер и маршрутизация):**
  * Установка веб-сервера `nginx`.
  * Развёртывание конфигурации обратного прокси из Jinja2-шаблона `devops-ci-app.conf.j2` в `/etc/nginx/sites-available/devops-ci-app` (проксирование запросов на `http://127.0.0.1:5000` с передачей заголовков `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`).
  * Отключение стандартного виртуального хоста (`sites-enabled/default -> absent`).
  * Активация конфигурации приложения символической ссылкой в `sites-enabled/devops-ci-app`.
  * Активация службы `nginx`.
  * Двухэтапные обработчики (handlers): `Validate Nginx before reload` (проверка синтаксиса `nginx -t`, `changed_when: false`) и `Reload Nginx` (безопасная перезагрузка процесса без простоя).
* **`app` (Контейнеризация и мониторинг приложения):**
  * Включение пользователя `devops` в группу `docker` для локальной диагностики.
  * Загрузка проверенного Docker-образа из реестра GHCR с фиксацией по полному неизменяемому SHA коммита.
  * Запуск контейнера приложения с политикой перезапуска `restart_policy: unless-stopped` и строгой привязкой публикации портов к локальному адресу loopback `127.0.0.1:5000:5000` (предотвращение прямого обхода Nginx в обход правил межсетевого экрана).
  * Непрерывный опрос эндпоинта состояния `http://127.0.0.1:5000/health` (до 15 попыток с задержкой 2 с) до подтверждения статуса HTTP 200 и тела `{"status":"ok"}`.

### 10.4. Параметры приложения и реестра контейнеров
* **Адрес реестра и образ:** `ghcr.io/scies113/devops-ci-app`
* **Неизменяемый тег релиза (полный SHA коммита из ПР-10):** `eeacc2d83e6b1b6fb07b2c76b6a90e95a197b770`
* **Имя контейнера:** `devops-ci-app`
* **Порт публикации хоста:** `5000` (строго `127.0.0.1:5000`)
* **Внутренний порт контейнера:** `5000`
* **Эндпоинты проверки жизнеспособности:**
  * Прямой внутренний эндпоинт приложения: `http://127.0.0.1:5000/health`
  * Внешний публичный эндпоинт через Nginx: `http://192.168.56.101/health`

### 10.5. Регламентные команды управления
* **Первичный запуск (Bootstrap) через учётную запись student:**
  ```bash
  ansible-playbook -i inventory/bootstrap.ini site.yml -e "ansible_password=... ansible_become_password=..."
  ```
* **Штатный запуск и обновление (Production) через SSH-ключ devops:**
  ```bash
  ansible-playbook site.yml
  ```
  *(файл `ansible.cfg` автоматически использует `inventory/prod.ini`, ключ `~/.ssh/devops_vm` и пользователя `devops`)*
* **Автоматический read-only аудит инфраструктуры:**
  ```bash
  ansible-playbook verify.yml
  ```
  *(проверяет действительную конфигурацию sshd -T, факт отключения паролей, статус контейнера в Docker Engine и валидность ответа /health без внесения изменений: changed=0)*
