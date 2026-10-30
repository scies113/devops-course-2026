* **Устанавливаемый пакет:** nginx
* **Конфигурация ресурса:** /etc/nginx/sites-available/devops-site (активирована символической ссылкой в /etc/nginx/sites-enabled/devops-site, стандартная конфигурация default удалена)
* **Каталог ресурса:** /var/www/devops-site, владелец devops:devops, права 755 (каталоги) и 644 (файлы)
* **TLS-сертификат:** /etc/ssl/certs/devops.crt (права 644, владелец root:root, срок действия 365 дней)
* **Закрытый ключ TLS:** /etc/ssl/private/devops.key (права 600, владелец root:root)
* **Команда выпуска сертификата:**
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"
