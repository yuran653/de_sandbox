# OpenVPN Server Administration (de_sandbox)

# Администрирование OpenVPN-сервера (de_sandbox)

Use these steps when you add a new VPN client.

Используйте эту инструкцию при добавлении нового VPN-клиента.

---

### Step 1. Generate the client configuration

### Шаг 1. Создание конфигурации клиента

* **EN:** Run the generation script with a unique client name:
**RU:** Запустите скрипт генерации, указав уникальное имя клиента:
`./etc/generate_client_ovpn.sh client_name`
* **Example / Пример:** `./etc/generate_client_ovpn.sh alice_laptop`

---

### Step 2. Transfer the .ovpn file to the client

### Шаг 2. Передача .ovpn-файла клиенту

* **EN:** The script will output the path to the generated `.ovpn` file.
**RU:** Скрипт выведет путь к созданному файлу `.ovpn`.
* **EN:** Securely transfer this file to the client (e.g., via `scp`, `sftp`, or a secure sharing link).
**RU:** Безопасно передайте этот файл клиенту (например, через `scp`, `sftp` или защищенную ссылку).
* **WARNING / ВНИМАНИЕ:** **EN:** Do NOT send this file over unencrypted channels (email/slack) as it contains the private key.
**RU:** НЕ отправляйте этот файл через незашифрованные каналы (email/slack), так как он содержит закрытый ключ.

---

### Step 3. Client Connection

### Шаг 3. Подключение клиента

* **EN:** The client should import the `.ovpn` file into their OpenVPN Connect client (Windows/macOS/Linux/Android/iOS).
**RU:** Клиент должен импортировать файл `.ovpn` в приложение OpenVPN Connect (Windows/macOS/Linux/Android/iOS).
* **EN:** Once connected, they should be able to reach internal resources (check `nftables` rules for specific access).
**RU:** После подключения должны стать доступны внутренние ресурсы (конкретные права доступа проверяйте в правилах `nftables`).

---

### Step 4. Revocation (if needed)

### Шаг 4. Отзыв сертификата (при необходимости)

* **EN:** To revoke a user, use the `./easyrsa revoke client_name` command in `/etc/openvpn/easy-rsa/` and then generate a new CRL: `./easyrsa gen-crl`.
**RU:** Чтобы отозвать доступ у пользователя, выполните команду `./easyrsa revoke имя_клиента` в директории `/etc/openvpn/easy-rsa/`, а затем создайте новый список отзыва: `./easyrsa gen-crl`.
* **EN:** Copy the `crl.pem` to `/etc/openvpn/` and restart the service.
**RU:** Скопируйте `crl.pem` в `/etc/openvpn/` и перезапустите службу.
* **Note / Примечание:** **EN:** CRL configuration might need to be added to `server.conf` if not already present.
**RU:** Если конфигурация CRL еще не добавлена в `server.conf`, это необходимо сделать.
