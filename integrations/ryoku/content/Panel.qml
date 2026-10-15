pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// content/Panel.qml: the dashboard under the glyph. Tabs for Claude, Grok and
// Antigravity; Claude also shows its plan limits. Clicking a tab only changes
// the view; REFRESH re-runs bin/ai-usage.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 380
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property var data: service ? service.data : null
    readonly property string tab: service ? service.tab : "claude"
    readonly property var svcData: data ? data[tab] : null
    readonly property var days: svcData ? svcData.days : []
    readonly property var models: svcData && svcData.models.length ? svcData.models : [{ name: "No usage yet", tokens: 0 }]
    readonly property real dayTop: Math.max(1, ...days.map(d => d.tokens))
    readonly property real modelTop: Math.max(1, ...models.map(m => m.tokens))

    // Recompute the countdowns each time the panel opens.
    property date now: new Date()
    onActiveChanged: if (active) now = new Date()

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    function dayName(iso, last) {
        if (last) return "Today";
        return new Date(iso + "T12:00:00").toLocaleDateString(Qt.locale(), "ddd");
    }

    component Meter: Rectangle {
        property real fraction: 0
        property color fill: Theme.accent
        height: 4 * root.s
        color: Theme.hair
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.fraction))
            height: parent.height
            color: parent.fill
        }
    }

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 12 * root.s

        // Tabs.
        Row {
            width: parent.width
            spacing: 14 * root.s

            Repeater {
                model: root.service ? root.service.tabs : []
                delegate: Text {
                    required property var modelData
                    readonly property bool current: modelData.id === root.tab
                    text: modelData.label
                    color: current ? Theme.bright : Theme.dim
                    font.family: Theme.display
                    font.pixelSize: 15 * root.s
                    font.underline: current
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.service.tab = parent.modelData.id
                    }
                }
            }
        }

        Text {
            visible: !!root.service && (root.service.error !== "" || !root.data)
            width: parent.width
            wrapMode: Text.Wrap
            text: root.service && root.service.error ? root.service.error : "Loading…"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }

        // Claude plan limits.
        Column {
            visible: root.tab === "claude" && !!root.svcData
            width: parent.width
            spacing: 8 * root.s

            MicroLabel {
                s: root.s
                label: "Limits" + (root.svcData && root.svcData.plan ? " · " + root.svcData.plan : "")
            }

            Text {
                visible: !!(root.svcData && root.svcData.error)
                text: root.svcData && root.svcData.error ? root.svcData.error : ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }

            Repeater {
                model: root.svcData && root.svcData.limits ? root.svcData.limits : []
                delegate: Column {
                    id: lim
                    required property var modelData
                    width: parent.width
                    spacing: 4 * root.s

                    Item {
                        width: parent.width
                        height: limName.implicitHeight
                        Text {
                            id: limName
                            text: lim.modelData.label
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 13 * root.s
                        }
                        Text {
                            anchors.right: parent.right
                            text: Math.round(lim.modelData.percent) + "%"
                            color: Theme.bright
                            font.family: Theme.mono
                            font.pixelSize: 12 * root.s
                        }
                    }
                    Meter {
                        width: parent.width
                        fraction: lim.modelData.percent / 100
                        fill: lim.modelData.percent >= 80 ? Theme.sun : Theme.accent
                    }
                    Text {
                        text: root.now && root.service ? root.service.resetsIn(lim.modelData.resets_at) : ""
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                    }
                }
            }
        }

        // Tokens by day.
        Column {
            visible: !!root.svcData
            width: parent.width
            spacing: 5 * root.s

            MicroLabel { s: root.s; label: "Tokens by day" }

            Repeater {
                model: root.days
                delegate: Row {
                    id: day
                    required property var modelData
                    required property int index
                    readonly property bool today: index === root.days.length - 1
                    width: parent.width
                    spacing: 8 * root.s

                    Text {
                        width: 44 * root.s
                        text: root.dayName(day.modelData.date, day.today)
                        color: day.today ? Theme.bright : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                        font.bold: day.today
                    }
                    Meter {
                        anchors.verticalCenter: parent.verticalCenter
                        width: day.width - 44 * root.s - 56 * root.s - 16 * root.s
                        fraction: day.modelData.tokens / root.dayTop
                        fill: day.today ? Theme.accent : Theme.dim
                    }
                    Text {
                        width: 56 * root.s
                        horizontalAlignment: Text.AlignRight
                        text: root.service ? root.service.formatTokens(day.modelData.tokens) : ""
                        color: Theme.bright
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                    }
                }
            }
        }

        // Tokens by model, 30 days.
        Column {
            visible: !!root.svcData
            width: parent.width
            spacing: 5 * root.s

            MicroLabel { s: root.s; label: "Tokens by model · 30 days" }

            Repeater {
                model: root.models
                delegate: Column {
                    id: mdl
                    required property var modelData
                    width: parent.width
                    spacing: 3 * root.s

                    Item {
                        width: parent.width
                        height: modelName.implicitHeight
                        Text {
                            id: modelName
                            width: parent.width - 64 * root.s
                            elide: Text.ElideRight
                            text: mdl.modelData.name
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                        }
                        Text {
                            anchors.right: parent.right
                            text: root.service ? root.service.formatTokens(mdl.modelData.tokens) : ""
                            color: Theme.bright
                            font.family: Theme.mono
                            font.pixelSize: 11 * root.s
                        }
                    }
                    Meter {
                        width: parent.width
                        fraction: mdl.modelData.tokens / root.modelTop
                    }
                }
            }
        }

        // Footer: last update and refresh.
        Item {
            width: parent.width
            height: refreshBtn.height

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.data ? "Updated " + new Date(root.data.updated * 1000).toLocaleTimeString(Qt.locale(), "HH:mm") : ""
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * root.s
            }

            Rectangle {
                id: refreshBtn
                anchors.right: parent.right
                width: refreshLabel.implicitWidth + 24 * root.s
                height: refreshLabel.implicitHeight + 12 * root.s
                radius: Theme.radius
                color: refreshArea.pressed ? Theme.vermDeep : Theme.accent
                opacity: root.service && root.service.busy ? 0.5 : 1

                Text {
                    id: refreshLabel
                    anchors.centerIn: parent
                    text: root.service && root.service.busy ? "LOADING" : "REFRESH"
                    color: Theme.cardBot
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                }

                MouseArea {
                    id: refreshArea
                    anchors.fill: parent
                    onClicked: if (root.service) root.service.refresh()
                }
            }
        }
    }
}
