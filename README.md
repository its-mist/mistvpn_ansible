# mistvpn_ansible

Ansible-проект для первичной настройки VPN-серверов.
Плейбук запускается **локально на самом сервере** (без управляющей машины).

## Структура

```
mistvpn_ansible/
├── ansible.cfg
├── site.yml              # главный плейбук
├── inventory.ini         # localhost (local connection)
├── requirements.yml      # зависимости коллекций
├── deploy_and_run.sh     # копирует проект на сервер и запускает там
├── group_vars/
│   └── all.yml           # ВСЕ переменные здесь
└── roles/
    ├── hostname/         # 1. меняем имя хоста
    ├── ssh_hardening/    # 2. ключ + отключение пароля
    ├── bbr/              # 3. включаем BBR
    ├── fail2ban/         # 4. ставим fail2ban
    └── remnawave/        # 5. устанавливаем ноду remnawave
```

## Быстрый старт

### С управляющей машины (рекомендуется)

```bash
# Настроить переменные, затем одной командой:
./deploy_and_run.sh <IP сервера>

# Или с тегами (только нужные роли):
./deploy_and_run.sh <IP сервера> hostname,bbr
```

Скрипт сам:
- Копирует проект на сервер в `/tmp/mistvpn_ansible`
- Устанавливает Ansible, если его нет
- Запускает `ansible-playbook` локально на сервере

### Прямо на сервере

```bash
# 1. Установить Ansible
apt install -y ansible

# 2. Клонировать/скопировать проект
git clone <repo> /tmp/mistvpn_ansible
cd /tmp/mistvpn_ansible

# 3. Установить зависимости коллекций
ansible-galaxy install -r requirements.yml

# 4. Настроить переменные
nano group_vars/all.yml

# 5. Запустить всё
ansible-playbook site.yml

# Или только отдельные роли (теги):
ansible-playbook site.yml --tags hostname
ansible-playbook site.yml --tags ssh
ansible-playbook site.yml --tags bbr
ansible-playbook site.yml --tags fail2ban
ansible-playbook site.yml --tags remnawave
```

## Переменные (group_vars/all.yml)

Переменные определённые в `group_vars/all.yml` перекрывают дефолты из `roles/*/defaults/main.yml`.

### Хостнейм

| Переменная | Пример | Описание |
|---|---|---|
| `server_node` | `node2` | Часть **a** → |
| `server_location` | `germany` | Часть **b** → итог: `node2-germany-004` |
| `server_number` | `004` | Часть **c** → |

### SSH

| Переменная | Пример | Описание |
|---|---|---|
| `ssh_user` | `root` | Пользователь, которому кладём ключ |
| `ssh_public_key` | `ssh-ed25519 AAAA...` | Публичный ключ |

### Fail2ban

| Переменная | Пример | Описание |
|---|---|---|
| `fail2ban_bantime` | `1h` | Время бана |
| `fail2ban_findtime` | `10m` | Окно поиска попыток |
| `fail2ban_maxretry` | `5` | Макс. попыток до бана |
| `fail2ban_ssh_port` | `22` | SSH-порт для защиты |

### Remnawave

| Переменная | Пример | Описание |
|---|---|---|
| `node_domain` | `node.example.com` | Selfsteal-домен ноды |
| `panel_ip` | `1.2.3.4` | IP-адрес панели |
| `node_certificate` | `eyJ...` | Сертификат из панели (base64 + `\n` в конце) |
| `admin_email` | `admin@example.com` | Email для TLS-сертификата |
| `remnawave_timeout` | `120` | Таймаут ожидания каждого промпта (сек) |
| `remnawave_script_commit` | `f8ea2d6...` | Пинённый коммит скрипта |
| `remnawave_script_sha256` | `sha256:109e...` | Checksum скрипта |

## Пиннинг версии скрипта

Скрипт remnawave скачивается по конкретному коммиту и проверяется checksum.
Если авторы обновили скрипт — таска упадёт на скачивании, до запуска диалога.

Чтобы обновить до новой версии:

```bash
# 1. Получить новый SHA коммита
curl -s "https://api.github.com/repos/eGamesAPI/remnawave-reverse-proxy/commits?path=install_remnawave.sh&per_page=1" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['sha'])"

# 2. Получить новый checksum
curl -Ls "https://raw.githubusercontent.com/eGamesAPI/remnawave-reverse-proxy/<NEW_SHA>/install_remnawave.sh" | sha256sum

# 3. Вставить оба значения в roles/remnawave/defaults/main.yml
# 4. Проверить что промпты не изменились (roles/remnawave/tasks/main.yml)
```

## Примечание по remnawave

Скрипт интерактивный. Используется `ansible.builtin.expect` (требует `python3-pexpect` на сервере — ставится автоматически). Если авторы изменят текст промптов — подправить паттерны в `roles/remnawave/tasks/main.yml`.
