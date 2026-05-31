pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root
    visible: false
    width: 0; height: 0

    // ── State ─────────────────────────────────────────────────────────────
    property string mode:         ""   // "" | "app" | "window" | "files" | "emoji" | "icon" | "clip"
    property var    targetScreen: null
    property string currentDir:   ""

    readonly property bool active: mode !== ""

    // ── Data models ───────────────────────────────────────────────────────
    property ListModel appModel:    ListModel {}
    property ListModel windowModel: ListModel {}
    property ListModel fileModel:   ListModel {}
    property ListModel emojiModel:  ListModel {}
    property ListModel iconModel:   ListModel {}
    property ListModel clipModel:   ListModel {}

    property bool appLoaded:    false
    property bool windowLoaded: false
    property bool fileLoaded:   false
    property bool emojiLoaded:  false
    property bool iconLoaded:   false
    property bool clipLoaded:   false

    // ── Public API ────────────────────────────────────────────────────────
    function open(m, screen) {
        targetScreen = screen ?? Quickshell.screens[0]
        mode = m
        if (m === "app")    _loadApps()
        if (m === "window") _loadWindows()
        if (m === "files")  _loadFiles(currentDir !== "" ? currentDir : _homeDir())
        if (m === "clip")   _loadClip()
        if (m === "emoji" && !emojiLoaded) _loadEmoji()
        if (m === "icon"  && !iconLoaded)  _loadIcons()
    }

    function close() {
        mode = ""
    }

    function navigateFiles(path) {
        _loadFiles(path)
    }

    function _homeDir() {
        return "/home/nexus"
    }

    // ── App loader — runs once at startup ─────────────────────────────────
    Process {
        id: appLoader
        command: ["bash", "-c",
            "{ IFS=: read -ra dirs <<< \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\"; " +
            "for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" \"${dirs[@]}\"; do echo \"$d/applications\"; done; } | " +
            "xargs -I{} find {} -name '*.desktop' 2>/dev/null | " +
            "sort -u | " +
            "xargs grep -l '^Type=Application' 2>/dev/null | " +
            "while IFS= read -r f; do " +
            "  nodisplay=$(grep -m1 '^NoDisplay=' \"$f\" | cut -d= -f2-); " +
            "  [ \"$nodisplay\" = 'true' ] && continue; " +
            "  name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "  exec_cmd=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | sed 's/ --file-forwarding//g;s/ @@[^ ]*//g;s/ %[A-Za-z]//g'); " +
            "  icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2- | sed 's/\\.[Pp][Nn][Gg]$//;s/\\.[Ss][Vv][Gg]$//;s/\\.[Xx][Pp][Mm]$//'); " +
            "  [ -z \"$name\" ] && continue; " +
            "  printf '%s\\t%s\\t%s\\n' \"$name\" \"$icon\" \"$exec_cmd\"; " +
            "done | sort -u"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.split("\t")
                if (parts.length >= 2) {
                    root.appModel.append({
                        name: parts[0],
                        icon: parts.length > 1 ? parts[1] : "",
                        exec: parts.length > 2 ? parts.slice(2).join("\t") : ""
                    })
                }
            }
        }
        onExited: { root.appLoaded = true }
    }

    // ── Window loader ─────────────────────────────────────────────────────
    Process {
        id: windowLoader
        command: ["bash", "-c",
            "hyprctl clients -j | jq -r '.[] | select(.title != \"\") | \"\\(.title)\\t\\(.class)\\t\\(.address)\"'"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.split("\t")
                if (parts.length >= 3) {
                    root.windowModel.append({
                        title:   parts[0],
                        cls:     parts[1],
                        address: parts[2]
                    })
                }
            }
        }
        onExited: { root.windowLoaded = true }
    }

    // ── File loader ───────────────────────────────────────────────────────
    Process {
        id: fileLoader
        stdout: SplitParser {
            onRead: (line) => {
                var parts = line.split("\t")
                if (parts.length >= 3) {
                    root.fileModel.append({
                        name:  parts[1],
                        path:  parts.slice(2).join("\t"),
                        isDir: parts[0] === "DIR"
                    })
                }
            }
        }
        onExited: { root.fileLoaded = true }
    }

    // ── Clipboard loader ──────────────────────────────────────────────────
    Process {
        id: clipLoader
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() !== "") {
                    var tab     = line.indexOf("\t")
                    var id      = tab >= 0 ? line.substring(0, tab) : line
                    var preview = tab >= 0 ? line.substring(tab + 1) : line
                    root.clipModel.append({ id: id, preview: preview, line: line })
                }
            }
        }
        onExited: root.clipLoaded = true
    }

    // ── Emoji loader ──────────────────────────────────────────────────────
    Process {
        id: emojiLoader
        command: ["bash", "-c",
            "cat /usr/lib/python3.14/site-packages/picker/data/emojis_*.csv"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "") return
                var spaceIdx = line.indexOf(" ")
                if (spaceIdx < 0) return
                var ch   = line.substring(0, spaceIdx)
                var name = line.substring(spaceIdx + 1).replace(/<small>[^<]*<\/small>/g, "").trim()
                root.emojiModel.append({ char: ch, name: name })
            }
        }
        onExited: root.emojiLoaded = true
    }

    // ── Nerd font / icon loader ───────────────────────────────────────────
    Process {
        id: iconLoader
        command: ["bash", "-c",
            "cat /usr/lib/python3.14/site-packages/picker/data/nerd_font.csv"
        ]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "") return
                var spaceIdx = line.indexOf(" ")
                if (spaceIdx < 0) return
                var ch   = line.substring(0, spaceIdx)
                var name = line.substring(spaceIdx + 1).trim()
                root.iconModel.append({ char: ch, name: name })
            }
        }
        onExited: root.iconLoaded = true
    }

    // ── Internal helpers ──────────────────────────────────────────────────
    function _loadApps() {
        appLoaded = false
        appModel.clear()
        appLoader.running = false
        appLoader.running = true
    }

    function _loadWindows() {
        windowLoaded = false
        windowModel.clear()
        windowLoader.running = false
        windowLoader.running = true
    }

    function _loadFiles(path) {
        fileLoaded = false
        currentDir = path
        fileModel.clear()
        var parentPath = path.substring(0, path.lastIndexOf("/"))
        if (parentPath === "") parentPath = "/"
        var script =
            "path=" + JSON.stringify(path) + "; " +
            "parent=" + JSON.stringify(parentPath) + "; " +
            "[ \"$path\" != '/' ] && printf 'DIR\\t..\\t%s\\n' \"$parent\"; " +
            "find \"$path\" -maxdepth 1 -mindepth 1 -not -name '.*' 2>/dev/null | sort | " +
            "while IFS= read -r p; do " +
            "  n=$(basename \"$p\"); " +
            "  [ -d \"$p\" ] && printf 'DIR\\t%s\\t%s\\n' \"$n\" \"$p\" || printf 'FILE\\t%s\\t%s\\n' \"$n\" \"$p\"; " +
            "done"
        fileLoader.command = ["bash", "-c", script]
        fileLoader.running = false
        fileLoader.running = true
    }

    function _loadClip() {
        clipLoaded = false
        clipModel.clear()
        clipLoader.running = false
        clipLoader.running = true
    }

    function _loadEmoji() {
        emojiModel.clear()
        emojiLoader.running = false
        emojiLoader.running = true
    }

    function _loadIcons() {
        iconModel.clear()
        iconLoader.running = false
        iconLoader.running = true
    }

}
