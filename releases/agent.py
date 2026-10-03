
# ============================================================
# WARDEN AGENT RELEASE
# Generated automatically.
# ============================================================

import sys
import types


# ------------------------------------------------------------
# Embedded modules
# ------------------------------------------------------------

_WARDEN_MODULES = {}

_WARDEN_MODULES['state'] = 'import random\n\nMY_SESSION_ID = str(random.randint(100000, 999999))\n\nIS_PAUSED = False\nFORCE_RESTART = False\nCURRENT_DEEPLINK = "EMPTY"'

_WARDEN_MODULES['config'] = 'FIREBASE_URL = "https://wardenpanel-default-rtdb.firebaseio.com/"\n\nHEARTBEAT_PATH = "/sdcard/Arceus X/Workspace/heartbeat.txt"\n\nMAX_IDLE = 120\nCHECK_INTERVAL = 20\n\nLICENSE_FILE = "license.txt"'

_WARDEN_MODULES['logger'] = 'import time\nimport os\n\n\nLOG_FILE = "warden.log"\n\n\ndef log_event(message):\n    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")\n\n    entry = f"[{timestamp}] {message}\\n"\n\n    print(entry.strip())\n\n    with open(LOG_FILE, "a", encoding="utf-8") as f:\n        f.write(entry)'

_WARDEN_MODULES['license'] = 'import os\nimport requests\n\nfrom config import FIREBASE_URL, LICENSE_FILE\n\n\ndef load_license():\n    if not os.path.exists(LICENSE_FILE):\n        return None, None\n\n    with open(LICENSE_FILE, "r") as f:\n        lines = f.read().splitlines()\n\n    if len(lines) < 2:\n        return None, None\n\n    return lines[0].strip().upper(), lines[1].strip()\n\n\ndef save_license(key, tg_id):\n    with open(LICENSE_FILE, "w") as f:\n        f.write(f"{key}\\n{tg_id}")\n\n\ndef check_license(key):\n    try:\n        res = requests.get(\n            f"{FIREBASE_URL}keys/{key}.json",\n            timeout=10\n        )\n\n        if res.status_code != 200:\n            return None\n\n        if res.text.strip() == "null":\n            return None\n\n        return res.json()\n\n    except Exception as e:\n        print(f"License check error: {e}")\n        return None\n\ndef validate_license(data):\n    if not data:\n        return False\n\n    if data.get("status") != "active":\n        return False\n\n    return True\n\n\ndef register_session(key, session_id, tg_id):\n    try:\n        requests.patch(\n            f"{FIREBASE_URL}keys/{key}.json",\n            json={\n                "session_id": session_id,\n                "telegram_id": tg_id\n            },\n            timeout=10\n        )\n\n    except Exception as e:\n        print(f"Session registration error: {e}")\n\n\ndef check_session(data, my_session_id):\n    if not data:\n        return False\n\n    old_session = str(data.get("session_id", ""))\n\n    if old_session and old_session != my_session_id:\n        return False\n\n    return True\n\ndef remove_license_file():\n    if os.path.exists(LICENSE_FILE):\n        try:\n            os.remove(LICENSE_FILE)\n            print("[🗑️] License file removed.")\n        except Exception as e:\n            print(f"[⚠️] Error removing license: {e}")'

_WARDEN_MODULES['commands'] = 'import state\ndef handle_command(cmd):\n    if cmd == "restart":\n        state.FORCE_RESTART = True\n\n    elif cmd == "pause":\n        state.IS_PAUSED = True\n\n    elif cmd == "resume":\n        state.IS_PAUSED = False'

_WARDEN_MODULES['firebase'] = 'import os\nimport sys\nimport time\nimport requests\n\nfrom config import FIREBASE_URL\nfrom license import remove_license_file\nfrom commands import handle_command \n\nimport state\n\n\ndef internet_loop(key, tg_id):\n    while True:\n        try:\n            res = requests.get(\n                f"{FIREBASE_URL}keys/{key}.json",\n                timeout=10\n            )\n\n            if res.status_code == 200:\n\n                # Ключ удалён из базы\n                if res.text.strip() == "null" or not res.json():\n                    print("🚨 Лицензия удалена из базы.")\n\n                    remove_license_file()\n\n                    os._exit(1)\n\n                data = res.json()\n\n                # Проверка статуса\n                if data.get("status") != "active":\n                    print("❌ Лицензия отключена.")\n\n                    remove_license_file()\n\n                    os._exit(1)\n\n                # Проверка Telegram ID\n                db_tg = str(data.get("telegram_id", ""))\n\n                if not db_tg or db_tg != str(tg_id):\n                    print("🔄 Привязка сброшена.")\n\n                    remove_license_file()\n\n                    os.execv(\n                        sys.executable,\n                        ["python"] + sys.argv\n                    )\n\n                # Проверка сессии\n                db_session = str(data.get("session_id", ""))\n\n                if db_session and db_session != state.MY_SESSION_ID:\n                    print("🚨 Обнаружен другой запуск ключа.")\n\n                    remove_license_file()\n\n                    os._exit(1)\n\n                # Получаем команды\n\n                state.CURRENT_DEEPLINK = data.get(\n                    "deeplink",\n                    "EMPTY"\n                )\n\n                cmd = data.get(\n                    "command",\n                    "none"\n                )\n\n                if cmd == "restart":\n                    handle_command(cmd)\n\n                    requests.patch(\n                        f"{FIREBASE_URL}keys/{key}.json",\n                        json={"command": "none"}\n                    )\n\n                    print("[📡] Restart command")\n\n                elif cmd == "pause":\n                    handle_command(cmd)\n\n                    print("[📡] Pause command")\n\n                elif cmd == "resume":\n                    handle_command(cmd)\n\n                    requests.patch(\n                        f"{FIREBASE_URL}keys/{key}.json",\n                        json={"command": "none"}\n                    )\n\n                    print("[📡] Resume command")\n\n        except Exception as e:\n            print(f"Firebase error: {e}")\n\n        time.sleep(12)'

_WARDEN_MODULES['recovery'] = 'import os\nimport time\nimport subprocess\n\nfrom config import HEARTBEAT_PATH\nfrom logger import log_event\nimport state\n\n\ndef restart_roblox(reason):\n\n    log_event(f"Recovery started: {reason}")\n\n    if (\n        state.CURRENT_DEEPLINK == "EMPTY"\n        or not state.CURRENT_DEEPLINK.startswith("roblox://")\n    ):\n        print("[Recovery] Deeplink не настроен.")\n        return\n\n    subprocess.call(\n        [\n            "su",\n            "-c",\n            "pkill -9 -f com.roblox.client"\n        ]\n    )\n\n    subprocess.call(\n        [\n            "su",\n            "-c",\n            "am force-stop com.roblox.client"\n        ]\n    )\n\n    if os.path.exists(HEARTBEAT_PATH):\n        try:\n            os.remove(HEARTBEAT_PATH)\n        except Exception:\n            pass\n\n    time.sleep(2)\n\n    subprocess.call(\n        [\n            "su",\n            "-c",\n            "input keyevent KEYCODE_WAKEUP"\n        ]\n    )\n\n    subprocess.call(\n        [\n            "su",\n            "-c",\n            "input keyevent KEYCODE_HOME"\n        ]\n    )\n\n    time.sleep(2)\n\n    subprocess.call(\n        [\n            "su",\n            "-c",\n            f"am start -a android.intent.action.VIEW -d \'{state.CURRENT_DEEPLINK}\' --activity-brought-to-front"\n        ]\n    )\n\n    print("[Recovery] Roblox запущен.")\n\n    time.sleep(45)'

_WARDEN_MODULES['watchdog'] = 'import os\nimport time\nimport subprocess\n\nfrom recovery import restart_roblox\n\nfrom config import (\n    HEARTBEAT_PATH,\n    MAX_IDLE,\n    CHECK_INTERVAL\n)\n\nimport state\n\n\ndef watchdog_loop():\n    print("=== Warden Watchdog запущен ===")\n\n    while True:\n        try:\n            if state.IS_PAUSED:\n                time.sleep(CHECK_INTERVAL)\n                continue\n\n            should_restart = False\n            reason = ""\n\n            # Проверка принудительного рестарта\n            if state.FORCE_RESTART:\n                should_restart = True\n                reason = "Принудительная команда."\n                state.FORCE_RESTART = False\n\n            # Проверка Roblox на экране\n            if not should_restart:\n                try:\n                    focus_check = subprocess.check_output(\n                        [\n                            "su",\n                            "-c",\n                            "dumpsys window | grep -E \'mCurrentFocus|mFocusedApp|mFocusedWindow\' | grep \'com.roblox.client\'"\n                        ]\n                    ).decode()\n\n                    if not focus_check.strip():\n                        should_restart = True\n                        reason = "Roblox не на экране."\n\n                except Exception:\n                    should_restart = True\n                    reason = "Не удалось проверить Roblox."\n\n            # Проверка heartbeat\n            if not should_restart:\n\n                if os.path.exists(HEARTBEAT_PATH):\n\n                    last_mod = os.path.getmtime(HEARTBEAT_PATH)\n                    idle_time = int(time.time() - last_mod)\n\n                    if idle_time > MAX_IDLE:\n                        should_restart = True\n                        reason = f"Нет heartbeat {idle_time} секунд."\n\n                    else:\n                        print(\n                            f"[{time.strftime(\'%H:%M:%S\')}] "\n                            f"Roblox работает. Ping: {idle_time} сек."\n                        )\n\n                else:\n                    print(\n                        f"[{time.strftime(\'%H:%M:%S\')}] "\n                        "heartbeat.txt не найден."\n                    )\n\n            # Передаем восстановление в Recovery\n            if should_restart:\n\n                if (\n                    state.CURRENT_DEEPLINK == "EMPTY"\n                    or not state.CURRENT_DEEPLINK.startswith("roblox://")\n                ):\n                    print("⚠️ Deeplink не настроен.")\n                    time.sleep(15)\n                    continue\n\n                print(\n                    f"[{time.strftime(\'%H:%M:%S\')}] "\n                    f"Причина: {reason}"\n                )\n\n                restart_roblox(reason)\n\n        except Exception as e:\n            print(f"Watchdog error: {e}")\n\n        time.sleep(CHECK_INTERVAL)'

_WARDEN_MODULES['setup'] = 'import os\nimport subprocess\n\n\nWORKSPACE_DIR = "/sdcard/Arceus X/Workspace"\nAUTOEXEC_DIR = "/storage/emulated/0/Arceus X/Autoexec"\n\nHEARTBEAT_FILE = os.path.join(\n    AUTOEXEC_DIR,\n    "warden_heartbeat.txt"\n)\n\nHEARTBEAT_SCRIPT = """task.spawn(function()\n    while task.wait(30) do\n        pcall(function()\n            writefile("heartbeat.txt", tostring(os.time()))\n        end)\n    end\nend)\n"""\n\n\ndef install_requests():\n    try:\n        import requests\n\n        print("[✓] requests уже установлен.")\n        return True\n\n    except ImportError:\n        print("[!] requests не найден.")\n        print("[SETUP] Устанавливаем requests...")\n\n        result = subprocess.run(\n            "pip install requests",\n            shell=True\n        )\n\n        if result.returncode != 0:\n            print("[❌] Не удалось установить requests.")\n            return False\n\n        print("[✓] requests установлен.")\n        return True\n\n\ndef create_directories():\n    print("[SETUP] Проверка директорий...")\n\n    os.makedirs(WORKSPACE_DIR, exist_ok=True)\n    os.makedirs(AUTOEXEC_DIR, exist_ok=True)\n\n    print("[✓] Директории готовы.")\n\n\ndef create_heartbeat():\n    if os.path.exists(HEARTBEAT_FILE):\n        print("[✓] Warden heartbeat уже существует.")\n        return True\n\n    print("[SETUP] Создание AutoExec heartbeat...")\n\n    try:\n        with open(\n            HEARTBEAT_FILE,\n            "w",\n            encoding="utf-8"\n        ) as file:\n            file.write(HEARTBEAT_SCRIPT)\n\n        print(f"[✓] AutoExec создан: {HEARTBEAT_FILE}")\n        return True\n\n    except Exception as e:\n        print(f"[❌] Не удалось создать AutoExec: {e}")\n        return False\n\n\ndef setup():\n    print("""\n==========================\n       Warden Setup\n==========================\n""")\n\n    if not install_requests():\n        return False\n\n    create_directories()\n\n    if not create_heartbeat():\n        return False\n\n    print("""\n==========================\n   Setup завершён\n==========================\n""")\n\n    return True\n\n\nif __name__ == "__main__":\n    setup()\n'

_WARDEN_MODULES['main'] = 'import threading\nimport time\n\nfrom logger import log_event\nfrom setup import setup\n\nimport state\nfrom firebase import internet_loop\nfrom watchdog import watchdog_loop\nfrom license import (\n    load_license,\n    save_license,\n    check_license,\n    validate_license,\n    register_session\n)\n\n\ndef authorize():\n    key, tg_id = load_license()\n\n    if key and tg_id:\n        print(f"[🔄] Проверка сохраненной лицензии {key}...")\n\n        data = check_license(key)\n\n        if validate_license(data):\n            print("[✓] Лицензия подтверждена.")\n            return key, tg_id\n\n        print("[❌] Сохраненная лицензия недействительна.")\n\n    while True:\n        raw = input(\n            "Введите ключ и TG ID через двоеточие (KEY:ID): "\n        )\n\n        if ":" not in raw:\n            print("Неверный формат.")\n            continue\n\n        parts = raw.split(":")\n\n        key = parts[0].strip().upper()\n        tg_id = parts[1].strip()\n\n        data = check_license(key)\n\n        if not data:\n            print("❌ Ключ не найден.")\n            continue\n\n        if not validate_license(data):\n            print("❌ Лицензия не активна.")\n            continue\n\n        save_license(key, tg_id)\n\n        return key, tg_id\n\n\ndef main():\n\n    if not setup():\n        print("[❌] Setup failed.")\n        return\n\n    print("""\n==========================\n     Warden Agent\n==========================\n""")\n\n    key, tg_id = authorize()\n\n    register_session(\n        key,\n        state.MY_SESSION_ID,\n        tg_id\n    )\n\n    print(\n        f"[🔒] Session registered: {state.MY_SESSION_ID}"\n    )\n\n    log_event("Agent started")\n\n    watchdog = threading.Thread(\n        target=watchdog_loop,\n        daemon=True\n    )\n\n    firebase = threading.Thread(\n        target=internet_loop,\n        args=(key, tg_id),\n        daemon=True\n    )\n\n    watchdog.start()\n    firebase.start()\n\n    while True:\n        time.sleep(60)\n\n\nif __name__ == "__main__":\n    main()\n\n'

# ------------------------------------------------------------
# Module loader
# ------------------------------------------------------------

def _warden_load(name):

    if name in sys.modules:
        return sys.modules[name]

    if name not in _WARDEN_MODULES:
        raise ImportError(
            f"No module named {name!r}"
        )

    module = types.ModuleType(name)

    module.__file__ = (
        "<warden-release>/" + name + ".py"
    )

    sys.modules[name] = module

    source = _WARDEN_MODULES[name]

    code = compile(
        source,
        module.__file__,
        "exec"
    )

    exec(
        code,
        module.__dict__
    )

    return module


# ------------------------------------------------------------
# Load embedded modules
# ------------------------------------------------------------

for _module_name in _WARDEN_MODULES:
    _warden_load(_module_name)


# ------------------------------------------------------------
# Start agent
# ------------------------------------------------------------

if __name__ == "__main__":
    _warden_load("main").main()
