#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
# Fallback for known problematic Android ABI
# (does not patch system Python files)
# ==========================================
fix_python_platform() {
    echo "[INFO] Checking Python platform..."

    if python -c "import sysconfig; sysconfig.get_platform()" >/dev/null 2>&1; then
        echo "[OK] Python platform detected correctly."
        return 0
    fi

    MACHINE="$(uname -m)"
    ABI_LIST="$(getprop ro.product.cpu.abilist 2>/dev/null)"
    API_LEVEL="$(getprop ro.build.version.sdk 2>/dev/null)"

    echo "[WARN] Python failed to detect platform."
    echo "[INFO] Kernel machine: $MACHINE"
    echo "[INFO] Android ABI: ${ABI_LIST:-unknown}"
    echo "[INFO] Android API: ${API_LEVEL:-unknown}"

    case "$MACHINE" in
        armv8)
            if printf '%s' "$ABI_LIST" | grep -qw "arm64-v8a"; then
                export _PYTHON_HOST_PLATFORM="android-aarch64"
                echo "[INFO] Using ARM64 Android platform override."
            else
                echo "[FAIL] armv8 detected but ARM64 ABI not confirmed."
                return 1
            fi
            ;;
        aarch64)
            export _PYTHON_HOST_PLATFORM="android-aarch64"
            echo "[INFO] Using ARM64 Android platform override."
            ;;
        x86_64)
            export _PYTHON_HOST_PLATFORM="android-x86_64"
            echo "[INFO] Using x86_64 Android platform override."
            ;;
        i686|x86)
            export _PYTHON_HOST_PLATFORM="android-i686"
            echo "[INFO] Using x86 Android platform override."
            ;;
        armv8l|armv7l|arm)
            export _PYTHON_HOST_PLATFORM="android-arm"
            echo "[INFO] Using ARM32 Android platform override."
            ;;
        *)
            echo "[FAIL] Unknown architecture: $MACHINE"
            return 1
            ;;
    esac

    PLATFORM="$(python -c "import sysconfig; print(sysconfig.get_platform())" 2>/dev/null)"

    if [ -z "$PLATFORM" ]; then
        echo "[FAIL] Python still cannot detect platform."
        return 1
    fi

    echo "[OK] Python platform: $PLATFORM"
}

# ==========================================
# Full environment setup
# ==========================================
{
    echo "================================"
    echo "       Warden Bootstrap"
    echo "================================"
    echo ""

    export DEBIAN_FRONTEND=noninteractive

    if ! command -v pkg >/dev/null 2>&1; then
        echo "[FAIL] pkg not found."
        exit 1
    fi
    echo "[OK] pkg found."
    echo ""

    echo "================================"
    echo "   Installing base packages"
    echo "================================"
    echo ""

    missing=()
    command -v python >/dev/null 2>&1 || missing+=(python)
    { command -v pip >/dev/null 2>&1 || command -v pip3 >/dev/null 2>&1; } || missing+=(python-pip)
    command -v curl >/dev/null 2>&1 || missing+=(curl)

    if [ "${#missing[@]}" -eq 0 ]; then
        echo "[OK] python, pip, curl already installed."
    else
        echo "[INFO] Will install: ${missing[*]}"
        echo ""

        echo "[INFO] Updating package lists..."
        if ! pkg update -y >/dev/null; then
            echo "[FAIL] Failed to update package lists."
            exit 1
        fi
        echo "[OK] Package lists updated."
        echo ""

        echo "[INFO] Installing packages..."
        if ! pkg install -y "${missing[@]}" >/dev/null; then
            echo "[FAIL] Failed to install base packages."
            exit 1
        fi

        hash -r
        echo "[OK] Base packages installed successfully."
    fi
    echo ""

    if ! fix_python_platform; then
        exit 1
    fi
    echo ""

    echo "================================"
    echo " Checking Python dependencies"
    echo "================================"
    echo ""

    if python -c "import requests" >/dev/null 2>&1; then
        echo "[OK] requests already installed."
    else
        echo "[INFO] Installing requests..."
        if ! python -m pip install requests --disable-pip-version-check >/dev/null 2>&1; then
            echo "[FAIL] Failed to install requests."
            exit 1
        fi
        echo "[OK] requests installed successfully."
    fi
    echo ""

    echo "================================"
    echo "  Checking system and paths"
    echo "================================"
    echo ""

    if su -c "id" >/dev/null 2>&1; then
        echo "[OK] Root access active."
    else
        echo "[FAIL] Root access not found."
        exit 1
    fi

    STORAGE_DIR="/storage/emulated/0"
    if [ -d "$STORAGE_DIR" ]; then
        echo "[OK] Storage available."
        STORAGE_TEST="$STORAGE_DIR/.warden_storage_test_$$"
        if touch "$STORAGE_TEST" >/dev/null 2>&1; then
            rm -f "$STORAGE_TEST"
            echo "[OK] Storage writable."
        else
            echo "[FAIL] Storage is not writable."
            echo "[INFO] Run in Termux: termux-setup-storage"
            exit 1
        fi
    else
        echo "[FAIL] Storage not found."
        echo "[INFO] Run in Termux: termux-setup-storage"
        exit 1
    fi
    echo ""

    echo "================================"
    echo "      Downloading Agent"
    echo "================================"
    echo ""

    GITHUB_OWNER="Wardenip"
    GITHUB_REPO="Warden-Releases"
    AGENT_FILE="$HOME/agent.py"
    RELEASE_API="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest"

    echo "[INFO] Fetching latest release info..."

    if ! RELEASE_JSON=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$RELEASE_API"); then
        echo "[FAIL] Failed to fetch release info."
        echo "[INFO] Make sure GitHub Release exists with agent.py file."
        exit 1
    fi

    PARSED=$(printf '%s' "$RELEASE_JSON" | python -c '
import json, sys
data = json.load(sys.stdin)
url = ""
digest = ""
for asset in data.get("assets", []):
    if asset.get("name") == "agent.py":
        url = asset.get("browser_download_url") or ""
        digest = asset.get("digest") or ""
        break
print(url)
print(digest)
')

    AGENT_URL=$(printf '%s\n' "$PARSED" | sed -n '1p')
    ASSET_DIGEST=$(printf '%s\n' "$PARSED" | sed -n '2p')

    if [ -z "$AGENT_URL" ]; then
        echo "[FAIL] agent.py not found in latest release."
        exit 1
    fi

    case "$ASSET_DIGEST" in
        sha256:*)
            ;;
        *)
            echo "[FAIL] Release has no sha256 digest for agent.py."
            exit 1
            ;;
    esac

    rm -f "$AGENT_FILE"

    echo "[INFO] Downloading agent.py..."
    if ! curl -fsSL "$AGENT_URL" -o "$AGENT_FILE"; then
        echo "[FAIL] Failed to download agent.py."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    if [ ! -s "$AGENT_FILE" ]; then
        echo "[FAIL] Downloaded file is empty."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    EXPECTED=$(printf '%s' "${ASSET_DIGEST#sha256:}" | tr '[:upper:]' '[:lower:]')
    ACTUAL=$(python -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$AGENT_FILE")

    if [ "$ACTUAL" != "$EXPECTED" ]; then
        echo "[FAIL] agent.py checksum mismatch."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    echo "[OK] agent.py checksum matches."

    if ! python -m py_compile "$AGENT_FILE" >/dev/null 2>&1; then
        echo "[FAIL] agent.py failed Python validation."
        rm -f "$AGENT_FILE"
        exit 1
    fi

    echo "[OK] agent.py passed validation."
    echo ""
    echo "================================"
    echo "      Bootstrap SUCCESS"
    echo "================================"
    echo "[INFO] Handing control to agent..."

}

EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
    exit "$EXIT_CODE"
fi

exec python "$HOME/agent.py" </dev/tty