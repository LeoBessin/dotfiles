import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root

    property var modelData
    screen: modelData

    anchors.left:   true
    anchors.right:  true
    anchors.top:    true
    anchors.bottom: true

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell-toasts"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"
    surfaceFormat.opaque: false
    visible: toastModel.count > 0 && !NotifService.dnd

    mask: Region { item: toastColumn }

    ListModel { id: toastModel }

    Connections {
        target: NotifService
        function onToastRequested(toastData) {
            if (NotifService.centerOpen) return
            while (toastModel.count >= 5)
                toastModel.remove(toastModel.count - 1)
            toastModel.insert(0, toastData)
        }
    }

    function removeToast(notifId) {
        for (var i = 0; i < toastModel.count; i++) {
            if (toastModel.get(i).notifId === notifId) {
                toastModel.remove(i)
                return
            }
        }
    }

    Column {
        id: toastColumn
        anchors.top:         parent.top
        anchors.right:       parent.right
        anchors.topMargin:   Theme.barHeight + 10
        anchors.rightMargin: 10
        spacing: 6

        Repeater {
            model: toastModel
            delegate: ToastCard {
                required property var model

                notifId:     model.notifId
                appName:     model.appName
                appIcon:     model.appIcon
                image:       model.image
                summary:     model.summary
                body:        model.body
                timeStr:     model.timeStr
                actionsJson: model.actionsJson

                onExpired:          root.removeToast(notifId)
                onDismissRequested: root.removeToast(notifId)
            }
        }
    }
}
