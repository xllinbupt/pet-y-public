import AppKit
import Foundation

let PetYRuntimeVersion = "v0.1.29"

struct PetProfile: Codable {
    let pet_id: String
    let owner_user_id: String
    let profile_version: Int
    let protocol_version: String
    let name: String
    let style: String
    let preview: String
    let personality_card: String
    let projection_capabilities: [String]
    let interaction_capabilities: [String]?
}

extension PetProfile {
    func owned(by userId: String) -> PetProfile {
        let nextPetId = owner_user_id == userId ? pet_id : "\(pet_id)_\(userId)"
        return PetProfile(
            pet_id: nextPetId,
            owner_user_id: userId,
            profile_version: profile_version,
            protocol_version: protocol_version,
            name: name,
            style: style,
            preview: preview,
            personality_card: personality_card,
            projection_capabilities: projection_capabilities,
            interaction_capabilities: interaction_capabilities
        )
    }
}

struct User: Codable {
    let user_id: String
    let display_name: String
    let pet_id: String
}

struct BootstrapResponse: Codable {
    let user: User
    let friend_ids: [String]
    let friends: [FriendStatus]?
}

struct FriendStatus: Codable {
    let user_id: String
    let display_name: String
    let pet_id: String
    let online: Bool
    let last_seen_at: String?
}

struct InviteResponse: Codable {
    let invite: Invite
}

struct Invite: Codable {
    let token: String
    let user_id: String
    let display_name: String
    let created_at: String
}

struct InviteRequest: Codable {
    let user_id: String
    let display_name: String
}

struct AcceptInviteRequest: Codable {
    let user_id: String
    let token: String
}

struct AcceptInviteResponse: Codable {
    let friends: [FriendStatus]
}

struct FriendAddedPayload: Codable {
    let friend: FriendStatus?
}

struct VisitSession: Codable {
    let visit_id: String
    let pet_id: String
    let owner_user_id: String
    let host_user_id: String
    let profile_version: Int
    let status: String
}

struct VisitStartedPayload: Codable {
    let visit: VisitSession
    let profile: PetProfile
    let animation_states: [String: AnimationState]?
    let asset_blobs: [String: String]?
}

struct VisitEndedPayload: Codable {
    let visit_id: String
    let reason: String?
}

final class VisitorProjection {
    var visit: VisitSession
    let profile: PetProfile
    let window: PetWindow
    var roamTimer: Timer?
    var animationTimer: Timer?

    init(visit: VisitSession, profile: PetProfile, window: PetWindow) {
        self.visit = visit
        self.profile = profile
        self.window = window
    }
}

struct MemoryReceipt: Codable {
    let receipt_id: String
    let visit_id: String
    let pet_id: String
    let life_log_entry: String
    let pet_voice: String
    let messages: [VisitMessage]?
}

struct VisitMessage: Codable {
    let event_id: String?
    let text: String
    let author_user_id: String?
    let author_name: String?
    let created_at: String?
}

struct LifeLogEntry: Codable {
    let id: String
    let text: String
    let created_at: String
}

struct LocalPetState: Codable {
    var profile: PetProfile
    var life_log: [LifeLogEntry]
    var memories: [MemoryReceipt]
}

struct LocalIdentity: Codable {
    let user_id: String
    let display_name: String
}

struct AnimationState: Codable {
    let description: String?
    let asset: String
    let format: String
    let frame_width: Int
    let frame_height: Int
    let frames: Int
    let fps: Int
    let loop: Bool
    let default_facing: String?
}

struct PetLifePack: Codable {
    let schema_version: String
    let profile: PetProfile
    let animation_states: [String: AnimationState]?
}

struct PetProfileRegistration: Codable {
    let pet_id: String
    let owner_user_id: String
    let profile_version: Int
    let protocol_version: String
    let name: String
    let style: String
    let preview: String
    let personality_card: String
    let projection_capabilities: [String]
    let interaction_capabilities: [String]?
    let animation_states: [String: AnimationState]?
    let asset_blobs: [String: String]?
}

enum AnimationIntent {
    case move
    case rest
    case sleep
    case returnWithGift
    case signature
}

struct AnimationResolver {
    let states: [String: AnimationState]

    func state(for intent: AnimationIntent) -> String? {
        switch intent {
        case .move:
            return firstExisting(["move", "run", "walk", "float", "drift", "hop", "idle"])
        case .rest:
            return firstExisting(["rest", "sit", "settle", "idle"])
        case .sleep:
            return firstExisting(["sleep", "rest", "sit", "idle"])
        case .returnWithGift:
            return firstExisting(["return_with_gift", "carry_ball", signatureState(), "rest", "sit", "idle"].compactMap { $0 })
        case .signature:
            return signatureState()
        }
    }

    func hasFetchBallAction() -> Bool {
        states["carry_ball"] != nil
    }

    func signatureActionTitle() -> String {
        guard let state = signatureState() else { return "互动" }
        if state.contains("glow") { return "闪一下" }
        if state.contains("dance") { return "跳舞" }
        if state.contains("hide") { return "躲一下" }
        return "招牌动作"
    }

    private func firstExisting(_ names: [String]) -> String? {
        names.first { states[$0] != nil }
    }

    private func signatureState() -> String? {
        states.keys.sorted().first { $0.hasPrefix("signature_") }
    }
}

struct LoadedLifePack {
    let pack: PetLifePack
    let directoryURL: URL
}

final class LocalPetStore {
    let stateURL: URL
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    init(userId: String, petId: String? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var directory = base.appendingPathComponent("PetY").appendingPathComponent(userId)
        if let petId {
            directory = directory.appendingPathComponent(petId)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        stateURL = directory.appendingPathComponent("pet-state.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load(defaultProfile: PetProfile) -> LocalPetState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? decoder.decode(LocalPetState.self, from: data) else {
            let state = LocalPetState(profile: defaultProfile, life_log: [], memories: [])
            save(state)
            return state
        }
        return state
    }

    func save(_ state: LocalPetState) {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: stateURL, options: [.atomic])
    }
}

final class LocalIdentityStore {
    let identityURL: URL
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("PetY")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        identityURL = directory.appendingPathComponent("identity.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadOrCreate() -> LocalIdentity {
        if let data = try? Data(contentsOf: identityURL),
           let identity = try? decoder.decode(LocalIdentity.self, from: data) {
            return identity
        }
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
        let identity = LocalIdentity(user_id: "user_\(suffix)", display_name: "我的桌面")
        save(identity)
        return identity
    }

    func save(_ identity: LocalIdentity) {
        guard let data = try? encoder.encode(identity) else { return }
        try? data.write(to: identityURL, options: [.atomic])
    }
}

enum PetLifePackLoader {
    static func load(for userId: String, lifePackPath: String? = nil) -> LoadedLifePack {
        let packURL = lifePackPath.map { URL(fileURLWithPath: $0) } ?? packURLForUser(userId)
        if let data = try? Data(contentsOf: packURL),
           let pack = try? JSONDecoder().decode(PetLifePack.self, from: data) {
            return LoadedLifePack(pack: pack, directoryURL: packURL.deletingLastPathComponent())
        }
        let fallback = PetLifePack(schema_version: "0.1", profile: fallbackProfile(for: userId), animation_states: nil)
        return LoadedLifePack(pack: fallback, directoryURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
    }

    private static func packURLForUser(_ userId: String) -> URL {
        let currentDirectory = FileManager.default.currentDirectoryPath
        if userId == "bob" {
            return URL(fileURLWithPath: "\(currentDirectory)/life-packs/bob-yuzu/pet-life.json")
        }
        return URL(fileURLWithPath: "\(currentDirectory)/life-packs/alice-momo/pet-life.json")
    }

    private static func fallbackProfile(for userId: String) -> PetProfile {
        if userId == "bob" {
            return PetProfile(
                pet_id: "pet_yuzu",
                owner_user_id: "bob",
                profile_version: 1,
                protocol_version: "0.1",
                name: "Yuzu",
                style: "sticker",
                preview: "#ee7b6c",
                personality_card: "外向、爱凑热闹，会把来访朋友带到屏幕边缘玩。",
                projection_capabilities: ["idle", "walk", "sleep", "react_to_click", "react_to_drag", "receive_gift"],
                interaction_capabilities: ["petting", "message", "return_home", "gift.simple", "pet_to_pet.greeting", "pet_to_pet.sit_together", "pet_to_pet.walk_together"]
            )
        }
        return PetProfile(
            pet_id: "pet_momo",
            owner_user_id: "alice",
            profile_version: 1,
            protocol_version: "0.1",
            name: "Momo",
            style: "pixel",
            preview: "#6bc6a8",
            personality_card: "慢热但好奇，喜欢被轻轻拖到新的观察点。",
            projection_capabilities: ["idle", "walk", "sleep", "react_to_click", "react_to_drag", "receive_gift"],
            interaction_capabilities: ["petting", "message", "return_home", "gift.simple", "pet_to_pet.greeting", "pet_to_pet.sit_together", "pet_to_pet.walk_together"]
        )
    }
}

struct RelayEvent: Codable {
    let id: Int
    let type: String
    let payload: JSONValue
}

enum JSONValue: Codable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct PollResponse: Codable {
    let events: [RelayEvent]
    let friends: [FriendStatus]?
}

final class RelayClient {
    let baseURL: URL
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func get<T: Decodable>(_ path: String, completion: @escaping (Result<T, Error>) -> Void) {
        request(path, method: "GET", body: Optional<Data>.none, completion: completion)
    }

    func post<Body: Encodable, T: Decodable>(_ path: String, body: Body, completion: @escaping (Result<T, Error>) -> Void) {
        do {
            let data = try encoder.encode(body)
            request(path, method: "POST", body: data, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    private func request<T: Decodable>(_ path: String, method: String, body: Data?, completion: @escaping (Result<T, Error>) -> Void) {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            completion(.failure(NSError(domain: "PetY", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL path: \(path)"])))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(NSError(domain: "PetY", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])))
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                completion(.failure(NSError(domain: "PetY", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: message])))
                return
            }
            do {
                completion(.success(try self.decoder.decode(T.self, from: data)))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

final class PetWindow: NSWindow {
    init(view: PetView, origin: CGPoint) {
        super.init(
            contentRect: NSRect(x: origin.x, y: origin.y, width: 124, height: 138),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = view
        ignoresMouseEvents = false
        makeKeyAndOrderFront(nil)
    }
}

final class AwaySignWindow: NSWindow {
    init(view: AwaySignView, origin: CGPoint) {
        super.init(
            contentRect: NSRect(x: origin.x, y: origin.y, width: 180, height: 118),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = view
        ignoresMouseEvents = false
        makeKeyAndOrderFront(nil)
    }
}

final class BallWindow: NSWindow {
    init(origin: CGPoint) {
        super.init(
            contentRect: NSRect(x: origin.x, y: origin.y, width: 34, height: 34),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = BallView(frame: NSRect(x: 0, y: 0, width: 34, height: 34))
        ignoresMouseEvents = true
        makeKeyAndOrderFront(nil)
    }
}

final class BallView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        let ball = NSBezierPath(ovalIn: NSRect(x: 5, y: 5, width: 24, height: 24))
        NSColor(red: 0.94, green: 0.14, blue: 0.17, alpha: 1).setFill()
        ball.fill()
        NSColor.black.withAlphaComponent(0.72).setStroke()
        ball.lineWidth = 2
        ball.stroke()

        let shine = NSBezierPath(ovalIn: NSRect(x: 11, y: 19, width: 6, height: 4))
        NSColor.white.withAlphaComponent(0.75).setFill()
        shine.fill()
    }
}

struct PetAction {
    let title: String
    let handler: () -> Void
}

final class InteractionMenuWindow: NSWindow {
    init(origin: CGPoint, actions: [PetAction]) {
        let buttonWidths = InteractionMenuView.buttonWidths(for: actions)
        let width = InteractionMenuView.menuWidth(for: buttonWidths)
        super.init(
            contentRect: NSRect(x: origin.x, y: origin.y, width: width, height: 48),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = InteractionMenuView(frame: NSRect(x: 0, y: 0, width: width, height: 48), actions: actions, buttonWidths: buttonWidths)
        makeKeyAndOrderFront(nil)
    }
}

final class InteractionMenuView: NSView {
    let actions: [PetAction]
    let buttonWidths: [CGFloat]

    static func buttonWidths(for actions: [PetAction]) -> [CGFloat] {
        actions.map { action in
            max(50, CGFloat(action.title.count) * 13 + 26)
        }
    }

    static func menuWidth(for buttonWidths: [CGFloat]) -> CGFloat {
        buttonWidths.reduce(16, +) + CGFloat(max(0, buttonWidths.count - 1) * 8)
    }

    init(frame frameRect: NSRect, actions: [PetAction], buttonWidths: [CGFloat]) {
        self.actions = actions
        self.buttonWidths = buttonWidths
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        var x: CGFloat = 8
        for (index, action) in actions.enumerated() {
            let button = NSButton(title: action.title, target: self, action: #selector(actionTapped(_:)))
            button.tag = index
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.96).cgColor
            button.layer?.cornerRadius = 8
            button.layer?.borderWidth = 1
            button.layer?.borderColor = NSColor.black.withAlphaComponent(0.14).cgColor
            button.font = .systemFont(ofSize: 12, weight: .semibold)
            button.contentTintColor = NSColor.black
            button.attributedTitle = NSAttributedString(
                string: action.title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: NSColor.black
                ]
            )
            let width = buttonWidths[index]
            button.frame = NSRect(x: x, y: 8, width: width, height: 30)
            addSubview(button)
            x += width + 8
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func actionTapped(_ sender: NSButton) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag].handler()
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        NSColor.white.withAlphaComponent(0.94).setFill()
        background.fill()
        NSColor.black.withAlphaComponent(0.12).setStroke()
        background.lineWidth = 1
        background.stroke()
    }
}

final class AwaySignView: NSView {
    let message: String
    let onClick: () -> Void
    var dragStartScreen: CGPoint?
    var dragStartFrame: NSRect?
    var didMove = false

    init(message: String, onClick: @escaping () -> Void) {
        self.message = message
        self.onClick = onClick
        super.init(frame: NSRect(x: 0, y: 0, width: 180, height: 118))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        dragStartScreen = NSEvent.mouseLocation
        dragStartFrame = window?.frame
        didMove = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let start = dragStartScreen, let frame = dragStartFrame else { return }
        let current = NSEvent.mouseLocation
        if abs(current.x - start.x) + abs(current.y - start.y) > 3 { didMove = true }
        window.setFrameOrigin(NSPoint(x: frame.origin.x + current.x - start.x, y: frame.origin.y + current.y - start.y))
    }

    override func mouseUp(with event: NSEvent) {
        if !didMove {
            onClick()
        }
        dragStartScreen = nil
        dragStartFrame = nil
        didMove = false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let post = NSBezierPath(roundedRect: NSRect(x: 84, y: 4, width: 12, height: 28), xRadius: 3, yRadius: 3)
        NSColor(red: 0.56, green: 0.39, blue: 0.23, alpha: 1).setFill()
        post.fill()

        let board = NSBezierPath(roundedRect: NSRect(x: 12, y: 28, width: 156, height: 74), xRadius: 10, yRadius: 10)
        NSColor(red: 1.0, green: 0.94, blue: 0.72, alpha: 0.98).setFill()
        board.fill()
        NSColor.black.withAlphaComponent(0.72).setStroke()
        board.lineWidth = 2.5
        board.stroke()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.black
        ]
        "出门中".draw(at: NSPoint(x: 66, y: 76), withAttributes: titleAttrs)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        NSString(string: message).draw(in: NSRect(x: 24, y: 46, width: 132, height: 28), withAttributes: attrs)

        let hintAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.black.withAlphaComponent(0.68),
            .paragraphStyle: paragraph
        ]
        "点一下喊回家".draw(in: NSRect(x: 24, y: 32, width: 132, height: 12), withAttributes: hintAttrs)
    }
}

final class PetView: NSView {
    let profile: PetProfile
    let isVisitor: Bool
    let animationStates: [String: AnimationState]
    let assetBaseURL: URL?
    let onClick: () -> Void
    let onAlternateClick: (() -> Void)?
    let onDragEnd: (_ from: CGPoint, _ to: CGPoint, _ durationMs: Int) -> Void
    var activeAnimationName = "idle"
    var animationImage: NSImage?
    var currentFrame = 0
    var renderScale: CGFloat = 1.0
    var facingLeft = false
    var frameTimer: Timer?
    var scaleTimer: Timer?
    var returnToIdleTimer: Timer?
    var bubble: String?
    var bubbleTimer: Timer?
    var dragStartScreen: CGPoint?
    var dragStartFrame: NSRect?
    var dragStartedAt = Date()
    var didMove = false

    init(
        profile: PetProfile,
        isVisitor: Bool,
        animationStates: [String: AnimationState]? = nil,
        assetBaseURL: URL? = nil,
        onClick: @escaping () -> Void,
        onAlternateClick: (() -> Void)? = nil,
        onDragEnd: @escaping (_ from: CGPoint, _ to: CGPoint, _ durationMs: Int) -> Void
    ) {
        self.profile = profile
        self.isVisitor = isVisitor
        self.animationStates = animationStates ?? [:]
        self.assetBaseURL = assetBaseURL
        self.onClick = onClick
        self.onAlternateClick = onAlternateClick
        self.onDragEnd = onDragEnd
        super.init(frame: NSRect(x: 0, y: 0, width: 124, height: 138))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        play("idle")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        frameTimer?.invalidate()
        scaleTimer?.invalidate()
        returnToIdleTimer?.invalidate()
        bubbleTimer?.invalidate()
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.type == .rightMouseDown || event.modifierFlags.contains(.control) {
            onAlternateClick?()
            return
        }
        dragStartScreen = NSEvent.mouseLocation
        dragStartFrame = window?.frame
        dragStartedAt = Date()
        didMove = false
    }

    override func rightMouseDown(with event: NSEvent) {
        onAlternateClick?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let start = dragStartScreen, let frame = dragStartFrame else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - start.x
        let dy = current.y - start.y
        if abs(dx) + abs(dy) > 3 { didMove = true }
        window.setFrameOrigin(NSPoint(x: frame.origin.x + dx, y: frame.origin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        guard let window, let frame = dragStartFrame else {
            onClick()
            return
        }
        if didMove {
            let duration = Int(Date().timeIntervalSince(dragStartedAt) * 1000)
            onDragEnd(frame.origin, window.frame.origin, duration)
        } else {
            onClick()
        }
        dragStartScreen = nil
        dragStartFrame = nil
    }

    func say(_ text: String) {
        bubble = text
        needsDisplay = true
        bubbleTimer?.invalidate()
        bubbleTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { [weak self] _ in
            self?.bubble = nil
            self?.needsDisplay = true
        }
    }

    func play(_ stateName: String, returnToIdleAfter delay: TimeInterval? = nil) {
        guard animationStates[stateName] != nil else { return }
        activeAnimationName = stateName
        loadAnimationIfAvailable()

        returnToIdleTimer?.invalidate()
        if let delay {
            returnToIdleTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.play("idle")
            }
        }
    }

    func setRenderScale(_ scale: CGFloat) {
        renderScale = min(max(scale, 0.45), 1.1)
        needsDisplay = true
    }

    func faceMovement(from start: CGPoint, to end: CGPoint) {
        guard abs(end.x - start.x) > 2 else { return }
        facingLeft = end.x < start.x
        needsDisplay = true
    }

    func animateRenderScale(to targetScale: CGFloat, duration: TimeInterval) {
        scaleTimer?.invalidate()
        let startScale = renderScale
        let endScale = min(max(targetScale, 0.45), 1.1)
        let startedAt = Date()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let progress = min(Date().timeIntervalSince(startedAt) / duration, 1.0)
            let eased = progress * progress * (3 - 2 * progress)
            self.renderScale = startScale + (endScale - startScale) * CGFloat(eased)
            self.needsDisplay = true

            if progress >= 1.0 {
                self.renderScale = endScale
                self.needsDisplay = true
                timer.invalidate()
                self.scaleTimer = nil
            }
        }
        scaleTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func loadAnimationIfAvailable() {
        frameTimer?.invalidate()
        frameTimer = nil
        currentFrame = 0
        animationImage = nil

        guard let animationState = animationStates[activeAnimationName],
              animationState.format == "sprite_sheet_png",
              let assetBaseURL else { return }

        let assetURL = assetBaseURL.appendingPathComponent(animationState.asset)
        guard FileManager.default.fileExists(atPath: assetURL.path),
              let image = NSImage(contentsOf: assetURL),
              animationState.frames > 0,
              animationState.frame_width > 0,
              animationState.frame_height > 0,
              animationState.fps > 0 else { return }

        animationImage = image
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(animationState.fps), repeats: true) { [weak self] _ in
            guard let self, let animationState = self.animationStates[self.activeAnimationName] else { return }
            if animationState.loop {
                self.currentFrame = (self.currentFrame + 1) % animationState.frames
            } else {
                self.currentFrame = min(self.currentFrame + 1, animationState.frames - 1)
            }
            self.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        if let bubble {
            drawBubble(bubble)
        }

        if drawSpriteFrameIfAvailable() {
            return
        }

        let color = NSColor(hex: profile.preview) ?? (isVisitor ? NSColor.systemCoral : NSColor.systemMint)
        let body = NSRect(x: 24, y: 28, width: 76, height: 62)
        drawEar(NSRect(x: 33, y: 80, width: 22, height: 30), rotation: -16, color: color)
        drawEar(NSRect(x: 69, y: 80, width: 22, height: 30), rotation: 16, color: color)

        let path = NSBezierPath(roundedRect: body, xRadius: 22, yRadius: 22)
        color.setFill()
        path.fill()
        NSColor.black.setStroke()
        path.lineWidth = 3
        path.stroke()

        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 46, y: 58, width: 8, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: 72, y: 58, width: 8, height: 10)).fill()

        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: 57, y: 48))
        mouth.curve(to: NSPoint(x: 67, y: 48), controlPoint1: NSPoint(x: 60, y: 43), controlPoint2: NSPoint(x: 64, y: 43))
        mouth.lineWidth = 2.5
        mouth.stroke()

    }

    private func drawSpriteFrameIfAvailable() -> Bool {
        guard let animationState = animationStates[activeAnimationName], let animationImage else { return false }
        let frameWidth = CGFloat(animationState.frame_width)
        let frameHeight = CGFloat(animationState.frame_height)
        let source = NSRect(
            x: CGFloat(currentFrame) * frameWidth,
            y: 0,
            width: frameWidth,
            height: frameHeight
        )
        let spriteSize = 64 * renderScale
        let target = NSRect(
            x: 30 + (64 - spriteSize) / 2,
            y: 28 + (64 - spriteSize) / 2,
            width: spriteSize,
            height: spriteSize
        )
        if shouldMirrorSprite(animationState) {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: target.midX, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.translateX(by: -target.midX, yBy: 0)
            transform.concat()
            animationImage.draw(in: target, from: source, operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.none])
            NSGraphicsContext.restoreGraphicsState()
        } else {
            animationImage.draw(in: target, from: source, operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.none])
        }
        return true
    }

    private func shouldMirrorSprite(_ animationState: AnimationState) -> Bool {
        switch animationState.default_facing?.lowercased() ?? "right" {
        case "none":
            return false
        case "left":
            return !facingLeft
        default:
            return facingLeft
        }
    }

    private func drawEar(_ rect: NSRect, rotation: CGFloat, color: NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        transform.rotate(byDegrees: rotation)
        transform.translateX(by: -rect.midX, yBy: -rect.midY)
        transform.concat()

        let path = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 14)
        color.setFill()
        path.fill()
        NSColor.black.setStroke()
        path.lineWidth = 3
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBubble(_ text: String) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        let limit = NSSize(width: 112, height: 44)
        let rect = NSString(string: text).boundingRect(
            with: limit,
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
        let bubbleRect = NSRect(x: 6, y: 96, width: 112, height: Swift.max(28, rect.height + 12))
        let path = NSBezierPath(roundedRect: bubbleRect, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.96).setFill()
        path.fill()
        NSColor.black.withAlphaComponent(0.16).setStroke()
        path.lineWidth = 1
        path.stroke()
        NSString(string: text).draw(in: bubbleRect.insetBy(dx: 8, dy: 6), withAttributes: attributes)
    }
}

final class ControlPanel: NSObject {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var title = "Pet Y Runtime"
    var status = "准备中"
    var friends: [FriendStatus] = []
    var hasVisitor = false
    var hasAwayPet = false
    var recentLogs: [String] = []
    var onSendVisit: ((String) -> Void)?
    var onReturn: (() -> Void)?
    var onRecallPet: (() -> Void)?
    var onShareInvite: (() -> Void)?
    var onAcceptInvite: (() -> Void)?

    override init() {
        super.init()
        statusItem.button?.title = "Pet Y"
        statusItem.button?.toolTip = "Pet Y Runtime \(PetYRuntimeVersion)"
        rebuildMenu()
    }

    func configure(title: String, friends: [FriendStatus]) {
        self.title = title
        self.friends = friends
        rebuildMenu()
    }

    func setStatus(_ text: String) {
        status = text
        rebuildMenu()
    }

    func setHasVisitor(_ value: Bool) {
        hasVisitor = value
        rebuildMenu()
    }

    func setHasAwayPet(_ value: Bool) {
        hasAwayPet = value
        rebuildMenu()
    }

    func appendLog(_ text: String) {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        recentLogs.insert("[\(stamp)] \(text)", at: 0)
        if recentLogs.count > 8 {
            recentLogs.removeLast(recentLogs.count - 8)
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "\(title) · \(PetYRuntimeVersion)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let statusMenuItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let friendsItem = NSMenuItem(title: "好友", action: nil, keyEquivalent: "")
        let friendsMenu = NSMenu()
        friendsMenu.addItem(actionItem(title: "邀请好友一起玩", action: #selector(shareInviteTapped)))
        friendsMenu.addItem(actionItem(title: "输入好友邀请口令", action: #selector(acceptInviteTapped)))
        friendsMenu.addItem(.separator())
        if friends.isEmpty {
            let item = NSMenuItem(title: "暂无好友", action: nil, keyEquivalent: "")
            item.isEnabled = false
            friendsMenu.addItem(item)
        } else {
            for friend in friends {
                let item = actionItem(title: "\(friend.display_name)\(friend.online ? " 串门" : " 不在家")", action: #selector(sendTapped(_:)))
                item.representedObject = friend.user_id
                item.isEnabled = friend.online
                friendsMenu.addItem(item)
            }
        }
        if hasAwayPet || hasVisitor {
            friendsMenu.addItem(.separator())
        }
        if hasAwayPet {
            friendsMenu.addItem(actionItem(title: "喊我的宠物回来", action: #selector(recallPetTapped)))
        }
        if hasVisitor {
            friendsMenu.addItem(actionItem(title: "送小客人回家", action: #selector(returnTapped)))
        }
        friendsItem.submenu = friendsMenu
        menu.addItem(friendsItem)
        menu.addItem(.separator())

        if !recentLogs.isEmpty {
            let logsItem = NSMenuItem(title: "最近日志", action: nil, keyEquivalent: "")
            let logsMenu = NSMenu()
            for log in recentLogs {
                let item = NSMenuItem(title: log, action: nil, keyEquivalent: "")
                item.isEnabled = false
                logsMenu.addItem(item)
            }
            logsItem.submenu = logsMenu
            menu.addItem(logsItem)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "退出 Pet Y", action: #selector(quitTapped), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func sendTapped(_ sender: NSMenuItem) { onSendVisit?(sender.representedObject as? String ?? "") }
    @objc private func returnTapped() { onReturn?() }
    @objc private func recallPetTapped() { onRecallPet?() }
    @objc private func shareInviteTapped() { onShareInvite?() }
    @objc private func acceptInviteTapped() { onAcceptInvite?() }
    @objc private func quitTapped() { NSApp.terminate(nil) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let userId: String
    let identity: LocalIdentity
    let relay: RelayClient
    let store: LocalPetStore
    let lifePack: LoadedLifePack
    let animationResolver: AnimationResolver
    var localState: LocalPetState
    var localPet: PetProfile { localState.profile }
    var panel: ControlPanel!
    var localWindow: PetWindow?
    var awaySignWindow: AwaySignWindow?
    var visitors: [String: VisitorProjection] = [:]
    let maxVisitors = 5
    var ballWindow: BallWindow?
    var interactionMenuWindow: InteractionMenuWindow?
    weak var interactionMenuAnchorWindow: PetWindow?
    var interactionMenuFollowTimer: Timer?
    var outgoingVisit: VisitSession?
    var outgoingVisitTargetName: String?
    var friends: [FriendStatus] = []
    var lastEventId = 0
    var pollTimer: Timer?
    var lastFriendOnlineNotifiedAt: [String: Date] = [:]
    var localSleepTimer: Timer?
    var localRoamTimer: Timer?
    var localAnimationTimer: Timer?
    var visitorPairTimer: Timer?

    override init() {
        let args = CommandLine.arguments
        let commandUser = AppDelegate.value(after: "--user", in: args)
        let localIdentity = LocalIdentityStore().loadOrCreate()
        let user = commandUser ?? localIdentity.user_id
        let relayURL = AppDelegate.value(after: "--relay", in: args) ?? "http://127.0.0.1:8787"
        let lifePackPath = AppDelegate.value(after: "--life-pack", in: args)
        userId = user
        identity = commandUser == nil ? localIdentity : LocalIdentity(user_id: user, display_name: user)
        relay = RelayClient(baseURL: URL(string: relayURL)!)
        lifePack = PetLifePackLoader.load(for: user, lifePackPath: lifePackPath)
        animationResolver = AnimationResolver(states: lifePack.pack.animation_states ?? [:])
        let runtimeProfile = lifePack.pack.profile.owned(by: user)
        store = LocalPetStore(userId: user, petId: lifePackPath == nil ? nil : runtimeProfile.pet_id)
        localState = store.load(defaultProfile: runtimeProfile)
        localState.profile = runtimeProfile
        store.save(localState)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = ControlPanel()
        panel.onSendVisit = { [weak self] friend in self?.sendVisit(to: friend) }
        panel.onReturn = { [weak self] in self?.returnVisitor() }
        panel.onRecallPet = { [weak self] in self?.recallLocalPet() }
        panel.onShareInvite = { [weak self] in self?.shareInvite() }
        panel.onAcceptInvite = { [weak self] in self?.promptForInvite() }

        restorePersistentLogToPanel()
        createLocalPet()
        bootstrap()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func createLocalPet() {
        guard localWindow == nil else { return }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let view = PetView(
            profile: localPet,
            isVisitor: false,
            animationStates: lifePack.pack.animation_states,
            assetBaseURL: lifePack.directoryURL,
            onClick: { [weak self] in
                self?.showLocalInteractionMenu()
            },
            onAlternateClick: { [weak self] in
                self?.showLocalInteractionMenu()
            },
            onDragEnd: { [weak self] _, _, _ in
                self?.closeInteractionMenu()
                self?.playLocal(.move, returnToIdleAfter: 1.4)
                self?.sayLocal("这里视野不错。")
                self?.remember("\(self?.localPet.name ?? "宠物") 被拖到了新的位置。")
                self?.scheduleLocalSleep()
                self?.scheduleLocalRoam()
            }
        )
        localWindow = PetWindow(view: view, origin: CGPoint(x: screen.maxX - 180, y: screen.minY + 140))
        scheduleLocalSleep()
        scheduleLocalRoam()
    }

    private func showAwaySign(to friend: String) {
        let origin = localWindow?.frame.origin ?? awaySignWindow?.frame.origin ?? CGPoint(x: 900, y: 140)
        localSleepTimer?.invalidate()
        localRoamTimer?.invalidate()
        localAnimationTimer?.invalidate()
        closeInteractionMenu()
        ballWindow?.close()
        ballWindow = nil
        localWindow?.close()
        localWindow = nil
        awaySignWindow?.close()
        let sign = AwaySignView(message: "我去 \(friend) 那儿") { [weak self] in
            self?.recallLocalPet()
        }
        awaySignWindow = AwaySignWindow(view: sign, origin: origin)
        panel?.setHasAwayPet(true)
    }

    private func restoreLocalPet() {
        let origin = awaySignWindow?.frame.origin
        awaySignWindow?.close()
        awaySignWindow = nil
        outgoingVisit = nil
        outgoingVisitTargetName = nil
        panel?.setHasAwayPet(false)
        guard localWindow == nil else { return }

        let view = PetView(
            profile: localPet,
            isVisitor: false,
            animationStates: lifePack.pack.animation_states,
            assetBaseURL: lifePack.directoryURL,
            onClick: { [weak self] in
                self?.showLocalInteractionMenu()
            },
            onAlternateClick: { [weak self] in
                self?.showLocalInteractionMenu()
            },
            onDragEnd: { [weak self] _, _, _ in
                self?.closeInteractionMenu()
                self?.playLocal(.move, returnToIdleAfter: 1.4)
                self?.sayLocal("这里视野不错。")
                self?.remember("\(self?.localPet.name ?? "宠物") 被拖到了新的位置。")
                self?.scheduleLocalSleep()
                self?.scheduleLocalRoam()
            }
        )
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        localWindow = PetWindow(view: view, origin: origin ?? CGPoint(x: screen.maxX - 180, y: screen.minY + 140))
        playLocal(.returnWithGift, returnToIdleAfter: 2.8)
        scheduleLocalSleep()
        scheduleLocalRoam()
    }

    private func bootstrap() {
        relay.get("api/bootstrap?user=\(userId)") { [weak self] (result: Result<BootstrapResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    let friends = response.friends ?? response.friend_ids.map {
                        FriendStatus(user_id: $0, display_name: $0, pet_id: "", online: false, last_seen_at: nil)
                    }
                    self?.friends = friends
                    self?.panel.configure(title: "\(self?.localPet.name ?? response.user.display_name) Runtime", friends: friends)
                    self?.panel.setStatus("已连接 Relay")
                    self?.log("桌面 Runtime \(PetYRuntimeVersion) 已启动。")
                    self?.registerProfile()
                    self?.startPolling()
                case .failure(let error):
                    self?.panel.setStatus("Relay 未连接：\(error.localizedDescription)")
                    self?.log("连接 Relay 失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func registerProfile() {
        relay.post("api/profiles", body: profileRegistration()) { [weak self] (result: Result<ProfileResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.log("已注册宠物名片：\(response.profile.name) v\(response.profile.profile_version)")
                case .failure(let error):
                    self?.log("注册宠物名片失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func profileRegistration() -> PetProfileRegistration {
        PetProfileRegistration(
            pet_id: localPet.pet_id,
            owner_user_id: localPet.owner_user_id,
            profile_version: localPet.profile_version,
            protocol_version: localPet.protocol_version,
            name: localPet.name,
            style: localPet.style,
            preview: localPet.preview,
            personality_card: localPet.personality_card,
            projection_capabilities: localPet.projection_capabilities,
            interaction_capabilities: localPet.interaction_capabilities,
            animation_states: lifePack.pack.animation_states,
            asset_blobs: projectionAssetBlobs()
        )
    }

    private func projectionAssetBlobs() -> [String: String] {
        guard let states = lifePack.pack.animation_states else { return [:] }
        var blobs: [String: String] = [:]
        for state in states.values {
            guard state.format == "sprite_sheet_png", blobs[state.asset] == nil else { continue }
            let assetURL = lifePack.directoryURL.appendingPathComponent(state.asset)
            guard let data = try? Data(contentsOf: assetURL) else { continue }
            blobs[state.asset] = data.base64EncodedString()
        }
        return blobs
    }

    private func shareInvite() {
        let body = InviteRequest(user_id: userId, display_name: localPet.name)
        relay.post("api/invites", body: body) { [weak self] (result: Result<InviteResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    guard let self else { return }
                    let text = self.friendInviteText(token: response.invite.token)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    self.panel.setStatus("邀请文案已复制")
                    self.sayLocal("邀请已经复制好了，发给朋友吧。")
                    self.log("已复制好友邀请。")
                case .failure(let error):
                    self?.sayLocal("邀请生成失败了。")
                    self?.log("邀请生成失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func friendInviteText(token: String) -> String {
        let relayURL = relay.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return """
        我在玩 Pet Y，一个可以让桌面宠物去朋友电脑上串门的小实验。

        先提醒一下：当前 Pet Y 桌面宠物暂时只支持 Mac / macOS。Windows 和 Linux 现在还不能运行桌面宠物 Runtime。

        我的宠物叫 \(localPet.name)，它想认识你未来创建的宠物。

        公开说明在这里：
        https://github.com/xllinbupt/pet-y-public

        你可以把下面这段话发给你的 Agent。优先用 Codex，因为它可以直接帮你生成宠物图像：

        请先确认我正在使用 Mac 电脑。然后根据 https://github.com/xllinbupt/pet-y-public 的说明，安装和准备 Pet Y 项目，并从公开 Release 下载最新的预编译 Pet Y Runtime。这个过程可能需要一点时间，不需要让我处理 Xcode、Swift 或 macOS SDK 编译问题。启动后菜单顶部应该能看到 Runtime 版本号。

        然后请访谈我，帮我创建一只属于我自己的桌面宠物。请问我宠物的名字、风格、外形、性格、动作、行为和它喜欢怎样陪伴我，不要直接运行邀请人的小狗。

        请先生成并确认宠物形象，让它在本地桌面成功运行；运行成功后，再帮我绑定好友关系，并连接这个 Relay：
        \(relayURL)

        绑定好友时，请使用这段好友邀请口令：

        \(token)

        绑定完成后请重启一次 Pet Y Runtime。邀请我的人会收到好友添加成功提醒，然后我们就可以互相串门了。
        """
    }

    private func promptForInvite() {
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "person.crop.circle.badge.plus", accessibilityDescription: "添加好友")
        alert.messageText = "添加好友"
        alert.informativeText = "粘贴朋友分享给你的邀请口令。"
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.placeholderString = "好友邀请口令"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        acceptInvite(token: input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func acceptInvite(token: String) {
        guard !token.isEmpty else {
            sayLocal("邀请口令是空的。")
            return
        }
        let body = AcceptInviteRequest(user_id: userId, token: token)
        relay.post("api/friends/accept", body: body) { [weak self] (result: Result<AcceptInviteResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.friends = response.friends
                    self?.panel.configure(title: self?.panel.title ?? "Pet Y Runtime", friends: response.friends)
                    self?.sayLocal("好友加好了。")
                    self?.log("已添加好友。")
                case .failure(let error):
                    self?.sayLocal("加好友失败了。")
                    self?.log("加好友失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func sendVisit(to friendUserId: String, displayName: String? = nil) {
        guard !friendUserId.isEmpty else {
            sayLocal("我还不知道要去谁那里。")
            log("串门失败：没有选择好友。")
            return
        }
        let friendName = displayName ?? friends.first(where: { $0.user_id == friendUserId })?.display_name ?? friendUserId
        closeInteractionMenu()
        sayLocal("我准备去 \(friendName) 那儿。")
        panel.setStatus("\(localPet.name) 准备出门")
        log("正在发起串门：\(friendName)")
        let body = VisitRequest(
            pet_id: localPet.pet_id,
            owner_user_id: userId,
            host_user_id: friendUserId,
            departure_context: ["mood": "curious", "intent": "play"]
        )
        relay.post("api/visits", body: body) { [weak self] (result: Result<VisitResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.outgoingVisit = response.visit
                    self?.outgoingVisitTargetName = friendName
                    if response.visit.status == "active" {
                        self?.panel.setStatus("\(self?.localPet.name ?? "宠物") 已出门")
                        self?.sayLocal("对方开门啦，我出门了。")
                        self?.showAwaySign(to: friendName)
                    } else {
                        self?.panel.setStatus("正在等 \(friendName) 开门")
                        self?.sayLocal("我先敲敲门。")
                    }
                    self?.log("创建串门请求：\(response.visit.visit_id)")
                case .failure(let error):
                    let message = self?.visitFailureMessage(error) ?? "串门失败了。"
                    self?.panel.setStatus(message)
                    self?.sayLocal(message)
                    self?.log("发起串门失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func visitFailureMessage(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("Host Runtime is offline") {
            return "对方现在不在家。"
        }
        if text.contains("not friends") {
            return "还不是好友，不能串门。"
        }
        if text.contains("allow auto visits") {
            return "对方现在不接待来访。"
        }
        if text.contains("not found") {
            return "宠物名片还没准备好。"
        }
        return "串门失败了，等会儿再试。"
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.pollEvents()
        }
        pollEvents()
    }

    private func pollEvents() {
        relay.get("api/events/poll?user=\(userId)&after=\(lastEventId)") { [weak self] (result: Result<PollResponse, Error>) in
            DispatchQueue.main.async {
                guard let self else { return }
                if case .success(let response) = result {
                    if let friends = response.friends {
                        self.notifyNewlyOnlineFriends(friends)
                        self.friends = friends
                        self.panel.configure(title: self.panel.title, friends: friends)
                    }
                    for event in response.events {
                        self.lastEventId = max(self.lastEventId, event.id)
                        self.handle(event)
                    }
                }
            }
        }
    }

    private func notifyNewlyOnlineFriends(_ nextFriends: [FriendStatus]) {
        let previous = Dictionary(uniqueKeysWithValues: friends.map { ($0.user_id, $0.online) })
        for friend in nextFriends {
            guard friend.online, previous[friend.user_id] == false else { continue }
            let lastNotified = lastFriendOnlineNotifiedAt[friend.user_id] ?? .distantPast
            guard Date().timeIntervalSince(lastNotified) > 600 else { continue }
            lastFriendOnlineNotifiedAt[friend.user_id] = Date()
            sayLocal("\(friend.display_name) 在家了，可以去串门。")
            log("好友上线：\(friend.display_name)")
        }
    }

    private func handle(_ event: RelayEvent) {
        let decoder = JSONDecoder()
        guard let data = try? JSONEncoder().encode(event.payload) else { return }

        switch event.type {
        case "profile_registered":
            break
        case "visit_requested":
            if let payload = try? decoder.decode(VisitStartedPayload.self, from: data) {
                answerVisitRequest(payload)
            }
        case "visit_started":
            if let payload = try? decoder.decode(VisitStartedPayload.self, from: data) {
                showVisitor(payload)
            }
        case "visit_status":
            if let visit = try? decoder.decode(VisitSession.self, from: data),
               visit.owner_user_id == userId {
                handleOutgoingVisitStatus(visit)
            }
        case "friend_added":
            if let payload = try? decoder.decode(FriendAddedPayload.self, from: data),
               let friend = payload.friend {
                friends.removeAll { $0.user_id == friend.user_id }
                friends.append(friend)
                panel.configure(title: panel.title, friends: friends)
                panel.setStatus("\(friend.display_name) 加好了")
                sayLocal("\(friend.display_name) 来啦，我们已经是好友了。")
                log("新好友已添加：\(friend.display_name)")
            }
        case "interaction_event":
            if let interaction = try? decoder.decode(InteractionEvent.self, from: data),
               interaction.type == "message",
               let text = interaction.data?["text"] {
                remember("有人给 \(localPet.name) 留言：\(text)")
                log("收到留言：\(text)")
            } else {
                log("收到远端互动事件：\(event.type)")
            }
        case "visit_ended":
            if let payload = try? decoder.decode(VisitEndedPayload.self, from: data) {
                removeVisitor(visitId: payload.visit_id)
            } else {
                removeAllVisitors()
            }
            log("小客人已经回家了。")
        case "memory_receipt":
            if let receipt = try? decoder.decode(MemoryReceipt.self, from: data) {
                panel.setStatus("\(localPet.name) 回家了")
                restoreLocalPet()
                sayLocal(receipt.pet_voice)
                remember(receipt.life_log_entry)
                remember(receipt.pet_voice)
                rememberMemory(receipt)
                showReturnedMessagesIfNeeded(receipt)
            }
        default:
            break
        }
    }

    private func showVisitor(_ payload: VisitStartedPayload) {
        removeVisitor(visitId: payload.visit.visit_id)
        panel.setHasVisitor(true)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let visitId = payload.visit.visit_id
        let view = PetView(
            profile: payload.profile,
            isVisitor: true,
            animationStates: payload.animation_states,
            assetBaseURL: materializeVisitorAssets(payload),
            onClick: { [weak self] in
                self?.showVisitorInteractionMenu(visitId: visitId)
            },
            onAlternateClick: { [weak self] in
                self?.showVisitorInteractionMenu(visitId: visitId)
            },
            onDragEnd: { [weak self] from, to, duration in
                self?.visitorView(visitId: visitId)?.say("这个角落也不错。")
                self?.recordVisitEvent(
                    visitId: visitId,
                    type: "dragged",
                    data: [
                        "from_x": "\(Int(from.x))",
                        "from_y": "\(Int(from.y))",
                        "to_x": "\(Int(to.x))",
                        "to_y": "\(Int(to.y))",
                        "duration_ms": "\(duration)"
                    ]
                )
                self?.scheduleVisitorRoam(visitId: visitId)
            }
        )
        let index = visitors.count
        let origin = CGPoint(
            x: screen.maxX - 320 - CGFloat(index % 3) * 118,
            y: screen.minY + 260 + CGFloat(index / 3) * 118
        )
        let window = PetWindow(view: view, origin: origin)
        visitors[visitId] = VisitorProjection(visit: payload.visit, profile: payload.profile, window: window)
        view.say("我是 \(payload.profile.name)，右键可以投喂我。")
        remember("\(payload.profile.name) 来你的桌面串门了。")
        scheduleVisitorRoam(visitId: visitId)
        scheduleVisitorPairPlay()
    }

    private func handleOutgoingVisitStatus(_ visit: VisitSession) {
        switch visit.status {
        case "pending":
            outgoingVisit = visit
            panel.setStatus("正在等对方开门")
        case "active":
            let wasActive = outgoingVisit?.status == "active"
            outgoingVisit = visit
            let friendName = outgoingVisitTargetName ?? friends.first(where: { $0.user_id == visit.host_user_id })?.display_name ?? visit.host_user_id
            panel.setHasAwayPet(true)
            panel.setStatus("\(localPet.name) 已出门")
            if !wasActive {
                sayLocal("对方开门啦，我出门了。")
                showAwaySign(to: friendName)
            }
        case "declined":
            outgoingVisit = nil
            outgoingVisitTargetName = nil
            panel.setHasAwayPet(false)
            panel.setStatus("对方这次没开门")
            sayLocal("对方这次没开门，我留在家里。")
            log("串门请求被拒绝。")
        case "cancelled", "failed":
            outgoingVisit = nil
            outgoingVisitTargetName = nil
            panel.setHasAwayPet(false)
            panel.setStatus("串门取消了")
            sayLocal("这次先不出门了。")
            log("串门请求已取消。")
        default:
            break
        }
    }

    private func answerVisitRequest(_ payload: VisitStartedPayload) {
        if visitors.count >= maxVisitors {
            let body = VisitDecisionRequest(user_id: userId, action: "decline")
            relay.post("api/visits/\(payload.visit.visit_id)/decision", body: body) { [weak self] (_: Result<VisitDecisionResponse, Error>) in
                DispatchQueue.main.async {
                    self?.log("桌面来访宠物已满，已拒绝 \(payload.profile.name) 来串门。")
                }
            }
            return
        }
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "door.left.hand.open", accessibilityDescription: "敲门")
        alert.messageText = "\(payload.profile.name) 在敲门"
        alert.informativeText = "它想来你的桌面玩一会儿。当前可同时接待 \(maxVisitors) 只来访宠物。"
        alert.addButton(withTitle: "让它进来")
        alert.addButton(withTitle: "这次不了")
        let accepted = alert.runModal() == .alertFirstButtonReturn
        let body = VisitDecisionRequest(user_id: userId, action: accepted ? "accept" : "decline")
        relay.post("api/visits/\(payload.visit.visit_id)/decision", body: body) { [weak self] (result: Result<VisitDecisionResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.log(accepted ? "已同意 \(payload.profile.name) 来串门。" : "已拒绝 \(payload.profile.name) 来串门。")
                case .failure(let error):
                    self?.log("回应敲门失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func materializeVisitorAssets(_ payload: VisitStartedPayload) -> URL? {
        guard let assetBlobs = payload.asset_blobs, !assetBlobs.isEmpty else { return nil }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PetY")
            .appendingPathComponent("visitor-assets")
            .appendingPathComponent(payload.profile.pet_id)
        try? FileManager.default.removeItem(at: base)

        for (assetPath, encoded) in assetBlobs {
            guard let data = Data(base64Encoded: encoded) else { continue }
            let fileURL = base.appendingPathComponent(assetPath)
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: [.atomic])
        }
        return base
    }

    private func visitorView(visitId: String) -> PetView? {
        visitors[visitId]?.window.contentView as? PetView
    }

    private func firstVisitorId() -> String? {
        visitors.keys.sorted().first
    }

    private func recordVisitEvent(visitId: String, type: String, data: [String: String]) {
        guard let visit = visitors[visitId]?.visit else {
            log("现在没有来串门的小客人。")
            return
        }
        let body = InteractionRequest(
            type: type,
            data: data,
            actor: ["type": "host_user", "user_id": userId]
        )
        relay.post("api/visits/\(visit.visit_id)/events", body: body) { [weak self] (result: Result<InteractionResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response): self?.log("记录互动事件：\(response.event.type)")
                case .failure(let error):
                    if self?.isLostVisitError(error) == true {
                        self?.handleLostVisitorVisit(visitId: visit.visit_id)
                    } else {
                        self?.log("互动事件上传失败：\(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func recordVisitEvent(type: String, data: [String: String]) {
        guard let visitId = firstVisitorId() else {
            log("现在没有来串门的小客人。")
            return
        }
        recordVisitEvent(visitId: visitId, type: type, data: data)
    }

    private func isLostVisitError(_ error: Error) -> Bool {
        let nsError = error as NSError
        let text = error.localizedDescription
        return (nsError.code == 404 && text.contains("Visit not found"))
            || (nsError.code == 409 && text.contains("Visit is not active"))
    }

    private func handleLostVisitorVisit(visitId: String) {
        guard visitors[visitId] != nil else { return }
        log("来访会话已经失效，已清理本地来访宠物。")
        removeVisitor(visitId: visitId)
    }

    private func handleLostOutgoingVisit() {
        guard outgoingVisit != nil || awaySignWindow != nil else { return }
        log("出门会话已经失效，已让本地宠物回家。")
        restoreLocalPet()
        panel.setStatus("\(localPet.name) 回家了")
    }

    private func feedVisitor(visitId: String) {
        guard let visitor = visitors[visitId] else {
            log("现在没有来串门的小客人。")
            return
        }
        visitor.roamTimer?.invalidate()
        (visitor.window.contentView as? PetView)?.say("我会把草莓带回去。")
        recordVisitEvent(visitId: visitId, type: "fed", data: ["item": "草莓"])
        scheduleVisitorRoam(visitId: visitId)
    }

    private func returnVisitor(visitId: String? = nil) {
        guard let resolvedVisitId = visitId ?? firstVisitorId(),
              let visit = visitors[resolvedVisitId]?.visit else {
            log("现在没有需要送回家的小客人。")
            return
        }
        let body = EndVisitRequest(reason: "host_requested_return", actor: ["type": "host_user", "user_id": userId])
        relay.post("api/visits/\(visit.visit_id)/end", body: body) { [weak self] (result: Result<EndVisitResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.removeVisitor(visitId: resolvedVisitId)
                    self?.log("已送小客人回家。")
                case .failure(let error):
                    if self?.isLostVisitError(error) == true {
                        self?.handleLostVisitorVisit(visitId: resolvedVisitId)
                    } else {
                        self?.log("送小客人回家失败：\(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func recallLocalPet() {
        guard let visit = outgoingVisit else {
            sayLocal("我已经在家啦。")
            log("当前没有出门中的宠物。")
            panel.setHasAwayPet(false)
            return
        }
        let body = EndVisitRequest(reason: "owner_requested_return", actor: ["type": "owner_user", "user_id": userId])
        relay.post("api/visits/\(visit.visit_id)/end", body: body) { [weak self] (result: Result<EndVisitResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if visit.status == "pending" {
                        self?.outgoingVisit = nil
                        self?.outgoingVisitTargetName = nil
                        self?.panel.setStatus("已取消敲门")
                        self?.log("已取消串门请求。")
                    } else {
                        self?.panel.setStatus("正在回家")
                        self?.log("已喊宠物回家。")
                    }
                case .failure(let error):
                    if self?.isLostVisitError(error) == true {
                        self?.handleLostOutgoingVisit()
                    } else {
                        self?.log("喊宠物回家失败：\(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func removeVisitor(visitId: String) {
        closeInteractionMenu()
        guard let visitor = visitors.removeValue(forKey: visitId) else {
            panel?.setHasVisitor(!visitors.isEmpty)
            return
        }
        visitor.roamTimer?.invalidate()
        visitor.animationTimer?.invalidate()
        visitor.window.close()
        panel?.setHasVisitor(!visitors.isEmpty)
        if visitors.count < 2 {
            visitorPairTimer?.invalidate()
            visitorPairTimer = nil
        } else {
            scheduleVisitorPairPlay()
        }
    }

    private func removeAllVisitors() {
        closeInteractionMenu()
        visitorPairTimer?.invalidate()
        visitorPairTimer = nil
        for visitId in Array(visitors.keys) {
            removeVisitor(visitId: visitId)
        }
    }

    private func sayLocal(_ text: String) {
        (localWindow?.contentView as? PetView)?.say(text)
    }

    private func showLocalInteractionMenu() {
        guard let localWindow else { return }
        closeInteractionMenu()
        var actions = [
            PetAction(title: "摸摸") { [weak self] in
                self?.closeInteractionMenu()
                self?.petLocalPet()
            }
        ]
        if animationResolver.hasFetchBallAction() {
            actions.append(PetAction(title: "丢球") { [weak self] in
                self?.closeInteractionMenu()
                self?.throwBallForLocalPet()
            })
        } else if animationResolver.state(for: .signature) != nil {
            actions.append(PetAction(title: animationResolver.signatureActionTitle()) { [weak self] in
                self?.closeInteractionMenu()
                self?.playSignatureAction()
            })
        }
        actions.append(PetAction(title: "好友") { [weak self] in
            self?.showFriendActions()
        })
        actions.append(
            PetAction(title: "睡觉") { [weak self] in
                self?.closeInteractionMenu()
                self?.putLocalPetToSleep()
            }
        )
        showInteractionMenu(anchor: localWindow, actions: actions)
    }

    private func showFriendActions() {
        guard let localWindow else { return }
        closeInteractionMenu()
        var actions = [
            PetAction(title: "邀请好友一起玩") { [weak self] in
                self?.closeInteractionMenu()
                self?.shareInvite()
            },
            PetAction(title: "加好友") { [weak self] in
                self?.closeInteractionMenu()
                self?.promptForInvite()
            }
        ]
        if !visitors.isEmpty {
            actions.append(PetAction(title: "送回家") { [weak self] in
                self?.closeInteractionMenu()
                self?.returnVisitor()
            })
        }
        if outgoingVisit != nil {
            actions.append(PetAction(title: "喊回来") { [weak self] in
                self?.closeInteractionMenu()
                self?.recallLocalPet()
            })
        }
        let onlineFriends = friends.filter { $0.online }
        for friend in onlineFriends {
            actions.append(PetAction(title: friend.display_name) { [weak self] in
                self?.closeInteractionMenu()
                self?.sayLocal("我去问问 \(friend.display_name) 在不在家。")
                self?.sendVisit(to: friend.user_id, displayName: friend.display_name)
            })
        }
        if friends.isEmpty {
            sayLocal("还没有好友，可以先邀请朋友。")
        } else if onlineFriends.isEmpty {
            sayLocal("好友现在都不在家。")
        } else {
            sayLocal("想去谁家串门？")
        }
        showInteractionMenu(anchor: localWindow, actions: actions)
    }

    private func showVisitorInteractionMenu(visitId: String) {
        guard let visitor = visitors[visitId] else { return }
        closeInteractionMenu()
        let visitorWindow = visitor.window
        guard let visitorView = visitorWindow.contentView as? PetView else { return }
        let capabilities = visitorInteractionCapabilities(for: visitorView.profile)
        var actions: [PetAction] = []
        if capabilities.contains("petting") {
            actions.append(PetAction(title: "摸摸") { [weak self] in
                self?.closeInteractionMenu()
                self?.petVisitor(visitId: visitId)
            })
        }
        if capabilities.contains("message") {
            actions.append(PetAction(title: "留言") { [weak self] in
                self?.closeInteractionMenu()
                self?.leaveMessageForVisitor(visitId: visitId)
            })
        }
        if capabilities.contains("gift.simple") {
            actions.append(PetAction(title: "投喂") { [weak self] in
                self?.closeInteractionMenu()
                self?.feedVisitor(visitId: visitId)
            })
        }
        if capabilities.contains("pet_to_pet.greeting"), localWindow != nil {
            actions.append(PetAction(title: "打招呼") { [weak self] in
                self?.closeInteractionMenu()
                self?.greetVisitorWithLocalPet(visitId: visitId)
            })
        }
        if capabilities.contains("pet_to_pet.sit_together"), localWindow != nil {
            actions.append(PetAction(title: "坐一会儿") { [weak self] in
                self?.closeInteractionMenu()
                self?.sitTogetherWithVisitor(visitId: visitId)
            })
        }
        if capabilities.contains("pet_to_pet.walk_together"), localWindow != nil {
            actions.append(PetAction(title: "一起玩") { [weak self] in
                self?.closeInteractionMenu()
                self?.playTogetherWithVisitor(visitId: visitId)
            })
        }
        if capabilities.contains("return_home") {
            actions.append(PetAction(title: "送回家") { [weak self] in
                self?.closeInteractionMenu()
                self?.returnVisitor(visitId: visitId)
            })
        }
        if actions.isEmpty {
            visitorView.say("我还不知道怎么和你互动。")
            return
        }
        showInteractionMenu(anchor: visitorWindow, actions: actions)
    }

    private func visitorInteractionCapabilities(for profile: PetProfile) -> Set<String> {
        let runtimeSupported: Set<String> = ["petting", "message", "return_home", "gift.simple", "pet_to_pet.greeting", "pet_to_pet.sit_together", "pet_to_pet.walk_together"]
        let petSupported = Set(profile.interaction_capabilities ?? ["petting", "message", "return_home"])
        let localSupported = Set(localPet.interaction_capabilities ?? ["petting", "message", "return_home"])
        var capabilities = runtimeSupported.intersection(petSupported)
        for petToPetCapability in ["pet_to_pet.greeting", "pet_to_pet.sit_together", "pet_to_pet.walk_together"] {
            if !localSupported.contains(petToPetCapability) {
                capabilities.remove(petToPetCapability)
            }
        }
        return capabilities
    }

    private func menuOrigin(for petFrame: NSRect, actions: [PetAction]) -> CGPoint {
        let width = InteractionMenuView.menuWidth(for: InteractionMenuView.buttonWidths(for: actions))
        return menuOrigin(for: petFrame, menuWidth: width)
    }

    private func menuOrigin(for petFrame: NSRect, menuWidth: CGFloat) -> CGPoint {
        CGPoint(x: petFrame.midX - menuWidth / 2, y: petFrame.minY - 52)
    }

    private func showInteractionMenu(anchor: PetWindow, actions: [PetAction]) {
        closeInteractionMenu()
        let menu = InteractionMenuWindow(origin: menuOrigin(for: anchor.frame, actions: actions), actions: actions)
        interactionMenuWindow = menu
        interactionMenuAnchorWindow = anchor
        startInteractionMenuFollowTimer()
    }

    private func startInteractionMenuFollowTimer() {
        interactionMenuFollowTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self,
                  let menu = self.interactionMenuWindow,
                  let anchor = self.interactionMenuAnchorWindow,
                  anchor.isVisible else {
                self?.closeInteractionMenu()
                return
            }
            let origin = self.menuOrigin(for: anchor.frame, menuWidth: menu.frame.width)
            if abs(menu.frame.origin.x - origin.x) > 0.5 || abs(menu.frame.origin.y - origin.y) > 0.5 {
                menu.setFrameOrigin(origin)
            }
        }
        interactionMenuFollowTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func closeInteractionMenu() {
        interactionMenuFollowTimer?.invalidate()
        interactionMenuFollowTimer = nil
        interactionMenuAnchorWindow = nil
        interactionMenuWindow?.close()
        interactionMenuWindow = nil
    }

    private func petLocalPet() {
        animatePettingReaction(window: localWindow)
        playLocal(.rest, returnToIdleAfter: 2.5)
        sayLocal("蹭了蹭你的手。")
        remember("\(localPet.name) 被你摸了摸。")
        scheduleLocalSleep()
        scheduleLocalRoam()
    }

    private func putLocalPetToSleep() {
        localRoamTimer?.invalidate()
        playLocal(.sleep)
        sayLocal("我先眯一会儿。")
        remember("\(localPet.name) 被你哄去睡觉了。")
    }

    private func playSignatureAction() {
        playLocal(.signature, returnToIdleAfter: 2.4)
        sayLocal("给你看一下。")
        remember("\(localPet.name) 给你展示了一个招牌动作。")
        scheduleLocalSleep()
        scheduleLocalRoam()
    }

    private func petVisitor(visitId: String) {
        guard let visitor = visitors[visitId] else { return }
        visitor.roamTimer?.invalidate()
        animatePettingReaction(window: visitor.window)
        (visitor.window.contentView as? PetView)?.say("谢谢你理我。")
        recordVisitEvent(visitId: visitId, type: "clicked", data: ["message": "host petted visitor pet"])
        scheduleVisitorRoam(visitId: visitId)
    }

    private func animatePettingReaction(window: PetWindow?) {
        guard let window else { return }
        let start = window.frame.origin
        let bump = CGPoint(x: start.x, y: start.y + 10)
        let view = window.contentView as? PetView
        view?.animateRenderScale(to: 1.08, duration: 0.1)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            window.animator().setFrameOrigin(bump)
        } completionHandler: {
            view?.animateRenderScale(to: 1.0, duration: 0.18)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                window.animator().setFrameOrigin(start)
            }
        }
    }

    private func leaveMessageForVisitor(visitId: String) {
        guard let visitor = visitors[visitId] else {
            log("现在没有来串门的小客人。")
            return
        }
        let name = visitor.profile.name
        promptForPetMessage(targetName: name) { [weak self] text in
            self?.recordVisitEvent(visitId: visitId, type: "message", data: ["text": text])
            self?.log("已给 \(name) 留言。")
        }
    }

    private func promptForPetMessage(targetName: String, onSubmit: (String) -> Void) {
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "留言")
        alert.messageText = "给 \(targetName) 留言"
        alert.informativeText = "发送后会被记下来。宠物现在不会马上回复。"
        alert.addButton(withTitle: "发送")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "想说的话"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            log("留言为空，没有发送。")
            return
        }
        onSubmit(String(text.prefix(500)))
    }

    private func showReturnedMessagesIfNeeded(_ receipt: MemoryReceipt) {
        let messages = receipt.messages?.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
        guard !messages.isEmpty else { return }

        let body = messages
            .prefix(8)
            .enumerated()
            .map { index, message in
                let author = message.author_name?.isEmpty == false ? message.author_name! : "朋友"
                return "\(index + 1). \(author)：\(message.text)"
            }
            .joined(separator: "\n\n")

        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "text.bubble.fill", accessibilityDescription: "留言")
        alert.messageText = "\(localPet.name) 带回了留言"
        alert.informativeText = body
        alert.addButton(withTitle: "关闭")
        alert.runModal()

        log("\(localPet.name) 带回 \(messages.count) 条留言。")
    }

    private func greetVisitorWithLocalPet(visitId: String) {
        guard let visitor = visitors[visitId] else {
            log("现在没有来串门的小客人。")
            return
        }
        sayLocal("你好呀。")
        (visitor.window.contentView as? PetView)?.say("我来玩一会儿。")
        playLocal(.rest, returnToIdleAfter: 1.8)
        playVisitorRest(visitId: visitId, returnToIdleAfter: 1.8)
        recordVisitEvent(
            visitId: visitId,
            type: "pet_to_pet.greeting",
            data: [
                "local_pet_id": localPet.pet_id,
                "visitor_pet_id": visitor.visit.pet_id
            ]
        )
        remember("\(localPet.name) 和来访的小客人打了招呼。")
        scheduleLocalSleep()
        scheduleLocalRoam()
    }

    private func sitTogetherWithVisitor(visitId: String) {
        guard let localWindow, let visitor = visitors[visitId] else {
            log("现在没有来串门的小客人。")
            return
        }
        let visitorWindow = visitor.window
        localSleepTimer?.invalidate()
        localRoamTimer?.invalidate()
        localAnimationTimer?.invalidate()
        visitor.roamTimer?.invalidate()
        visitor.animationTimer?.invalidate()

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let localStart = localWindow.frame.origin
        let visitorStart = visitorWindow.frame.origin
        let rightTargetX = localStart.x + 92
        let leftTargetX = localStart.x - 92
        let targetX = rightTargetX + visitorWindow.frame.width < screen.maxX
            ? rightTargetX
            : max(screen.minX + 40, leftTargetX)
        let visitorTarget = CGPoint(
            x: targetX,
            y: min(max(localStart.y, screen.minY + 70), screen.maxY - 170)
        )
        let duration = localMoveDuration(from: visitorStart, to: visitorTarget, speed: 280, minimum: 0.9, maximum: 2.4)

        sayLocal("坐这里吧。")
        (visitorWindow.contentView as? PetView)?.say("我坐一会儿。")
        (visitorWindow.contentView as? PetView)?.faceMovement(from: visitorStart, to: visitorTarget)
        playLocal(.rest)
        playVisitorMove(visitId: visitId)
        recordVisitEvent(
            visitId: visitId,
            type: "pet_to_pet.sit_together",
            data: [
                "local_pet_id": localPet.pet_id,
                "visitor_pet_id": visitor.visit.pet_id,
                "from_x": "\(Int(visitorStart.x))",
                "from_y": "\(Int(visitorStart.y))",
                "to_x": "\(Int(visitorTarget.x))",
                "to_y": "\(Int(visitorTarget.y))"
            ]
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            visitorWindow.animator().setFrameOrigin(visitorTarget)
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.playLocal(.rest, returnToIdleAfter: 2.8)
            self.playVisitorRest(visitId: visitId, returnToIdleAfter: 2.8)
            self.remember("\(self.localPet.name) 和来访的小客人靠在一起坐了一会儿。")
            self.scheduleLocalRoam()
            self.scheduleLocalSleep()
            self.scheduleVisitorRoam(visitId: visitId)
        }
    }

    private func playTogetherWithVisitor(visitId: String) {
        guard let localWindow, let visitor = visitors[visitId] else {
            log("现在没有来串门的小客人。")
            return
        }
        let visitorWindow = visitor.window
        localSleepTimer?.invalidate()
        localRoamTimer?.invalidate()
        localAnimationTimer?.invalidate()
        visitor.roamTimer?.invalidate()
        visitor.animationTimer?.invalidate()
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let localStart = localWindow.frame.origin
        let visitorStart = visitorWindow.frame.origin
        let localTarget = CGPoint(
            x: localStart.x < screen.midX ? screen.maxX - 260 : screen.minX + 120,
            y: min(max(localStart.y + 120, screen.minY + 90), screen.maxY - 180)
        )
        let visitorTarget = CGPoint(x: localTarget.x + 92, y: localTarget.y + 6)
        let duration = localMoveDuration(from: localStart, to: localTarget, speed: 240, minimum: 2.2, maximum: 4.8)

        sayLocal("我们一起去那边玩。")
        (visitorWindow.contentView as? PetView)?.say("一起跑一下。")
        (localWindow.contentView as? PetView)?.faceMovement(from: localStart, to: localTarget)
        (visitorWindow.contentView as? PetView)?.faceMovement(from: visitorStart, to: visitorTarget)
        playLocal(.move)
        playVisitorMove(visitId: visitId)
        recordVisitEvent(
            visitId: visitId,
            type: "pet_to_pet.walk_together",
            data: [
                "local_pet_id": localPet.pet_id,
                "visitor_pet_id": visitor.visit.pet_id,
                "from_x": "\(Int(visitorStart.x))",
                "from_y": "\(Int(visitorStart.y))",
                "to_x": "\(Int(visitorTarget.x))",
                "to_y": "\(Int(visitorTarget.y))"
            ]
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            localWindow.animator().setFrameOrigin(localTarget)
            visitorWindow.animator().setFrameOrigin(visitorTarget)
        } completionHandler: { [weak self] in
            self?.playLocal(.rest, returnToIdleAfter: 1.4)
            (visitor.window.contentView as? PetView)?.play("idle")
            self?.remember("\(self?.localPet.name ?? "宠物") 和来访的小客人一起在桌面上跑了一段。")
            self?.scheduleLocalRoam()
            self?.scheduleLocalSleep()
            self?.scheduleVisitorRoam(visitId: visitId)
        }
    }

    private func playVisitorRest(visitId: String, returnToIdleAfter delay: TimeInterval? = nil) {
        guard let visitorView = visitors[visitId]?.window.contentView as? PetView else { return }
        for state in ["rest", "sit", "idle"] {
            if visitorView.animationStates[state] != nil {
                visitorView.play(state, returnToIdleAfter: delay)
                return
            }
        }
    }

    private func playVisitorMove(visitId: String) {
        guard let visitorView = visitors[visitId]?.window.contentView as? PetView else { return }
        for state in ["move", "run", "walk", "float", "drift", "hop", "idle"] {
            if visitorView.animationStates[state] != nil {
                visitorView.play(state)
                return
            }
        }
    }

    private func playLocal(_ stateName: String, returnToIdleAfter delay: TimeInterval? = nil) {
        (localWindow?.contentView as? PetView)?.play(stateName, returnToIdleAfter: delay)
    }

    private func playLocal(_ intent: AnimationIntent, returnToIdleAfter delay: TimeInterval? = nil) {
        guard let stateName = animationResolver.state(for: intent) else { return }
        playLocal(stateName, returnToIdleAfter: delay)
    }

    private func setLocalRenderScale(_ scale: CGFloat) {
        (localWindow?.contentView as? PetView)?.setRenderScale(scale)
    }

    private func animateLocalRenderScale(to scale: CGFloat, duration: TimeInterval) {
        (localWindow?.contentView as? PetView)?.animateRenderScale(to: scale, duration: duration)
    }

    private func throwBallForLocalPet() {
        guard let localWindow else { return }
        closeInteractionMenu()
        localSleepTimer?.invalidate()
        localRoamTimer?.invalidate()

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let start = localWindow.frame.origin
        let farX = start.x < screen.midX ? screen.maxX - 180 : screen.minX + 120
        let farY = min(max(start.y + 180, screen.minY + 100), screen.maxY - 180)
        let ballOrigin = CGPoint(x: farX + 44, y: farY + 34)

        ballWindow?.close()
        ballWindow = BallWindow(origin: ballOrigin)
        sayLocal("球！我去捡。")
        playLocal(.move)
        let chaseDuration = localMoveDuration(from: start, to: CGPoint(x: farX, y: farY), speed: 300, minimum: 1.8, maximum: 3.8)
        let returnDuration = localMoveDuration(from: CGPoint(x: farX, y: farY), to: start, speed: 280, minimum: 2.0, maximum: 4.2)
        animateLocalRenderScale(to: 0.55, duration: chaseDuration)
        remember("你把球丢到了远处，\(localPet.name) 追了过去。")

        animateLocalPet(to: CGPoint(x: farX, y: farY), duration: chaseDuration) { [weak self] in
            guard let self else { return }
            self.ballWindow?.close()
            self.ballWindow = nil
            self.playLocal(.returnWithGift)
            self.sayLocal("捡到了。")
            self.animateLocalRenderScale(to: 1.0, duration: returnDuration)
            self.animateLocalPet(to: start, duration: returnDuration) { [weak self] in
                guard let self else { return }
                self.setLocalRenderScale(1.0)
                self.sayLocal("我把球叼回来啦。")
                self.playLocal(.rest, returnToIdleAfter: 2.0)
                self.remember("\(self.localPet.name) 把你丢出去的球叼回来了。")
                self.scheduleLocalSleep()
                self.scheduleLocalRoam()
            }
        }
    }

    private func animateLocalPet(to origin: CGPoint, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let localWindow else {
            completion?()
            return
        }
        localAnimationTimer?.invalidate()
        let start = localWindow.frame.origin
        (localWindow.contentView as? PetView)?.faceMovement(from: start, to: origin)
        let startedAt = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak localWindow] timer in
            guard let self, let localWindow else {
                timer.invalidate()
                return
            }
            let progress = min(Date().timeIntervalSince(startedAt) / duration, 1.0)
            let eased = progress * progress * (3 - 2 * progress)
            let next = CGPoint(
                x: start.x + (origin.x - start.x) * CGFloat(eased),
                y: start.y + (origin.y - start.y) * CGFloat(eased)
            )
            localWindow.setFrameOrigin(next)
            if progress >= 1.0 {
                localWindow.setFrameOrigin(origin)
                timer.invalidate()
                self.localAnimationTimer = nil
                completion?()
            }
        }
        localAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func animateVisitorPet(visitId: String, to origin: CGPoint, duration: TimeInterval, completion: (() -> Void)? = nil) {
        guard let visitor = visitors[visitId] else {
            completion?()
            return
        }
        let visitorWindow = visitor.window
        visitor.animationTimer?.invalidate()
        let start = visitorWindow.frame.origin
        (visitorWindow.contentView as? PetView)?.faceMovement(from: start, to: origin)
        let startedAt = Date()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak visitorWindow] timer in
            guard let self, let visitorWindow, let visitor = self.visitors[visitId] else {
                timer.invalidate()
                return
            }
            let progress = min(Date().timeIntervalSince(startedAt) / duration, 1.0)
            let eased = progress * progress * (3 - 2 * progress)
            let next = CGPoint(
                x: start.x + (origin.x - start.x) * CGFloat(eased),
                y: start.y + (origin.y - start.y) * CGFloat(eased)
            )
            visitorWindow.setFrameOrigin(next)
            if progress >= 1.0 {
                visitorWindow.setFrameOrigin(origin)
                timer.invalidate()
                visitor.animationTimer = nil
                completion?()
            }
        }
        visitor.animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func localMoveDuration(
        from start: CGPoint,
        to end: CGPoint,
        speed: CGFloat,
        minimum: TimeInterval,
        maximum: TimeInterval
    ) -> TimeInterval {
        let distance = hypot(end.x - start.x, end.y - start.y)
        return min(max(TimeInterval(distance / speed), minimum), maximum)
    }

    private func scheduleLocalSleep() {
        localSleepTimer?.invalidate()
        localSleepTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            self?.localRoamTimer?.invalidate()
            self?.playLocal(.sleep)
            self?.sayLocal("我先眯一会儿。")
        }
    }

    private func scheduleLocalRoam() {
        localRoamTimer?.invalidate()
        guard localWindow != nil, awaySignWindow == nil else { return }
        let delay = TimeInterval.random(in: 16...32)
        localRoamTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performLocalRoam()
        }
    }

    private func performLocalRoam() {
        guard localWindow != nil, awaySignWindow == nil, ballWindow == nil else {
            scheduleLocalRoam()
            return
        }
        closeInteractionMenu()
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let x = CGFloat.random(in: (screen.minX + 80)...(screen.maxX - 180))
        let y = CGFloat.random(in: (screen.minY + 80)...(screen.maxY - 180))
        let target = CGPoint(x: x, y: y)
        let start = localWindow?.frame.origin ?? target
        let duration = localMoveDuration(from: start, to: target, speed: 220, minimum: 2.6, maximum: 6.0)
        playLocal(.move)
        animateLocalPet(to: target, duration: duration) { [weak self] in
            self?.playLocal(.rest, returnToIdleAfter: 1.4)
            self?.scheduleLocalRoam()
        }
    }

    private func scheduleVisitorRoam(visitId: String) {
        visitors[visitId]?.roamTimer?.invalidate()
        guard let visitor = visitors[visitId], visitor.visit.status == "active" else { return }
        let delay = TimeInterval.random(in: 10...22)
        visitor.roamTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performVisitorRoam(visitId: visitId)
        }
    }

    private func performVisitorRoam(visitId: String) {
        guard let visitor = visitors[visitId], visitor.visit.status == "active" else {
            visitors[visitId]?.roamTimer?.invalidate()
            visitors[visitId]?.roamTimer = nil
            return
        }
        let visitorWindow = visitor.window
        closeInteractionMenu()
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let x = CGFloat.random(in: (screen.minX + 80)...(screen.maxX - 180))
        let y = CGFloat.random(in: (screen.minY + 80)...(screen.maxY - 180))
        let target = CGPoint(x: x, y: y)
        let start = visitorWindow.frame.origin
        let duration = localMoveDuration(from: start, to: target, speed: 190, minimum: 2.4, maximum: 6.2)
        playVisitorMove(visitId: visitId)
        if Bool.random() {
            (visitorWindow.contentView as? PetView)?.say("我去那边看看。")
        }
        recordVisitEvent(
            visitId: visitId,
            type: "visitor_autonomous_roam",
            data: [
                "from_x": "\(Int(start.x))",
                "from_y": "\(Int(start.y))",
                "to_x": "\(Int(target.x))",
                "to_y": "\(Int(target.y))"
            ]
        )
        animateVisitorPet(visitId: visitId, to: target, duration: duration) { [weak self] in
            self?.playVisitorRest(visitId: visitId, returnToIdleAfter: 1.6)
            self?.scheduleVisitorRoam(visitId: visitId)
        }
    }

    private func scheduleVisitorPairPlay() {
        visitorPairTimer?.invalidate()
        guard visitors.filter({ $0.value.visit.status == "active" }).count >= 2 else { return }
        let delay = TimeInterval.random(in: 18...36)
        visitorPairTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.performVisitorPairPlay()
        }
    }

    private func performVisitorPairPlay() {
        let activeIds = visitors
            .filter { $0.value.visit.status == "active" }
            .map(\.key)
            .shuffled()
        guard activeIds.count >= 2,
              let firstId = activeIds.first,
              let secondId = activeIds.dropFirst().first,
              let first = visitors[firstId],
              let second = visitors[secondId] else {
            scheduleVisitorPairPlay()
            return
        }

        first.roamTimer?.invalidate()
        second.roamTimer?.invalidate()
        first.animationTimer?.invalidate()
        second.animationTimer?.invalidate()

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let firstStart = first.window.frame.origin
        let secondStart = second.window.frame.origin
        let baseTarget = CGPoint(
            x: firstStart.x < screen.midX ? screen.maxX - 300 : screen.minX + 120,
            y: min(max((firstStart.y + secondStart.y) / 2 + 90, screen.minY + 90), screen.maxY - 190)
        )
        let firstTarget = baseTarget
        let secondTarget = CGPoint(x: baseTarget.x + 104, y: baseTarget.y + 8)
        let duration = localMoveDuration(from: firstStart, to: firstTarget, speed: 210, minimum: 2.4, maximum: 5.4)

        (first.window.contentView as? PetView)?.say("一起去那边看看。")
        (second.window.contentView as? PetView)?.say("好呀。")
        playVisitorMove(visitId: firstId)
        playVisitorMove(visitId: secondId)
        recordVisitorPairEvent(
            type: "pet_to_pet.walk_together",
            firstId: firstId,
            secondId: secondId,
            data: [
                "from_x": "\(Int(firstStart.x))",
                "from_y": "\(Int(firstStart.y))",
                "to_x": "\(Int(firstTarget.x))",
                "to_y": "\(Int(firstTarget.y))"
            ]
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            first.window.animator().setFrameOrigin(firstTarget)
            second.window.animator().setFrameOrigin(secondTarget)
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.playVisitorRest(visitId: firstId, returnToIdleAfter: 2.0)
            self.playVisitorRest(visitId: secondId, returnToIdleAfter: 2.0)
            self.scheduleVisitorRoam(visitId: firstId)
            self.scheduleVisitorRoam(visitId: secondId)
            self.scheduleVisitorPairPlay()
        }
    }

    private func recordVisitorPairEvent(type: String, firstId: String, secondId: String, data: [String: String]) {
        guard let first = visitors[firstId], let second = visitors[secondId] else { return }
        var firstData = data
        firstData["peer_visit_id"] = second.visit.visit_id
        firstData["peer_pet_id"] = second.visit.pet_id
        firstData["peer_pet_name"] = second.profile.name
        recordVisitEvent(visitId: firstId, type: type, data: firstData)

        var secondData = data
        secondData["peer_visit_id"] = first.visit.visit_id
        secondData["peer_pet_id"] = first.visit.pet_id
        secondData["peer_pet_name"] = first.profile.name
        recordVisitEvent(visitId: secondId, type: type, data: secondData)
    }

    private func restorePersistentLogToPanel() {
        let entries = localState.life_log.prefix(20).reversed()
        for entry in entries {
            panel.appendLog("历史：\(entry.text)")
        }
        if !localState.memories.isEmpty {
            panel.appendLog("已加载 \(localState.memories.count) 条本地记忆。")
        }
    }

    private func remember(_ text: String) {
        let entry = LifeLogEntry(
            id: "life_\(UUID().uuidString)",
            text: text,
            created_at: ISO8601DateFormatter().string(from: Date())
        )
        localState.life_log.insert(entry, at: 0)
        if localState.life_log.count > 300 {
            localState.life_log.removeLast(localState.life_log.count - 300)
        }
        store.save(localState)
        panel.appendLog(text)
    }

    private func rememberMemory(_ receipt: MemoryReceipt) {
        if !localState.memories.contains(where: { $0.receipt_id == receipt.receipt_id }) {
            localState.memories.insert(receipt, at: 0)
            if localState.memories.count > 120 {
                localState.memories.removeLast(localState.memories.count - 120)
            }
            store.save(localState)
        }
    }

    private func log(_ text: String) {
        panel.appendLog(text)
    }

    static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

}

struct ProfileResponse: Codable { let profile: PetProfile }
struct VisitResponse: Codable { let visit: VisitSession }
struct VisitDecisionResponse: Codable { let visit: VisitSession }
struct EndVisitResponse: Codable { let receipt: MemoryReceipt? }
struct InteractionResponse: Codable { let event: InteractionEvent }
struct InteractionEvent: Codable {
    let event_id: String
    let type: String
    let data: [String: String]?
}
struct VisitRequest: Codable {
    let pet_id: String
    let owner_user_id: String
    let host_user_id: String
    let departure_context: [String: String]
}

struct VisitDecisionRequest: Codable {
    let user_id: String
    let action: String
}

struct InteractionRequest: Codable {
    let type: String
    let data: [String: String]
    let actor: [String: String]
}

struct EndVisitRequest: Codable {
    let reason: String
    let actor: [String: String]
}

extension NSColor {
    static var systemMint: NSColor { NSColor(red: 0.42, green: 0.78, blue: 0.66, alpha: 1) }
    static var systemCoral: NSColor { NSColor(red: 0.93, green: 0.48, blue: 0.42, alpha: 1) }

    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let int = Int(value, radix: 16) else { return nil }
        self.init(
            red: CGFloat((int >> 16) & 0xff) / 255,
            green: CGFloat((int >> 8) & 0xff) / 255,
            blue: CGFloat(int & 0xff) / 255,
            alpha: 1
        )
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
