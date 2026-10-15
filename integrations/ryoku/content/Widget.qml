import QtQuick
import Ryoku.PluginKit.Singletons

// content/Widget.qml: the bar glyph. Shows Claude's session limit (or today's
// tokens, per the Bar label setting); a click only opens the panel.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "glyph"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property string label: service ? service.label : "AI"
    readonly property real percent: service && service.session ? service.session.percent : 0

    implicitWidth: row.implicitWidth
    implicitHeight: Math.max(row.implicitHeight, 18 * root.s)

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6 * root.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F06A9}"
            // Warm once the session limit passes 80%.
            color: root.percent >= 80 ? Theme.sun : (root.active ? Theme.accent : Theme.dim)
            font.family: Theme.mono
            font.pixelSize: 14 * root.s
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 13 * root.s
            elide: Text.ElideRight
            width: root.widthBudget > 0 ? Math.min(implicitWidth, root.widthBudget) : implicitWidth
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: if (root.pluginApi) root.pluginApi.togglePanel()
    }
}
