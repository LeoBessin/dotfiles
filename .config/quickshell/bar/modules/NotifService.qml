pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    visible: false
    width: 0
    height: 0

    // ── Notification server ───────────────────────────────────────────────
    NotificationServer {
        id: _server
        keepOnReload: true

        persistenceSupported:     true
        actionsSupported:         true
        imageSupported:           true
        bodyMarkupSupported:      true
        bodyHyperlinksSupported:  true

        onNotification: (notif) => {
            notif.tracked = true
            notif.closed.connect(() => root._markDismissed(notif.id))
            root._add(notif)
        }
    }

    // ── State ─────────────────────────────────────────────────────────────
    property ListModel historyModel:    _historyModel
    property ListModel appGroupsModel:  _appGroupsModel
    property var _liveRefs:     ({})
    property var _imageLocks:   ({})    // RetainableLocks keeping image data alive
    property var _collapsedApps: ({})    // persists collapse state by appName
    property int unreadCount:   0
    property bool centerOpen:   false
    property bool dnd:          false
    property var targetScreen:  null
    signal toastRequested(var toastData)

    Component {
        id: _lockComponent
        RetainableLock { locked: true }
    }

    ListModel { id: _historyModel }
    ListModel { id: _appGroupsModel }

    // ── Panel control ─────────────────────────────────────────────────────
    function toggleCenter(screen) {
        if (centerOpen && targetScreen === screen) {
            centerOpen = false
        } else {
            targetScreen = screen
            centerOpen = true
        }
    }
    function closeCenter() { centerOpen = false }

    // ── Group helpers ─────────────────────────────────────────────────────
    function _groupIndexOf(appName) {
        for (var i = 0; i < _appGroupsModel.count; i++) {
            if (_appGroupsModel.get(i).appName === appName) return i
        }
        return -1
    }

    function toggleAppCollapsed(appName) {
        var idx = _groupIndexOf(appName)
        if (idx < 0) return
        var cur = _appGroupsModel.get(idx).collapsed
        _appGroupsModel.setProperty(idx, "collapsed", !cur)
        _collapsedApps[appName] = !cur
    }

    // ── Internal helpers ──────────────────────────────────────────────────
    function _add(notif) {
        _liveRefs[notif.id] = notif
        var acts = []
        var hasDefault = false
        try {
            for (var i = 0; i < notif.actions.length; i++) {
                var act = notif.actions[i]
                if (act.identifier === "default") {
                    hasDefault = true
                } else if (act.text !== "") {
                    acts.push({ id: act.identifier, text: act.text })
                }
            }
        } catch(e) {}

        var data = {
            notifId:     notif.id,
            appName:     notif.appName  || "Unknown",
            appIcon:     notif.appIcon  || "",
            image:       notif.image    || "",
            summary:     notif.summary  || "",
            body:        notif.body     || "",
            timeStr:     Qt.formatTime(new Date(), "h:mm ap"),
            actionsJson: JSON.stringify(acts),
            hasDefault:  hasDefault,
            read:        false,
            dismissed:   false
        }

        // Keep notification alive so image URL stays valid in history
        if (data.image !== "") {
            var lock = _lockComponent.createObject(root, { object: notif })
            _imageLocks[notif.id] = lock
        }

        if (!dnd) {
            root.toastRequested(data)
        }

        _historyModel.insert(0, data)
        unreadCount++

        // Update or create the app group
        var gIdx = _groupIndexOf(data.appName)
        if (gIdx < 0) {
            _appGroupsModel.insert(0, {
                appName:     data.appName,
                appIcon:     data.appIcon,
                count:       1,
                unreadCount: 1,
                collapsed:   _collapsedApps[data.appName] !== undefined ? _collapsedApps[data.appName] : true
            })
        } else {
            _appGroupsModel.setProperty(gIdx, "count",       _appGroupsModel.get(gIdx).count + 1)
            _appGroupsModel.setProperty(gIdx, "unreadCount", _appGroupsModel.get(gIdx).unreadCount + 1)
            // Bubble the group to top
            if (gIdx > 0) {
                var entry = _appGroupsModel.get(gIdx)
                var snap = { appName: entry.appName, appIcon: entry.appIcon,
                             count: entry.count, unreadCount: entry.unreadCount, collapsed: entry.collapsed }
                _appGroupsModel.remove(gIdx)
                _appGroupsModel.insert(0, snap)
            }
        }
    }

    function _markDismissed(id) {
        // Keep _liveRefs[id] alive so action buttons can still invoke after
        // the sender (e.g. browser) closes the notification to suppress its own popup.
        for (var i = 0; i < _historyModel.count; i++) {
            if (_historyModel.get(i).notifId === id) {
                var wasUnread = !_historyModel.get(i).read
                var appName  = _historyModel.get(i).appName
                _historyModel.setProperty(i, "dismissed", true)
                _historyModel.setProperty(i, "read", true)
                if (wasUnread && unreadCount > 0) unreadCount--
                if (wasUnread) _decrementGroupUnread(appName)
                return
            }
        }
    }

    function _releaseImageLock(id) {
        var lock = _imageLocks[id]
        if (lock) {
            lock.locked = false
            lock.destroy()
            delete _imageLocks[id]
        }
    }

    function _decrementGroupUnread(appName) {
        var gIdx = _groupIndexOf(appName)
        if (gIdx < 0) return
        var cur = _appGroupsModel.get(gIdx).unreadCount
        if (cur > 0) _appGroupsModel.setProperty(gIdx, "unreadCount", cur - 1)
    }

    function _decrementGroupCount(appName) {
        var gIdx = _groupIndexOf(appName)
        if (gIdx < 0) return
        var cur = _appGroupsModel.get(gIdx).count
        if (cur <= 1) {
            _appGroupsModel.remove(gIdx)
        } else {
            _appGroupsModel.setProperty(gIdx, "count", cur - 1)
        }
    }

    // ── Public API ────────────────────────────────────────────────────────
    function closeNotification(notifId) {
        var ref = _liveRefs[notifId]
        try { if (ref) ref.dismiss() } catch(e) {}
        delete _liveRefs[notifId]
        _releaseImageLock(notifId)
        for (var i = 0; i < _historyModel.count; i++) {
            if (_historyModel.get(i).notifId === notifId) {
                var wasUnread = !_historyModel.get(i).read
                var appName  = _historyModel.get(i).appName
                _historyModel.remove(i)
                if (wasUnread && unreadCount > 0) unreadCount--
                _decrementGroupCount(appName)
                if (wasUnread) _decrementGroupUnread(appName)
                return
            }
        }
    }

    function markRead(notifId) {
        for (var i = 0; i < _historyModel.count; i++) {
            if (_historyModel.get(i).notifId === notifId && !_historyModel.get(i).read) {
                var appName = _historyModel.get(i).appName
                _historyModel.setProperty(i, "read", true)
                if (unreadCount > 0) unreadCount--
                _decrementGroupUnread(appName)
                return
            }
        }
    }

    function markAllRead() {
        for (var i = 0; i < _historyModel.count; i++)
            _historyModel.setProperty(i, "read", true)
        for (var j = 0; j < _appGroupsModel.count; j++)
            _appGroupsModel.setProperty(j, "unreadCount", 0)
        unreadCount = 0
    }

    function clearAll() {
        for (var k in _liveRefs) {
            try { _liveRefs[k].dismiss() } catch(e) {}
        }
        _liveRefs = {}
        for (var k2 in _imageLocks) _releaseImageLock(parseInt(k2))
        _historyModel.clear()
        _appGroupsModel.clear()
        unreadCount = 0
    }

    function clearApp(appName) {
        // Dismiss live refs for this app
        for (var i = _historyModel.count - 1; i >= 0; i--) {
            if (_historyModel.get(i).appName === appName) {
                var nid = _historyModel.get(i).notifId
                var ref = _liveRefs[nid]
                try { if (ref) ref.dismiss() } catch(e) {}
                delete _liveRefs[nid]
                _releaseImageLock(nid)
                var wasUnread = !_historyModel.get(i).read
                _historyModel.remove(i)
                if (wasUnread && unreadCount > 0) unreadCount--
            }
        }
        var gIdx = _groupIndexOf(appName)
        if (gIdx >= 0) _appGroupsModel.remove(gIdx)
    }
}
