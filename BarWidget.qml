import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "azambekdev.gitpulse"

  // User Settings
  property int pollIntervalSeconds: Number(setting("pollIntervalSeconds", 60)) || 60
  property bool showCiStatus: setting("showCiStatus", true) !== false
  property bool showReviewRequests: setting("showReviewRequests", true) !== false
  property bool showNotifications: setting("showNotifications", true) !== false
  property bool compactView: setting("compactView", false) === true

  // State
  property bool popupOpen: false
  property bool isFetching: false
  property string activeTab: "prs" // "prs" | "reviews" | "notifications"
  property string statusMessage: ""
  property int cursorIndex: 0
  property bool keyboardActive: false

  // Data
  property bool authenticated: false
  property string errorMessage: ""
  property var userData: ({ login: "", name: "", avatarUrl: "", url: "" })
  property var counts: ({ notifications: 0, reviewRequests: 0, myPrs: 0, failingCi: 0, runningCi: 0, passingCi: 0 })
  property var notificationsList: []
  property var reviewRequestsList: []
  property var myPrsList: []
  property int lastUpdated: 0

  readonly property string fetchScriptPath: Qt.resolvedUrl("scripts/fetch.sh").toString().replace(/^file:\/\//, "")
  readonly property string actionScriptPath: Qt.resolvedUrl("scripts/action.sh").toString().replace(/^file:\/\//, "")

  function open() {
    popupOpen = true
    cursorIndex = 0
    keyboardActive = false
    Qt.callLater(function() {
      if (keyCatcher) keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    popupOpen = false
    keyboardActive = false
  }

  function toggle() {
    if (popupOpen) close()
    else open()
  }

  function currentActiveList() {
    if (activeTab === "prs") return myPrsList
    if (activeTab === "reviews") return reviewRequestsList
    return notificationsList
  }

  function moveCursor(dy) {
    var list = currentActiveList()
    if (!list || list.length === 0) return
    keyboardActive = true
    cursorIndex = Math.max(0, Math.min(list.length - 1, cursorIndex + dy))
  }

  function switchTab(dir) {
    var tabs = ["prs", "reviews", "notifications"]
    var curr = tabs.indexOf(activeTab)
    var next = (curr + dir + tabs.length) % tabs.length
    activeTab = tabs[next]
    cursorIndex = 0
    keyboardActive = true
  }

  function setTab(tabName) {
    activeTab = tabName
    cursorIndex = 0
    keyboardActive = true
  }

  function openSelected() {
    var list = currentActiveList()
    if (list && cursorIndex >= 0 && cursorIndex < list.length) {
      openUrl(list[cursorIndex].url)
    }
  }

  function deleteSelected() {
    if (activeTab === "notifications" && notificationsList && cursorIndex >= 0 && cursorIndex < notificationsList.length) {
      markNotificationRead(notificationsList[cursorIndex].id)
    }
  }

  function refresh() {
    if (isFetching) return
    isFetching = true
    statusMessage = "Refreshing GitHub data..."
    fetchBuffer = ""
    fetchProc.command = ["/bin/bash", root.fetchScriptPath]
    fetchProc.running = true
  }

  function markNotificationRead(id) {
    actionProc.command = ["/bin/bash", root.actionScriptPath, "mark-read", id]
    actionProc.running = true
    var updated = []
    for (var i = 0; i < notificationsList.length; i++) {
      if (notificationsList[i].id !== id) updated.push(notificationsList[i])
    }
    notificationsList = updated
    counts.notifications = updated.length
    if (cursorIndex >= updated.length) cursorIndex = Math.max(0, updated.length - 1)
    Qt.callLater(refresh)
  }

  function markAllNotificationsRead() {
    actionProc.command = ["/bin/bash", root.actionScriptPath, "mark-all-read"]
    actionProc.running = true
    notificationsList = []
    counts.notifications = 0
    cursorIndex = 0
    Qt.callLater(refresh)
  }

  function openUrl(url) {
    if (!url) return
    actionProc.command = ["/bin/bash", root.actionScriptPath, "open", url]
    actionProc.running = true
  }

  function formatRelativeTime(ts) {
    if (!ts) return ""
    var diff = Math.max(0, Math.floor((Date.now() / 1000) - ts))
    if (diff < 60) return "just now"
    if (diff < 3600) return Math.floor(diff / 60) + "m ago"
    if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
    return Math.floor(diff / 86400) + "d ago"
  }

  property string fetchBuffer: ""

  Process {
    id: fetchProc
    stdout: SplitParser {
      onRead: function(line) {
        root.fetchBuffer += line + "\n"
      }
    }
    onExited: function(code, status) {
      root.isFetching = false
      if (code === 0 && root.fetchBuffer.trim().length > 0) {
        try {
          var parsed = JSON.parse(root.fetchBuffer.trim())
          if (parsed.authenticated !== undefined) {
            root.authenticated = parsed.authenticated
            if (parsed.authenticated) {
              root.errorMessage = ""
              root.userData = parsed.user || root.userData
              root.counts = parsed.counts || root.counts
              root.notificationsList = parsed.notifications || []
              root.reviewRequestsList = parsed.reviewRequests || []
              root.myPrsList = parsed.myPrs || []
              root.lastUpdated = parsed.timestamp || Math.floor(Date.now() / 1000)
              root.statusMessage = ""
            } else {
              root.errorMessage = parsed.error || "Authentication failed"
              root.statusMessage = root.errorMessage
            }
          }
        } catch (e) {
          root.errorMessage = "Failed to parse GitHub response"
          root.statusMessage = root.errorMessage
        }
      } else {
        root.errorMessage = "Failed to run GitHub fetch script"
        root.statusMessage = root.errorMessage
      }
    }
  }

  Process {
    id: actionProc
  }

  Timer {
    id: pollTimer
    interval: Math.max(10000, root.pollIntervalSeconds * 1000)
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    Qt.callLater(root.refresh)
  }

  IpcHandler {
    target: "azambekdev.gitpulse"

    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function markAllRead(): void { root.markAllNotificationsRead() }
    function nextTab(): void { root.switchTab(1) }
    function prevTab(): void { root.switchTab(-1) }
  }

  // Pill Label Construction
  readonly property string pillLabel: {
    if (!root.authenticated) return " 󰌹"
    if (root.compactView) return ""

    var parts = [""]
    if (root.showCiStatus && root.counts.failingCi > 0) {
      parts.push("✖" + root.counts.failingCi)
    } else if (root.showCiStatus && root.counts.runningCi > 0) {
      parts.push("●" + root.counts.runningCi)
    }

    if (root.showReviewRequests && root.counts.reviewRequests > 0) {
      parts.push("󰏤" + root.counts.reviewRequests)
    }

    if (root.showNotifications && root.counts.notifications > 0) {
      parts.push("󰂚" + root.counts.notifications)
    }

    if (parts.length === 1 && root.counts.myPrs > 0) {
      parts.push("" + root.counts.myPrs)
    }

    return parts.join(" ")
  }

  readonly property color pillColor: {
    if (!root.authenticated) return root.bar ? root.bar.foreground : Color.foreground
    if (root.counts.failingCi > 0) return root.bar ? root.bar.urgent : Color.urgent
    if (root.counts.reviewRequests > 0) return "#f59e0b"
    if (root.counts.notifications > 0) return Color.accent
    return root.bar ? root.bar.foreground : Color.foreground
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.pillLabel
    tooltipText: root.authenticated
      ? ("GitPulse: @" + (root.userData.login || "user") + " — " + root.counts.notifications + " unread, " + root.counts.reviewRequests + " review requests, " + root.counts.myPrs + " PRs")
      : "GitPulse: Click to login with GitHub CLI"
    active: root.popupOpen || root.counts.failingCi > 0 || root.counts.reviewRequests > 0 || root.counts.notifications > 0
    activeColor: root.pillColor
    useActiveColor: true

    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh()
      else if (b === Qt.MiddleButton) root.openUrl(root.userData.url || "https://github.com")
      else root.toggle()
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(420))
    contentHeight: popup.fittedContentHeight(mainColumn.implicitHeight + Style.space(16))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.switchTab(dx)
      }
      onActivateRequested: root.openSelected()
      onCloseRequested: root.close()
      onTabRequested: function(dir) { root.switchTab(dir) }
      onDeleteRequested: root.deleteSelected()

      onTextKey: function(t) {
        if (t === "1") root.setTab("prs")
        else if (t === "2") root.setTab("reviews")
        else if (t === "3") root.setTab("notifications")
        else if (t === "r" || t === "R") root.refresh()
        else if (t === "a" || t === "A") root.markAllNotificationsRead()
        else if (t === "o" || t === "O") root.openSelected()
        else if (t === "p" || t === "P") root.openUrl(root.userData.url || "https://github.com")
        else if (t === "q" || t === "Q") root.close()
        else if (t === "x" || t === "X" || t === "d" || t === "D") root.deleteSelected()
        else if (t === "h" || t === "H") root.switchTab(-1)
        else if (t === "l" || t === "L") root.switchTab(1)
        else if (t === "n" || t === "N") root.openUrl("https://github.com/pulls")
        else if (t === "i" || t === "I") root.openUrl("https://github.com/issues")
      }

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        // ==========================================
        // HEADER BAR
        // ==========================================
        Item {
          width: parent.width
          height: Style.space(34)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Text {
              text: ""
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0

              Row {
                spacing: Style.space(6)
                Text {
                  text: root.userData.name || root.userData.login || "GitPulse"
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }

                BorderSurface {
                  visible: root.authenticated && root.userData.login !== ""
                  height: Style.space(16)
                  radius: height / 2
                  color: Style.normalFillFor(Color.accent, Color.accent)
                  borderSpec: Border.controlSpec("normal", Color.accent, Color.accent)
                  anchors.verticalCenter: parent.verticalCenter
                  leftPadding: Style.space(5)
                  rightPadding: Style.space(5)

                  Text {
                    anchors.centerIn: parent
                    text: "@" + root.userData.login
                    color: Color.accent
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }
          }

          // Action Buttons (Refresh, Web, Close)
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Button {
              width: Style.space(26)
              height: Style.space(26)
              iconText: "󰑐"
              iconSpinning: root.isFetching
              tooltipText: "Refresh data [r]"
              onClicked: root.refresh()
            }

            Button {
              width: Style.space(26)
              height: Style.space(26)
              iconText: "󰌹"
              tooltipText: "Open GitHub in browser [p]"
              onClicked: root.openUrl(root.userData.url || "https://github.com")
            }

            Button {
              width: Style.space(26)
              height: Style.space(26)
              iconText: "✕"
              tooltipText: "Close [q / Esc]"
              onClicked: root.close()
            }
          }
        }

        // ==========================================
        // NOT AUTHENTICATED STATE
        // ==========================================
        BorderSurface {
          visible: !root.authenticated
          width: parent.width
          height: Style.space(120)
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.bar ? root.bar.urgent : Color.urgent, Color.accent)
          borderSpec: Border.controlSpec("normal", root.bar ? root.bar.urgent : Color.urgent, Color.accent)

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            width: parent.width - Style.space(24)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "GitHub CLI Not Logged In"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.errorMessage || "Run 'gh auth login' in your terminal to connect GitPulse"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Button {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Check Login Status"
              iconText: "󰑐"
              accent: Color.accent
              onClicked: root.refresh()
            }
          }
        }

        // ==========================================
        // SUMMARY METRICS TILES (When Authenticated)
        // ==========================================
        Row {
          visible: root.authenticated
          width: parent.width
          spacing: Style.space(6)

          // My PRs Tile
          BorderSurface {
            width: (parent.width - Style.space(12)) / 3
            height: Style.space(48)
            radius: Style.cornerRadius
            color: root.activeTab === "prs" ? Style.hoverFillFor(Color.accent, Color.accent) : Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(root.activeTab === "prs" ? "selected" : "normal", Color.accent, Color.accent)

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setTab("prs")
            }

            Column {
              anchors.centerIn: parent
              spacing: 0

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(4)

                Text {
                  text: ""
                  color: Color.accent
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "" + root.counts.myPrs
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "My PRs [1]"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          // Review Requests Tile
          BorderSurface {
            width: (parent.width - Style.space(12)) / 3
            height: Style.space(48)
            radius: Style.cornerRadius
            color: root.activeTab === "reviews" ? Style.hoverFillFor("#f59e0b", Color.accent) : Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(root.activeTab === "reviews" ? "selected" : "normal", "#f59e0b", Color.accent)

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setTab("reviews")
            }

            Column {
              anchors.centerIn: parent
              spacing: 0

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(4)

                Text {
                  text: "󰏤"
                  color: "#f59e0b"
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "" + root.counts.reviewRequests
                  color: root.counts.reviewRequests > 0 ? "#f59e0b" : (root.bar ? root.bar.foreground : Color.foreground)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Reviews [2]"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }

          // Notifications Tile
          BorderSurface {
            width: (parent.width - Style.space(12)) / 3
            height: Style.space(48)
            radius: Style.cornerRadius
            color: root.activeTab === "notifications" ? Style.hoverFillFor(Color.accent, Color.accent) : Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
            borderSpec: Border.controlSpec(root.activeTab === "notifications" ? "selected" : "normal", Color.accent, Color.accent)

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.setTab("notifications")
            }

            Column {
              anchors.centerIn: parent
              spacing: 0

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(4)

                Text {
                  text: "󰂚"
                  color: root.counts.notifications > 0 ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "" + root.counts.notifications
                  color: root.counts.notifications > 0 ? Color.accent : (root.bar ? root.bar.foreground : Color.foreground)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Alerts [3]"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        // ==========================================
        // TAB NAVIGATION BAR
        // ==========================================
        Row {
          visible: root.authenticated
          width: parent.width
          spacing: Style.space(4)

          Button {
            width: (parent.width - Style.space(8)) / 3
            text: "My PRs [1]"
            iconText: ""
            selected: root.activeTab === "prs"
            accent: Color.accent
            onClicked: root.setTab("prs")
          }

          Button {
            width: (parent.width - Style.space(8)) / 3
            text: "Reviews [2]"
            iconText: "󰏤"
            selected: root.activeTab === "reviews"
            accent: "#f59e0b"
            onClicked: root.setTab("reviews")
          }

          Button {
            width: (parent.width - Style.space(8)) / 3
            text: "Alerts [3]"
            iconText: "󰂚"
            selected: root.activeTab === "notifications"
            accent: Color.accent
            onClicked: root.setTab("notifications")
          }
        }

        // ==========================================
        // TAB 1: MY PULL REQUESTS
        // ==========================================
        Column {
          visible: root.authenticated && root.activeTab === "prs"
          width: parent.width
          spacing: Style.space(6)

          // Empty state
          BorderSurface {
            visible: root.myPrsList.length === 0
            width: parent.width
            height: Style.space(80)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

            Column {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No open pull requests"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          // List of PRs
          Repeater {
            model: root.myPrsList

            BorderSurface {
              required property var modelData
              required property int index
              readonly property bool isSelected: (root.keyboardActive && root.cursorIndex === index) || prHover.containsMouse
              width: parent.width
              height: Style.space(56)
              radius: Style.cornerRadius
              color: isSelected ? Style.hoverFillFor(Color.accent, Color.accent) : Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
              borderSpec: Border.controlSpec(isSelected ? "hover-cursor" : "normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)

              MouseArea {
                id: prHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: {
                  root.cursorIndex = index
                  root.keyboardActive = false
                }
                onClicked: root.openUrl(modelData.url)
              }

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(3)

                // Repo name + CI status
                Item {
                  width: parent.width
                  height: Style.space(18)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Text {
                      text: (modelData.repo || "") + " #" + (modelData.number || "")
                      color: Color.accent
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    // CI Status Pill
                    BorderSurface {
                      height: Style.space(16)
                      radius: height / 2
                      color: modelData.ciState === "success" ? "#064e3b" : (modelData.ciState === "failure" ? "#7f1d1d" : (modelData.ciState === "pending" ? "#78350f" : "transparent"))
                      borderSpec: Border.controlSpec("normal", modelData.ciState === "success" ? "#10b981" : (modelData.ciState === "failure" ? "#ef4444" : "#f59e0b"), Color.accent)
                      visible: modelData.ciState !== "none"
                      anchors.verticalCenter: parent.verticalCenter
                      leftPadding: Style.space(4)
                      rightPadding: Style.space(4)

                      Text {
                        anchors.centerIn: parent
                        text: modelData.ciState === "success" ? "✓ CI Passed" : (modelData.ciState === "failure" ? "✖ CI Failed" : "● CI Running")
                        color: modelData.ciState === "success" ? "#10b981" : (modelData.ciState === "failure" ? "#ef4444" : "#f59e0b")
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption * 0.85
                        font.bold: true
                      }
                    }

                    // Review Decision Pill
                    BorderSurface {
                      height: Style.space(16)
                      radius: height / 2
                      color: modelData.reviewDecision === "approved" ? "#064e3b" : (modelData.reviewDecision === "changes_requested" ? "#7f1d1d" : "transparent")
                      borderSpec: Border.controlSpec("normal", modelData.reviewDecision === "approved" ? "#10b981" : (modelData.reviewDecision === "changes_requested" ? "#ef4444" : Color.accent), Color.accent)
                      visible: modelData.reviewDecision !== "none"
                      anchors.verticalCenter: parent.verticalCenter
                      leftPadding: Style.space(4)
                      rightPadding: Style.space(4)

                      Text {
                        anchors.centerIn: parent
                        text: modelData.reviewDecision === "approved" ? "Approved" : (modelData.reviewDecision === "changes_requested" ? "Changes Requested" : "In Review")
                        color: modelData.reviewDecision === "approved" ? "#10b981" : (modelData.reviewDecision === "changes_requested" ? "#ef4444" : Color.accent)
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.caption * 0.85
                        font.bold: true
                      }
                    }
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.timeAgo || ""
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption * 0.85
                  }
                }

                // PR Title
                Text {
                  width: parent.width
                  text: modelData.title || ""
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }
              }
            }
          }
        }

        // ==========================================
        // TAB 2: REVIEW REQUESTS
        // ==========================================
        Column {
          visible: root.authenticated && root.activeTab === "reviews"
          width: parent.width
          spacing: Style.space(6)

          // Empty state
          BorderSurface {
            visible: root.reviewRequestsList.length === 0
            width: parent.width
            height: Style.space(80)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

            Column {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰏤"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All caught up! No pending review requests."
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          // List of Review Requests
          Repeater {
            model: root.reviewRequestsList

            BorderSurface {
              required property var modelData
              required property int index
              readonly property bool isSelected: (root.keyboardActive && root.cursorIndex === index) || reviewHover.containsMouse
              width: parent.width
              height: Style.space(56)
              radius: Style.cornerRadius
              color: isSelected ? Style.hoverFillFor("#f59e0b", Color.accent) : Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
              borderSpec: Border.controlSpec(isSelected ? "hover-cursor" : "normal", "#f59e0b", Color.accent)

              MouseArea {
                id: reviewHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: {
                  root.cursorIndex = index
                  root.keyboardActive = false
                }
                onClicked: root.openUrl(modelData.url)
              }

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(3)

                Item {
                  width: parent.width
                  height: Style.space(18)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Text {
                      text: (modelData.repo || "") + " #" + (modelData.number || "")
                      color: "#f59e0b"
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      text: "by @" + (modelData.author || "author")
                      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption * 0.9
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.timeAgo || ""
                    color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.caption * 0.85
                  }
                }

                Text {
                  width: parent.width
                  text: modelData.title || ""
                  color: root.bar ? root.bar.foreground : Color.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                  maximumLineCount: 1
                }
              }
            }
          }
        }

        // ==========================================
        // TAB 3: NOTIFICATIONS
        // ==========================================
        Column {
          visible: root.authenticated && root.activeTab === "notifications"
          width: parent.width
          spacing: Style.space(6)

          // Mark All As Read Bar (if has notifications)
          Item {
            visible: root.notificationsList.length > 0
            width: parent.width
            height: Style.space(26)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.notificationsList.length + " unread alert" + (root.notificationsList.length > 1 ? "s" : "")
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
            }

            Button {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Mark All Read [a]"
              iconText: "󰄳"
              fontSize: Style.font.caption
              verticalPadding: Style.space(3)
              horizontalPadding: Style.space(6)
              onClicked: root.markAllNotificationsRead()
            }
          }

          // Empty state
          BorderSurface {
            visible: root.notificationsList.length === 0
            width: parent.width
            height: Style.space(80)
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

            Column {
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰂚"
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All clear! No unread notifications."
                color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.3)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          // List of Notifications
          Repeater {
            model: root.notificationsList

            BorderSurface {
              required property var modelData
              required property int index
              readonly property bool isSelected: (root.keyboardActive && root.cursorIndex === index) || notifHover.containsMouse
              width: parent.width
              height: Style.space(56)
              radius: Style.cornerRadius
              color: isSelected ? Style.hoverFillFor(Color.accent, Color.accent) : Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)
              borderSpec: Border.controlSpec(isSelected ? "hover-cursor" : "normal", root.bar ? root.bar.foreground : Color.foreground, Color.accent)

              MouseArea {
                id: notifHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: {
                  root.cursorIndex = index
                  root.keyboardActive = false
                }
                onClicked: root.openUrl(modelData.url)
              }

              Row {
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(8)

                Column {
                  width: parent.width - Style.space(36)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Row {
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                      text: modelData.type === "PullRequest" ? "" : (modelData.type === "Issue" ? "" : "󰂚")
                      color: Color.accent
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      text: modelData.repo || ""
                      color: Color.accent
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      text: "• " + (modelData.timeAgo || "")
                      color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.caption * 0.85
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  Text {
                    width: parent.width
                    text: modelData.title || ""
                    color: root.bar ? root.bar.foreground : Color.foreground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }
                }

                // 1-Click Mark Read Button
                Button {
                  width: Style.space(26)
                  height: Style.space(26)
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "󰄳"
                  tooltipText: "Mark as read [x]"
                  onClicked: root.markNotificationRead(modelData.id)
                }
              }
            }
          }
        }

        // ==========================================
        // KEYBOARD HINTS RIBBON
        // ==========================================
        BorderSurface {
          width: parent.width
          height: Style.space(22)
          radius: Style.cornerRadius
          color: Style.normalFillFor(root.bar ? root.bar.foreground : Color.foreground, Color.accent)

          Row {
            anchors.centerIn: parent
            spacing: Style.space(8)

            Text {
              text: "󰌌"
              color: Color.accent
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption * 0.9
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              text: "j/k: nav · ↵/o: open · 1-3/h/l: tabs · x: read · r: refresh · q: close"
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption * 0.85
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        // ==========================================
        // FOOTER / STATUS BAR
        // ==========================================
        Item {
          width: parent.width
          height: Style.space(24)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.lastUpdated > 0 ? ("Updated " + root.formatRelativeTime(root.lastUpdated)) : "Ready"
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Button {
              text: "+ Issue [i]"
              fontSize: Style.font.caption
              verticalPadding: Style.space(2)
              horizontalPadding: Style.space(6)
              onClicked: root.openUrl("https://github.com/issues")
            }

            Button {
              text: "+ PR [n]"
              fontSize: Style.font.caption
              verticalPadding: Style.space(2)
              horizontalPadding: Style.space(6)
              onClicked: root.openUrl("https://github.com/pulls")
            }
          }
        }
      }
    }
  }
}
