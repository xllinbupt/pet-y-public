import AppKit
import Foundation

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
            projection_capabilities: projection_capabilities
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

struct MemoryReceipt: Codable {
    let receipt_id: String
    let visit_id: String
    let pet_id: String
    let life_log_entry: String
    let pet_voice: String
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
                projection_capabilities: ["idle", "walk", "sleep", "react_to_click", "react_to_drag", "receive_gift"]
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
            projection_capabilities: ["idle", "walk", "sleep", "react_to_click", "react_to_drag", "receive_gift"]
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
        let width = CGFloat(max(1, actions.count) * 58 + 12)
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
        contentView = InteractionMenuView(frame: NSRect(x: 0, y: 0, width: width, height: 48), actions: actions)
        makeKeyAndOrderFront(nil)
    }
}

final class InteractionMenuView: NSView {
    let actions: [PetAction]

    init(frame frameRect: NSRect, actions: [PetAction]) {
        self.actions = actions
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        for (index, action) in actions.enumerated() {
            let button = NSButton(title: action.title, target: self, action: #selector(actionTapped(_:)))
            button.tag = index
            button.bezelStyle = .rounded
            button.font = .systemFont(ofSize: 12, weight: .semibold)
            button.frame = NSRect(x: 8 + index * 58, y: 8, width: 50, height: 30)
            addSubview(button)
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
    var dragStartScreen: CGPoint?
    var dragStartFrame: NSRect?

    init(message: String) {
        self.message = message
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
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let start = dragStartScreen, let frame = dragStartFrame else { return }
        let current = NSEvent.mouseLocation
        window.setFrameOrigin(NSPoint(x: frame.origin.x + current.x - start.x, y: frame.origin.y + current.y - start.y))
    }

    override func mouseUp(with event: NSEvent) {
        dragStartScreen = nil
        dragStartFrame = nil
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
        NSString(string: message).draw(in: NSRect(x: 24, y: 42, width: 132, height: 30), withAttributes: attrs)
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
            drawLabel()
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

        drawLabel()
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
        animationImage.draw(in: target, from: source, operation: .sourceOver, fraction: 1.0, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.none])
        return true
    }

    private func drawLabel() {
        let label = "\(profile.name)\(isVisitor ? " 来访中" : "")"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: 5), withAttributes: attributes)
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
    var recentLogs: [String] = []
    var onSendVisit: ((String) -> Void)?
    var onReturn: (() -> Void)?
    var onShareInvite: (() -> Void)?
    var onAcceptInvite: (() -> Void)?

    override init() {
        super.init()
        statusItem.button?.title = "Pet Y"
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

        let titleItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let statusMenuItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let friendsItem = NSMenuItem(title: "好友", action: nil, keyEquivalent: "")
        let friendsMenu = NSMenu()
        friendsMenu.addItem(actionItem(title: "邀请好友一起玩", action: #selector(shareInviteTapped)))
        friendsMenu.addItem(actionItem(title: "输入邀请码加好友", action: #selector(acceptInviteTapped)))
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
        friendsMenu.addItem(.separator())
        friendsMenu.addItem(actionItem(title: "请回来访宠物", action: #selector(returnTapped)))
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
    var visitorWindow: PetWindow?
    var ballWindow: BallWindow?
    var interactionMenuWindow: InteractionMenuWindow?
    var visitorVisit: VisitSession?
    var friends: [FriendStatus] = []
    var lastEventId = 0
    var pollTimer: Timer?
    var localSleepTimer: Timer?
    var localRoamTimer: Timer?
    var localAnimationTimer: Timer?

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
        let sign = AwaySignView(message: "我去 \(friend) 那儿")
        awaySignWindow = AwaySignWindow(view: sign, origin: origin)
    }

    private func restoreLocalPet() {
        let origin = awaySignWindow?.frame.origin
        awaySignWindow?.close()
        awaySignWindow = nil
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
                    self?.log("桌面 Runtime 已启动。")
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

        我的宠物叫 \(localPet.name)，它想认识你未来创建的宠物。

        公开说明在这里：
        https://github.com/xllinbupt/pet-y-public

        你可以把下面这段话发给 Codex：

        请根据 https://github.com/xllinbupt/pet-y-public 的说明，先安装和准备 Pet Y 项目，并下载预编译的 Pet Y Runtime。这个过程可能需要一点时间，不需要让我处理 Xcode、Swift 或 macOS SDK 编译问题。

        然后请访谈我，帮我创建一只属于我自己的桌面宠物。请问我宠物的名字、风格、外形、性格、动作、行为和它喜欢怎样陪伴我，不要直接运行邀请人的小狗。

        创建完成后，请启动我的宠物，并连接这个 Relay：
        \(relayURL)

        启动后，在 Pet Y 菜单里选择“输入邀请码加好友”，粘贴这个邀请码：

        \(token)

        你的宠物上线以后，我们就可以互相串门了。
        """
    }

    private func promptForInvite() {
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "person.crop.circle.badge.plus", accessibilityDescription: "添加好友")
        alert.messageText = "添加好友"
        alert.informativeText = "粘贴朋友发给你的邀请码。"
        alert.addButton(withTitle: "添加")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.placeholderString = "邀请码"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        acceptInvite(token: input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func acceptInvite(token: String) {
        guard !token.isEmpty else {
            sayLocal("邀请码是空的。")
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
                    self?.panel.setStatus("\(self?.localPet.name ?? "宠物") 已出门")
                    self?.sayLocal("我出门啦。")
                    self?.showAwaySign(to: friendName)
                    self?.log("创建串门会话：\(response.visit.visit_id)")
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

    private func handle(_ event: RelayEvent) {
        let decoder = JSONDecoder()
        guard let data = try? JSONEncoder().encode(event.payload) else { return }

        switch event.type {
        case "profile_registered":
            break
        case "visit_started":
            if let payload = try? decoder.decode(VisitStartedPayload.self, from: data) {
                showVisitor(payload)
            }
        case "interaction_event":
            log("收到远端互动事件：\(event.type)")
        case "visit_ended":
            removeVisitor()
            log("来访宠物已经回家。")
        case "memory_receipt":
            if let receipt = try? decoder.decode(MemoryReceipt.self, from: data) {
                panel.setStatus("\(localPet.name) 回家了")
                restoreLocalPet()
                sayLocal(receipt.pet_voice)
                remember(receipt.life_log_entry)
                remember(receipt.pet_voice)
                rememberMemory(receipt)
            }
        default:
            break
        }
    }

    private func showVisitor(_ payload: VisitStartedPayload) {
        removeVisitor()
        visitorVisit = payload.visit
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let view = PetView(
            profile: payload.profile,
            isVisitor: true,
            animationStates: payload.animation_states,
            assetBaseURL: materializeVisitorAssets(payload),
            onClick: { [weak self] in
                self?.showVisitorInteractionMenu()
            },
            onAlternateClick: { [weak self] in
                self?.showVisitorInteractionMenu()
            },
            onDragEnd: { [weak self] from, to, duration in
                self?.visitorWindow?.contentView.map { ($0 as? PetView)?.say("这个角落也不错。") }
                self?.recordVisitEvent(
                    type: "dragged",
                    data: [
                        "from_x": "\(Int(from.x))",
                        "from_y": "\(Int(from.y))",
                        "to_x": "\(Int(to.x))",
                        "to_y": "\(Int(to.y))",
                        "duration_ms": "\(duration)"
                    ]
                )
            }
        )
        visitorWindow = PetWindow(view: view, origin: CGPoint(x: screen.maxX - 320, y: screen.minY + 300))
        view.say("我是 \(payload.profile.name)，右键可以投喂我。")
        remember("\(payload.profile.name) 来你的桌面串门了。")
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

    private func recordVisitEvent(type: String, data: [String: String]) {
        guard let visit = visitorVisit else {
            log("当前没有来访宠物。")
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
                case .failure(let error): self?.log("互动事件上传失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func feedVisitor() {
        guard visitorVisit != nil else {
            log("当前没有来访宠物可以投喂。")
            return
        }
        (visitorWindow?.contentView as? PetView)?.say("我会把草莓带回去。")
        recordVisitEvent(type: "fed", data: ["item": "草莓"])
    }

    private func returnVisitor() {
        guard let visit = visitorVisit else {
            log("当前没有来访宠物可以请回。")
            return
        }
        let body = EndVisitRequest(reason: "host_requested_return", actor: ["type": "host_user", "user_id": userId])
        relay.post("api/visits/\(visit.visit_id)/end", body: body) { [weak self] (result: Result<EndVisitResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.removeVisitor()
                    self?.log("已请回来访宠物。")
                case .failure(let error):
                    self?.log("请回失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func removeVisitor() {
        closeInteractionMenu()
        visitorWindow?.close()
        visitorWindow = nil
        visitorVisit = nil
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
        interactionMenuWindow = InteractionMenuWindow(origin: menuOrigin(for: localWindow.frame, actionCount: actions.count), actions: actions)
    }

    private func showFriendActions() {
        guard let localWindow else { return }
        closeInteractionMenu()
        var actions = [
            PetAction(title: "邀请") { [weak self] in
                self?.closeInteractionMenu()
                self?.shareInvite()
            },
            PetAction(title: "加好友") { [weak self] in
                self?.closeInteractionMenu()
                self?.promptForInvite()
            }
        ]
        if visitorVisit != nil {
            actions.append(PetAction(title: "请回") { [weak self] in
                self?.closeInteractionMenu()
                self?.returnVisitor()
            })
        }
        for friend in friends {
            actions.append(PetAction(title: "\(friend.display_name)\(friend.online ? "" : " 不在家")") { [weak self] in
                self?.closeInteractionMenu()
                if friend.online {
                    self?.sayLocal("我去问问 \(friend.display_name) 在不在家。")
                    self?.sendVisit(to: friend.user_id, displayName: friend.display_name)
                } else {
                    self?.sayLocal("\(friend.display_name) 现在不在家。")
                    self?.log("\(friend.display_name) 当前离线，不能串门。")
                }
            })
        }
        if friends.isEmpty {
            sayLocal("还没有好友，可以先邀请朋友。")
        } else {
            sayLocal("好友都在这里。")
        }
        interactionMenuWindow = InteractionMenuWindow(origin: menuOrigin(for: localWindow.frame, actionCount: actions.count), actions: actions)
    }

    private func showVisitorInteractionMenu() {
        guard let visitorWindow else { return }
        closeInteractionMenu()
        let actions = [
            PetAction(title: "摸摸") { [weak self] in
                self?.closeInteractionMenu()
                self?.petVisitor()
            },
            PetAction(title: "投喂") { [weak self] in
                self?.closeInteractionMenu()
                self?.feedVisitor()
            },
            PetAction(title: "请回") { [weak self] in
                self?.closeInteractionMenu()
                self?.returnVisitor()
            }
        ]
        interactionMenuWindow = InteractionMenuWindow(origin: menuOrigin(for: visitorWindow.frame, actionCount: actions.count), actions: actions)
    }

    private func menuOrigin(for petFrame: NSRect, actionCount: Int) -> CGPoint {
        let width = CGFloat(max(1, actionCount) * 58 + 12)
        return CGPoint(x: petFrame.midX - width / 2, y: petFrame.minY - 52)
    }

    private func closeInteractionMenu() {
        interactionMenuWindow?.close()
        interactionMenuWindow = nil
    }

    private func petLocalPet() {
        playLocal(.rest, returnToIdleAfter: 2.5)
        sayLocal("我在桌面上。")
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

    private func petVisitor() {
        (visitorWindow?.contentView as? PetView)?.say("谢谢你理我。")
        recordVisitEvent(type: "clicked", data: ["message": "host petted visitor pet"])
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
struct EndVisitResponse: Codable { let receipt: MemoryReceipt? }
struct InteractionResponse: Codable { let event: InteractionEvent }
struct InteractionEvent: Codable { let event_id: String; let type: String }

struct VisitRequest: Codable {
    let pet_id: String
    let owner_user_id: String
    let host_user_id: String
    let departure_context: [String: String]
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
