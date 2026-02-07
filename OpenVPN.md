# OpenVPN — Client Connect Instructions / Инструкция по подключению клиента OpenVPN

## English ✅
1. Download the OpenVPN client
   - Visit: https://openvpn.net/client/
   - Choose and install **OpenVPN Connect** for your platform (Windows / macOS / Linux)

2. Get your client configuration (.ovpn)
   - The administrator will generate a `.ovpn` file for you

3. Import the `.ovpn` file into the client
   - Desktop (OpenVPN Connect): open the app → Import Profile → select `client_name.ovpn` (or drag & drop)
   - Linux CLI (openvpn package): place `client_name.ovpn` locally and run: `sudo openvpn --config client_name.ovpn`
   
4. Connect and verify
   - Click or run the connection in your OpenVPN client
   - After connected, try accessing internal services (examples):
     - Airflow UI: http://10.104.0.5:8080
     - PostgreSQL (Airflow Metadata): tcp://10.104.0.5:5433
     - PostgreSQL (Datalake): tcp://10.104.0.5:5432
     - MinIO Console: http://10.104.0.5:9001 (web UI)
     - MinIO S3 API (TCP): tcp://10.104.0.5:9000
     - ClickHouse Node 1 (HTTP / Native): http://10.104.0.2:8123 / tcp://10.104.0.2:9000
     - ClickHouse Node 2 (HTTP / Native): http://10.104.0.2:18123 / tcp://10.104.0.2:19000
     - Spark Master UI: http://10.104.0.3:30080
     - Jupyter Lab: http://10.104.0.3:30888

---

## Русский ✅
1. Скачивание OpenVPN клиента
   - Перейдите на: https://openvpn.net/client/
   - Установите **OpenVPN Connect** для вашей платформы (Windows / macOS / Linux)

2. Получение файла конфигурации (.ovpn)
   - Администратор создаст для вас `.ovpn`

3. Импорт `.ovpn` в клиент
   - Десктоп (OpenVPN Connect): откройте приложение → Import Profile → выберите `client_name.ovpn` (или перетащите файл)
   - Linux (CLI): поместите `client_name.ovpn` на машину и выполните: `sudo openvpn --config client_name.ovpn`

4. Подключение и проверка
   - Запустите подключение в клиенте OpenVPN.
   - После подключения проверьте доступ к сервисам (примеры):
     - Airflow UI: http://10.104.0.5:8080
     - PostgreSQL (Airflow Metadata): tcp://10.104.0.5:5433
     - PostgreSQL (Datalake): tcp://10.104.0.5:5432
     - MinIO Console: http://10.104.0.5:9001 (веб-интерфейс)
     - MinIO S3 API (TCP): tcp://10.104.0.5:9000
     - ClickHouse Шард 1 (HTTP / Native): http://10.104.0.2:8123 / tcp://10.104.0.2:9000
     - ClickHouse Шард 2 (HTTP / Native): http://10.104.0.2:18123 / tcp://10.104.0.2:19000
     - Spark Master UI: http://10.104.0.3:30080
     - Jupyter Lab: http://10.104.0.3:30888
   