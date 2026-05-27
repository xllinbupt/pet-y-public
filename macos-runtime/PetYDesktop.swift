import AppKit
import Foundation

let PetYRuntimeVersion = "v0.1.34"

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

struct VisitInvitation: Codable {
    let request_id: String
    let requester_user_id: String
    let owner_user_id: String
    let pet_id: String
    let status: String
    let visit_id: String?
    let expires_at: String?
}

struct VisitInvitationPayload: Codable {
    let invitation: VisitInvitation
    let requester: FriendStatus?
    let profile: PetProfile?
}

struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String?
}

struct VisitSession: Codable {
    let visit_id: String
    let pet_id: String
    let owner_user_id: String
    let host_user_id: String
    let profile_version: Int
    let status: String
    let requested_at: String?
    let request_expires_at: String?
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
    static let windowSize = NSSize(width: 220, height: 190)

    init(view: PetView, origin: CGPoint) {
        super.init(
            contentRect: NSRect(x: origin.x, y: origin.y, width: PetWindow.windowSize.width, height: PetWindow.windowSize.height),
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

final class KnockRequestWindow: NSWindow {
    init(origin: CGPoint, petName: String, message: String, onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: origin.x, y: origin.y, width: 258, height: 148),
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
        contentView = KnockRequestView(
            frame: NSRect(x: 0, y: 0, width: 258, height: 148),
            petName: petName,
            message: message,
            onAccept: onAccept,
            onDecline: onDecline
        )
        ignoresMouseEvents = false
        makeKeyAndOrderFront(nil)
    }
}

final class KnockRequestView: NSView {
    let petName: String
    let message: String
    let onAccept: () -> Void
    let onDecline: () -> Void

    init(frame frameRect: NSRect, petName: String, message: String, onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        self.petName = petName
        self.message = message
        self.onAccept = onAccept
        self.onDecline = onDecline
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let accept = NSButton(title: "进来玩", target: self, action: #selector(acceptTapped))
        accept.isBordered = false
        accept.wantsLayer = true
        accept.layer?.backgroundColor = NSColor(red: 0.42, green: 0.78, blue: 0.66, alpha: 1).cgColor
        accept.layer?.cornerRadius = 9
        accept.attributedTitle = NSAttributedString(string: "进来玩", attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: NSColor.white])
        accept.frame = NSRect(x: 104, y: 16, width: 68, height: 30)
        addSubview(accept)

        let decline = NSButton(title: "先不了", target: self, action: #selector(declineTapped))
        decline.isBordered = false
        decline.wantsLayer = true
        decline.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.95).cgColor
        decline.layer?.cornerRadius = 9
        decline.layer?.borderWidth = 1
        decline.layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor
        decline.attributedTitle = NSAttributedString(string: "先不了", attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.black])
        decline.frame = NSRect(x: 180, y: 16, width: 62, height: 30)
        addSubview(decline)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func acceptTapped() { onAccept() }
    @objc private func declineTapped() { onDecline() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 4), xRadius: 18, yRadius: 18)
        NSColor(red: 1.0, green: 0.96, blue: 0.82, alpha: 0.98).setFill()
        card.fill()
        NSColor.black.withAlphaComponent(0.18).setStroke()
        card.lineWidth = 1.5
        card.stroke()

        drawPaw(at: NSPoint(x: 34, y: 62))
        drawKnockLines()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        "\(petName) 在敲门".draw(at: NSPoint(x: 82, y: 98), withAttributes: titleAttrs)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.black.withAlphaComponent(0.72),
            .paragraphStyle: paragraph
        ]
        NSString(string: message).draw(in: NSRect(x: 82, y: 56, width: 148, height: 34), withAttributes: attrs)
    }

    private func drawPaw(at origin: NSPoint) {
        let color = NSColor(red: 0.93, green: 0.48, blue: 0.42, alpha: 1)
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: origin.x + 13, y: origin.y, width: 26, height: 24)).fill()
        for point in [
            NSPoint(x: origin.x + 0, y: origin.y + 24),
            NSPoint(x: origin.x + 14, y: origin.y + 31),
            NSPoint(x: origin.x + 31, y: origin.y + 29),
            NSPoint(x: origin.x + 44, y: origin.y + 20)
        ] {
            NSBezierPath(ovalIn: NSRect(x: point.x, y: point.y, width: 13, height: 15)).fill()
        }
    }

    private func drawKnockLines() {
        NSColor.black.withAlphaComponent(0.3).setStroke()
        for (x, y, length) in [(63.0, 102.0, 12.0), (70.0, 84.0, 10.0), (62.0, 73.0, 8.0)] {
            let line = NSBezierPath()
            line.move(to: NSPoint(x: x, y: y))
            line.line(to: NSPoint(x: x + length, y: y + 4))
            line.lineWidth = 2
            line.stroke()
        }
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
    let isEnabled: Bool
    let handler: () -> Void

    init(title: String, isEnabled: Bool = true, handler: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.handler = handler
    }
}

enum InteractionMenuLayout {
    case horizontal
    case vertical
}

final class InteractionMenuWindow: NSWindow {
    init(origin: CGPoint, actions: [PetAction], layout: InteractionMenuLayout = .horizontal) {
        let buttonWidths = InteractionMenuView.buttonWidths(for: actions, layout: layout)
        let size = InteractionMenuView.menuSize(for: buttonWidths, layout: layout)
        super.init(
            contentRect: NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height),
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
        contentView = InteractionMenuView(
            frame: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            actions: actions,
            buttonWidths: buttonWidths,
            layout: layout
        )
        makeKeyAndOrderFront(nil)
    }
}

final class InteractionMenuView: NSView {
    let actions: [PetAction]
    let buttonWidths: [CGFloat]
    let layout: InteractionMenuLayout

    static func buttonWidths(for actions: [PetAction], layout: InteractionMenuLayout = .horizontal) -> [CGFloat] {
        actions.map { action in
            let base: CGFloat = layout == .vertical ? 12 : 13
            let padding: CGFloat = layout == .vertical ? 30 : 26
            let minWidth: CGFloat = layout == .vertical ? 78 : 50
            return max(minWidth, CGFloat(action.title.count) * base + padding)
        }
    }

    static func menuSize(for buttonWidths: [CGFloat], layout: InteractionMenuLayout = .horizontal, maxWidth: CGFloat? = nil) -> CGSize {
        switch layout {
        case .horizontal:
            let resolvedMaxWidth = maxWidth ?? horizontalMaxWidth()
            let rows = horizontalRows(for: buttonWidths, maxWidth: resolvedMaxWidth)
            let width = min(resolvedMaxWidth, rows.map { rowWidth(for: $0) }.max() ?? 16)
            let height = CGFloat(rows.count) * 30 + CGFloat(max(0, rows.count - 1) * 8) + 16
            return CGSize(width: width, height: height)
        case .vertical:
            let width = min(max(buttonWidths.max() ?? 120, 120), 240) + 16
            let height = CGFloat(buttonWidths.count) * 34 + CGFloat(max(0, buttonWidths.count - 1) * 8) + 16
            return CGSize(width: width, height: height)
        }
    }

    private static func horizontalMaxWidth() -> CGFloat {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        return min(620, max(220, screen.width - 32))
    }

    private static func horizontalRows(for buttonWidths: [CGFloat], maxWidth: CGFloat) -> [[CGFloat]] {
        guard !buttonWidths.isEmpty else { return [[]] }
        var rows: [[CGFloat]] = [[]]
        var currentWidth: CGFloat = 16

        for width in buttonWidths {
            let nextWidth = rows[rows.count - 1].isEmpty ? currentWidth + width : currentWidth + 8 + width
            if nextWidth > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([width])
                currentWidth = 16 + width
            } else {
                rows[rows.count - 1].append(width)
                currentWidth = nextWidth
            }
        }

        return rows
    }

    private static func rowWidth(for row: [CGFloat]) -> CGFloat {
        row.reduce(16, +) + CGFloat(max(0, row.count - 1) * 8)
    }

    init(frame frameRect: NSRect, actions: [PetAction], buttonWidths: [CGFloat], layout: InteractionMenuLayout = .horizontal) {
        self.actions = actions
        self.buttonWidths = buttonWidths
        self.layout = layout
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        switch layout {
        case .horizontal:
            var x: CGFloat = 8
            var y = frameRect.height - 8 - 30
            for (index, action) in actions.enumerated() {
                let width = buttonWidths[index]
                if x > 8, x + width > frameRect.width - 8 {
                    x = 8
                    y -= 38
                }
                let button = NSButton(title: action.title, target: self, action: #selector(actionTapped(_:)))
                button.tag = index
                button.isBordered = false
                button.wantsLayer = true
                button.isEnabled = action.isEnabled
                button.layer?.backgroundColor = buttonBackgroundColor(for: action).cgColor
                button.layer?.cornerRadius = 8
                button.layer?.borderWidth = 1
                button.layer?.borderColor = buttonBorderColor(for: action).cgColor
                button.font = .systemFont(ofSize: 12, weight: .semibold)
                button.contentTintColor = buttonTextColor(for: action)
                button.attributedTitle = NSAttributedString(
                    string: action.title,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: buttonTextColor(for: action)
                    ]
                )
                button.frame = NSRect(x: x, y: y, width: width, height: 30)
                addSubview(button)
                x += width + 8
            }
        case .vertical:
            let availableWidth = frameRect.width - 16
            var y = frameRect.height - 8 - 30
            for (index, action) in actions.enumerated() {
                let button = NSButton(title: action.title, target: self, action: #selector(actionTapped(_:)))
                button.tag = index
                button.isBordered = false
                button.wantsLayer = true
                button.isEnabled = action.isEnabled
                button.layer?.backgroundColor = buttonBackgroundColor(for: action).cgColor
                button.layer?.cornerRadius = 8
                button.layer?.borderWidth = 1
                button.layer?.borderColor = buttonBorderColor(for: action).cgColor
                button.font = .systemFont(ofSize: 12, weight: .semibold)
                button.contentTintColor = buttonTextColor(for: action)
                button.attributedTitle = NSAttributedString(
                    string: action.title,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                        .foregroundColor: buttonTextColor(for: action)
                    ]
                )
                let width = min(buttonWidths[index], availableWidth)
                button.frame = NSRect(x: 8, y: y, width: width, height: 30)
                addSubview(button)
                y -= 38
            }
        }
    }

    private func buttonBackgroundColor(for action: PetAction) -> NSColor {
        action.isEnabled ? NSColor.white.withAlphaComponent(0.96) : NSColor.white.withAlphaComponent(0.48)
    }

    private func buttonBorderColor(for action: PetAction) -> NSColor {
        action.isEnabled ? NSColor.black.withAlphaComponent(0.14) : NSColor.black.withAlphaComponent(0.07)
    }

    private func buttonTextColor(for action: PetAction) -> NSColor {
        action.isEnabled ? NSColor.black : NSColor.black.withAlphaComponent(0.36)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func actionTapped(_ sender: NSButton) {
        guard actions.indices.contains(sender.tag) else { return }
        guard actions[sender.tag].isEnabled else { return }
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
    var animationBitmap: NSBitmapImageRep?
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
        super.init(frame: NSRect(x: 0, y: 0, width: PetWindow.windowSize.width, height: PetWindow.windowSize.height))
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

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Let clicks pass through the transparent parts of the pet window.
        guard isInteractivePoint(point) else { return nil }
        return super.hitTest(point)
    }

    func isInteractiveWindowPoint(_ point: NSPoint) -> Bool {
        isInteractivePoint(convert(point, from: nil))
    }

    var isDraggingPet: Bool {
        dragStartFrame != nil
    }

    private func isInteractivePoint(_ point: NSPoint) -> Bool {
        if bubbleHitRect()?.contains(point) == true { return true }
        return isOpaquePetPoint(point)
    }

    private func petHitRect() -> NSRect {
        if animationImage != nil {
            return spriteTargetRect().insetBy(dx: -10, dy: -10)
        }

        return NSRect(x: (bounds.width - 96) / 2, y: 20, width: 96, height: 100)
    }

    private func spriteTargetRect() -> NSRect {
        let spriteSize = 64 * renderScale
        return NSRect(
            x: (bounds.width - spriteSize) / 2,
            y: 28 + (64 - spriteSize) / 2,
            width: spriteSize,
            height: spriteSize
        )
    }

    private func isOpaquePetPoint(_ point: NSPoint) -> Bool {
        guard let animationState = animationStates[activeAnimationName],
              let animationImage,
              let animationBitmap else {
            return petHitRect().contains(point)
        }

        let target = spriteTargetRect()
        guard target.contains(point) else { return false }

        let frameWidth = CGFloat(animationState.frame_width)
        let frameHeight = CGFloat(animationState.frame_height)
        guard frameWidth > 0, frameHeight > 0, target.width > 0, target.height > 0 else { return false }

        var normalizedX = (point.x - target.minX) / target.width
        let normalizedY = (point.y - target.minY) / target.height
        if shouldMirrorSprite(animationState) {
            normalizedX = 1 - normalizedX
        }

        let clampedFrame = max(0, min(currentFrame, animationState.frames - 1))
        let sourceX = CGFloat(clampedFrame) * frameWidth + normalizedX * frameWidth
        let sourceY = normalizedY * frameHeight

        let imageScaleX = CGFloat(animationBitmap.pixelsWide) / max(animationImage.size.width, 1)
        let imageScaleY = CGFloat(animationBitmap.pixelsHigh) / max(animationImage.size.height, 1)
        let pixelX = max(0, min(animationBitmap.pixelsWide - 1, Int(sourceX * imageScaleX)))
        let pixelY = max(0, min(animationBitmap.pixelsHigh - 1, Int(sourceY * imageScaleY)))

        return (animationBitmap.colorAt(x: pixelX, y: pixelY)?.alphaComponent ?? 0) > 0.2
    }

    private func bubbleHitRect() -> NSRect? {
        guard let bubble else { return nil }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        let bubbleWidth = min(bounds.width - 12, 208)
        let limit = NSSize(width: bubbleWidth - 16, height: 76)
        let rect = NSString(string: bubble).boundingRect(
            with: limit,
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
        let bubbleHeight = min(88, Swift.max(32, rect.height + 14))
        let bubbleTopPadding: CGFloat = 6
        let bubbleBottomNearPet: CGFloat = 118
        let bubbleY = min(bounds.height - bubbleHeight - bubbleTopPadding, bubbleBottomNearPet)
        return NSRect(x: (bounds.width - bubbleWidth) / 2, y: bubbleY, width: bubbleWidth, height: bubbleHeight)
    }

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
        let duration = min(8.0, max(3.2, Double(text.count) * 0.08))
        bubbleTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
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
        animationBitmap = nil

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
        if let tiffData = image.tiffRepresentation {
            animationBitmap = NSBitmapImageRep(data: tiffData)
        }
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
        let bodyX = (bounds.width - 76) / 2
        let body = NSRect(x: bodyX, y: 28, width: 76, height: 62)
        drawEar(NSRect(x: bodyX + 9, y: 80, width: 22, height: 30), rotation: -16, color: color)
        drawEar(NSRect(x: bodyX + 45, y: 80, width: 22, height: 30), rotation: 16, color: color)

        let path = NSBezierPath(roundedRect: body, xRadius: 22, yRadius: 22)
        color.setFill()
        path.fill()
        NSColor.black.setStroke()
        path.lineWidth = 3
        path.stroke()

        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: bodyX + 22, y: 58, width: 8, height: 10)).fill()
        NSBezierPath(ovalIn: NSRect(x: bodyX + 48, y: 58, width: 8, height: 10)).fill()

        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: bodyX + 33, y: 48))
        mouth.curve(to: NSPoint(x: bodyX + 43, y: 48), controlPoint1: NSPoint(x: bodyX + 36, y: 43), controlPoint2: NSPoint(x: bodyX + 40, y: 43))
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
        let target = spriteTargetRect()
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
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        let bubbleWidth = min(bounds.width - 12, 208)
        let limit = NSSize(width: bubbleWidth - 16, height: 76)
        let rect = NSString(string: text).boundingRect(
            with: limit,
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
        let bubbleHeight = min(88, Swift.max(32, rect.height + 14))
        let bubbleTopPadding: CGFloat = 6
        let bubbleBottomNearPet: CGFloat = 118
        let bubbleY = min(bounds.height - bubbleHeight - bubbleTopPadding, bubbleBottomNearPet)
        let bubbleRect = NSRect(x: (bounds.width - bubbleWidth) / 2, y: bubbleY, width: bubbleWidth, height: bubbleHeight)
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
    var updateVersion: String?
    var updateURL: URL?
    var recentLogs: [String] = []
    var onSendVisit: ((String) -> Void)?
    var onReturn: (() -> Void)?
    var onRecallPet: (() -> Void)?
    var onShareInvite: (() -> Void)?
    var onAcceptInvite: (() -> Void)?
    var onInviteFriendPet: ((String) -> Void)?
    var onDoNotDisturb: ((Int) -> Void)?
    var onCheckUpdate: (() -> Void)?
    var onOpenUpdate: (() -> Void)?
    var onQuit: (() -> Void)?

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

    func setUpdateAvailable(version: String?, url: URL?) {
        updateVersion = version
        updateURL = url
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

        if let updateVersion {
            menu.addItem(actionItem(title: "发现新版本 \(updateVersion)，打开下载页", action: #selector(openUpdateTapped)))
        } else {
            menu.addItem(actionItem(title: "检查更新", action: #selector(checkUpdateTapped)))
        }
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
                guard friend.online else {
                    let item = NSMenuItem(title: "\(friend.display_name) 不在家", action: nil, keyEquivalent: "")
                    item.isEnabled = false
                    friendsMenu.addItem(item)
                    continue
                }

                let item = actionItem(title: "\(friend.display_name) 串门", action: #selector(sendTapped(_:)))
                item.representedObject = friend.user_id
                friendsMenu.addItem(item)

                let inviteItem = actionItem(title: "邀请 \(friend.display_name) 来我家", action: #selector(inviteFriendPetTapped(_:)))
                inviteItem.representedObject = friend.user_id
                friendsMenu.addItem(inviteItem)
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

        let dndItem = NSMenuItem(title: "勿扰", action: nil, keyEquivalent: "")
        let dndMenu = NSMenu()
        for (title, minutes) in [("半小时", 30), ("1 小时", 60), ("2 小时", 120)] {
            let item = actionItem(title: title, action: #selector(doNotDisturbTapped(_:)))
            item.representedObject = minutes
            dndMenu.addItem(item)
        }
        dndItem.submenu = dndMenu
        menu.addItem(dndItem)
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
    @objc private func inviteFriendPetTapped(_ sender: NSMenuItem) { onInviteFriendPet?(sender.representedObject as? String ?? "") }
    @objc private func doNotDisturbTapped(_ sender: NSMenuItem) { onDoNotDisturb?(sender.representedObject as? Int ?? 30) }
    @objc private func checkUpdateTapped() { onCheckUpdate?() }
    @objc private func openUpdateTapped() { onOpenUpdate?() }
    @objc private func quitTapped() { onQuit?() ?? NSApp.terminate(nil) }
}

final class PasteFriendlyTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "v":
            if !NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self),
               let text = NSPasteboard.general.string(forType: .string) {
                stringValue += text
            }
            return true
        case "a":
            _ = NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
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
    var knockWindows: [String: KnockRequestWindow] = [:]
    var ballWindow: BallWindow?
    var interactionMenuWindow: InteractionMenuWindow?
    weak var interactionMenuAnchorWindow: PetWindow?
    var interactionMenuFollowTimer: Timer?
    var outgoingVisit: VisitSession?
    var outgoingVisitTargetName: String?
    var friends: [FriendStatus] = []
    var lastEventId = 0
    var handledEventIds: Set<Int> = []
    var pollInFlight = false
    var pollTimer: Timer?
    var activeVisitInvitationIds: Set<String> = []
    var answeredVisitInvitationIds: Set<String> = []
    var lastFriendOnlineNotifiedAt: [String: Date] = [:]
    var localSleepTimer: Timer?
    var localRoamTimer: Timer?
    var localAnimationTimer: Timer?
    var visitorPairTimer: Timer?
    var mousePassthroughTimer: Timer?
    var knockExpiryTimers: [String: Timer] = [:]
    var latestRuntimeReleaseURL: URL?
    var doNotDisturbUntil: Date?

    override init() {
        let args = CommandLine.arguments
        let commandUser = AppDelegate.value(after: "--user", in: args)
        let localIdentity = LocalIdentityStore().loadOrCreate()
        let user = commandUser ?? localIdentity.user_id
        let relayURL = AppDelegate.value(after: "--relay", in: args) ?? "http://127.0.0.1:8787"
        let lifePackPath = AppDelegate.value(after: "--life-pack", in: args)
        userId = user
        identity = commandUser == nil ? localIdentity : LocalIdentity(user_id: user, display_name: user)
        answeredVisitInvitationIds = Set(UserDefaults.standard.stringArray(forKey: "answeredVisitInvitationIds:\(user)") ?? [])
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
        panel.onInviteFriendPet = { [weak self] friend in self?.inviteFriendPet(to: friend) }
        panel.onDoNotDisturb = { [weak self] minutes in self?.enableDoNotDisturb(minutes: minutes) }
        panel.onCheckUpdate = { [weak self] in self?.checkForRuntimeUpdate(silent: false) }
        panel.onOpenUpdate = { [weak self] in self?.openRuntimeReleasePage() }
        panel.onQuit = { [weak self] in self?.quitFromMenu() }

        restorePersistentLogToPanel()
        createLocalPet()
        startMousePassthroughTracking()
        bootstrap()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func quitFromMenu() {
        stopLaunchAgentsForUserQuit()
        NSApp.terminate(nil)
    }

    private func stopLaunchAgentsForUserQuit() {
        let uid = String(getuid())
        let launchAgentDir = NSHomeDirectory() + "/Library/LaunchAgents"
        let commands = [
            ["remove", "com.pety.desktop"],
            ["remove", "com.pety.runtime"],
            ["bootout", "gui/\(uid)", "\(launchAgentDir)/com.pety.desktop.plist"],
            ["bootout", "gui/\(uid)", "\(launchAgentDir)/com.pety.runtime.plist"]
        ]
        for command in commands {
            runLaunchctl(command)
        }
    }

    private func runLaunchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return
        }
    }

    private func startMousePassthroughTracking() {
        mousePassthroughTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updatePetMousePassthrough()
        }
        mousePassthroughTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updatePetMousePassthrough() {
        let mouse = NSEvent.mouseLocation
        let windows = [localWindow] + visitors.values.map { Optional($0.window) }
        for window in windows.compactMap({ $0 }) {
            guard window.isVisible, let view = window.contentView as? PetView else { continue }
            let windowPoint = window.convertPoint(fromScreen: mouse)
            let shouldReceiveMouse = view.isDraggingPet || view.isInteractiveWindowPoint(windowPoint)
            if window.ignoresMouseEvents == shouldReceiveMouse {
                window.ignoresMouseEvents = !shouldReceiveMouse
            }
        }
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
        localWindow = PetWindow(view: view, origin: CGPoint(x: screen.maxX - PetWindow.windowSize.width - 40, y: screen.minY + 140))
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
        localWindow = PetWindow(view: view, origin: origin ?? CGPoint(x: screen.maxX - PetWindow.windowSize.width - 40, y: screen.minY + 140))
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
                    self?.checkForRuntimeUpdate(silent: true)
                case .failure(let error):
                    self?.panel.setStatus("Relay 未连接：\(error.localizedDescription)")
                    self?.log("连接 Relay 失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func registerProfile(completion: ((Bool) -> Void)? = nil) {
        relay.post("api/profiles", body: profileRegistration()) { [weak self] (result: Result<ProfileResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    self?.log("已注册宠物名片：\(response.profile.name) v\(response.profile.profile_version)")
                    completion?(true)
                case .failure(let error):
                    self?.log("注册宠物名片失败：\(error.localizedDescription)")
                    completion?(false)
                }
            }
        }
    }

    private func checkForRuntimeUpdate(silent: Bool) {
        guard let url = URL(string: "https://api.github.com/repos/xllinbupt/pet-y-public/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("PetYDesktop/\(PetYRuntimeVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    if !silent {
                        self.panel.setStatus("检查更新失败")
                        self.log("检查更新失败：\(error.localizedDescription)")
                    }
                    return
                }
                guard let http = response as? HTTPURLResponse, http.statusCode < 400, let data else {
                    if !silent {
                        self.panel.setStatus("检查更新失败")
                        self.log("检查更新失败：GitHub 暂时不可用。")
                    }
                    return
                }
                guard let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                    if !silent {
                        self.panel.setStatus("检查更新失败")
                        self.log("检查更新失败：Release 信息无法读取。")
                    }
                    return
                }
                let releaseURL = release.html_url.flatMap(URL.init(string:))
                if self.isVersion(release.tag_name, newerThan: PetYRuntimeVersion) {
                    self.latestRuntimeReleaseURL = releaseURL
                    self.panel.setUpdateAvailable(version: release.tag_name, url: releaseURL)
                    self.panel.setStatus("有新版本 \(release.tag_name)")
                    self.sayLocal("Pet Y 有新版本啦。")
                    self.log("发现新 Runtime：\(release.tag_name)")
                } else if !silent {
                    self.panel.setUpdateAvailable(version: nil, url: nil)
                    self.panel.setStatus("已经是最新版本")
                    self.sayLocal("已经是最新版本。")
                    self.log("当前 Runtime 已是最新版本。")
                }
            }
        }.resume()
    }

    private func openRuntimeReleasePage() {
        let url = latestRuntimeReleaseURL
            ?? URL(string: "https://github.com/xllinbupt/pet-y-public/releases/latest")!
        NSWorkspace.shared.open(url)
    }

    private func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let left = versionParts(candidate)
        let right = versionParts(current)
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private func versionParts(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".")
            .map { Int($0) ?? 0 }
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

        let input = PasteFriendlyTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.placeholderString = "好友邀请口令"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        NSApp.activate(ignoringOtherApps: true)

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
                    let message = self?.acceptInviteFailureMessage(error) ?? "加好友失败了。"
                    self?.sayLocal(message)
                    self?.log("加好友失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func acceptInviteFailureMessage(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("Invite not found") {
            return "邀请口令失效了，请朋友重新发一个。"
        }
        if text.contains("Cannot add yourself") {
            return "这个是你自己的邀请口令。"
        }
        return "加好友失败了。"
    }

    private func inviteFriendPet(to friendUserId: String) {
        clearDoNotDisturb()
        guard !friendUserId.isEmpty else { return }
        let friendName = friends.first(where: { $0.user_id == friendUserId })?.display_name ?? friendUserId
        closeInteractionMenu()
        sayLocal("我想请 \(friendName) 来家里玩。")
        let body = VisitInvitationRequest(requester_user_id: userId, owner_user_id: friendUserId)
        relay.post("api/visit-invitations", body: body) { [weak self] (result: Result<VisitInvitationResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    if let visit = response.visit, visit.status == "active" {
                        self?.panel.setStatus("\(friendName) 来家里了")
                        self?.log("好友宠物已接受邀请：\(visit.visit_id)")
                    } else {
                        self?.panel.setStatus("正在等 \(friendName) 回复")
                        self?.log("已邀请 \(friendName) 的宠物来家里玩。")
                    }
                case .failure(let error):
                    let text = error.localizedDescription
                    let message = text.contains("正在睡觉") ? "\(friendName) 正在睡觉呢。" : "邀请失败了，等会儿再试。"
                    self?.panel.setStatus(message)
                    self?.sayLocal(message)
                    self?.log("邀请好友宠物失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func sendVisit(to friendUserId: String, displayName: String? = nil) {
        clearDoNotDisturb()
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
        registerProfile { [weak self] registered in
            guard let self else { return }
            guard registered else {
                self.panel.setStatus("宠物名片还没准备好")
                self.sayLocal("我名片没准备好。")
                self.log("串门失败：宠物名片发布失败。")
                return
            }

            let body = VisitRequest(
                pet_id: self.localPet.pet_id,
                owner_user_id: self.userId,
                host_user_id: friendUserId,
                departure_context: ["mood": "curious", "intent": "play"]
            )
            self.relay.post("api/visits", body: body) { [weak self] (result: Result<VisitResponse, Error>) in
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
        guard !pollInFlight else { return }
        pollInFlight = true
        relay.get("api/events/poll?user=\(userId)&after=\(lastEventId)") { [weak self] (result: Result<PollResponse, Error>) in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pollInFlight = false
                if case .success(let response) = result {
                    if let friends = response.friends {
                        self.notifyNewlyOnlineFriends(friends)
                        self.friends = friends
                        self.panel.configure(title: self.panel.title, friends: friends)
                    }
                    for event in response.events {
                        guard self.markEventHandled(event) else { continue }
                        self.handle(event)
                    }
                }
            }
        }
    }

    private func markEventHandled(_ event: RelayEvent) -> Bool {
        guard !handledEventIds.contains(event.id) else { return false }
        handledEventIds.insert(event.id)
        if handledEventIds.count > 300 {
            handledEventIds = Set(handledEventIds.sorted().suffix(200))
        }
        lastEventId = max(lastEventId, event.id)
        return true
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
        case "visit_invitation_requested":
            if let payload = try? decoder.decode(VisitInvitationPayload.self, from: data) {
                answerVisitInvitation(payload)
            }
        case "visit_invitation_status":
            if let invitation = try? decoder.decode(VisitInvitation.self, from: data) {
                if invitation.status == "declined" {
                    panel.setStatus("对方这次不来")
                    sayLocal("对方这次想待在家里。")
                }
            }
        case "visit_started":
            if let payload = try? decoder.decode(VisitStartedPayload.self, from: data) {
                showVisitor(payload)
            }
        case "visit_status":
            if let visit = try? decoder.decode(VisitSession.self, from: data) {
                if visit.owner_user_id == userId {
                    handleOutgoingVisitStatus(visit)
                }
                if visit.host_user_id == userId {
                    handleIncomingVisitStatus(visit)
                }
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
        let duplicateVisitIds = visitors
            .filter { $0.value.visit.pet_id == payload.visit.pet_id && $0.value.visit.owner_user_id == payload.visit.owner_user_id }
            .map { $0.key }
        for visitId in duplicateVisitIds {
            removeVisitor(visitId: visitId)
        }
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

    private func handleIncomingVisitStatus(_ visit: VisitSession) {
        guard visit.status != "pending" else { return }
        closeKnockWindow(visitId: visit.visit_id)
    }

    private func answerVisitRequest(_ payload: VisitStartedPayload) {
        guard payload.visit.status == "pending",
              !isExpiredVisitRequest(payload.visit) else { return }
        if visitors.count >= maxVisitors {
            decideVisitRequest(payload, accept: false, logText: "桌面来访宠物已满，已拒绝 \(payload.profile.name) 来串门。")
            return
        }
        if isDoNotDisturbActive() {
            decideVisitRequest(payload, accept: false, logText: "\(localPet.name) 正在勿扰睡觉，已拒绝 \(payload.profile.name) 来串门。")
            return
        }
        if knockWindows[payload.visit.visit_id] != nil { return }
        let origin = knockOrigin()
        let window = KnockRequestWindow(
            origin: origin,
            petName: payload.profile.name,
            message: "它想来你的桌面玩一会儿。",
            onAccept: { [weak self] in
                self?.closeKnockWindow(visitId: payload.visit.visit_id)
                self?.decideVisitRequest(payload, accept: true, logText: "已同意 \(payload.profile.name) 来串门。")
            },
            onDecline: { [weak self] in
                self?.closeKnockWindow(visitId: payload.visit.visit_id)
                self?.decideVisitRequest(payload, accept: false, logText: "已拒绝 \(payload.profile.name) 来串门。")
            }
        )
        knockWindows[payload.visit.visit_id] = window
        scheduleKnockExpiry(for: payload.visit)
        log("\(payload.profile.name) 正在敲门。")
    }

    private func closeKnockWindow(visitId: String) {
        knockWindows[visitId]?.close()
        knockWindows[visitId] = nil
        knockExpiryTimers[visitId]?.invalidate()
        knockExpiryTimers[visitId] = nil
    }

    private func scheduleKnockExpiry(for visit: VisitSession) {
        guard let expiresAt = visit.request_expires_at,
              let expiry = ISO8601DateFormatter().date(from: expiresAt) else { return }
        let interval = max(0, expiry.timeIntervalSinceNow)
        knockExpiryTimers[visit.visit_id]?.invalidate()
        knockExpiryTimers[visit.visit_id] = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.closeKnockWindow(visitId: visit.visit_id)
        }
    }

    private func isExpiredVisitRequest(_ visit: VisitSession) -> Bool {
        guard let expiresAt = visit.request_expires_at,
              let expiry = ISO8601DateFormatter().date(from: expiresAt) else { return false }
        return Date() > expiry
    }

    private func decideVisitRequest(_ payload: VisitStartedPayload, accept: Bool, logText: String) {
        let body = VisitDecisionRequest(user_id: userId, action: accept ? "accept" : "decline")
        relay.post("api/visits/\(payload.visit.visit_id)/decision", body: body) { [weak self] (result: Result<VisitDecisionResponse, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.log(logText)
                case .failure(let error):
                    self?.log("回应敲门失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func knockOrigin() -> CGPoint {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let anchor = localWindow?.frame ?? NSRect(x: screen.maxX - PetWindow.windowSize.width - 40, y: screen.minY + 140, width: PetWindow.windowSize.width, height: PetWindow.windowSize.height)
        let x = min(max(anchor.midX - 129, screen.minX + 16), screen.maxX - 274)
        let y = min(max(anchor.maxY + 8, screen.minY + 16), screen.maxY - 164)
        return CGPoint(x: x, y: y)
    }

    private func answerVisitInvitation(_ payload: VisitInvitationPayload) {
        let requestId = payload.invitation.request_id
        guard payload.invitation.status == "pending",
              !isExpiredVisitInvitation(payload.invitation),
              !activeVisitInvitationIds.contains(requestId),
              !answeredVisitInvitationIds.contains(requestId) else { return }
        activeVisitInvitationIds.insert(requestId)
        let requesterName = payload.requester?.display_name ?? payload.invitation.requester_user_id
        if isDoNotDisturbActive() {
            decideVisitInvitation(payload.invitation, accept: false, requesterName: requesterName)
            return
        }
        let alert = NSAlert()
        alert.icon = NSImage(systemSymbolName: "pawprint", accessibilityDescription: "邀请")
        alert.messageText = "\(requesterName) 邀请 \(localPet.name) 去玩"
        alert.informativeText = "同意后，\(localPet.name) 会去对方桌面串门。"
        alert.addButton(withTitle: "去玩")
        alert.addButton(withTitle: "留在家")
        let accepted = alert.runModal() == .alertFirstButtonReturn
        decideVisitInvitation(payload.invitation, accept: accepted, requesterName: requesterName)
    }

    private func isExpiredVisitInvitation(_ invitation: VisitInvitation) -> Bool {
        guard let expiresAt = invitation.expires_at,
              let expiry = ISO8601DateFormatter().date(from: expiresAt) else { return false }
        return Date() > expiry
    }

    private func decideVisitInvitation(_ invitation: VisitInvitation, accept: Bool, requesterName: String) {
        markVisitInvitationAnswered(invitation.request_id)
        let body = VisitDecisionRequest(user_id: userId, action: accept ? "accept" : "decline")
        relay.post("api/visit-invitations/\(invitation.request_id)/decision", body: body) { [weak self] (result: Result<VisitInvitationResponse, Error>) in
            DispatchQueue.main.async {
                self?.activeVisitInvitationIds.remove(invitation.request_id)
                switch result {
                case .success(let response):
                    if accept, let visit = response.visit {
                        self?.outgoingVisit = visit
                        self?.outgoingVisitTargetName = requesterName
                        self?.showAwaySign(to: requesterName)
                        self?.panel.setStatus("\(self?.localPet.name ?? "宠物") 已出门")
                    }
                    self?.log(accept ? "已同意去 \(requesterName) 家玩。" : "已拒绝 \(requesterName) 的邀请。")
                case .failure(let error):
                    self?.log("回应邀请失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func markVisitInvitationAnswered(_ requestId: String) {
        answeredVisitInvitationIds.insert(requestId)
        if answeredVisitInvitationIds.count > 300 {
            answeredVisitInvitationIds = Set(answeredVisitInvitationIds.sorted().suffix(200))
        }
        UserDefaults.standard.set(Array(answeredVisitInvitationIds), forKey: "answeredVisitInvitationIds:\(userId)")
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
        actions.append(PetAction(title: "勿扰") { [weak self] in
            self?.showDoNotDisturbActions()
        })
        showInteractionMenu(anchor: localWindow, actions: actions)
    }

    private func showDoNotDisturbActions() {
        guard let localWindow else { return }
        closeInteractionMenu()
        let actions = [
            PetAction(title: "半小时") { [weak self] in
                self?.closeInteractionMenu()
                self?.enableDoNotDisturb(minutes: 30)
            },
            PetAction(title: "1 小时") { [weak self] in
                self?.closeInteractionMenu()
                self?.enableDoNotDisturb(minutes: 60)
            },
            PetAction(title: "2 小时") { [weak self] in
                self?.closeInteractionMenu()
                self?.enableDoNotDisturb(minutes: 120)
            }
        ]
        showInteractionMenu(anchor: localWindow, actions: actions)
    }

    private func showFriendActions() {
        guard let localWindow else { return }
        closeInteractionMenu()
        var actions: [PetAction] = []
        for friend in friends {
            if friend.online {
                actions.append(PetAction(title: friend.display_name) { [weak self] in
                    self?.showFriendActionPicker(friend)
                })
            } else {
                actions.append(PetAction(title: friend.display_name, isEnabled: false) {})
            }
        }
        actions.append(PetAction(title: "发邀请") { [weak self] in
            self?.closeInteractionMenu()
            self?.shareInvite()
        })
        actions.append(PetAction(title: "加好友") { [weak self] in
            self?.closeInteractionMenu()
            self?.promptForInvite()
        })
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
        if friends.isEmpty {
            sayLocal("还没有好友，可以先邀请朋友。")
        } else if friends.filter({ $0.online }).isEmpty {
            sayLocal("好友现在都不在家。")
        } else {
            sayLocal("想找哪个朋友？")
        }
        showInteractionMenu(anchor: localWindow, actions: actions)
    }

    private func showFriendActionPicker(_ friend: FriendStatus) {
        guard let localWindow else { return }
        closeInteractionMenu()
        guard friend.online else {
            sayLocal("\(friend.display_name) 现在不在家。")
            return
        }
        var actions = [
            PetAction(title: "去串门") { [weak self] in
                self?.sayLocal("我去问问 \(friend.display_name) 在不在家。")
                self?.sendVisit(to: friend.user_id, displayName: friend.display_name)
            },
            PetAction(title: "邀请好友来") { [weak self] in
                self?.inviteFriendPet(to: friend.user_id)
            }
        ]
        actions.append(PetAction(title: "返回") { [weak self] in
            self?.showFriendActions()
        })
        sayLocal("想和 \(friend.display_name) 做什么？")
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
        if localWindow != nil {
            actions.append(PetAction(title: "一起睡") { [weak self] in
                self?.closeInteractionMenu()
                self?.sleepTogetherWithVisitor(visitId: visitId)
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

    private func menuOrigin(for petFrame: NSRect, actions: [PetAction], layout: InteractionMenuLayout = .horizontal) -> CGPoint {
        let size = InteractionMenuView.menuSize(for: InteractionMenuView.buttonWidths(for: actions, layout: layout), layout: layout)
        return menuOrigin(for: petFrame, menuSize: size)
    }

    private func menuOrigin(for petFrame: NSRect, menuSize: CGSize) -> CGPoint {
        CGPoint(x: petFrame.midX - menuSize.width / 2, y: petFrame.minY - menuSize.height - 12)
    }

    private func showInteractionMenu(anchor: PetWindow, actions: [PetAction], layout: InteractionMenuLayout = .horizontal) {
        closeInteractionMenu()
        let menu = InteractionMenuWindow(origin: menuOrigin(for: anchor.frame, actions: actions, layout: layout), actions: actions, layout: layout)
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
            let origin = self.menuOrigin(for: anchor.frame, menuSize: menu.frame.size)
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
        clearDoNotDisturb()
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

    private func enableDoNotDisturb(minutes: Int) {
        guard let localWindow else { return }
        closeInteractionMenu()
        let until = Date().addingTimeInterval(TimeInterval(minutes * 60))
        doNotDisturbUntil = until
        localSleepTimer?.invalidate()
        localRoamTimer?.invalidate()
        localAnimationTimer?.invalidate()
        for (_, visitor) in visitors {
            visitor.roamTimer?.invalidate()
        }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let target = CGPoint(x: screen.minX + 24, y: screen.minY + 24)
        playLocal(.move)
        animateLocalPet(to: target, duration: localMoveDuration(from: localWindow.frame.origin, to: target, speed: 240, minimum: 0.8, maximum: 2.8)) { [weak self] in
            guard let self else { return }
            self.playLocal(.sleep)
            self.sayLocal("勿扰中，我睡一会儿。")
        }
        panel.setStatus("勿扰到 \(DateFormatter.localizedString(from: until, dateStyle: .none, timeStyle: .short))")
        updateDoNotDisturbRelay(until: until)
        localSleepTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            self?.clearDoNotDisturb()
        }
        remember("\(localPet.name) 开始勿扰睡觉。")
    }

    private func clearDoNotDisturb() {
        guard doNotDisturbUntil != nil else { return }
        doNotDisturbUntil = nil
        localSleepTimer?.invalidate()
        localSleepTimer = nil
        panel.setStatus("已连接 Relay")
        sayLocal("我醒啦。")
        updateDoNotDisturbRelay(until: nil)
        scheduleLocalSleep()
        scheduleLocalRoam()
    }

    private func isDoNotDisturbActive() -> Bool {
        guard let until = doNotDisturbUntil else { return false }
        if Date() < until { return true }
        clearDoNotDisturb()
        return false
    }

    private func updateDoNotDisturbRelay(until: Date?) {
        let formatter = ISO8601DateFormatter()
        let body = DoNotDisturbRequest(user_id: userId, until: until.map { formatter.string(from: $0) })
        relay.post("api/users/\(userId)/do-not-disturb", body: body) { [weak self] (result: Result<DoNotDisturbResponse, Error>) in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    self?.log("勿扰状态同步失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func playSignatureAction() {
        clearDoNotDisturb()
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

        let input = PasteFriendlyTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "想说的话"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        NSApp.activate(ignoringOtherApps: true)

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

        let messageLines = messages
            .prefix(3)
            .enumerated()
            .map { index, message in
                let author = message.author_name?.isEmpty == false ? message.author_name! : "朋友"
                return "\(index + 1). \(author)：\(message.text.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
        var bubbleText = "我回来了：\(receipt.pet_voice)\n留言：\(messageLines.joined(separator: " / "))"
        if messages.count > 3 {
            bubbleText += " / 还有 \(messages.count - 3) 条"
        }
        sayLocal(String(bubbleText.prefix(180)))
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
            self.playLocal(.rest, returnToIdleAfter: 8.0)
            self.playVisitorRest(visitId: visitId, returnToIdleAfter: 8.0)
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

    private func sleepTogetherWithVisitor(visitId: String) {
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
        let targetX = min(max(localStart.x + 86, screen.minX + 40), screen.maxX - 170)
        let visitorTarget = CGPoint(x: targetX, y: min(max(localStart.y, screen.minY + 70), screen.maxY - 170))
        let duration = localMoveDuration(from: visitorStart, to: visitorTarget, speed: 260, minimum: 0.8, maximum: 2.4)

        sayLocal("一起睡一会儿吧。")
        (visitorWindow.contentView as? PetView)?.say("好呀。")
        playLocal(.sleep)
        playVisitorMove(visitId: visitId)
        recordVisitEvent(
            visitId: visitId,
            type: "pet_to_pet.sleep_together",
            data: [
                "local_pet_id": localPet.pet_id,
                "visitor_pet_id": visitor.visit.pet_id,
                "from_x": "\(Int(visitorStart.x))",
                "from_y": "\(Int(visitorStart.y))",
                "to_x": "\(Int(visitorTarget.x))",
                "to_y": "\(Int(visitorTarget.y))"
            ]
        )

        animateVisitorPet(visitId: visitId, to: visitorTarget, duration: duration) { [weak self] in
            self?.playLocal(.sleep)
            self?.playVisitorSleep(visitId: visitId)
            self?.remember("\(self?.localPet.name ?? "宠物") 和来访的小客人一起睡了一会儿。")
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

    private func playVisitorSleep(visitId: String) {
        guard let visitorView = visitors[visitId]?.window.contentView as? PetView else { return }
        for state in ["sleep", "rest", "sit", "idle"] {
            if visitorView.animationStates[state] != nil {
                visitorView.play(state)
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
        clearDoNotDisturb()
        guard let localWindow else { return }
        closeInteractionMenu()
        localSleepTimer?.invalidate()
        localRoamTimer?.invalidate()

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let start = localWindow.frame.origin
        let farX = start.x < screen.midX ? screen.maxX - PetWindow.windowSize.width - 40 : screen.minX + 120
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
        let x = CGFloat.random(in: (screen.minX + 80)...(screen.maxX - PetWindow.windowSize.width - 40))
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
        let x = CGFloat.random(in: (screen.minX + 80)...(screen.maxX - PetWindow.windowSize.width - 40))
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

struct VisitInvitationRequest: Codable {
    let requester_user_id: String
    let owner_user_id: String
}

struct VisitInvitationResponse: Codable {
    let invitation: VisitInvitation?
    let visit: VisitSession?
}

struct VisitDecisionRequest: Codable {
    let user_id: String
    let action: String
}

struct DoNotDisturbRequest: Codable {
    let user_id: String
    let until: String?
}

struct DoNotDisturbResponse: Codable {
    let user_id: String
    let do_not_disturb_until: String?
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

func ensureSingleInstance() {
    let dir = NSHomeDirectory() + "/Library/Application Support/PetY"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let lockPath = dir + "/petydesktop.lock"
    let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
    guard fd != -1 else { return }
    if flock(fd, LOCK_EX | LOCK_NB) != 0 {
        FileHandle.standardError.write(Data("PetYDesktop already running; exiting duplicate.\n".utf8))
        exit(0)
    }
    // Intentionally keep fd open for the process lifetime so the lock is held
    // until this instance exits; the OS releases it automatically on exit/crash.
}

ensureSingleInstance()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
