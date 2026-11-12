import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "vedix.hdr"
  ipcTarget: "vedix.hdr"
  manageIpc: true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property bool hdrEnabled: true
  property string monitor: "eDP-1"
  property string monitorName: "Display"
  property real sdrBrightness: 2.0
  property real sdrSaturation: 1.15
  property real sdrMaxLum: 617.0
  property real edidMaxLum: 617.0
  property real edidAvgLum: 400.0
  property real edidMinLum: 0.005
  property string cmPreset: "hdr"
  property bool backlightSync: true
  property string currentPreset: "custom"
  property real colorTemp: 6500

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property string statusScript: Qt.resolvedUrl("bin/omarchy-hdr-status").toString().replace("file://", "")
  readonly property string setScript: Qt.resolvedUrl("bin/omarchy-hdr-set").toString().replace("file://", "")

  function refresh() { if (!statusProc.running) statusProc.running = true }
  function rescanHardware() { statusProc.running = false; statusProc.running = true }
  function runAction(args) { if (actionProc.running) return; actionProc.command = [root.setScript].concat(args); actionProc.running = true }
  function applyPreset(name) { runAction(["preset", name]) }
  function setTemp(t) { root.colorTemp = t; runAction(["temperature", t.toString()]) }

  Process {
    id: statusProc
    command: [root.statusScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { try { var data = JSON.parse(text); root.hdrEnabled = data.enabled; root.monitor = data.monitor; root.monitorName = data.monitorName; root.sdrBrightness = data.sdrBrightness; root.sdrSaturation = data.sdrSaturation; root.sdrMaxLum = data.sdrMaxLuminance; root.edidMaxLum = data.edidMaxLuminance; root.cmPreset = data.cm || "hdr"; root.currentPreset = data.preset || "custom" } catch (e) {} }
    }
  }
  
  Process { id: actionProc; onExited: root.refresh() }

  BarIconButton { id: button; anchors.fill: parent; bar: root.bar; text: root.hdrEnabled ? "󰽒" : "󰽑"; active: root.hdrEnabled }

  KeyboardPanel {
    id: panel; anchorItem: button; owner: root; bar: root.bar; open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(380))
    content: PanelKeyCatcher {
      anchors.fill: parent
      Column {
        width: parent.width; spacing: Style.space(12)
        Item {
          width: parent.width; implicitHeight: heroTexts.implicitHeight
          Column { id: heroTexts; width: parent.width - Style.space(40); Text { text: strings.t("title"); font.pixelSize: Style.font.title; font.bold: true; color: root.bar ? root.bar.foreground : "#ffffff" } }
          Button { anchors.right: parent.right; text: "󰑐"; bordered: true; onClicked: root.rescanHardware() }
        }
        PanelSeparator { foreground: root.bar ? root.bar.foreground : Commons.Color.foreground }
        
        Column {
           width: parent.width; spacing: Style.space(4)
           Text { text: "Température Couleur (K)"; font.pixelSize: Style.font.bodySmall; color: "#ffffff" }
           PanelSlider { width: parent.width; minimum: 3000; maximum: 9000; step: 100; value: root.colorTemp; onMoved: function(v) { root.setTemp(v) } }
        }

        Column {
          width: parent.width; spacing: Style.space(6)
          PanelSectionHeader { text: "Modes HDR"; foreground: root.bar ? root.bar.foreground : Commons.Color.foreground }
          Flow { width: parent.width; spacing: Style.space(6); 
             Button { text: "Vivid HDR"; onClicked: root.applyPreset("vivid") }
             Button { text: "Cinéma HDR"; onClicked: root.applyPreset("cinema_hdr") }
          }
        }
        Column {
          width: parent.width; spacing: Style.space(6)
          PanelSectionHeader { text: "Modes SDR"; foreground: root.bar ? root.bar.foreground : Commons.Color.foreground }
          Flow { width: parent.width; spacing: Style.space(6); 
             Button { text: "Cinéma (P3)"; onClicked: root.applyPreset("cinema") }
             Button { text: "Design (sRGB)"; onClicked: root.applyPreset("eco") }
          }
        }
      }
    }
  }
}
