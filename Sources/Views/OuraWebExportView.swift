import SwiftUI
import WebKit

// MARK: - State machine

enum OuraWebPhase: Equatable {
    case login
    case navigatingToExport
    case exportPage
    case downloading(Double)   // 0…1 progress
    case processing
    case done(Int)             // days imported
    case failed(String)

    var statusText: String {
        switch self {
        case .login:                return "Sign in to your Oura account"
        case .navigatingToExport:   return "Navigating to export page…"
        case .exportPage:           return "Tap \"Download data\" on the page below"
        case .downloading(let p):   return p > 0 ? "Downloading… \(Int(p * 100))%" : "Downloading…"
        case .processing:           return "Parsing export data…"
        case .done(let d):          return "✓ \(d) days imported"
        case .failed(let e):        return "Error: \(e)"
        }
    }

    var isTerminal: Bool {
        if case .done = self { return true }
        if case .failed = self { return true }
        return false
    }

    var accentColor: Color {
        switch self {
        case .done:   return .ouraActivity
        case .failed: return .ouraStress
        default:      return Color(red: 0.72, green: 0.55, blue: 0.98)
        }
    }
}

// MARK: - WKWebView representable

struct OuraWebView: UIViewRepresentable {
    @Binding var phase: OuraWebPhase
    let onResult: (OuraExportResult) -> Void
    let onError:  (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(phase: $phase, onResult: onResult, onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()   // persists cookies across sessions

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = wv

        wv.load(URLRequest(url: URL(string: "https://membership.ouraring.com")!))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        @Binding var phase: OuraWebPhase
        let onResult: (OuraExportResult) -> Void
        let onError:  (String) -> Void
        weak var webView: WKWebView?
        private var downloadDest: URL?

        init(phase: Binding<OuraWebPhase>,
             onResult: @escaping (OuraExportResult) -> Void,
             onError:  @escaping (String) -> Void) {
            _phase    = phase
            self.onResult = onResult
            self.onError  = onError
        }

        // MARK: Navigation

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url?.absoluteString else { return }
            DispatchQueue.main.async { self.handleURLChange(url, webView: webView) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            // Ignore "Frame load interrupted" — that's our download interception working
            let nsErr = error as NSError
            if nsErr.code == NSURLErrorCancelled { return }
        }

        private func handleURLChange(_ url: String, webView: WKWebView) {
            if url.contains("/data-export") {
                phase = .exportPage
            } else if isLoggedIn(url: url) && phase == .login {
                phase = .navigatingToExport
                webView.load(URLRequest(
                    url: URL(string: "https://membership.ouraring.com/data-export")!
                ))
            } else if url.contains("membership.ouraring.com") &&
                      !url.contains("login") && !url.contains("authn") &&
                      phase == .login {
                phase = .navigatingToExport
                webView.load(URLRequest(
                    url: URL(string: "https://membership.ouraring.com/data-export")!
                ))
            }
        }

        private func isLoggedIn(url: String) -> Bool {
            let lower = url.lowercased()
            return lower.contains("membership.ouraring.com") &&
                   !lower.contains("login") &&
                   !lower.contains("authn") &&
                   !lower.contains("oauth")
        }

        // MARK: Download interception — response policy

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            guard let http = navigationResponse.response as? HTTPURLResponse,
                  let url  = navigationResponse.response.url else {
                decisionHandler(.allow)
                return
            }

            let ct  = http.allHeaderFields["Content-Type"]  as? String ?? ""
            let cd  = http.allHeaderFields["Content-Disposition"] as? String ?? ""

            if ct.contains("zip") || ct.contains("octet-stream") || cd.contains("attachment") {
                decisionHandler(.cancel)
                DispatchQueue.main.async { self.phase = .downloading(0) }
                downloadUsingCookies(url: url, webView: webView)
                return
            }
            decisionHandler(.allow)
        }

        // WKDownloadDelegate path (iOS 14.5+, preferred)
        func webView(_ webView: WKWebView,
                     navigationAction: WKNavigationAction,
                     didBecome download: WKDownload) {
            download.delegate = self
            DispatchQueue.main.async { self.phase = .downloading(0) }
        }

        func webView(_ webView: WKWebView,
                     navigationResponse: WKNavigationResponse,
                     didBecome download: WKDownload) {
            download.delegate = self
            DispatchQueue.main.async { self.phase = .downloading(0) }
        }

        // MARK: WKDownloadDelegate

        func download(_ download: WKDownload,
                      decideDestinationUsing response: URLResponse,
                      suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {
            let name = suggestedFilename.isEmpty ? "oura_export.zip" : suggestedFilename
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: dest)
            downloadDest = dest
            completionHandler(dest)
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let dest = downloadDest else { return }
            parseZIP(at: dest)
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            DispatchQueue.main.async { self.onError(error.localizedDescription) }
        }

        // MARK: Cookie-based fallback download

        private func downloadUsingCookies(url: URL, webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                var req = URLRequest(url: url)
                req.timeoutInterval = 120
                HTTPCookie.requestHeaderFields(with: cookies).forEach {
                    req.addValue($0.value, forHTTPHeaderField: $0.key)
                }

                let task = URLSession.shared.downloadTask(with: req) { tmpURL, resp, error in
                    if let error = error {
                        DispatchQueue.main.async { self.onError(error.localizedDescription) }
                        return
                    }
                    guard let tmpURL else {
                        DispatchQueue.main.async { self.onError("Download returned no file") }
                        return
                    }
                    let dest = FileManager.default.temporaryDirectory
                        .appendingPathComponent("oura_export.zip")
                    try? FileManager.default.removeItem(at: dest)
                    do {
                        try FileManager.default.moveItem(at: tmpURL, to: dest)
                        self.parseZIP(at: dest)
                    } catch {
                        DispatchQueue.main.async { self.onError(error.localizedDescription) }
                    }
                }
                task.resume()
            }
        }

        // MARK: Parse

        private func parseZIP(at url: URL) {
            DispatchQueue.main.async { self.phase = .processing }
            Task {
                do {
                    let result = try OuraExportParser.parse(zipURL: url)
                    try? FileManager.default.removeItem(at: url)
                    await MainActor.run {
                        self.phase = .done(result.daysImported)
                        self.onResult(result)
                    }
                } catch {
                    try? FileManager.default.removeItem(at: url)
                    await MainActor.run {
                        self.onError(error.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - Full screen view

struct OuraWebExportView: View {
    @EnvironmentObject var viewModel: SyncViewModel
    @Environment(\.dismiss)  private var dismiss
    @State private var phase: OuraWebPhase = .login

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // WebView fills whole screen
                OuraWebView(
                    phase: $phase,
                    onResult: { result in
                        Task { await viewModel.applyExportResult(result) }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { dismiss() }
                    },
                    onError: { err in
                        viewModel.importError = err
                        dismiss()
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // Status banner
                statusBanner
            }
            .navigationTitle("Oura Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(Color.surfaceBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Status banner

    private var statusBanner: some View {
        HStack(spacing: 10) {
            // Icon / spinner
            Group {
                switch phase {
                case .login:
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(phase.accentColor)
                case .navigatingToExport, .processing:
                    ProgressView()
                        .tint(phase.accentColor)
                        .scaleEffect(0.85)
                case .exportPage:
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(phase.accentColor)
                case .downloading(let p):
                    ZStack {
                        Circle()
                            .stroke(phase.accentColor.opacity(0.2), lineWidth: 3)
                            .frame(width: 22, height: 22)
                        Circle()
                            .trim(from: 0, to: CGFloat(p))
                            .stroke(phase.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 22, height: 22)
                            .rotationEffect(.degrees(-90))
                    }
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(phase.accentColor)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(phase.accentColor)
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 24)

            Text(phase.statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.25), value: phase.statusText)
    }
}
