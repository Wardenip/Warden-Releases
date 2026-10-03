#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# Фикс вывода для Termux (убираем перекосы)
# ==========================================
fix_print() {
    awk '{print $0 "\r"}'
}

# ==========================================
# Весь код подготовки окружения
# ==========================================
{
    echo "================================"
    echo "       Warden Bootstrap"
    echo "================================"
    echo ""

    export DEBIAN_FRONTEND=noninteractive

    # --- Проверка pkg ---
    if ! command -v pkg >/dev/null 2>&1; then
        echo "[FAIL] pkg не найден."
        exit 1
    fi
    echo "[OK] pkg найден."
    echo ""

    # ==========================================
    # Блок 1: Базовые пакеты
    # ==========================================
    echo "================================"
    echo "    Установка базовых пакетов"
    echo "================================"
    echo ""

    missing=()
    command -v python >/dev/null 2>&1 || missing+=(python)
    { command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; } || missing+=(python-pip)
    command -v curl >/dev/null 2>&1 || missing+=(curl)

    if [ "${#missing[@]}" -eq 0 ]; then
        echo "[OK] python, pip, curl уже установлены."
    else
        echo "[INFO] Будут установлены: ${missing[*]}"
        echo ""
        
        echo "[INFO] Обновление списков пакетов..."
        if ! pkg update -y </dev/null >/dev/null 2>&1; then
            echo "[FAIL] Не удалось обновить списки пакетов."
            exit 1
        fi
        echo "[OK] Списки пакетов обновлены."
        echo ""

        echo "[INFO] Установка пакетов..."
        if ! pkg install -y "${missing[@]}" </dev/null >/dev/null 2>&1; then
            echo "[FAIL] Установка базовых пакетов не удалась."
            exit 1
        fi
        
        hash -r
        echo "[OK] Базовые пакеты успешно установлены."
    fi
    echo ""

    # ==========================================
    # Блок 1.5: Фикс бага Python 3.14 (armv8)
    # ==========================================
    PYTHON_VER=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if [ "$PYTHON_VER" = "3.14" ]; then
        echo "[INFO] Python 3.14: применение патча sysconfig (armv8)..."
        cat > /tmp/fix_armv8.py << 'PYEOF'
import sysconfig
path = sysconfig.__file__
with open(path, 'r') as f:
    content = f.read()
if "'armv8'" not in content:
    old_str = '        "x86_64": "x86_64",'
    new_str = '        "armv8": "aarch64",\n' + old_str
    if old_str in content:
        content = content.replace(old_str, new_str)
        with open(path, 'w') as f:
            f.write(content)
PYEOF
        python /tmp/fix_armv8.py >/dev/null 2>&1
        rm -f /tmp/fix_armv8.py
        echo "[OK] Патч sysconfig применен."
        echo ""
    fi

    # ==========================================
    # Блок 2: Python-зависимости
    # ==========================================
    echo "================================"
    echo "   Проверка Python-зависимостей"
    echo "================================"
    echo ""

    if python -c "import requests" >/dev/null 2>&1; then
        echo "[OK] requests уже установлен."
    else
        echo "[INFO] Установка requests..."
        if ! python -m pip install requests --disable-pip-version-check >/dev/null 2>&1; then
            echo "[FAIL] Не удалось установить requests."
            exit 1
        fi
        echo "[OK] requests успешно установлен."
    fi
    echo ""

    # ==========================================
    # Блок 3: Системные требования
    # ==========================================
    echo "================================"
    echo "    Проверка системы и путей"
    echo "================================"
    echo ""

    # Root (строго обязательный)
    if su -c "id" >/dev/null 2>&1; then
        echo "[OK] Root-доступ активен."
    else
        echo "[FAIL] Root-доступ не найден."
        exit 1
    fi

    # Storage
    STORAGE_DIR="/storage/emulated/0"
    if [ -d "$STORAGE_DIR" ]; then
        echo "[OK] Storage доступна."
        # $$ добавляет PID процесса, чтобы избежать коллизий при параллельных запусках
        STORAGE_TEST="$STORAGE_DIR/.warden_storage_test_$$"
        if touch "$STORAGE_TEST" >/dev/null 2>&1; then
            rm -f "$STORAGE_TEST"
            echo "[OK] Storage доступна для записи."
        else
            echo "[FAIL] Запись в Storage запрещена."
            echo "[INFO] Выполните в Termux: termux-setup-storage"
            exit 1
        fi
    else
        echo "[FAIL] Storage не найдена."
        echo "[INFO] Выполните в Termux: termux-setup-storage"
        exit 1
    fi
    echo ""

    # ==========================================
    # Блок 4: Загрузка Агента (GitHub Release)
    # ==========================================
    echo "================================"
    echo "        Загрузка Агента"
    echo "================================"
    echo ""

    GITHUB_OWNER="Wardenip"
    GITHUB_REPO="Warden-Releases"
    AGENT_FILE="$HOME/agent.py"

    RELEASE_API="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest"

    echo "[INFO] Получение информации о последнем релизе..."
    
    RELEASE_JSON=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$RELEASE_API")

    if [ $? -ne 0 ] || [ -z "$RELEASE_JSON" ]; then
        echo "[FAIL] Не удалось получить информацию о релизе."
        echo "[INFO] Убедитесь, что в репозитории создан GitHub Release с файлом agent.py."
        exit 1
    fi

    AGENT_URL=$(printf '%s' "$RELEASE_JSON" | python -c '
import json, sys
data = json.load(sys.stdin)
for asset in data.get("assets", []):
    if asset.get("name") == "agent.py":
        print(asset.get("browser_download_url", ""))
        break
')

    if [ -z "$AGENT_URL" ]; then
        echo "[FAIL] Файл agent.py отсутствует в последнем релизе."
        exit 1
    fi

    echo "[INFO] Скачивание agent.py..."
    if ! curl -fL "$AGENT_URL" -o "$AGENT_FILE"; then
        echo "[FAIL] Не удалось скачать agent.py."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    if [ ! -s "$AGENT_FILE" ]; then
        echo "[FAIL] Скачанный файл пустой."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    echo "[OK] agent.py успешно загружен."
    echo ""
    echo "================================"
    echo "       Bootstrap SUCCESS"
    echo "================================"
    echo "[INFO] Передача управления агенту..."

} | fix_print

# ==========================================
# Проверка статуса выполнения Bootstrap
# ==========================================
EXIT_CODE=${PIPESTATUS[0]}
if [ "$EXIT_CODE" -ne 0 ]; then
    exit "$EXIT_CODE"
fi

# ==========================================
# Handoff: Передача управления Python-агенту
# ==========================================
exec python "$HOME/agent.py" </dev/tty