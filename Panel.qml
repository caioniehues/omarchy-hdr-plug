import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "caioniehues.hdr"
  ipcTarget: "caioniehues.hdr"
  manageIpc: true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property bool hdrEnabled: true
  property bool hdrCapable: true
  property string selectedMonitor: ""
  property string monitor: ""
  property string monitorName: "Display"
  property var monitors: []
  property real sdrBrightness: 1.0
  property real sdrSaturation: 1.0
  property real sdrMaxLum: 300
  property real edidMaxLum: 300
  property real edidAvgLum: 250
  property real edidMinLum: 0.05
  property string cmPreset: "hdr"
  property string sdrEotf: "gamma22"
  property string currentPreset: "desktop"
  property real colorTemp: 6500
  property real pendingTemp: 6500
  property real pendingSdrMaxLum: 300
  property real pendingSdrBrightness: 1.0
  property real pendingSdrSaturation: 1.0
  property bool showAdvanced: true

  readonly property color panelForeground: root.bar ? root.bar.foreground : Commons.Color.foreground

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  readonly property string statusScript: Qt.resolvedUrl("bin/omarchy-hdr-status").toString().replace("file://", "")
  readonly property string setScript: Qt.resolvedUrl("bin/omarchy-hdr-set").toString().replace("file://", "")

  function refresh() {
    if (statusProc.running) return
    statusProc.command = root.selectedMonitor !== ""
      ? [root.statusScript, root.selectedMonitor]
      : [root.statusScript]
    statusProc.running = true
  }

  function rescanHardware() {
    statusProc.running = false
    statusProc.command = root.selectedMonitor !== ""
      ? [root.statusScript, root.selectedMonitor]
      : [root.statusScript]
    statusProc.running = true
  }

  function runAction(args) {
    if (actionProc.running) return
    var cmd = [root.setScript]
    if (root.selectedMonitor !== "") {
      cmd = cmd.concat(["--monitor", root.selectedMonitor])
    }
    actionProc.command = cmd.concat(args)
    actionProc.running = true
  }

  function applyPreset(name) {
    runAction(["preset", name])
  }

  function scheduleTemp(t) {
    root.colorTemp = t
    root.pendingTemp = t
    tempDebounce.restart()
  }

  function scheduleSliders() {
    root.pendingSdrBrightness = root.sdrBrightness
    root.pendingSdrSaturation = root.sdrSaturation
    root.pendingSdrMaxLum = root.sdrMaxLum
    sliderDebounce.restart()
  }

  Component.onCompleted: refresh()

  Timer {
    id: tempDebounce
    interval: 80
    repeat: false
    onTriggered: root.runAction(["temperature", Math.round(root.pendingTemp).toString()])
  }

  Timer {
    id: sliderDebounce
    interval: 80
    repeat: false
    onTriggered: root.runAction([
      "apply",
      root.pendingSdrBrightness.toFixed(2),
      root.pendingSdrSaturation.toFixed(2),
      Math.round(root.pendingSdrMaxLum).toString(),
      root.cmPreset
    ])
  }

  Process {
    id: statusProc
    command: [root.statusScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.hdrEnabled = data.enabled === true
          root.hdrCapable = data.hdrCapable !== false
          root.monitor = data.monitor || ""
          root.monitorName = data.monitorName || root.monitor
          root.monitors = Array.isArray(data.monitors) ? data.monitors : []
          if (!sliderDebounce.running) {
            root.sdrBrightness = data.sdrBrightness !== undefined ? data.sdrBrightness : 1.0
            root.sdrSaturation = data.sdrSaturation !== undefined ? data.sdrSaturation : 1.0
            root.sdrMaxLum = data.sdrMaxLuminance !== undefined ? data.sdrMaxLuminance : 300
          }
          root.edidMaxLum = data.edidMaxLuminance !== undefined ? data.edidMaxLuminance : 300
          root.edidAvgLum = data.edidAvgLuminance !== undefined ? data.edidAvgLuminance : 250
          root.edidMinLum = data.edidMinLuminance !== undefined ? data.edidMinLuminance : 0.05
          root.cmPreset = data.cm || "hdr"
          root.sdrEotf = data.sdrEotf || "gamma22"
          root.currentPreset = data.preset || "custom"
          if (!tempDebounce.running && data.colorTemp !== undefined) {
            root.colorTemp = data.colorTemp
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.hdrEnabled ? "󰃠" : "󰃞"
    active: root.hdrEnabled

    HoverHandler { id: barHover }

    PanelToolTip {
      visible: barHover.hovered && !root.opened
      text: root.hdrEnabled ? strings.t("toggle_tooltip_on") : strings.t("toggle_tooltip_off")
    }

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) {
        root.toggle()
      } else if (mouseButton === Qt.RightButton) {
        root.runAction(["toggle"])
      }
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
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(760))

    onOpenChanged: {
      if (panel.open) {
        root.refresh()
      } else {
        resetConfirm.opened = false
      }
    }

    content: PanelKeyCatcher {
      anchors.fill: parent
      implicitHeight: mainColumn.implicitHeight

      Keys.onPressed: function(event) {
        if (resetConfirm.opened && resetConfirm.handleKey(event)) {
          event.accepted = true
        }
      }

      Column {
        id: mainColumn
        width: parent.width
        spacing: Style.space(12)

        // Header: Title + Monitor metadata + ToggleSwitch + Rescan
        Item {
          width: parent.width
          implicitHeight: Math.max(heroTexts.implicitHeight, headerActions.implicitHeight)

          Column {
            id: heroTexts
            width: parent.width - headerActions.implicitWidth - Style.space(8)
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: strings.t("title")
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              color: root.panelForeground
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.monitor + " • " + (root.hdrCapable ? (Math.round(root.edidMaxLum) + " nits") : strings.t("hdr_not_supported"))
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: Util.alpha(root.panelForeground, 0.7)
              elide: Text.ElideRight
            }
          }

          Row {
            id: headerActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            ToggleSwitch {
              anchors.verticalCenter: parent.verticalCenter
              checked: root.hdrEnabled
              busy: actionProc.running
              onToggled: root.runAction(["toggle"])
            }

            Button {
              text: "󰑐"
              bordered: true
              tooltipText: strings.t("rescan_tooltip")
              onClicked: root.rescanHardware()
            }
          }
        }

        // Multi-monitor selector (visible only when >1 monitor is connected)
        Dropdown {
          visible: root.monitors.length > 1
          width: parent.width
          label: strings.t("monitor_label")
          value: root.monitor
          options: root.monitors.map(function(m) {
            return { value: m.name, label: m.name + " (" + m.description + ")" }
          })
          onChanged: function(val) {
            root.selectedMonitor = val
            root.refresh()
          }
        }

        PanelSeparator { foreground: root.panelForeground }

        // Color Temperature Slider
        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            implicitHeight: tempLabel.implicitHeight

            Text {
              id: tempLabel
              text: strings.t("color_temp")
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              color: root.panelForeground
            }

            Text {
              anchors.right: parent.right
              text: Math.round(root.colorTemp) + " K"
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              color: Commons.Color.accent
            }
          }

          PanelSlider {
            width: parent.width
            minimum: 3000
            maximum: 9000
            step: 100
            value: root.colorTemp
            onMoved: function(v) { root.scheduleTemp(v) }
          }
        }

        // HDR Presets
        Column {
          width: parent.width
          spacing: Style.space(6)
          PanelSectionHeader { text: strings.t("hdr_modes"); foreground: root.panelForeground }

          Flow {
            width: parent.width
            spacing: Style.space(6)
            Button {
              text: strings.t("preset_desktop")
              bordered: true
              selected: root.hdrEnabled && root.currentPreset === "desktop"
              onClicked: root.applyPreset("desktop")
            }
            Button {
              text: strings.t("preset_bright")
              bordered: true
              selected: root.hdrEnabled && root.currentPreset === "bright"
              onClicked: root.applyPreset("bright")
            }
            Button {
              text: strings.t("preset_cinema")
              bordered: true
              selected: root.hdrEnabled && root.currentPreset === "cinema"
              onClicked: root.applyPreset("cinema")
            }
          }
        }

        // SDR Presets
        Column {
          width: parent.width
          spacing: Style.space(6)
          PanelSectionHeader { text: strings.t("sdr_modes"); foreground: root.panelForeground }

          Flow {
            width: parent.width
            spacing: Style.space(6)
            Button {
              text: strings.t("preset_sdr")
              bordered: true
              selected: !root.hdrEnabled
              onClicked: root.applyPreset("sdr")
            }
          }
        }

        PanelSeparator { foreground: root.panelForeground }

        // Color Space (cm)
        Column {
          width: parent.width
          spacing: Style.space(6)
          PanelSectionHeader { text: strings.t("color_gamut"); foreground: root.panelForeground }

          Flow {
            width: parent.width
            spacing: Style.space(6)
            Button {
              text: "HDR"
              bordered: true
              selected: root.cmPreset === "hdr"
              onClicked: root.runAction(["cm", "hdr"])
            }
            Button {
              text: "DCI-P3"
              bordered: true
              selected: root.cmPreset === "dcip3"
              onClicked: root.runAction(["cm", "dcip3"])
            }
            Button {
              text: "sRGB"
              bordered: true
              selected: root.cmPreset === "srgb"
              onClicked: root.runAction(["cm", "srgb"])
            }
          }
        }

        // SDR transfer curve used to place SDR content in HDR
        Column {
          width: parent.width
          spacing: Style.space(6)
          PanelSectionHeader { text: strings.t("sdr_eotf"); foreground: root.panelForeground }

          Flow {
            width: parent.width
            spacing: Style.space(6)
            Button {
              text: "Gamma 2.2"
              bordered: true
              selected: root.sdrEotf === "gamma22"
              onClicked: root.runAction(["sdr_eotf", "gamma22"])
            }
            Button {
              text: "sRGB"
              bordered: true
              selected: root.sdrEotf === "srgb"
              onClicked: root.runAction(["sdr_eotf", "srgb"])
            }
          }
        }

        // Luminance / Brightness / Saturation Sliders
        Column {
          width: parent.width
          spacing: Style.space(8)

          // Target SDR Luminance
          Column {
            width: parent.width
            spacing: Style.space(2)
            Item {
              width: parent.width
              implicitHeight: lumLabel.implicitHeight
              Text {
                id: lumLabel
                text: strings.t("sdr_max_lum")
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: root.panelForeground
              }
              Text {
                anchors.right: parent.right
                text: Math.round(root.sdrMaxLum) + " nits"
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                color: Commons.Color.accent
              }
            }
            PanelSlider {
              width: parent.width
              minimum: 100
              maximum: Math.max(300, root.edidMaxLum)
              step: 10
              value: root.sdrMaxLum
              onMoved: function(v) { root.sdrMaxLum = v; root.scheduleSliders() }
            }
          }

          // SDR Brightness Boost
          Column {
            width: parent.width
            spacing: Style.space(2)
            Item {
              width: parent.width
              implicitHeight: brightLabel.implicitHeight
              Text {
                id: brightLabel
                text: strings.t("sdr_brightness")
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: root.panelForeground
              }
              Text {
                anchors.right: parent.right
                text: root.sdrBrightness.toFixed(2) + "x"
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                color: Commons.Color.accent
              }
            }
            PanelSlider {
              width: parent.width
              minimum: 0.50
              maximum: 2.50
              step: 0.05
              value: root.sdrBrightness
              onMoved: function(v) { root.sdrBrightness = v; root.scheduleSliders() }
            }
          }

          // SDR Saturation
          Column {
            width: parent.width
            spacing: Style.space(2)
            Item {
              width: parent.width
              implicitHeight: satLabel.implicitHeight
              Text {
                id: satLabel
                text: strings.t("sdr_saturation")
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                color: root.panelForeground
              }
              Text {
                anchors.right: parent.right
                text: Math.round(root.sdrSaturation * 100) + "%"
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                color: Commons.Color.accent
              }
            }
            PanelSlider {
              width: parent.width
              minimum: 0.50
              maximum: 1.50
              step: 0.05
              value: root.sdrSaturation
              onMoved: function(v) { root.sdrSaturation = v; root.scheduleSliders() }
            }
          }
        }

        PanelSeparator { foreground: root.panelForeground }

        // Footer: Reset to factory state
        Item {
          width: parent.width
          implicitHeight: resetBtn.implicitHeight

          Button {
            id: resetBtn
            anchors.right: parent.right
            iconText: "󰜉"
            text: strings.t("reset")
            tooltipText: strings.t("reset_tooltip")
            bordered: true
            onClicked: resetConfirm.opened = true
          }
        }
      }

      ConfirmDialog {
        id: resetConfirm
        anchors.fill: parent
        opened: false
        message: strings.t("reset_confirm_message")
        confirmText: strings.t("reset_confirm_btn")
        onCanceled: resetConfirm.opened = false
        onConfirmed: {
          resetConfirm.opened = false
          root.runAction(["reset"])
        }
      }
    }
  }
}
