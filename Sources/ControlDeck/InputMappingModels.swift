import Foundation

enum ControllerTransport: String, Codable, CaseIterable, Sendable {
    case usb
    case bluetooth
    case unknown

    var label: String {
        switch self {
        case .usb: "USB"
        case .bluetooth: "Bluetooth"
        case .unknown: "Wireless / USB"
        }
    }

    var systemImage: String {
        switch self {
        case .usb: "cable.connector"
        case .bluetooth: "bluetooth"
        case .unknown: "gamecontroller"
        }
    }
}

enum ControllerInput: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case cross
    case circle
    case square
    case triangle
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case l1
    case r1
    case l2
    case r2
    case l3
    case r3
    case create
    case options
    case ps
    case touchpadClick
    case microphone

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cross: "Cross"
        case .circle: "Circle"
        case .square: "Square"
        case .triangle: "Triangle"
        case .dpadUp: "D-pad Up"
        case .dpadDown: "D-pad Down"
        case .dpadLeft: "D-pad Left"
        case .dpadRight: "D-pad Right"
        case .l1: "L1"
        case .r1: "R1"
        case .l2: "L2"
        case .r2: "R2"
        case .l3: "L3"
        case .r3: "R3"
        case .create: "Create"
        case .options: "Options"
        case .ps: "PS"
        case .touchpadClick: "Touchpad Click"
        case .microphone: "Microphone"
        }
    }

    var shortLabel: String {
        switch self {
        case .dpadUp: "↑"
        case .dpadDown: "↓"
        case .dpadLeft: "←"
        case .dpadRight: "→"
        case .touchpadClick: "Pad"
        case .microphone: "Mic"
        default: label
        }
    }
}

enum ControllerStick: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case left
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .left: "Left stick"
        case .right: "Right stick"
        }
    }
}

enum TouchFinger: String, Codable, Sendable {
    case primary
    case secondary
}

enum TouchGesture: String, Codable, CaseIterable, Identifiable, Sendable {
    case oneFingerTap
    case twoFingerTap
    case oneFingerLongPress
    case twoFingerLongPress
    case oneFingerSwipeLeft
    case oneFingerSwipeRight
    case oneFingerSwipeUp
    case oneFingerSwipeDown
    case twoFingerSwipeLeft
    case twoFingerSwipeRight
    case twoFingerSwipeUp
    case twoFingerSwipeDown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneFingerTap: "One-finger tap"
        case .twoFingerTap: "Two-finger tap"
        case .oneFingerLongPress: "One-finger hold"
        case .twoFingerLongPress: "Two-finger hold"
        case .oneFingerSwipeLeft: "One-finger swipe left"
        case .oneFingerSwipeRight: "One-finger swipe right"
        case .oneFingerSwipeUp: "One-finger swipe up"
        case .oneFingerSwipeDown: "One-finger swipe down"
        case .twoFingerSwipeLeft: "Two-finger swipe left"
        case .twoFingerSwipeRight: "Two-finger swipe right"
        case .twoFingerSwipeUp: "Two-finger swipe up"
        case .twoFingerSwipeDown: "Two-finger swipe down"
        }
    }

    static func swipe(fingers: Int, deltaX: Float, deltaY: Float) -> TouchGesture {
        let horizontal = abs(deltaX) >= abs(deltaY)
        if fingers >= 2 {
            if horizontal {
                return deltaX < 0 ? .twoFingerSwipeLeft : .twoFingerSwipeRight
            }
            return deltaY < 0 ? .twoFingerSwipeDown : .twoFingerSwipeUp
        }
        if horizontal {
            return deltaX < 0 ? .oneFingerSwipeLeft : .oneFingerSwipeRight
        }
        return deltaY < 0 ? .oneFingerSwipeDown : .oneFingerSwipeUp
    }
}

enum ActionCategory: String, CaseIterable, Identifiable, Sendable {
    case codex
    case claude
    case meeting
    case presentation
    case communication
    case files
    case creative
    case terminal
    case mouse
    case navigation
    case keyboard
    case browser
    case media
    case apps
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        case .meeting: "Meetings"
        case .presentation: "Presentations"
        case .communication: "Communication"
        case .files: "Files & photos"
        case .creative: "Creative tools"
        case .terminal: "Terminal"
        default: rawValue.capitalized
        }
    }
}

enum MappedAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case none

    case codexSend
    case codexStop
    case codexReview
    case codexPlan
    case codexNewTask
    case codexCommandMenu
    case codexFocus
    case codexPreviousTask
    case codexNextTask
    case codexBack
    case codexForward
    case codexSidebar
    case codexQuickChat
    case codexTerminal
    case codexApprove
    case codexDecline
    case codexDictation
    case codexFastMode
    case codexContinueInNewTask

    case claudeNewChat
    case claudeSidebar
    case claudeCode
    case claudeProjects

    case meetingMute
    case meetingPushToTalk
    case meetingVideo
    case meetingChat
    case meetingParticipants
    case meetingShare
    case meetingRaiseHand

    case presentationStart
    case presentationNext
    case presentationPrevious
    case presentationBlackScreen
    case presentationPointer
    case presentationNotesUp
    case presentationNotesDown
    case presentationExit

    case slackJumpConversation
    case slackPreviousUnread
    case slackNextUnread
    case slackThreads
    case slackActivity
    case slackHuddle

    case mailArchive
    case mailReply
    case mailUnread

    case photosFavorite
    case photosEdit
    case photosRotate
    case photosInfo

    case timelinePlayPause
    case timelineReverse
    case timelinePause
    case timelineForward
    case timelineMarkIn
    case timelineMarkOut
    case timelinePreviousEdit
    case timelineNextEdit
    case timelineRecord
    case timelineRewind
    case timelineFastForward

    case figmaComment
    case figmaFrame
    case figmaHand
    case figmaDevMode

    case terminalNewTab
    case terminalCloseTab
    case terminalNextTab
    case terminalPreviousTab
    case terminalClear
    case terminalInterrupt
    case terminalSearchHistory
    case terminalSplitPane
    case terminalClosePane

    case mouseLeftClick
    case mouseRightClick
    case mouseMiddleClick
    case screenshotSelection

    case back
    case forward
    case missionControl
    case showDesktop
    case appSwitcher

    case returnKey
    case escapeKey
    case spaceKey
    case tabKey
    case copy
    case paste
    case cut
    case selectAll
    case undo
    case redo
    case zoomIn
    case zoomOut
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight

    case browserAddress
    case browserNewTab
    case browserCloseTab
    case browserReopenTab
    case browserReload
    case browserFind
    case browserNextTab
    case browserPreviousTab

    case mediaPlayPause
    case mediaNext
    case mediaPrevious
    case volumeUp
    case volumeDown
    case volumeMute

    case openCodex
    case openChrome
    case openSpotify
    case openClaude
    case systemDictation
    case showControllerOverlay
    case deleteTextWithConfirmation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "No action"
        case .codexSend: "Codex · Send"
        case .codexStop: "Codex · Stop"
        case .codexReview: "Codex · Review changes"
        case .codexPlan: "Codex · Plan mode"
        case .codexNewTask: "Codex · New task"
        case .codexCommandMenu: "Codex · Command menu"
        case .codexFocus: "Codex · Focus"
        case .codexPreviousTask: "Codex · Previous task"
        case .codexNextTask: "Codex · Next task"
        case .codexBack: "Codex · Back"
        case .codexForward: "Codex · Forward"
        case .codexSidebar: "Codex · Toggle sidebar"
        case .codexQuickChat: "Codex · Quick chat"
        case .codexTerminal: "Codex · Toggle terminal"
        case .codexApprove: "Codex · Approve"
        case .codexDecline: "Codex · Decline"
        case .codexDictation: "Codex · Dictation"
        case .codexFastMode: "Codex · Fast mode"
        case .codexContinueInNewTask: "Codex · Continue in new task"
        case .claudeNewChat: "Claude · New chat"
        case .claudeSidebar: "Claude · Toggle sidebar"
        case .claudeCode: "Claude · Code"
        case .claudeProjects: "Claude · Projects"
        case .meetingMute: "Meeting · Mute / unmute"
        case .meetingPushToTalk: "Meeting · Push to talk"
        case .meetingVideo: "Meeting · Camera"
        case .meetingChat: "Meeting · Chat"
        case .meetingParticipants: "Meeting · Participants"
        case .meetingShare: "Meeting · Share tray"
        case .meetingRaiseHand: "Meeting · Raise hand"
        case .presentationStart: "Presentation · Start"
        case .presentationNext: "Presentation · Next"
        case .presentationPrevious: "Presentation · Previous"
        case .presentationBlackScreen: "Presentation · Black screen"
        case .presentationPointer: "Presentation · Pointer"
        case .presentationNotesUp: "Presentation · Notes up"
        case .presentationNotesDown: "Presentation · Notes down"
        case .presentationExit: "Presentation · Exit"
        case .slackJumpConversation: "Slack · Jump to conversation"
        case .slackPreviousUnread: "Slack · Previous unread"
        case .slackNextUnread: "Slack · Next unread"
        case .slackThreads: "Slack · Threads"
        case .slackActivity: "Slack · Activity"
        case .slackHuddle: "Slack · Huddle"
        case .mailArchive: "Mail · Archive"
        case .mailReply: "Mail · Reply"
        case .mailUnread: "Mail · Read / unread"
        case .photosFavorite: "Photos · Favourite"
        case .photosEdit: "Photos · Edit"
        case .photosRotate: "Photos · Rotate"
        case .photosInfo: "Photos · Info"
        case .timelinePlayPause: "Timeline · Play / pause"
        case .timelineReverse: "Timeline · Reverse"
        case .timelinePause: "Timeline · Pause"
        case .timelineForward: "Timeline · Forward"
        case .timelineMarkIn: "Timeline · Mark in"
        case .timelineMarkOut: "Timeline · Mark out"
        case .timelinePreviousEdit: "Timeline · Previous edit"
        case .timelineNextEdit: "Timeline · Next edit"
        case .timelineRecord: "Timeline · Record"
        case .timelineRewind: "Timeline · Rewind"
        case .timelineFastForward: "Timeline · Fast forward"
        case .figmaComment: "Figma · Comment tool"
        case .figmaFrame: "Figma · Frame tool"
        case .figmaHand: "Figma · Hand tool"
        case .figmaDevMode: "Figma · Dev mode"
        case .terminalNewTab: "Terminal · New tab"
        case .terminalCloseTab: "Terminal · Close tab"
        case .terminalNextTab: "Terminal · Next tab"
        case .terminalPreviousTab: "Terminal · Previous tab"
        case .terminalClear: "Terminal · Clear"
        case .terminalInterrupt: "Terminal · Interrupt"
        case .terminalSearchHistory: "Terminal · Search history"
        case .terminalSplitPane: "Terminal · Split pane"
        case .terminalClosePane: "Terminal · Close pane"
        case .mouseLeftClick: "Mouse · Left click"
        case .mouseRightClick: "Mouse · Right click"
        case .mouseMiddleClick: "Mouse · Middle click"
        case .screenshotSelection: "Screenshot · Select area"
        case .back: "Navigate back"
        case .forward: "Navigate forward"
        case .missionControl: "Mission Control"
        case .showDesktop: "Show desktop"
        case .appSwitcher: "App switcher"
        case .returnKey: "Return"
        case .escapeKey: "Escape"
        case .spaceKey: "Space"
        case .tabKey: "Tab"
        case .copy: "Edit · Copy"
        case .paste: "Edit · Paste"
        case .cut: "Edit · Cut"
        case .selectAll: "Edit · Select all"
        case .undo: "Edit · Undo"
        case .redo: "Edit · Redo"
        case .zoomIn: "View · Zoom in"
        case .zoomOut: "View · Zoom out"
        case .arrowUp: "Arrow up"
        case .arrowDown: "Arrow down"
        case .arrowLeft: "Arrow left"
        case .arrowRight: "Arrow right"
        case .browserAddress: "Browser · Address bar"
        case .browserNewTab: "Browser · New tab"
        case .browserCloseTab: "Browser · Close tab"
        case .browserReopenTab: "Browser · Reopen tab"
        case .browserReload: "Browser · Reload"
        case .browserFind: "Browser · Find"
        case .browserNextTab: "Browser · Next tab"
        case .browserPreviousTab: "Browser · Previous tab"
        case .mediaPlayPause: "Media · Play / pause"
        case .mediaNext: "Media · Next"
        case .mediaPrevious: "Media · Previous"
        case .volumeUp: "Volume up"
        case .volumeDown: "Volume down"
        case .volumeMute: "Mute"
        case .openCodex: "Open Codex"
        case .openChrome: "Open Chrome"
        case .openSpotify: "Open Spotify"
        case .openClaude: "Open Claude"
        case .systemDictation: "System dictation (Fn Fn)"
        case .showControllerOverlay: "Show controller overlay"
        case .deleteTextWithConfirmation: "Text · Delete with confirmation"
        }
    }

    var category: ActionCategory {
        switch self {
        case .codexSend, .codexStop, .codexReview, .codexPlan, .codexNewTask,
             .codexCommandMenu, .codexFocus, .codexPreviousTask, .codexNextTask,
             .codexBack, .codexForward, .codexSidebar, .codexQuickChat,
             .codexTerminal, .codexApprove, .codexDecline, .codexDictation,
             .codexFastMode, .codexContinueInNewTask:
            .codex
        case .claudeNewChat, .claudeSidebar, .claudeCode,
             .claudeProjects:
            .claude
        case .meetingMute, .meetingPushToTalk, .meetingVideo,
             .meetingChat, .meetingParticipants, .meetingShare,
             .meetingRaiseHand:
            .meeting
        case .presentationStart, .presentationNext,
             .presentationPrevious, .presentationBlackScreen,
             .presentationPointer, .presentationNotesUp,
             .presentationNotesDown, .presentationExit:
            .presentation
        case .slackJumpConversation, .slackPreviousUnread,
             .slackNextUnread, .slackThreads, .slackActivity,
             .slackHuddle, .mailArchive, .mailReply, .mailUnread:
            .communication
        case .photosFavorite, .photosEdit, .photosRotate, .photosInfo:
            .files
        case .timelinePlayPause, .timelineReverse, .timelinePause,
             .timelineForward, .timelineMarkIn, .timelineMarkOut,
             .timelinePreviousEdit, .timelineNextEdit, .timelineRecord,
             .timelineRewind, .timelineFastForward, .figmaComment,
             .figmaFrame, .figmaHand, .figmaDevMode:
            .creative
        case .terminalNewTab, .terminalCloseTab, .terminalNextTab,
             .terminalPreviousTab, .terminalClear, .terminalInterrupt,
             .terminalSearchHistory, .terminalSplitPane,
             .terminalClosePane:
            .terminal
        case .mouseLeftClick, .mouseRightClick, .mouseMiddleClick:
            .mouse
        case .back, .forward, .missionControl, .showDesktop, .appSwitcher:
            .navigation
        case .returnKey, .escapeKey, .spaceKey, .tabKey, .copy, .paste, .cut,
             .selectAll, .undo, .redo, .zoomIn, .zoomOut, .arrowUp,
             .arrowDown, .arrowLeft, .arrowRight:
            .keyboard
        case .browserAddress, .browserNewTab, .browserCloseTab, .browserReopenTab,
             .browserReload, .browserFind, .browserNextTab, .browserPreviousTab:
            .browser
        case .mediaPlayPause, .mediaNext, .mediaPrevious, .volumeUp, .volumeDown,
             .volumeMute:
            .media
        case .openCodex, .openChrome, .openSpotify, .openClaude:
            .apps
        case .none, .systemDictation, .screenshotSelection,
             .showControllerOverlay, .deleteTextWithConfirmation:
            .other
        }
    }
}

struct StickPointerSettings: Codable, Equatable, Sendable {
    var source: ControllerStick
    var speed: Double
    var acceleration: Double
    var deadZone: Double
    var scrollSource: ControllerStick
    var scrollSpeed: Double
    var scrollAcceleration: Double
    var scrollDeadZone: Double

    init(
        source: ControllerStick,
        speed: Double,
        acceleration: Double,
        deadZone: Double,
        scrollSource: ControllerStick = .right,
        scrollSpeed: Double = 1_050,
        scrollAcceleration: Double = 1.35,
        scrollDeadZone: Double = 0.18
    ) {
        self.source = source
        self.speed = speed
        self.acceleration = acceleration
        self.deadZone = deadZone
        self.scrollSource = scrollSource
        self.scrollSpeed = scrollSpeed
        self.scrollAcceleration = scrollAcceleration
        self.scrollDeadZone = scrollDeadZone
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case speed
        case acceleration
        case deadZone
        case scrollSource
        case scrollSpeed
        case scrollAcceleration
        case scrollDeadZone
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        source = try values.decode(ControllerStick.self, forKey: .source)
        speed = try values.decode(Double.self, forKey: .speed)
        acceleration = try values.decode(Double.self, forKey: .acceleration)
        deadZone = try values.decode(Double.self, forKey: .deadZone)
        scrollSource = try values.decodeIfPresent(
            ControllerStick.self,
            forKey: .scrollSource
        ) ?? .right
        scrollSpeed = try values.decodeIfPresent(
            Double.self,
            forKey: .scrollSpeed
        ) ?? 1_050
        scrollAcceleration = try values.decodeIfPresent(
            Double.self,
            forKey: .scrollAcceleration
        ) ?? 1.35
        scrollDeadZone = try values.decodeIfPresent(
            Double.self,
            forKey: .scrollDeadZone
        ) ?? 0.18
    }

    static let codexDefault = StickPointerSettings(
        source: .left,
        speed: 820,
        acceleration: 1.7,
        deadZone: 0.17
    )
    static let generalDefault = StickPointerSettings(
        source: .left,
        speed: 900,
        acceleration: 1.65,
        deadZone: 0.16
    )
}

enum TouchpadMotionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case scroll
    case pointer
    case gesturesOnly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scroll: "Scroll"
        case .pointer: "Pointer"
        case .gesturesOnly: "Gestures"
        }
    }
}

struct TouchpadSettings: Codable, Equatable, Sendable {
    var oneFingerMode: TouchpadMotionMode
    var twoFingerScroll: Bool
    var pointerSensitivity: Double
    var scrollSensitivity: Double
    var gestureBindings: [String: String]

    init(
        oneFingerMode: TouchpadMotionMode,
        twoFingerScroll: Bool,
        pointerSensitivity: Double,
        scrollSensitivity: Double,
        gestureBindings: [String: String]
    ) {
        self.oneFingerMode = oneFingerMode
        self.twoFingerScroll = twoFingerScroll
        self.pointerSensitivity = pointerSensitivity
        self.scrollSensitivity = scrollSensitivity
        self.gestureBindings = gestureBindings
    }

    private enum CodingKeys: String, CodingKey {
        case oneFingerMode
        case oneFingerPointer
        case twoFingerScroll
        case pointerSensitivity
        case scrollSensitivity
        case gestureBindings
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        if let mode = try values.decodeIfPresent(
            TouchpadMotionMode.self,
            forKey: .oneFingerMode
        ) {
            oneFingerMode = mode
        } else {
            let legacyPointer = try values.decodeIfPresent(
                Bool.self,
                forKey: .oneFingerPointer
            ) ?? true
            oneFingerMode = legacyPointer ? .pointer : .scroll
        }
        twoFingerScroll = try values.decode(
            Bool.self,
            forKey: .twoFingerScroll
        )
        pointerSensitivity = try values.decode(
            Double.self,
            forKey: .pointerSensitivity
        )
        scrollSensitivity = try values.decode(
            Double.self,
            forKey: .scrollSensitivity
        )
        gestureBindings = try values.decode(
            [String: String].self,
            forKey: .gestureBindings
        )
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(oneFingerMode, forKey: .oneFingerMode)
        try values.encode(twoFingerScroll, forKey: .twoFingerScroll)
        try values.encode(pointerSensitivity, forKey: .pointerSensitivity)
        try values.encode(scrollSensitivity, forKey: .scrollSensitivity)
        try values.encode(gestureBindings, forKey: .gestureBindings)
    }

    func action(for gesture: TouchGesture) -> MappedAction {
        guard let rawValue = gestureBindings[gesture.rawValue] else { return .none }
        return MappedAction(rawValue: rawValue) ?? .none
    }

    mutating func setAction(_ action: MappedAction, for gesture: TouchGesture) {
        gestureBindings[gesture.rawValue] = action.rawValue
    }

    static let trackpadDefault = TouchpadSettings(
        oneFingerMode: .scroll,
        twoFingerScroll: true,
        pointerSensitivity: 1,
        scrollSensitivity: 1,
        gestureBindings: [
            TouchGesture.oneFingerTap.rawValue: MappedAction.mouseLeftClick.rawValue,
            TouchGesture.twoFingerTap.rawValue: MappedAction.mouseRightClick.rawValue,
            TouchGesture.oneFingerLongPress.rawValue: MappedAction.mouseLeftClick.rawValue,
            TouchGesture.twoFingerSwipeLeft.rawValue: MappedAction.back.rawValue,
            TouchGesture.twoFingerSwipeRight.rawValue: MappedAction.forward.rawValue,
            TouchGesture.twoFingerSwipeUp.rawValue: MappedAction.missionControl.rawValue,
            TouchGesture.twoFingerSwipeDown.rawValue: MappedAction.showDesktop.rawValue
        ]
    )
}

enum ProfileKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex
    case general
    case chrome
    case spotify
    case claude
    case xcode
    case finder
    case meetings
    case presentations
    case slack
    case mail
    case photos
    case figma
    case videoEditing
    case logic
    case terminal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .codex: "Codex"
        case .general: "General"
        case .chrome: "Chrome"
        case .spotify: "Spotify"
        case .claude: "Claude"
        case .xcode: "Xcode"
        case .finder: "Finder"
        case .meetings: "Meetings"
        case .presentations: "Presentations"
        case .slack: "Slack"
        case .mail: "Mail"
        case .photos: "Photos"
        case .figma: "Figma"
        case .videoEditing: "Video Editing"
        case .logic: "Logic Pro"
        case .terminal: "Terminal"
        }
    }

    var systemImage: String {
        switch self {
        case .codex: "terminal"
        case .general: "macbook"
        case .chrome: "globe"
        case .spotify: "music.note"
        case .claude: "sparkles"
        case .xcode: "hammer"
        case .finder: "folder"
        case .meetings: "video"
        case .presentations: "play.rectangle"
        case .slack: "number"
        case .mail: "envelope"
        case .photos: "photo.on.rectangle"
        case .figma: "paintbrush.pointed"
        case .videoEditing: "timeline.selection"
        case .logic: "waveform"
        case .terminal: "apple.terminal"
        }
    }
}

struct ControllerProfile: Codable, Equatable, Identifiable, Sendable {
    var kind: ProfileKind
    var name: String
    var bundleIdentifiers: [String]
    var windowTitleKeywords: [String]
    var bindings: [String: String]
    var pointer: StickPointerSettings
    var touchpad: TouchpadSettings
    var gyro: GyroSettings

    var id: String { kind.rawValue }

    init(
        kind: ProfileKind,
        name: String,
        bundleIdentifiers: [String],
        windowTitleKeywords: [String] = [],
        bindings: [String: String],
        pointer: StickPointerSettings,
        touchpad: TouchpadSettings,
        gyro: GyroSettings = .shakeOnly
    ) {
        self.kind = kind
        self.name = name
        self.bundleIdentifiers = bundleIdentifiers
        self.windowTitleKeywords = windowTitleKeywords
        self.bindings = bindings
        self.pointer = pointer
        self.touchpad = touchpad
        self.gyro = gyro
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case name
        case bundleIdentifiers
        case windowTitleKeywords
        case bindings
        case pointer
        case touchpad
        case gyro
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(ProfileKind.self, forKey: .kind)
        name = try values.decode(String.self, forKey: .name)
        bundleIdentifiers = try values.decode(
            [String].self,
            forKey: .bundleIdentifiers
        )
        windowTitleKeywords = try values.decodeIfPresent(
            [String].self,
            forKey: .windowTitleKeywords
        ) ?? []
        bindings = try values.decode([String: String].self, forKey: .bindings)
        pointer = try values.decode(StickPointerSettings.self, forKey: .pointer)
        touchpad = try values.decode(TouchpadSettings.self, forKey: .touchpad)
        gyro = try values.decodeIfPresent(
            GyroSettings.self,
            forKey: .gyro
        ) ?? .shakeOnly
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(kind, forKey: .kind)
        try values.encode(name, forKey: .name)
        try values.encode(bundleIdentifiers, forKey: .bundleIdentifiers)
        try values.encode(windowTitleKeywords, forKey: .windowTitleKeywords)
        try values.encode(bindings, forKey: .bindings)
        try values.encode(pointer, forKey: .pointer)
        try values.encode(touchpad, forKey: .touchpad)
        try values.encode(gyro, forKey: .gyro)
    }

    func action(for input: ControllerInput) -> MappedAction {
        guard let rawValue = bindings[input.rawValue] else { return .none }
        return MappedAction(rawValue: rawValue) ?? .none
    }

    mutating func setAction(_ action: MappedAction, for input: ControllerInput) {
        bindings[input.rawValue] = action.rawValue
    }

    func matches(bundleIdentifier: String?, windowTitle: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        let bundleMatches = bundleIdentifiers.contains { pattern in
            if pattern.hasSuffix("*") {
                return bundleIdentifier.hasPrefix(String(pattern.dropLast()))
            }
            return pattern == bundleIdentifier
        }
        if bundleMatches { return true }
        guard Self.browserBundleIdentifiers.contains(bundleIdentifier),
              let windowTitle,
              !windowTitleKeywords.isEmpty
        else {
            return false
        }
        return windowTitleKeywords.contains {
            windowTitle.localizedCaseInsensitiveContains($0)
        }
    }

    private static let browserBundleIdentifiers: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser"
    ]

    static var defaults: [ControllerProfile] {
        [
            codex, claude, general, finder, chrome, meetings,
            presentations, slack, mail, photos, spotify, figma,
            videoEditing, logic, terminal, xcode
        ]
    }

    static let codex = ControllerProfile(
        kind: .codex,
        name: "Codex",
        bundleIdentifiers: [
            "com.openai.codex",
            "com.ianhansel.controldeck",
            "com.ianhansel.ps5codex"
        ],
        bindings: mapping([
            .cross: .mouseLeftClick,
            .circle: .codexStop,
            .square: .codexReview,
            .triangle: .codexPlan,
            .l1: .codexPreviousTask,
            .r1: .codexNextTask,
            .l2: .codexDictation,
            .r2: .screenshotSelection,
            .l3: .copy,
            .r3: .paste,
            .create: .codexNewTask,
            .options: .codexCommandMenu,
            .ps: .codexFocus,
            .dpadUp: .codexSend,
            .dpadDown: .codexSidebar,
            .dpadLeft: .codexBack,
            .dpadRight: .codexForward,
            .touchpadClick: .showControllerOverlay,
            .microphone: .codexDictation
        ]),
        pointer: .codexDefault,
        touchpad: .trackpadDefault
    )

    static let general = ControllerProfile(
        kind: .general,
        name: "General macOS",
        bundleIdentifiers: [],
        bindings: mapping([
            .cross: .mouseLeftClick,
            .circle: .mouseRightClick,
            .square: .copy,
            .triangle: .paste,
            .l1: .back,
            .r1: .forward,
            .l2: .mouseRightClick,
            .r2: .mouseLeftClick,
            .l3: .copy,
            .r3: .paste,
            .create: .systemDictation,
            .options: .escapeKey,
            .ps: .openCodex,
            .dpadUp: .arrowUp,
            .dpadDown: .arrowDown,
            .dpadLeft: .arrowLeft,
            .dpadRight: .arrowRight,
            .touchpadClick: .showControllerOverlay,
            .microphone: .systemDictation
        ]),
        pointer: .generalDefault,
        touchpad: .trackpadDefault
    )

    static let chrome = ControllerProfile(
        kind: .chrome,
        name: "Web browsers",
        bundleIdentifiers: [
            "com.google.Chrome",
            "com.apple.Safari",
            "org.mozilla.firefox",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "company.thebrowser.Browser"
        ],
        bindings: mapping([
            .cross: .mouseLeftClick,
            .circle: .escapeKey,
            .square: .browserNewTab,
            .triangle: .browserAddress,
            .l1: .back,
            .r1: .forward,
            .l2: .browserPreviousTab,
            .r2: .browserNextTab,
            .l3: .browserFind,
            .r3: .browserReload,
            .create: .browserReopenTab,
            .options: .browserCloseTab,
            .ps: .openCodex,
            .dpadUp: .arrowUp,
            .dpadDown: .arrowDown,
            .dpadLeft: .browserPreviousTab,
            .dpadRight: .browserNextTab,
            .touchpadClick: .showControllerOverlay,
            .microphone: .systemDictation
        ]),
        pointer: .generalDefault,
        touchpad: .trackpadDefault
    )

    static let spotify = ControllerProfile(
        kind: .spotify,
        name: "Music & media",
        bundleIdentifiers: [
            "com.spotify.client",
            "com.apple.Music",
            "org.videolan.vlc"
        ],
        bindings: mapping([
            .cross: .mediaPlayPause,
            .circle: .volumeMute,
            .square: .mediaPrevious,
            .triangle: .mediaNext,
            .l1: .mediaPrevious,
            .r1: .mediaNext,
            .l2: .volumeDown,
            .r2: .volumeUp,
            .l3: .showDesktop,
            .r3: .missionControl,
            .create: .systemDictation,
            .options: .escapeKey,
            .ps: .openCodex,
            .dpadUp: .volumeUp,
            .dpadDown: .volumeDown,
            .dpadLeft: .mediaPrevious,
            .dpadRight: .mediaNext,
            .touchpadClick: .showControllerOverlay,
            .microphone: .systemDictation
        ]),
        pointer: .generalDefault,
        touchpad: .trackpadDefault
    )

    static let claude = ControllerProfile(
        kind: .claude,
        name: "Claude",
        bundleIdentifiers: [
            "com.anthropic.claudefordesktop",
            "com.anthropic.Claude"
        ],
        bindings: mapping([
            .cross: .mouseLeftClick,
            .circle: .escapeKey,
            .square: .copy,
            .triangle: .claudeCode,
            .l1: .back,
            .r1: .forward,
            .l2: .systemDictation,
            .r2: .screenshotSelection,
            .l3: .claudeProjects,
            .r3: .claudeSidebar,
            .create: .claudeNewChat,
            .options: .claudeProjects,
            .ps: .openCodex,
            .dpadUp: .returnKey,
            .dpadDown: .claudeSidebar,
            .dpadLeft: .back,
            .dpadRight: .forward,
            .touchpadClick: .showControllerOverlay,
            .microphone: .systemDictation
        ]),
        pointer: .generalDefault,
        touchpad: .trackpadDefault
    )

    static let xcode = ControllerProfile(
        kind: .xcode,
        name: "Xcode & editors",
        bundleIdentifiers: [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92"
        ],
        bindings: mapping([
            .cross: .mouseLeftClick,
            .circle: .escapeKey,
            .square: .browserFind,
            .triangle: .appSwitcher,
            .l1: .back,
            .r1: .forward,
            .l2: .systemDictation,
            .r2: .screenshotSelection,
            .l3: .showDesktop,
            .r3: .missionControl,
            .create: .openCodex,
            .options: .browserFind,
            .ps: .openCodex,
            .dpadUp: .arrowUp,
            .dpadDown: .arrowDown,
            .dpadLeft: .arrowLeft,
            .dpadRight: .arrowRight,
            .touchpadClick: .showControllerOverlay,
            .microphone: .systemDictation
        ]),
        pointer: .generalDefault,
        touchpad: .trackpadDefault
    )

    static func mapping(
        _ values: [ControllerInput: MappedAction]
    ) -> [String: String] {
        Dictionary(
            uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value.rawValue) }
        )
    }
}
