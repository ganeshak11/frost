import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_city: city.text
    property real cfg_latitude
    property real cfg_longitude
    QQC2.TextField { id: city; Kirigami.FormData.label: "City name (shown on the widget):" }
    QQC2.TextField {
        Kirigami.FormData.label: "Latitude:"; text: cfg_latitude
        validator: DoubleValidator { bottom: -90; top: 90 }
        onEditingFinished: cfg_latitude = Number(text)
    }
    QQC2.TextField {
        Kirigami.FormData.label: "Longitude:"; text: cfg_longitude
        validator: DoubleValidator { bottom: -180; top: 180 }
        onEditingFinished: cfg_longitude = Number(text)
    }
    QQC2.Label { text: "Find coordinates by searching your city on openstreetmap.org." ; opacity: 0.7 }
}
