import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Bloco com "líquido" que enche conforme o valor (0-100)
Item {
    id: root
    property real value: 0
    property string label: ""
    property string iconName: ""
    property string valueText: Math.round(value) + "%"
    property color fillColor: "#34b85f"
    property color baseColor: "#d3f3de"
    property color textColor: "#0f6e2e"
    property color trackColor: "#33000000"
    // anel: medidor circular em vez do líquido
    property bool anel: false

    implicitWidth: 84
    implicitHeight: 100

    RoundClip {
        anchors.fill: parent
        radius: 30
        visible: !root.anel

        Rectangle { anchors.fill: parent; color: root.baseColor }

        Rectangle {
            id: liquid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.height * Math.max(0.06, Math.min(1, root.value / 100))
            Behavior on height { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(root.fillColor, 1.35) }
                GradientStop { position: 1; color: root.fillColor }
            }

            // ondinha no topo do líquido
            Repeater {
                model: 4
                Rectangle {
                    width: root.width / 2.2
                    height: 14
                    radius: 7
                    color: Qt.lighter(root.fillColor, 1.35)
                    y: -6
                    x: index * root.width / 3 - 10 + wave.offset
                }
            }
        }
    }

    QtObject {
        id: wave
        property real offset: 0
        SequentialAnimation on offset {
            loops: Animation.Infinite
            NumberAnimation { from: -8; to: 8; duration: 2200; easing.type: Easing.InOutSine }
            NumberAnimation { from: 8; to: -8; duration: 2200; easing.type: Easing.InOutSine }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2
        visible: !root.anel
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Kirigami.Icon {
                source: root.iconName
                width: 16; height: 16
                color: root.textColor
                isMask: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.label
                color: root.textColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.family: "Noto Sans"
            }
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: valueLabel.implicitWidth * 0.78
            height: valueLabel.implicitHeight
            Text {
                id: valueLabel
                text: root.valueText
                color: root.textColor
                font.pixelSize: 30
                font.family: "Noto Sans"
                font.weight: Font.Black
                transform: Scale { xScale: 0.78 }
            }
        }
    }

    // ---- modo anel ----
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: root.anel
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Kirigami.Icon {
                source: root.iconName
                width: 14; height: 14
                color: root.textColor
                isMask: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.label
                color: root.textColor
                font.pixelSize: 12
                font.family: "Noto Sans"
            }
        }
        Item {
            width: 66; height: 66
            anchors.horizontalCenter: parent.horizontalCenter
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.trackColor
                    strokeWidth: 5
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 33; centerY: 33; radiusX: 28; radiusY: 28; startAngle: -90; sweepAngle: 359.9 }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.fillColor
                    strokeWidth: 5
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 33; centerY: 33; radiusX: 28; radiusY: 28
                        startAngle: -90
                        sweepAngle: 359.9 * Math.max(0.02, Math.min(1, root.value / 100))
                        Behavior on sweepAngle { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: root.valueText
                color: root.textColor
                font.pixelSize: 17
                font.family: "Noto Sans"
                font.weight: Font.DemiBold
            }
        }
    }
}
