#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# Фикс вывода для Termux
# ==========================================
fix_print() {
    awk '{print $0 "\r"}'
}

# ==========================================
# Функция определения/фикса платформы Python
# ==========================================
fix_python_platform() {
    echo "[INFO] Проверка платформы Python..."

    if python -c "import sysconfig; sysconfig.get_platform()" >/dev/null 2>&1; then
        echo "[OK] Платформа Python определяется нормально."
        return 0
    fi

    MACHINE="$(uname -m)"
    ABI_LIST="$(getprop ro.product.cpu.abilist 2>/dev/null)"
    API_LEVEL="$(getprop ro.build.version.sdk 2>/dev/null)"

    echo "[WARN] Python не смог определить платформу."
    echo "[INFO] Kernel machine: $MACHINE"
    echo "[INFO] Android ABI: ${ABI_LIST:-unknown}"
    echo "[INFO] Android API: ${API_LEVEL:-unknown}"

    case "$MACHINE" in

        armv8)
            if printf '%s' "$ABI_LIST" | grep -qw "arm64-v8a"; then
                export _PYTHON_HOST_PLATFORM="android-aarch64"
                echo "[INFO] Используем ARM64 Android platform override."
            else
                echo "[FAIL] armv8 обнаружен, но ARM64 ABI не подтверждён."
                return 1
            fi
            ;;

        aarch64)
            export _PYTHON_HOST_PLATFORM="android-aarch64"
            echo "[INFO] Используем ARM64 Android platform override."
            ;;

        x86_64)
            export _PYTHON_HOST_PLATFORM="android-x86_64"
            echo "[INFO] Используем x86_64 Android platform override."
            ;;

        i686|x86)
            export _PYTHON_HOST_PLATFORM="android-i686"
            echo "[INFO] Используем x86 Android platform override."
            ;;

        armv8l|armv7l|arm)
            export _PYTHON_HOST_PLATFORM="android-arm"
            echo "[INFO] Используем ARM32 Android platform override."
            ;;

        *)
            echo "[FAIL] Неизвестная архитектура: $MACHINE"
            return 1
            ;;
    esac

    PLATFORM="$(python -c "import sysconfig; print(sysconfig.get_platform())" 2>/dev/null)"

    if [ -z "$PLATFORM" ]; then
        echo "[FAIL] Python всё ещё не может определить платформу."
        return 1
    fi

    echo "[OK] Платформа Python: $PLATFORM"
}

# ==========================================
# Определяем папку самого bootstrap
# ==========================================
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

LOCAL_AGENT="$SCRIPT_DIR/agent.py"
AGENT_FILE="$HOME/agent.py"

# ==========================================
# Весь код подготовки окружения
# ==========================================
{
    echo "================================"
    echo "       Warden Bootstrap"
    echo "================================"
    echo ""

    echo "[INFO] Bootstrap directory:"
    echo "$SCRIPT_DIR"
    echo ""

    export DEBIAN_FRONTEND=noninteractive

    # ==========================================
    # Проверка pkg
    # ==========================================
    if ! command -v pkg >/dev/null 2>&1; then
        echo "[FAIL] pkg не найден."
        exit 1
    fi

    echo "[OK] pkg найден."
    echo ""

    # ==========================================
    # Базовые пакеты
    # ==========================================
    echo "================================"
    echo "    Установка базовых пакетов"
    echo "================================"
    echo ""

    missing=()

    command -v python >/dev/null 2>&1 || missing+=(python)

    {
        command -v pip >/dev/null 2>&1 ||
        command -v pip3 >/dev/null 2>&1
    } || missing+=(python-pip)

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
    # Проверка платформы Python
    # ==========================================
    if ! fix_python_platform; then
        exit 1
    fi

    echo ""

    # ==========================================
    # Python-зависимости
    # ==========================================
    echo "================================"
    echo "   Проверка Python-зависимостей"
    echo "================================"
    echo ""

    if python -c "import requests" >/dev/null 2>&1; then

        echo "[OK] requests уже установлен."

    else

        echo "[INFO] Установка requests..."

        if ! python -m pip install requests \
            --disable-pip-version-check \
            >/dev/null 2>&1; then

            echo "[FAIL] Не удалось установить requests."
            exit 1
        fi

        echo "[OK] requests успешно установлен."
    fi

    echo ""

    # ==========================================
    # Системные требования
    # ==========================================
    echo "================================"
    echo "    Проверка системы и путей"
    echo "================================"
    echo ""

    # Root

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
    # Локальный Agent
    # ==========================================
    echo "================================"
    echo "        Загрузка Агента"
    echo "================================"
    echo ""

    echo "[INFO] Поиск agent.py рядом с bootstrap..."
    echo "[INFO] Путь: $LOCAL_AGENT"

    if [ ! -f "$LOCAL_AGENT" ]; then

        echo "[FAIL] agent.py не найден рядом с bootstrap."
        echo ""
        echo "[INFO] Ожидаемый путь:"
        echo "$LOCAL_AGENT"

        exit 1
    fi

    if [ ! -s "$LOCAL_AGENT" ]; then

        echo "[FAIL] agent.py пустой."
        exit 1
    fi

    echo "[OK] Локальный agent.py найден."

    # ==========================================
    # Копирование агента в HOME
    # ==========================================

    echo "[INFO] Копирование agent.py в:"
    echo "$AGENT_FILE"

    if ! cp -f "$LOCAL_AGENT" "$AGENT_FILE"; then

        echo "[FAIL] Не удалось скопировать agent.py."
        exit 1
    fi

    if [ ! -s "$AGENT_FILE" ]; then

        echo "[FAIL] Скопированный agent.py пустой."
        rm -f "$AGENT_FILE"

        exit 1
    fi

    echo "[OK] agent.py успешно подготовлен."
    echo ""

    echo "================================"
    echo "       Bootstrap SUCCESS"
    echo "================================"

    echo "[INFO] Agent:"
    echo "$AGENT_FILE"

    echo ""
    echo "[INFO] Передача управления агенту..."

} | fix_print

# ==========================================
# Проверка статуса Bootstrap
# ==========================================
EXIT_CODE=${PIPESTATUS[0]}

if [ "$EXIT_CODE" -ne 0 ]; then
    exit "$EXIT_CODE"
fi

# ==========================================
# Повторная проверка Python platform
# ==========================================
if ! fix_python_platform >/dev/null 2>&1; then
    exit 1
fi

# ==========================================
# Запуск агента
# ==========================================
exec python "$AGENT_FILE" </dev/tty
