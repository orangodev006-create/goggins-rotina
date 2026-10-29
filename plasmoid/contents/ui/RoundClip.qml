import QtQuick
import QtQuick.Effects

// Recorta os filhos num retângulo arredondado (ou no shape passado em maskItem)
Item {
    id: root
    property real radius: 20
    default property alias content: inner.data

    Item {
        id: inner
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            color: "black"
            antialiasing: true
        }
    }
}
