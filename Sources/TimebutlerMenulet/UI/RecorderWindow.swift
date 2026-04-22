import SwiftUI
import WebKit
import Combine

@MainActor
final class RecorderModel: NSObject, ObservableObject, WKScriptMessageHandler {
    struct Captured: Equatable, Identifiable {
        let id = UUID()
        let at: Date
        let kind: String
        let method: String
        let url: String
        let body: String?
    }

    @Published var recent: [Captured] = []
    @Published var assignments: [TimebutlerAction: Captured] = [:]
    @Published var hideRepeats: Bool = true
    @Published var selectedID: UUID?

    let config: WKWebViewConfiguration

    init(session: SessionManager, sniffer: String) {
        let ucc = WKUserContentController()
        let script = WKUserScript(source: sniffer, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        ucc.addUserScript(script)
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = session.dataStore
        cfg.userContentController = ucc
        self.config = cfg
        super.init()
        ucc.add(self, name: "tb")
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "tb", let dict = message.body as? [String: Any] else { return }
        let captured = Captured(
            at: Date(),
            kind: dict["kind"] as? String ?? "?",
            method: (dict["method"] as? String ?? "GET").uppercased(),
            url: dict["url"] as? String ?? "",
            body: dict["body"] as? String
        )
        push(captured)
    }

    private func push(_ c: Captured) {
        recent.insert(c, at: 0)
        if recent.count > 400 { recent.removeLast(recent.count - 400) }
    }

    func registerNavigation(_ url: URL) {
        push(Captured(at: Date(), kind: "nav", method: "GET", url: url.absoluteString, body: nil))
    }

    var filtered: [Captured] {
        guard hideRepeats else { return recent }
        var seen = Set<String>()
        var out: [Captured] = []
        for c in recent {
            let key = "\(c.kind)|\(c.method)|\(EndpointRegistry.stripCacheBuster(c.url))|\(c.body ?? "")"
            if seen.insert(key).inserted { out.append(c) }
        }
        return out
    }

    func assign(_ action: TimebutlerAction, _ c: Captured) {
        assignments[action] = c
    }

    func clearCaptures() {
        recent.removeAll()
        selectedID = nil
    }

    func save() {
        var reg = EndpointRegistry.load()
        for (action, c) in assignments {
            reg.set(action, EndpointRegistry.Endpoint(
                method: c.method,
                url: EndpointRegistry.templatizeURL(c.url),
                body: EndpointRegistry.templatize(c.body)
            ))
        }
        reg.save()
    }
}

struct RecorderWindow: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        RecorderContent(model: state.recorderModel)
    }
}

struct RecorderContent: View {
    @ObservedObject var model: RecorderModel
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            WebViewHost(
                url: URL(string: "https://app.timebutler.com/")!,
                config: model.config,
                onCommit: { url in model.registerNavigation(url) }
            )
            .frame(minHeight: 420)

            Divider()

            HStack {
                Toggle("Hide polling repeats", isOn: $model.hideRepeats)
                    .toggleStyle(.checkbox)
                Spacer()
                Text("\(model.recent.count) captured")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear") { model.clearCaptures() }
                    .disabled(model.recent.isEmpty)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)

            List(selection: $model.selectedID) {
                ForEach(model.filtered) { c in
                    captureRow(c)
                        .tag(c.id)
                }
            }
            .frame(minHeight: 180)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Assignments").font(.caption).foregroundStyle(.secondary).padding(.leading, 10)
                ForEach(TimebutlerAction.allCases, id: \.self) { a in
                    HStack(alignment: .top, spacing: 8) {
                        Text(a.displayName).bold().frame(width: 80, alignment: .leading)
                        if let c = model.assignments[a] {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(c.method)  \(c.url)").font(.caption.monospaced()).lineLimit(2)
                                if let b = c.body, !b.isEmpty {
                                    Text(b).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        } else if state.endpoints.has(a) {
                            Text("saved previously — reassign to overwrite")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("unset").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                }
            }
            .padding(.vertical, 6)

            HStack {
                Spacer()
                Button("Clear pending") { model.assignments.removeAll() }
                    .disabled(model.assignments.isEmpty)
                Button("Save to endpoints.json") {
                    model.save()
                    state.reloadEndpoints()
                    model.assignments.removeAll()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.assignments.isEmpty)
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private func captureRow(_ c: RecorderModel.Captured) -> some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(c.kind.uppercased())
                        .font(.caption2.monospaced())
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.2)))
                    Text(c.method)
                        .font(.caption2.monospaced()).bold()
                    Text(timeString(c.at))
                        .font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                Text(c.url)
                    .font(.caption.monospaced())
                    .lineLimit(1).truncationMode(.middle)
                if let b = c.body, !b.isEmpty {
                    Text(b)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2).truncationMode(.tail)
                }
            }
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                ForEach(TimebutlerAction.allCases, id: \.self) { a in
                    Button(shortLabel(a)) { model.assign(a, c) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Assign to \(a.displayName)")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func shortLabel(_ a: TimebutlerAction) -> String {
        switch a {
        case .checkIn:  return "→ In"
        case .pause:    return "→ Pause"
        case .resume:   return "→ Resume"
        case .checkOut: return "→ Out"
        }
    }

    private func timeString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }
}
