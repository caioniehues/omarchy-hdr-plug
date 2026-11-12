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

  // Persistent & Hardware State
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

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  readonly property string statusScript: Qt.resolvedUrl("bin/omarchy-hdr-status").toString().replace("file://", "")
  readonly property string setScript: Qt.resolvedUrl("bin/omarchy-hdr-set").toString().replace("file://", "")

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function rescanHardware() {
    statusProc.running = false
    statusProc.running = true
  }

  function runAction(args) {
    if (actionProc.running) return
    actionProc.command = [root.setScript].concat(args)
    actionProc.running = true
  }

  function toggleHdr() {
    runAction(["toggle"])
  }

  function setCm(cm) {
    root.cmPreset = cm
    runAction(["cm", cm])
  }

  function setBacklightSync(sync) {
    root.backlightSync = sync
    runAction(["backlight_sync", sync ? "true" : "false"])
  }

  function applyPreset(name) {
    runAction(["preset", name])
  }

  function commitSliders() {
    runAction([
      "apply",
      root.sdrBrightness.toFixed(2),
      root.sdrSaturation.toFixed(2),
      Math.round(root.sdrMaxLum).toString(),
      root.cmPreset,
      root.backlightSync ? "true" : "false"
    ])
  }

  Timer {
    id: sliderDebounce
    interval: 150
    repeat: false
    onTriggered: root.commitSliders()
  }

  Process {
    id: statusProc
    command: [root.statusScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.hdrEnabled = data.enabled
          root.monitor = data.monitor
          root.monitorName = data.monitorName
          root.sdrBrightness = data.sdrBrightness
          root.sdrSaturation = data.sdrSaturation
          root.sdrMaxLum = data.sdrMaxLuminance
          root.edidMaxLum = data.edidMaxLuminance
          root.edidAvgLum = data.edidAvgLuminance
          root.edidMinLum = data.edidMinLuminance
          root.cmPreset = data.cm || "hdr"
          root.backlightSync = (data.backlightSync !== false)
          root.currentPreset = data.preset || "custom"
        } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()
  onOpenedChanged: if (opened) root.refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.hdrEnabled ? "󰽒" : "󰽑"
    active: root.hdrEnabled
    tooltipText: root.hdrEnabled ? strings.t("toggle_tooltip_on") : strings.t("toggle_tooltip_off")
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleHdr()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: panelColumn.implicitHeight
      onCloseRequested: root.close()

      Column {
        id: panelColumn
        width: parent.width
        spacing: Style.space(12)

        // 1. Header Section
        Item {
          width: parent.width
          implicitHeight: Math.max(heroTexts.implicitHeight, headerButtons.implicitHeight)

          Column {
            id: heroTexts
            anchors.left: parent.left
            anchors.right: headerButtons.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: strings.t("title")
              color: root.bar ? root.bar.foreground : "#ffffff"
              font.family: root.bar ? root.bar.fontFamily : "sans-serif"
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.monitorName + " • " + Math.round(root.edidMaxLum) + " nits"
              color: root.bar ? root.bar.foreground : "#ffffff"
              font.family: root.bar ? root.bar.fontFamily : "sans-serif"
              font.pixelSize: Style.font.caption
              opacity: 0.65
              elide: Text.ElideRight
            }
          }

          Row {
            id: headerButtons
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Button {
              text: "󰑐"
              tooltipText: strings.t("rescan_tooltip")
              bordered: true
              fontSize: Style.font.bodySmall
              onClicked: root.rescanHardware()
            }

            Button {
              id: toggleBtn
              text: root.hdrEnabled ? strings.t("active") : strings.t("inactive")
              active: root.hdrEnabled
              bordered: true
              fontSize: Style.font.bodySmall
              onClicked: root.toggleHdr()
            }
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
        }

        // 2. Color Gamut Selector
        Item {
          width: parent.width
          implicitHeight: cmRow.implicitHeight

          Row {
            id: cmRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: strings.t("color_gamut")
              color: root.bar ? root.bar.foreground : "#ffffff"
              font.family: root.bar ? root.bar.fontFamily : "sans-serif"
              font.pixelSize: Style.font.bodySmall
              width: parent.width - Style.space(210)
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
            }

            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Button {
                text: "HDR"
                active: root.cmPreset === "hdr"
                fontSize: Style.font.caption
                bordered: true
                onClicked: root.setCm("hdr")
              }
              Button {
                text: "HDR-EDID"
                active: root.cmPreset === "hdredid"
                fontSize: Style.font.caption
                bordered: true
                onClicked: root.setCm("hdredid")
              }
              Button {
                text: "DCI-P3"
                active: root.cmPreset === "dcip3"
                fontSize: Style.font.caption
                bordered: true
                onClicked: root.setCm("dcip3")
              }
              Button {
                text: "sRGB"
                active: root.cmPreset === "srgb"
                fontSize: Style.font.caption
                bordered: true
                onClicked: root.setCm("srgb")
              }
            }
          }
        }

        // 3. Sliders Section
        Column {
          width: parent.width
          spacing: Style.space(10)
          opacity: root.hdrEnabled ? 1.0 : 0.4
          enabled: root.hdrEnabled

          // Luminance Cible SDR
          Column {
            width: parent.width
            spacing: Style.space(2)

            Item {
              width: parent.width
              implicitHeight: Style.space(18)

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: strings.t("sdr_max_lum")
                font.family: root.bar ? root.bar.fontFamily : "sans-serif"
                font.pixelSize: Style.font.bodySmall
                color: root.bar ? root.bar.foreground : "#ffffff"
                opacity: 0.85
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: Math.round(root.sdrMaxLum) + " nits (Dalle: " + Math.round(root.edidMaxLum) + " nits)"
                font.family: root.bar ? root.bar.fontFamily : "sans-serif"
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                color: root.bar ? root.bar.foreground : "#ffffff"
              }
            }

            PanelSlider {
              bar: root.bar
              width: parent.width
              minimum: 100
              maximum: Math.max(2000, root.edidMaxLum)
              step: 10
              value: root.sdrMaxLum
              onMoved: function(v) {
                root.sdrMaxLum = v
                sliderDebounce.restart()
              }
            }
          }

          // Gain Luminosité SDR
          Column {
            width: parent.width
            spacing: Style.space(2)

            Item {
              width: parent.width
              implicitHeight: Style.space(18)

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: strings.t("sdr_brightness")
                font.family: root.bar ? root.bar.fontFamily : "sans-serif"
                font.pixelSize: Style.font.bodySmall
                color: root.bar ? root.bar.foreground : "#ffffff"
                opacity: 0.85
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.sdrBrightness.toFixed(2) + "x (" + Math.round((root.sdrBrightness / 1.4) * 100) + "%)"
                font.family: root.bar ? root.bar.fontFamily : "sans-serif"
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                color: root.bar ? root.bar.foreground : "#ffffff"
              }
            }

            PanelSlider {
              bar: root.bar
              width: parent.width
              minimum: 0.5
              maximum: 2.5
              step: 0.05
              value: root.sdrBrightness
              onMoved: function(v) {
                root.sdrBrightness = v
                sliderDebounce.restart()
              }
            }
          }

          // Saturation Couleurs SDR
          Column {
            width: parent.width
            spacing: Style.space(2)

            Item {
              width: parent.width
              implicitHeight: Style.space(18)

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: strings.t("sdr_saturation")
                font.family: root.bar ? root.bar.fontFamily : "sans-serif"
                font.pixelSize: Style.font.bodySmall
                color: root.bar ? root.bar.foreground : "#ffffff"
                opacity: 0.85
              }

              Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.sdrSaturation.toFixed(2) + "x"
                font.family: root.bar ? root.bar.fontFamily : "sans-serif"
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                color: root.bar ? root.bar.foreground : "#ffffff"
              }
            }

            PanelSlider {
              bar: root.bar
              width: parent.width
              minimum: 0.8
              maximum: 1.5
              step: 0.05
              value: root.sdrSaturation
              onMoved: function(v) {
                root.sdrSaturation = v
                sliderDebounce.restart()
              }
            }
          }
        }

        // 4. Backlight Tracking Toggle
        Item {
          width: parent.width
          implicitHeight: blRow.implicitHeight

          Row {
            id: blRow
            anchors.left: parent.left
            anchors.right: parent.right

            Text {
              textFormat: Text.PlainText
              text: strings.t("backlight_sync")
              color: root.bar ? root.bar.foreground : "#ffffff"
              font.family: root.bar ? root.bar.fontFamily : "sans-serif"
              font.pixelSize: Style.font.bodySmall
              width: parent.width - Style.space(120)
              anchors.verticalCenter: parent.verticalCenter
              opacity: 0.85
              elide: Text.ElideRight
            }

            Button {
              anchors.verticalCenter: parent.verticalCenter
              text: root.backlightSync ? "Auto (ON)" : "Fixe (OFF)"
              active: root.backlightSync
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.setBacklightSync(!root.backlightSync)
            }
          }
        }

        PanelSeparator {
          foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
        }

        // 5. Quick Presets Section
        Column {
          width: parent.width
          spacing: Style.space(6)

          PanelSectionHeader {
            text: strings.t("presets_title")
            foreground: root.bar ? root.bar.foreground : Commons.Color.foreground
            fontFamily: root.bar ? root.bar.fontFamily : "sans-serif"
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(6)) / 2
              text: strings.t("preset_vivid")
              active: root.currentPreset === "vivid"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.applyPreset("vivid")
            }
            Button {
              width: (parent.width - Style.space(6)) / 2
              text: strings.t("preset_cinema")
              active: root.currentPreset === "cinema"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.applyPreset("cinema")
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: (parent.width - Style.space(6)) / 2
              text: strings.t("preset_outdoor")
              active: root.currentPreset === "outdoor"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.applyPreset("outdoor")
            }
            Button {
              width: (parent.width - Style.space(6)) / 2
              text: strings.t("preset_eco")
              active: root.currentPreset === "eco"
              fontSize: Style.font.caption
              bordered: true
              onClicked: root.applyPreset("eco")
            }
          }
        }

        // 6. Footer Actions
        Row {
          width: parent.width
          spacing: Style.space(6)

          Button {
            width: (parent.width - Style.space(12)) / 3
            text: strings.t("optimal_edid")
            fontSize: Style.font.caption
            bordered: true
            onClicked: root.applyPreset("optimal")
          }

          Button {
            width: (parent.width - Style.space(12)) / 3
            text: strings.t("rescan")
            tooltipText: strings.t("rescan_tooltip")
            fontSize: Style.font.caption
            bordered: true
            onClicked: root.rescanHardware()
          }

          Button {
            width: (parent.width - Style.space(12)) / 3
            text: root.hdrEnabled ? strings.t("disable") : strings.t("enable")
            active: !root.hdrEnabled
            fontSize: Style.font.caption
            bordered: true
            onClicked: root.toggleHdr()
          }
        }
      }
    }
  }
}
