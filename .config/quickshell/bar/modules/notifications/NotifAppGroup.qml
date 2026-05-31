import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import ".."

Item {
    id: root

    property string appName
    property string appIcon
    property int    count
    property int    unreadCount
    property bool   collapsed

    signal clearRequested
    signal toggleCollapse

    implicitWidth: 356

    readonly property var _items: {
        var arr = []
        for (var i = 0; i < NotifService.historyModel.count; i++) {
            var it = NotifService.historyModel.get(i)
            if (it.appName === root.appName) arr.push(it)
        }
        return arr
    }

    implicitHeight: root.count === 1
                    ? singleView.implicitHeight
                    : root.collapsed
                      ? groupBody.implicitHeight
                      : groupHeader.implicitHeight + 4 + groupBody.implicitHeight

    // ── SINGLE NOTIFICATION ───────────────────────────────────────────────
    NotificationItem {
        id: singleView
        anchors.left:  parent.left
        anchors.right: parent.right
        visible: root.count === 1

        notifId:     root._items.length > 0 ? root._items[0].notifId     : 0
        appName:     root._items.length > 0 ? root._items[0].appName     : root.appName
        appIcon:     root._items.length > 0 ? root._items[0].appIcon     : root.appIcon
        image:       root._items.length > 0 ? root._items[0].image       : ""
        summary:     root._items.length > 0 ? root._items[0].summary     : ""
        body:        root._items.length > 0 ? root._items[0].body        : ""
        timeStr:     root._items.length > 0 ? root._items[0].timeStr     : ""
        actionsJson: root._items.length > 0 ? root._items[0].actionsJson : "[]"
        hasDefault:  root._items.length > 0 ? root._items[0].hasDefault  : false
        read:        root._items.length > 0 ? root._items[0].read        : true
        dismissed:   root._items.length > 0 ? root._items[0].dismissed   : false

        onDismissRequested: NotifService.closeNotification(notifId)
        onReadRequested:    NotifService.markRead(notifId)
    }

    // ── GROUP HEADER (shown when count > 1) ───────────────────────────────
    Rectangle {
        id: groupHeader
        visible: root.count > 1 && !root.collapsed
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        implicitHeight: headerRow.implicitHeight + 8
        radius: Theme.pillRadius
        color: headerMouse.containsMouse && !root.collapsed
               ? Qt.rgba(0.18, 0.17, 0.30, 0.85)
               : Qt.rgba(0.12, 0.11, 0.22, 0.70)
        border.color: Theme.notifBorderDim
        border.width: 1
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: headerRow
            anchors {
                left:  parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin:  8
                rightMargin: 6
            }
            spacing: 6

            IconImage {
                source:       root.appIcon !== "" ? (root.appIcon.startsWith("/") ? "file://" + root.appIcon : root.appIcon.startsWith("image://") ? root.appIcon : "image://icon/" + root.appIcon) : ""
                implicitSize: 14
                visible:      root.appIcon !== ""
            }
            Text {
                visible:        root.appIcon === ""
                text:           ""
                font.family:    Theme.iconFamily
                font.pixelSize: 12
                color:          Theme.fgDim
            }

            Text {
                text:           root.appName
                font.family:    Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                font.weight:    Font.Medium
                color:          root.unreadCount > 0 ? Theme.accent : Theme.fgDim
                Layout.fillWidth: true
                elide:          Text.ElideRight
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            // Unread / total badge
            Rectangle {
                implicitWidth:  badgeLbl.implicitWidth + 8
                implicitHeight: 16
                radius: 8
                color:  root.unreadCount > 0 ? Theme.accent : Qt.rgba(0.70, 0.62, 0.86, 0.25)

                Text {
                    id: badgeLbl
                    anchors.centerIn: parent
                    text:           root.count > 9 ? "9+" : root.count
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 3
                    font.weight:    Font.Bold
                    color:          root.unreadCount > 0 ? Theme.bgSolid : Theme.accent
                }
            }

            // Collapse chevron (only shown when expanded)
            Text {
                visible:        !root.collapsed
                text:           ""   // expand_less
                font.family:    Theme.iconFamily
                font.pixelSize: 14
                color:          Theme.fgDim
            }

            // Clear app
            Rectangle {
                implicitWidth:  16; implicitHeight: 16
                radius: 8
                color:  clearHdr.containsMouse ? Theme.red : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Text {
                    anchors.centerIn: parent
                    text:           ""
                    font.family:    Theme.iconFamily
                    font.pixelSize: 11
                    color:          clearHdr.containsMouse ? Theme.bgSolid : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                MouseArea {
                    id: clearHdr
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: (m) => { m.accepted = true; root.clearRequested() }
                }
            }
        }

        // Clicking the header collapses when expanded
        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  root.collapsed ? Qt.ArrowCursor : Qt.PointingHandCursor
            z: -1
            enabled: !root.collapsed
            onClicked: root.toggleCollapse()
        }
    }

    // ── GROUP BODY ────────────────────────────────────────────────────────
    Item {
        id: groupBody
        visible: root.count > 1
        anchors.top:      root.collapsed ? parent.top : groupHeader.bottom
        anchors.topMargin: root.collapsed ? 0 : 4
        anchors.left:  parent.left
        anchors.right: parent.right
        implicitHeight: root.collapsed ? stackArea.implicitHeight : expandedCards.implicitHeight

        // ── Collapsed: stacked cards ──────────────────────────────────────
        Item {
            id: stackArea
            anchors.left:  parent.left
            anchors.right: parent.right
            visible: root.collapsed
            implicitHeight: topCard.implicitHeight + (root.count > 2 ? 12 : 6)

            // Shadow card 2 (deepest)
            Rectangle {
                visible: root.count >= 3
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.leftMargin:  12
                anchors.rightMargin: 12
                y: 12
                height: topCard.implicitHeight
                radius: Theme.pillRadius
                opacity: 0.25
                color: Theme.notifCardBg
                border.color: Qt.rgba(0.70, 0.62, 0.86, 0.12)
                border.width: 1
            }

            // Shadow card 1
            Rectangle {
                anchors.left:  parent.left
                anchors.right: parent.right
                anchors.leftMargin:  6
                anchors.rightMargin: 6
                y: 6
                height: topCard.implicitHeight
                radius: Theme.pillRadius
                opacity: 0.5
                color: Theme.notifCardBg
                border.color: Qt.rgba(0.70, 0.62, 0.86, 0.16)
                border.width: 1
            }

            // Top card
            NotificationItem {
                id: topCard
                anchors.left:  parent.left
                anchors.right: parent.right
                z: 2

                notifId:     root._items.length > 0 ? root._items[0].notifId     : 0
                appName:     root._items.length > 0 ? root._items[0].appName     : root.appName
                appIcon:     root._items.length > 0 ? root._items[0].appIcon     : root.appIcon
                image:       root._items.length > 0 ? root._items[0].image       : ""
                summary:     root._items.length > 0 ? root._items[0].summary     : ""
                body:        root._items.length > 0 ? root._items[0].body        : ""
                timeStr:     root._items.length > 0 ? root._items[0].timeStr     : ""
                actionsJson: root._items.length > 0 ? root._items[0].actionsJson : "[]"
                hasDefault:  root._items.length > 0 ? root._items[0].hasDefault  : false
                read:        root._items.length > 0 ? root._items[0].read        : true
                dismissed:   root._items.length > 0 ? root._items[0].dismissed   : false

                onDismissRequested: NotifService.closeNotification(notifId)
                onReadRequested:    NotifService.markRead(notifId)
            }

            // Transparent overlay — clicking the stacked card expands the group
            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                z: 3
                onClicked: root.toggleCollapse()
            }
        }

        // ── Expanded: flat list ───────────────────────────────────────────
        Column {
            id: expandedCards
            anchors.left:  parent.left
            anchors.right: parent.right
            visible: !root.collapsed
            spacing: 4

            Repeater {
                model: NotifService.historyModel

                delegate: NotificationItem {
                    required property var model

                    visible:     model.appName === root.appName
                    width:       expandedCards.width
                    notifId:     model.notifId
                    appName:     model.appName
                    appIcon:     model.appIcon
                    image:       model.image
                    summary:     model.summary
                    body:        model.body
                    timeStr:     model.timeStr
                    actionsJson: model.actionsJson
                    hasDefault:  model.hasDefault
                    read:        model.read
                    dismissed:   model.dismissed

                    onDismissRequested: NotifService.closeNotification(notifId)
                    onReadRequested:    NotifService.markRead(notifId)
                }
            }
        }
    }
}
