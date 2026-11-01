## 8. Веб-сервер
* **Устанавливаемый пакет:** nginx
* **Конфигурация ресурса:** /etc/nginx/sites-available/devops-site (активирована символической ссылкой в /etc/nginx/sites-enabled/devops-site, стандартная конфигурация default удалена)
* **Каталог ресурса:** /var/www/devops-site, владелец devops:devops, права 755 (каталоги) и 644 (файлы)
* **TLS-сертификат:** /etc/ssl/certs/devops.crt (права 644, владелец root:root, срок действия 365 дней)
* **Закрытый ключ TLS:** /etc/ssl/private/devops.key (права 600, владелец root:root)
* **Команда выпуска сертификата:**
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"

## 9. Контейнеризация
* **Способ установки Docker Engine и его версия:** Установка из официального репозитория Docker (`https://download.docker.com/linux/ubuntu noble stable`). Установлены пакеты `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`. Версия Docker Engine: Community `29.9.2`, плагина Docker Compose: `v5.6.1`.
* **Участники группы docker:** Пользователь `devops` добавлен в дополнительную группу `docker` командой `sudo usermod -aG docker devops` для выполнения команд Docker без повышения привилегий через `sudo`.
* **Расположение проекта на сервере:** Каталог `/home/devops/app` (владелец `devops:devops`, права `700`). Включает `Dockerfile`, `docker-compose.yml`, `requirements.txt`, `app.py`, `.dockerignore`, `.env.example`, `.env`.
* **Расположение файла .env и его права:** Файл `/home/devops/app/.env` (права `600`, `-rw-------`, владелец `devops:devops`). Содержит переменные `POSTGRES_DB=app`, `POSTGRES_USER=app`, `POSTGRES_PASSWORD=<случайный 16-байтный hex-пароль>`, `DB_HOST=db`. Файл исключён из системы контроля версий Git.
* **Публикуемые порты и адреса:**
  * Порт приложения: привязан строго к петлевому адресу `127.0.0.1:5000:5000` (прослушивается только локально).
  * Порт СУБД PostgreSQL (5432): не опубликован на хосте, доступен только внутри изолированной Docker-сети проекта `app_backend`.
* **Именованные тома:** Именованный том `app_db_data` (тип драйвера `local`, точка монтирования в контейнере `/var/lib/postgresql/data`) обеспечивает долговременное сохранение данных базы данных при пересоздании контейнеров (`docker compose down` сохраняет том; удаление возможно только при явном указании флага `-v`).
* **Конфигурация обратного прокси-сервера:** В блоке HTTPS виртуального хоста `/etc/nginx/sites-available/devops-site` добавлена секция:
  ```nginx
  location /app/ {
      proxy_pass http://127.0.0.1:5000/;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
  }
  ```
  Завершающий слеш в `proxy_pass` нормализует URI (заменяя `/app/` на `/`), проксируя запросы к приложению Gunicorn по протоколу HTTP на локальный сокет `127.0.0.1:5000`.
