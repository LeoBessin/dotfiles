// BarWidget.qml — reusable hoverable pill container
// Usage:
//   BarWidget {
//       onClicked: { ... }
//       content: Row { ... }
//   }
import QtQuick
import QtQuick.Layouts
import "."

Item {
    id: root

    property alias content: contentLoader.sourceComponent
    property bool  hovered: mouseArea.containsMouse
    signal clicked
    signal rightClicked
    signal scrolled(int delta)

    implicitHeight: Theme.barHeight
    implicitWidth:  contentLayout.implicitWidth + Theme.widgetPad * 2

    // Visual pill — inset vertically so it stays inside the bar border
    Rectangle {
        anchors.centerIn: parent
        width:  parent.width
        height: parent.height - 8
        radius: Theme.pillRadius
        color:  hovered ? Theme.bgHover : "transparent"

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    // Content
    Item {
        id: contentLayout
        anchors.centerIn: parent
        implicitWidth:    contentLoader.implicitWidth
        implicitHeight:   contentLoader.implicitHeight

        Loader {
            id: contentLoader
            anchors.centerIn: parent
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill:  parent
        hoverEnabled:  true
        cursorShape:   Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else
                root.clicked()
        }

        onWheel: (wheel) => root.scrolled(wheel.angleDelta.y)
    }
}
