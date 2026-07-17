pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false
    width: 0; height: 0

    property bool panelOpen:    false
    property var  targetScreen: null

    property bool unlocked: false
    property ListModel entries: ListModel {}
    property var codes:   ({})   // entry id -> current code string
    property int nowSec:  Math.floor(Date.now() / 1000)

    readonly property string _vaultDir:    "/home/nexus/.local/share/quickshell"
    readonly property string _vaultPath:   _vaultDir + "/totp_vault.gpg"
    readonly property string _keyScript:   "/home/nexus/.config/quickshell/bar/scripts/totp_vault_key.sh"
    readonly property string _codesScript: "/home/nexus/.config/quickshell/bar/scripts/totp_codes.py"

    function togglePanel(screen) {
        if (panelOpen && targetScreen === screen) {
            closePanel()
        } else {
            targetScreen = screen
            panelOpen    = true
        }
    }

    function closePanel() {
        panelOpen = false
    }

    // ── Unlock (called by UnlockView once face/sudo auth succeeds) ─────────
    function unlockVault() {
        decryptProc.running = false
        decryptProc.command = ["sh", "-c",
            "key=$(" + _keyScript + "); pf=$(mktemp); chmod 600 \"$pf\"; printf '%s' \"$key\" > \"$pf\"; " +
            "if [ -f " + _vaultPath + " ]; then gpg --batch --quiet --passphrase-file \"$pf\" --decrypt " + _vaultPath + " 2>/dev/null; fi; " +
            "rm -f \"$pf\""]
        decryptProc.running = true
    }

    function lockVault() {
        unlocked = false
        entries.clear()
        codes = ({})
    }

    Process {
        id: decryptProc
        stdout: StdioCollector {
            id: decryptCollector
            onStreamFinished: {
                root.entries.clear()
                var text = decryptCollector.text.trim()
                if (text) {
                    try {
                        var data = JSON.parse(text)
                        for (var i = 0; i < data.length; i++) root.entries.append(data[i])
                    } catch (e) {
                        console.log("TotpVaultState: failed to parse vault contents:", e)
                    }
                }
                root.unlocked = true
                root.refreshCodes()
            }
        }
    }

    // ── Persist (re-encrypt whole vault on every add/delete) ────────────────
    Process {
        id: encryptProc
        stdinEnabled: true
    }

    function persist() {
        var arr = []
        for (var i = 0; i < entries.count; i++) arr.push(entries.get(i))
        var json = JSON.stringify(arr)

        encryptProc.running = false
        encryptProc.command = ["sh", "-c",
            "key=$(" + _keyScript + "); pf=$(mktemp); chmod 600 \"$pf\"; printf '%s' \"$key\" > \"$pf\"; " +
            "mkdir -p " + _vaultDir + "; " +
            "gpg --batch --quiet --yes --passphrase-file \"$pf\" --symmetric --cipher-algo AES256 -o " + _vaultPath + "; " +
            "rm -f \"$pf\""]
        encryptProc.stdinEnabled = true
        encryptProc.running = true
        encryptProc.write(json)
        encryptProc.stdinEnabled = false
    }

    function addEntry(entry) {
        entries.append({
            id:     "e" + Date.now() + "_" + Math.floor(Math.random() * 100000),
            label:  entry.label,
            issuer: entry.issuer || "",
            secret: entry.secret,
            digits: entry.digits || 6,
            period: entry.period || 30,
            algo:   entry.algo   || "SHA1"
        })
        persist()
        refreshCodes()
    }

    function deleteEntry(id) {
        for (var i = 0; i < entries.count; i++) {
            if (entries.get(i).id === id) { entries.remove(i); break }
        }
        persist()
        refreshCodes()
    }

    // ── Code generation ──────────────────────────────────────────────────
    Process {
        id: codesProc
        stdinEnabled: true
        stdout: StdioCollector {
            id: codesCollector
            onStreamFinished: {
                try {
                    var arr = JSON.parse(codesCollector.text)
                    var map = {}
                    for (var i = 0; i < arr.length; i++) map[arr[i].id] = arr[i].code
                    root.codes = map
                } catch (e) {
                    console.log("TotpVaultState: failed to parse codes:", e)
                }
            }
        }
    }

    function refreshCodes() {
        if (!unlocked || entries.count === 0) { codes = ({}); return }
        var arr = []
        for (var i = 0; i < entries.count; i++) {
            var e = entries.get(i)
            arr.push({ id: e.id, secret: e.secret, digits: e.digits, period: e.period, algo: e.algo })
        }
        codesProc.running = false
        codesProc.command = ["python3", _codesScript]
        codesProc.stdinEnabled = true
        codesProc.running = true
        codesProc.write(JSON.stringify(arr))
        codesProc.stdinEnabled = false
    }

    Timer {
        interval: 1000
        running:  true
        repeat:   true
        onTriggered: {
            var s = Math.floor(Date.now() / 1000)
            root.nowSec = s
            if (root.unlocked && s % 30 === 0) root.refreshCodes()
        }
    }
}
