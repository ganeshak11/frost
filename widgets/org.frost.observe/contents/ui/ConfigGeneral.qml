import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property alias cfg_url: url.text
    property alias cfg_token: token.text
    QQC2.TextField { id: url; Kirigami.FormData.label: "Dashboard address:"; placeholderText: "https://analytics.ganeshangadi.online" }
    QQC2.TextField { id: token; Kirigami.FormData.label: "Widget token:"; echoMode: TextInput.Password; placeholderText: "WIDGET_TOKEN from Vercel" }
    QQC2.Label {
        text: "The token is the WIDGET_TOKEN environment variable of the dashboard. It only reads today's counts and page paths."
        wrapMode: Text.Wrap; Layout.maximumWidth: 360; opacity: 0.7
    }
}
