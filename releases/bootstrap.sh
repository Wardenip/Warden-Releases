#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# Р¤РёРєСЃ РІС‹РІРѕРґР° РґР»СЏ Termux (СѓР±РёСЂР°РµРј РїРµСЂРµРєРѕСЃС‹)
# ==========================================
fix_print() {
    awk '{print $0 "\r"}'
}

# ==========================================
# Fallback РґР»СЏ РёР·РІРµСЃС‚РЅС‹С… РїСЂРѕР±Р»РµРјРЅС‹С… Android ABI
# (РЅРµ РїР°С‚С‡РёРј СЃРёСЃС‚РµРјРЅС‹Рµ С„Р°Р№Р»С‹ Python)
# ==========================================
fix_python_platform() {
    echo "[INFO] РџСЂРѕРІРµСЂРєР° РїР»Р°С‚С„РѕСЂРјС‹ Python..."

    # РќРѕСЂРјР°Р»СЊРЅС‹Р№ СЃР»СѓС‡Р°Р№ вЂ” РЅРёС‡РµРіРѕ РЅРµ С‚СЂРѕРіР°РµРј.
    if python -c "import sysconfig; sysconfig.get_platform()" >/dev/null 2>&1; then
        echo "[OK] РџР»Р°С‚С„РѕСЂРјР° Python РѕРїСЂРµРґРµР»СЏРµС‚СЃСЏ РЅРѕСЂРјР°Р»СЊРЅРѕ."
        return 0
    fi

    MACHINE="$(uname -m)"
    ABI_LIST="$(getprop ro.product.cpu.abilist 2>/dev/null)"
    API_LEVEL="$(getprop ro.build.version.sdk 2>/dev/null)"

    echo "[WARN] Python РЅРµ СЃРјРѕРі РѕРїСЂРµРґРµР»РёС‚СЊ РїР»Р°С‚С„РѕСЂРјСѓ."
    echo "[INFO] Kernel machine: $MACHINE"
    echo "[INFO] Android ABI: ${ABI_LIST:-unknown}"
    echo "[INFO] Android API: ${API_LEVEL:-unknown}"

    case "$MACHINE" in

        armv8)
            if printf '%s' "$ABI_LIST" | grep -qw "arm64-v8a"; then
                export _PYTHON_HOST_PLATFORM="android-aarch64"
                echo "[INFO] РСЃРїРѕР»СЊР·СѓРµРј ARM64 Android platform override."
            else
                echo "[FAIL] armv8 РѕР±РЅР°СЂСѓР¶РµРЅ, РЅРѕ ARM64 ABI РЅРµ РїРѕРґС‚РІРµСЂР¶РґС‘РЅ."
                return 1
            fi
            ;;

        aarch64)
            export _PYTHON_HOST_PLATFORM="android-aarch64"
            echo "[INFO] РСЃРїРѕР»СЊР·СѓРµРј ARM64 Android platform override."
            ;;

        x86_64)
            export _PYTHON_HOST_PLATFORM="android-x86_64"
            echo "[INFO] РСЃРїРѕР»СЊР·СѓРµРј x86_64 Android platform override."
            ;;

        i686|x86)
            export _PYTHON_HOST_PLATFORM="android-i686"
            echo "[INFO] РСЃРїРѕР»СЊР·СѓРµРј x86 Android platform override."
            ;;

        armv8l|armv7l|arm)
            export _PYTHON_HOST_PLATFORM="android-arm"
            echo "[INFO] РСЃРїРѕР»СЊР·СѓРµРј ARM32 Android platform override."
            ;;

        *)
            echo "[FAIL] РќРµРёР·РІРµСЃС‚РЅР°СЏ Р°СЂС…РёС‚РµРєС‚СѓСЂР°: $MACHINE"
            return 1
            ;;
    esac

    # РџРѕСЃР»Рµ override РѕР±СЏР·Р°С‚РµР»СЊРЅРѕ РїСЂРѕРІРµСЂСЏРµРј СЂРµР·СѓР»СЊС‚Р°С‚.
    PLATFORM="$(python -c "import sysconfig; print(sysconfig.get_platform())" 2>/dev/null)"

    if [ -z "$PLATFORM" ]; then
        echo "[FAIL] Python РІСЃС‘ РµС‰С‘ РЅРµ РјРѕР¶РµС‚ РѕРїСЂРµРґРµР»РёС‚СЊ РїР»Р°С‚С„РѕСЂРјСѓ."
        return 1
    fi

    echo "[OK] РџР»Р°С‚С„РѕСЂРјР° Python: $PLATFORM"
}

# ==========================================
# Р’РµСЃСЊ РєРѕРґ РїРѕРґРіРѕС‚РѕРІРєРё РѕРєСЂСѓР¶РµРЅРёСЏ
# ==========================================
{
    echo "================================"
    echo "       Warden Bootstrap"
    echo "================================"
    echo ""

    export DEBIAN_FRONTEND=noninteractive

    # --- РџСЂРѕРІРµСЂРєР° pkg ---
    if ! command -v pkg >/dev/null 2>&1; then
        echo "[FAIL] pkg РЅРµ РЅР°Р№РґРµРЅ."
        exit 1
    fi
    echo "[OK] pkg РЅР°Р№РґРµРЅ."
    echo ""

    # ==========================================
    # Р‘Р»РѕРє 1: Р‘Р°Р·РѕРІС‹Рµ РїР°РєРµС‚С‹
    # ==========================================
    echo "================================"
    echo "    РЈСЃС‚Р°РЅРѕРІРєР° Р±Р°Р·РѕРІС‹С… РїР°РєРµС‚РѕРІ"
    echo "================================"
    echo ""

    missing=()
    command -v python >/dev/null 2>&1 || missing+=(python)
    { command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; } || missing+=(python-pip)
    command -v curl >/dev/null 2>&1 || missing+=(curl)

    if [ "${#missing[@]}" -eq 0 ]; then
        echo "[OK] python, pip, curl СѓР¶Рµ СѓСЃС‚Р°РЅРѕРІР»РµРЅС‹."
    else
        echo "[INFO] Р‘СѓРґСѓС‚ СѓСЃС‚Р°РЅРѕРІР»РµРЅС‹: ${missing[*]}"
        echo ""

        echo "[INFO] РћР±РЅРѕРІР»РµРЅРёРµ СЃРїРёСЃРєРѕРІ РїР°РєРµС‚РѕРІ..."
        if ! pkg update -y </dev/null >/dev/null 2>&1; then
            echo "[FAIL] РќРµ СѓРґР°Р»РѕСЃСЊ РѕР±РЅРѕРІРёС‚СЊ СЃРїРёСЃРєРё РїР°РєРµС‚РѕРІ."
            exit 1
        fi
        echo "[OK] РЎРїРёСЃРєРё РїР°РєРµС‚РѕРІ РѕР±РЅРѕРІР»РµРЅС‹."
        echo ""

        echo "[INFO] РЈСЃС‚Р°РЅРѕРІРєР° РїР°РєРµС‚РѕРІ..."
        if ! pkg install -y "${missing[@]}" </dev/null >/dev/null 2>&1; then
            echo "[FAIL] РЈСЃС‚Р°РЅРѕРІРєР° Р±Р°Р·РѕРІС‹С… РїР°РєРµС‚РѕРІ РЅРµ СѓРґР°Р»Р°СЃСЊ."
            exit 1
        fi

        hash -r
        echo "[OK] Р‘Р°Р·РѕРІС‹Рµ РїР°РєРµС‚С‹ СѓСЃРїРµС€РЅРѕ СѓСЃС‚Р°РЅРѕРІР»РµРЅС‹."
    fi
    echo ""

    # ==========================================
    # Р‘Р»РѕРє 1.5: Fallback РґР»СЏ РїСЂРѕР±Р»РµРјРЅС‹С… Android ABI
    # ==========================================
    if ! fix_python_platform; then
        exit 1
    fi
    echo ""

    # ==========================================
    # Р‘Р»РѕРє 2: Python-Р·Р°РІРёСЃРёРјРѕСЃС‚Рё
    # ==========================================
    echo "================================"
    echo "   РџСЂРѕРІРµСЂРєР° Python-Р·Р°РІРёСЃРёРјРѕСЃС‚РµР№"
    echo "================================"
    echo ""

    if python -c "import requests" >/dev/null 2>&1; then
        echo "[OK] requests СѓР¶Рµ СѓСЃС‚Р°РЅРѕРІР»РµРЅ."
    else
        echo "[INFO] РЈСЃС‚Р°РЅРѕРІРєР° requests..."
        if ! python -m pip install requests --disable-pip-version-check >/dev/null 2>&1; then
            echo "[FAIL] РќРµ СѓРґР°Р»РѕСЃСЊ СѓСЃС‚Р°РЅРѕРІРёС‚СЊ requests."
            exit 1
        fi
        echo "[OK] requests СѓСЃРїРµС€РЅРѕ СѓСЃС‚Р°РЅРѕРІР»РµРЅ."
    fi
    echo ""

    # ==========================================
    # Р‘Р»РѕРє 3: РЎРёСЃС‚РµРјРЅС‹Рµ С‚СЂРµР±РѕРІР°РЅРёСЏ
    # ==========================================
    echo "================================"
    echo "    РџСЂРѕРІРµСЂРєР° СЃРёСЃС‚РµРјС‹ Рё РїСѓС‚РµР№"
    echo "================================"
    echo ""

    # Root (СЃС‚СЂРѕРіРѕ РѕР±СЏР·Р°С‚РµР»СЊРЅС‹Р№)
    if su -c "id" >/dev/null 2>&1; then
        echo "[OK] Root-РґРѕСЃС‚СѓРї Р°РєС‚РёРІРµРЅ."
    else
        echo "[FAIL] Root-РґРѕСЃС‚СѓРї РЅРµ РЅР°Р№РґРµРЅ."
        exit 1
    fi

    # Storage
    STORAGE_DIR="/storage/emulated/0"
    if [ -d "$STORAGE_DIR" ]; then
        echo "[OK] Storage РґРѕСЃС‚СѓРїРЅР°."
        STORAGE_TEST="$STORAGE_DIR/.warden_storage_test_$$"
        if touch "$STORAGE_TEST" >/dev/null 2>&1; then
            rm -f "$STORAGE_TEST"
            echo "[OK] Storage РґРѕСЃС‚СѓРїРЅР° РґР»СЏ Р·Р°РїРёСЃРё."
        else
            echo "[FAIL] Р—Р°РїРёСЃСЊ РІ Storage Р·Р°РїСЂРµС‰РµРЅР°."
            echo "[INFO] Р’С‹РїРѕР»РЅРёС‚Рµ РІ Termux: termux-setup-storage"
            exit 1
        fi
    else
        echo "[FAIL] Storage РЅРµ РЅР°Р№РґРµРЅР°."
        echo "[INFO] Р’С‹РїРѕР»РЅРёС‚Рµ РІ Termux: termux-setup-storage"
        exit 1
    fi
    echo ""

    # ==========================================
    # Р‘Р»РѕРє 4: Р—Р°РіСЂСѓР·РєР° РђРіРµРЅС‚Р° (РўРћР›Р¬РљРћ GitHub Release)
    # ==========================================
    echo "================================"
    echo "        Р—Р°РіСЂСѓР·РєР° РђРіРµРЅС‚Р°"
    echo "================================"
    echo ""

    GITHUB_OWNER="Wardenip"
    GITHUB_REPO="Warden-Releases"
    AGENT_FILE="$HOME/agent.py"

    RELEASE_API="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest"

    echo "[INFO] РџРѕР»СѓС‡РµРЅРёРµ РёРЅС„РѕСЂРјР°С†РёРё Рѕ РїРѕСЃР»РµРґРЅРµРј СЂРµР»РёР·Рµ..."

    RELEASE_JSON=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$RELEASE_API")

    if [ $? -ne 0 ] || [ -z "$RELEASE_JSON" ]; then
        echo "[FAIL] РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕР»СѓС‡РёС‚СЊ РёРЅС„РѕСЂРјР°С†РёСЋ Рѕ СЂРµР»РёР·Рµ."
        echo "[INFO] РЈР±РµРґРёС‚РµСЃСЊ, С‡С‚Рѕ РІ СЂРµРїРѕР·РёС‚РѕСЂРёРё СЃРѕР·РґР°РЅ GitHub Release СЃ С„Р°Р№Р»РѕРј agent.py."
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
        echo "[FAIL] Р¤Р°Р№Р» agent.py РѕС‚СЃСѓС‚СЃС‚РІСѓРµС‚ РІ РїРѕСЃР»РµРґРЅРµРј СЂРµР»РёР·Рµ."
        exit 1
    fi

    # РЈРґР°Р»СЏРµРј СЃС‚Р°СЂСѓСЋ РІРµСЂСЃРёСЋ РїРµСЂРµРґ СЃРєР°С‡РёРІР°РЅРёРµРј
    rm -f "$AGENT_FILE"

    echo "[INFO] РЎРєР°С‡РёРІР°РЅРёРµ agent.py..."
    if ! curl -fsSL "$AGENT_URL" -o "$AGENT_FILE"; then
        echo "[FAIL] РќРµ СѓРґР°Р»РѕСЃСЊ СЃРєР°С‡Р°С‚СЊ agent.py."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    if [ ! -s "$AGENT_FILE" ]; then
        echo "[FAIL] РЎРєР°С‡Р°РЅРЅС‹Р№ С„Р°Р№Р» РїСѓСЃС‚РѕР№."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    echo "[OK] agent.py СѓСЃРїРµС€РЅРѕ Р·Р°РіСЂСѓР¶РµРЅ."

    # РџСЂРѕРІРµСЂРєР° РІР°Р»РёРґРЅРѕСЃС‚Рё Python-С„Р°Р№Р»Р° РїРµСЂРµРґ Р·Р°РїСѓСЃРєРѕРј
    if ! python -m py_compile "$AGENT_FILE" >/dev/null 2>&1; then
        echo "[FAIL] agent.py РЅРµ РїСЂРѕС€РµР» РїСЂРѕРІРµСЂРєСѓ Python."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    echo "[OK] agent.py РїСЂРѕС€РµР» РїСЂРѕРІРµСЂРєСѓ РІР°Р»РёРґРЅРѕСЃС‚Рё."
    echo ""
    echo "================================"
    echo "       Bootstrap SUCCESS"
    echo "================================"
    echo "[INFO] РџРµСЂРµРґР°С‡Р° СѓРїСЂР°РІР»РµРЅРёСЏ Р°РіРµРЅС‚Сѓ..."

} | fix_print

# ==========================================
# РџСЂРѕРІРµСЂРєР° СЃС‚Р°С‚СѓСЃР° РІС‹РїРѕР»РЅРµРЅРёСЏ Bootstrap
# ==========================================
EXIT_CODE=${PIPESTATUS[0]}
if [ "$EXIT_CODE" -ne 0 ]; then
    exit "$EXIT_CODE"
fi

# ==========================================
# Р’РѕСЃСЃС‚Р°РЅРѕРІР»РµРЅРёРµ _PYTHON_HOST_PLATFORM РґР»СЏ Р°РіРµРЅС‚Р°
# ==========================================
if ! fix_python_platform >/dev/null 2>&1; then
    exit 1
fi

# ==========================================
# Handoff: РџРµСЂРµРґР°С‡Р° СѓРїСЂР°РІР»РµРЅРёСЏ Python-Р°РіРµРЅС‚Сѓ
# ==========================================
exec python "$HOME/agent.py" </dev/tty
