import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."

Item {
    id: root

    property bool showAddForm: false
    property string uriError: ""

    // Parses an otpauth://totp/Issuer:account?secret=...&issuer=...&algorithm=...&digits=...&period=...
    // URI (the format most services show/export) into the manual-entry fields.
    function parseOtpAuthUri(uri) {
        var m = uri.trim().match(/^otpauth:\/\/totp\/([^?]*)\?(.*)$/i)
        if (!m) return null

        var label = decodeURIComponent(m[1])
        var params = {}
        m[2].split("&").forEach((pair) => {
            var kv = pair.split("=")
            if (kv.length >= 2)
                params[decodeURIComponent(kv[0])] = decodeURIComponent(kv.slice(1).join("=").replace(/\+/g, " "))
        })
        if (!params.secret) return null

        var issuer = params.issuer || ""
        var accountLabel = label
        var colonIdx = label.indexOf(":")
        if (colonIdx >= 0) {
            var labelIssuer = label.substring(0, colonIdx).trim()
            accountLabel = label.substring(colonIdx + 1).trim()
            if (!issuer) issuer = labelIssuer
        }

        return {
            label:  accountLabel,
            issuer: issuer,
            secret: params.secret.replace(/\s+/g, "").toUpperCase(),
            digits: parseInt(params.digits) || 6,
            period: parseInt(params.period) || 30,
            algo:   (params.algorithm || "SHA1").toUpperCase()
        }
    }

    function _applyUri() {
        var parsed = parseOtpAuthUri(uriField.text)
        if (!parsed) {
            uriError = "Couldn't parse that otpauth:// URI"
            return
        }
        uriError = ""
        labelField.text  = parsed.label
        issuerField.text = parsed.issuer
        secretField.text = parsed.secret
        digitsField.text = String(parsed.digits)
        periodField.text = String(parsed.period)
        var algoIdx = algoBox.model.indexOf(parsed.algo)
        algoBox.currentIndex = algoIdx >= 0 ? algoIdx : 0
        uriField.text = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Toolbar ───────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            height: 40

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }

                Text {
                    Layout.fillWidth: true
                    text: TotpVaultState.entries.count + (TotpVaultState.entries.count === 1 ? " code" : " codes")
                    font.family:    Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fgDim
                }

                Text {
                    text: root.showAddForm ? "close" : "add"
                    font.family:    Theme.iconFamily
                    font.pixelSize: 20
                    color: addHov.containsMouse ? Theme.accent : Theme.fgDim
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    MouseArea {
                        id: addHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showAddForm = !root.showAddForm
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.notifBorderDim }

        // ── Add-entry form ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.showAddForm ? formCol.implicitHeight + 24 : 0
            visible: root.showAddForm
            clip: true
            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.animFast } }

            ColumnLayout {
                id: formCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                TextField {
                    id: uriField
                    Layout.fillWidth: true
                    placeholderText: "Paste otpauth:// URI to autofill…"
                    placeholderTextColor: Theme.fgDim
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: Theme.fg
                    background: Rectangle {
                        radius: Theme.pillRadius
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: uriField.activeFocus ? Theme.notifBorderBase : Theme.notifBorderDim
                        border.width: 1
                    }
                    onAccepted: root._applyUri()
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.uriError !== ""
                    text: root.uriError
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    color: Theme.red
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.notifBorderDim }

                TextField {
                    id: labelField
                    Layout.fillWidth: true
                    placeholderText: "Label (e.g. GitHub)"
                    placeholderTextColor: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    background: Rectangle {
                        radius: Theme.pillRadius
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: Theme.notifBorderDim
                        border.width: 1
                    }
                }

                TextField {
                    id: issuerField
                    Layout.fillWidth: true
                    placeholderText: "Issuer (optional)"
                    placeholderTextColor: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                    background: Rectangle {
                        radius: Theme.pillRadius
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: Theme.notifBorderDim
                        border.width: 1
                    }
                }

                TextField {
                    id: secretField
                    Layout.fillWidth: true
                    placeholderText: "Secret (base32)"
                    placeholderTextColor: Theme.fgDim
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontSize - 1
                    color: Theme.fg
                    background: Rectangle {
                        radius: Theme.pillRadius
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.color: Theme.notifBorderDim
                        border.width: 1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    TextField {
                        id: digitsField
                        Layout.preferredWidth: 56
                        text: "6"
                        validator: IntValidator { bottom: 6; top: 10 }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                        background: Rectangle {
                            radius: Theme.pillRadius
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Theme.notifBorderDim
                            border.width: 1
                        }
                    }

                    TextField {
                        id: periodField
                        Layout.preferredWidth: 56
                        text: "30"
                        validator: IntValidator { bottom: 15; top: 120 }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                        color: Theme.fg
                        background: Rectangle {
                            radius: Theme.pillRadius
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.color: Theme.notifBorderDim
                            border.width: 1
                        }
                    }

                    ComboBox {
                        id: algoBox
                        Layout.fillWidth: true
                        model: ["SHA1", "SHA256", "SHA512"]
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                }

                Rectangle {
                    id: saveBtn
                    Layout.fillWidth: true
                    height: 32
                    radius: Theme.pillRadius
                    property bool canSave: labelField.text.trim() !== "" && secretField.text.trim() !== ""
                    color: canSave
                           ? (saveHov.containsMouse ? Theme.accentDim : Theme.accent)
                           : Qt.rgba(0.44, 0.39, 0.68, 0.15)
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: "Save"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        color: saveBtn.canSave ? Theme.bgSolid : Theme.fgDim
                    }

                    MouseArea {
                        id: saveHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: saveBtn.canSave ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: saveBtn.canSave
                        onClicked: {
                            TotpVaultState.addEntry({
                                label:  labelField.text.trim(),
                                issuer: issuerField.text.trim(),
                                secret: secretField.text.trim().replace(/\s+/g, "").toUpperCase(),
                                digits: parseInt(digitsField.text) || 6,
                                period: parseInt(periodField.text) || 30,
                                algo:   algoBox.currentText
                            })
                            labelField.text  = ""
                            issuerField.text = ""
                            secretField.text = ""
                            digitsField.text = "6"
                            periodField.text = "30"
                            algoBox.currentIndex = 0
                            uriField.text    = ""
                            root.uriError    = ""
                            root.showAddForm = false
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            visible: root.showAddForm
            color: Theme.notifBorderDim
        }

        // ── Entry list ────────────────────────────────────────────────────
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: TotpVaultState.entries
            spacing: 6
            topMargin: 10
            bottomMargin: 10
            leftMargin: 10
            rightMargin: 10

            Text {
                anchors.centerIn: parent
                visible: TotpVaultState.entries.count === 0
                text: "No codes yet — tap + to add one"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                color: Theme.fgDim
                wrapMode: Text.Wrap
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
            }

            delegate: VaultEntryRow {
                width: listView.width - 20
                entryId: model.id
                label:   model.label
                issuer:  model.issuer
                period:  model.period
            }
        }
    }
}
