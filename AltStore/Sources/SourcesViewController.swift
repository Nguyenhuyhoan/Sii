
//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 3/17/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SwiftUI
@preconcurrency import WebKit
import CoreData
import Nuke

// MARK: - 🧊 BỘ GIAO DIỆN "NORDIC COOL MINIMALIST" (TÔNG LẠNH MÁT MẮT, TỐI GIẢN, SANG TRỌNG)
private struct CoolMinimalTheme {
    // Nền tổng thể: Xám xanh băng giá dịu mắt
    static let bgTop = UIColor(red: 243/255, green: 247/255, blue: 251/255, alpha: 1.0).cgColor      // #F3F7FB
    static let bgBottom = UIColor(red: 234/255, green: 242/255, blue: 248/255, alpha: 1.0).cgColor   // #EAF2F8

    // Bề mặt thẻ & khối nội dung
    static let surfaceWhite = UIColor.white                                                          // #FFFFFF
    static let surfaceSubtle = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1.0)      // #F8FAFC
    static let iceBadgeBg = UIColor(red: 224/255, green: 242/255, blue: 254/255, alpha: 1.0)         // #E0F2FE

    // Đường viền mảnh tinh tế
    static let hairlineBorder = UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0)     // #E2E8F0
    static let dividerLine = UIColor(red: 241/255, green: 245/255, blue: 249/255, alpha: 1.0)        // #F1F5F9

    // Hệ thống chữ (Typography)
    static let inkPrimary = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)            // #0F172A (Đen xanh than)
    static let inkSecondary = UIColor(red: 71/255, green: 85/255, blue: 105/255, alpha: 1.0)         // #475569 (Xám đá lạnh)
    static let inkMuted = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)           // #94A3B8 (Xám sương mù)

    // Điểm nhấn tông lạnh (Cool Ocean & Teal)
    static let accentOcean = UIColor(red: 2/255, green: 132/255, blue: 199/255, alpha: 1.0)          // #0284C7 (Xanh lam lạnh)
    static let accentDeepBlue = UIColor(red: 3/255, green: 105/255, blue: 161/255, alpha: 1.0)       // #0369A1 (Xanh biển sâu)
    static let accentTeal = UIColor(red: 13/255, green: 148/255, blue: 136/255, alpha: 1.0)          // #0D9488 (Xanh ngọc bích trầm)

    static let cardCornerRadius: CGFloat = 16.0
    static let innerCornerRadius: CGFloat = 12.0
    static let mediaCornerRadius: CGFloat = 18.0

    static func applyMinimalCard(to view: UIView, radius: CGFloat = CoolMinimalTheme.cardCornerRadius) {
        view.backgroundColor = surfaceWhite
        view.layer.cornerRadius = radius
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.borderWidth = 1.0
        view.layer.borderColor = hairlineBorder.cgColor
        view.layer.shadowColor = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.layer.shadowOpacity = 0.035
    }
}

// MARK: - 🎬 CÁC THÀNH PHẦN VIDEO YOUTUBE (PHONG CÁCH TỐI GIẢN, MÁT MẮT, GỌN GÀNG)
private enum MinimalVideoTheme {
    static let accent = SwiftUI.Color(red: 2/255, green: 132/255, blue: 199/255)        // #0284C7
    static let inkPrimary = SwiftUI.Color(red: 15/255, green: 23/255, blue: 42/255)     // #0F172A
    static let inkSecondary = SwiftUI.Color(red: 71/255, green: 85/255, blue: 105/255)  // #475569
    static let surfaceWhite = SwiftUI.Color.white
    static let surfaceSubtle = SwiftUI.Color(red: 248/255, green: 250/255, blue: 252/255)
    static let border = SwiftUI.Color(red: 226/255, green: 232/255, blue: 240/255)
    static let frameCornerRadius: CGFloat = 28.0
}

/// Khung phát video dọc tỉ lệ 9:19.5 tinh gọn, sang trọng
private struct MinimalVerticalVideoFrameView: SwiftUI.View {
    let videoID: String
    @State private var isVisibleOnScreen: Bool = false
    @State private var shouldMountWebView: Bool = false
    @State private var mountTask: Task<Void, Never>? = nil

    var body: some SwiftUI.View {
        ZStack {
            SwiftUI.Color.black
            if shouldMountWebView {
                MinimalYouTubePlayerWebView(
                    videoID: videoID,
                    isVisibleOnScreen: isVisibleOnScreen
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(MinimalVideoTheme.accent)
            }
        }
        .aspectRatio(9.0 / 19.5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: MinimalVideoTheme.frameCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MinimalVideoTheme.frameCornerRadius, style: .continuous)
                .strokeBorder(MinimalVideoTheme.border, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
        .onAppear {
            isVisibleOnScreen = true
            if !shouldMountWebView {
                mountTask?.cancel()
                mountTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    guard !Task.isCancelled, isVisibleOnScreen else { return }
                    shouldMountWebView = true
                }
            }
        }
        .onDisappear {
            isVisibleOnScreen = false
            mountTask?.cancel()
            mountTask = nil
        }
    }
}

/// WebView nhúng trình phát YouTube
private struct MinimalYouTubePlayerWebView: UIViewRepresentable {
    let videoID: String
    let isVisibleOnScreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [.all]
        config.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if !isVisibleOnScreen {
            uiView.evaluateJavaScript(
                "var iframe = document.querySelector('iframe'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage('{\"event\":\"command\",\"func\":\"pauseVideo\",\"args\":\"\"}', '*'); }",
                completionHandler: nil
            )
            return
        }

        guard context.coordinator.loadedVideoID != videoID else { return }
        context.coordinator.loadedVideoID = videoID

        let originDomain = "https://sidestore.io"
        let embedURL = "https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1&fs=1&enablejsapi=1&origin=\(originDomain)"

        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html, body {
                width: 100%;
                height: 100%;
                background-color: #000000;
                overflow: hidden;
            }
            .video-container {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background-color: #000000;
            }
            iframe {
                width: 100%;
                height: 100%;
                border: 0;
            }
        </style>
        </head>
        <body>
            <div class="video-container">
                <iframe
                    src="\(embedURL)"
                    title="YouTube video player"
                    referrerpolicy="strict-origin-when-cross-origin"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                    allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """

        uiView.loadHTMLString(embedHTML, baseURL: URL(string: originDomain))
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        if #available(iOS 15.0, tvOS 15.0, *) {
            uiView.pauseAllMediaPlayback()
        }
    }

    final class Coordinator {
        var loadedVideoID: String?
    }
}

/// Khối thẻ Video hướng dẫn gọn gàng
private struct MinimalVideoGuideSectionView: SwiftUI.View {
    let videoID: String

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(MinimalVideoTheme.accent.opacity(0.12))
                        .frame(width: 32, height: 32)
                    SwiftUI.Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MinimalVideoTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    SwiftUI.Text("Video hướng dẫn trực quan")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(MinimalVideoTheme.inkPrimary)
                    SwiftUI.Text("Nhấn vào khung bên dưới để xem thao tác chi tiết")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(MinimalVideoTheme.inkSecondary)
                }
                Spacer()
            }

            MinimalVerticalVideoFrameView(videoID: videoID)
        }
        .padding(16)
        .background(MinimalVideoTheme.surfaceWhite)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MinimalVideoTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 10, x: 0, y: 4)
    }
}

private final class OverviewHostedVideoSectionView: UIView {
    private let hostingController: UIHostingController<MinimalVideoGuideSectionView>

    init(videoID: String, parentViewController: UIViewController?) {
        let rootView = MinimalVideoGuideSectionView(videoID: videoID)
        self.hostingController = UIHostingController(rootView: rootView)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        hostingController.overrideUserInterfaceStyle = .light
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        if let parentVC = parentViewController {
            parentVC.addChild(hostingController)
        }

        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if let parentVC = parentViewController {
            hostingController.didMove(toParent: parentVC)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - 🧊 LỚP NỀN BĂNG SƯƠNG MÁT MẮT CỐ ĐỊNH
private final class SourcesCoolBackgroundView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    private func setupGradient() {
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        gradientLayer.colors = [CoolMinimalTheme.bgTop, CoolMinimalTheme.bgBottom]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
    }
}

// Giữ nguyên class này để Storyboard không bao giờ báo lỗi thiếu class khi load Nib
@objc(SourcesFooterView)
private final class SourcesFooterView: TextCollectionReusableView {
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet var textView: UITextView!
}

// MARK: - 📚 MÔ HÌNH DỮ LIỆU & BỘ PHÂN TÍCH HƯỚNG DẪN TỪ GITHUB (GIỮ NGUYÊN 100% LOGIC GỐC)
private struct GuideContentBlock: Hashable {
    enum BlockType: Hashable {
        case text(String)
        case image(URL)
        case youtube(String)
        case download(URL)
    }
    let id = UUID()
    let type: BlockType
}

private struct GuideArticle: Hashable {
    let id = UUID()
    let orderNumber: Int
    let title: String
    let blocks: [GuideContentBlock]

    var stepCount: Int {
        var count = 0
        for block in blocks {
            if case .text(let str) = block.type {
                let lines = str
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                count += lines.count
            }
        }
        return count
    }

    var imageCount: Int {
        return blocks.filter {
            if case .image = $0.type { return true }
            return false
        }.count
    }

    var videoCount: Int {
        return blocks.filter {
            if case .youtube = $0.type { return true }
            return false
        }.count
    }

    var downloadCount: Int {
        return blocks.filter {
            if case .download = $0.type { return true }
            return false
        }.count
    }

    var previewSubtitle: String {
        for block in blocks {
            if case .text(let text) = block.type {
                let firstLine = text
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }
                if let line = firstLine {
                    return GuideParser.stripLeadingNumberOrBullet(from: line)
                }
            }
        }
        return "Xem chi tiết hướng dẫn thực hiện từng bước"
    }

    var cleanSummaryMeta: String {
        var parts: [String] = []
        if stepCount > 0 {
            parts.append("\(stepCount) bước")
        }
        if imageCount > 0 {
            parts.append("\(imageCount) ảnh")
        }
        if videoCount > 0 {
            parts.append("Video")
        }
        if downloadCount > 0 {
            parts.append("Tệp tải")
        }
        return parts.isEmpty ? "Chi tiết" : parts.joined(separator: " • ")
    }

    var searchableContent: String {
        var parts: [String] = [title, "#\(orderNumber)"]
        for block in blocks {
            if case .text(let str) = block.type {
                parts.append(str)
            }
        }
        return parts.joined(separator: " ").lowercased()
    }
}

private enum GuideParser {
    static let githubGuideURL = "https://github.com/Nguyenhuyhoan/Config/blob/main/huongdan.txt"

    private enum DetectedLinkType {
        case githubImage(URL)
        case youtubeVideo(String)
        case downloadLink(URL)
    }

    static func stripLeadingNumberOrBullet(from line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(?:(?:\d+[\.\)\:\-]?)|(?:[•\-\*\+]))\s*"#
        if let range = cleaned.range(of: pattern, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func cleanCandidateURLString(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let leadingChars = CharacterSet(charactersIn: "<>\"'()[]{}")
        let trailingChars = CharacterSet(charactersIn: "<>\"'()[]{}.,;!")
        cleaned = cleaned.trimmingCharacters(in: leadingChars)
        while let last = cleaned.unicodeScalars.last, trailingChars.contains(last) {
            cleaned.removeLast()
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func convertToRawGitHubURL(_ urlString: String) -> URL? {
        var cleaned = cleanCandidateURLString(urlString)
        guard !cleaned.isEmpty else { return nil }

        if cleaned.contains("github.com") {
            cleaned = cleaned
                .replacingOccurrences(of: "http://github.com/", with: "https://github.com/")
                .replacingOccurrences(of: "https://www.github.com/", with: "https://github.com/")

            if cleaned.contains("/blob/") {
                cleaned = cleaned
                    .replacingOccurrences(of: "https://github.com/", with: "https://raw.githubusercontent.com/")
                    .replacingOccurrences(of: "/blob/refs/heads/", with: "/")
                    .replacingOccurrences(of: "/blob/", with: "/")
            } else if cleaned.contains("/raw/") {
                cleaned = cleaned
                    .replacingOccurrences(of: "https://github.com/", with: "https://raw.githubusercontent.com/")
                    .replacingOccurrences(of: "/raw/refs/heads/", with: "/")
                    .replacingOccurrences(of: "/raw/", with: "/")
            }
        }

        if cleaned.contains("raw.githubusercontent.com") {
            cleaned = cleaned.replacingOccurrences(of: "/refs/heads/", with: "/")
        }

        if cleaned.lowercased().hasSuffix("?raw=true") {
            cleaned = String(cleaned.dropLast("?raw=true".count))
        } else if cleaned.lowercased().hasSuffix("&raw=true") {
            cleaned = String(cleaned.dropLast("&raw=true".count))
        }

        if let url = URL(string: cleaned) {
            return url
        } else if let decoded = cleaned.removingPercentEncoding,
                  let encoded = decoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encoded) {
            return url
        } else if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: encoded)
        }
        return nil
    }

    static func extractYouTubeVideoID(from urlString: String) -> String? {
        let cleaned = cleanCandidateURLString(urlString)
        guard let url = URL(string: cleaned),
              let host = url.host?.lowercased() else {
            return nil
        }

        let isYouTubeHost = host == "youtu.be"
            || host.hasSuffix(".youtu.be")
            || host == "youtube.com"
            || host.hasSuffix(".youtube.com")
            || host == "youtube-nocookie.com"
            || host.hasSuffix(".youtube-nocookie.com")

        guard isYouTubeHost else { return nil }

        var candidateID: String?

        if host.contains("youtu.be") {
            let comps = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
            candidateID = comps.first
        } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let vParam = components.queryItems?.first(where: { $0.name.lowercased() == "v" })?.value,
               !vParam.isEmpty {
                candidateID = vParam
            } else {
                let pathComps = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
                if let first = pathComps.first?.lowercased(),
                   ["shorts", "embed", "live", "v"].contains(first),
                   pathComps.count >= 2 {
                    candidateID = pathComps[1]
                }
            }
        }

        guard let rawID = candidateID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawID.isEmpty else {
            return nil
        }

        let validPattern = #"^[A-Za-z0-9_-]{6,20}$"#
        if rawID.range(of: validPattern, options: .regularExpression) != nil {
            return rawID
        }
        return nil
    }

    static func extractGitHubImageURL(from urlString: String) -> URL? {
        let cleaned = cleanCandidateURLString(urlString)
        guard cleaned.lowercased().hasPrefix("http://") || cleaned.lowercased().hasPrefix("https://"),
              !cleaned.contains(" ") else {
            return nil
        }

        let lower = cleaned.lowercased()
        let isGitHubDomain = lower.contains("github.com") || lower.contains("githubusercontent.com")
        guard isGitHubDomain else { return nil }

        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".bmp", ".svg"]
        let hasImageExtension = imageExtensions.contains {
            lower.hasSuffix($0) || lower.contains("\($0)?") || lower.contains("\($0)#") || lower.contains("\($0)&")
        }

        let isGitHubAssetImage = lower.contains("github.com/user-attachments/assets/")

        if hasImageExtension || isGitHubAssetImage {
            return convertToRawGitHubURL(cleaned)
        }
        return nil
    }

    private static func classifyURL(from rawCandidate: String) -> DetectedLinkType? {
        let cleaned = cleanCandidateURLString(rawCandidate)
        guard cleaned.lowercased().hasPrefix("http://") || cleaned.lowercased().hasPrefix("https://"),
              !cleaned.contains(" ") else {
            return nil
        }

        if let ytID = extractYouTubeVideoID(from: cleaned) {
            return .youtubeVideo(ytID)
        }

        if let ghImageURL = extractGitHubImageURL(from: cleaned) {
            return .githubImage(ghImageURL)
        }

        let lower = cleaned.lowercased()
        if (lower.contains("github.com") || lower.contains("githubusercontent.com")),
           (lower.contains("/blob/") || lower.contains("/raw/")),
           let rawDownloadURL = convertToRawGitHubURL(cleaned) {
            return .downloadLink(rawDownloadURL)
        }

        if let validURL = URL(string: cleaned) {
            return .downloadLink(validURL)
        } else if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let validURL = URL(string: encoded) {
            return .downloadLink(validURL)
        }
        return nil
    }

    static func parse(_ rawText: String) -> [GuideArticle] {
        let normalized = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        let headerPattern = #"^\s*(\d+)\s*TTT\s*:\s*(.+)$"#
        let headerRegex = try? NSRegularExpression(pattern: headerPattern, options: [.caseInsensitive])

        var articles: [GuideArticle] = []
        var currentNumber: Int?
        var currentTitle: String?
        var currentLines: [String] = []

        func finalizeCurrentArticle() {
            guard let num = currentNumber, let title = currentTitle else { return }
            let blocks = parseContentBlocks(from: currentLines)
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanTitle.isEmpty {
                articles.append(GuideArticle(orderNumber: num, title: cleanTitle, blocks: blocks))
            }
        }

        for line in lines {
            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)

            if let match = headerRegex?.firstMatch(in: line, options: [], range: range),
               match.numberOfRanges >= 3 {
                finalizeCurrentArticle()

                let numberString = nsLine.substring(with: match.range(at: 1))
                let titleString = nsLine.substring(with: match.range(at: 2))

                currentNumber = Int(numberString) ?? 0
                currentTitle = titleString
                currentLines = []
            } else {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && trimmed.range(of: #"^[.,…\s]+$"#, options: .regularExpression) != nil {
                    continue
                }
                if currentNumber != nil {
                    currentLines.append(line)
                }
            }
        }

        finalizeCurrentArticle()
        return articles.sorted { $0.orderNumber > $1.orderNumber }
    }

    private static func parseContentBlocks(from lines: [String]) -> [GuideContentBlock] {
        var blocks: [GuideContentBlock] = []
        var currentTextBuffer: [String] = []

        let inlineURLRegex = try? NSRegularExpression(
            pattern: #"https?://[^\s<>"]+"#,
            options: [.caseInsensitive]
        )

        func flushTextBuffer() {
            let joined = currentTextBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                blocks.append(GuideContentBlock(type: .text(joined)))
            }
            currentTextBuffer.removeAll()
        }

        func appendDetectedLink(_ link: DetectedLinkType) {
            switch link {
            case .githubImage(let imgURL):
                blocks.append(GuideContentBlock(type: .image(imgURL)))
            case .youtubeVideo(let videoID):
                blocks.append(GuideContentBlock(type: .youtube(videoID)))
            case .downloadLink(let dlURL):
                blocks.append(GuideContentBlock(type: .download(dlURL)))
            }
        }

        for line in lines {
            let strippedLine = stripLeadingNumberOrBullet(from: line)

            if let directLink = classifyURL(from: strippedLine) {
                flushTextBuffer()
                appendDetectedLink(directLink)
                continue
            }

            let nsLine = line as NSString
            let matches = inlineURLRegex?.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length)) ?? []

            var foundInlineLinks: [DetectedLinkType] = []
            var remainingText = line

            for match in matches.reversed() {
                let matchedString = nsLine.substring(with: match.range)
                if let detected = classifyURL(from: matchedString) {
                    foundInlineLinks.insert(detected, at: 0)
                    if let swiftRange = Range(match.range, in: remainingText) {
                        remainingText.removeSubrange(swiftRange)
                    }
                }
            }

            if !foundInlineLinks.isEmpty {
                let cleanedRemaining = remainingText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ":-→"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !cleanedRemaining.isEmpty {
                    let checkStripped = stripLeadingNumberOrBullet(from: cleanedRemaining)
                    if !checkStripped.isEmpty {
                        currentTextBuffer.append(cleanedRemaining)
                    }
                }
                flushTextBuffer()
                for link in foundInlineLinks {
                    appendDetectedLink(link)
                }
            } else {
                currentTextBuffer.append(line)
            }
        }
        flushTextBuffer()

        return blocks
    }
}

// MARK: - 🏷️ HEADER ĐẦU TRANG TỐI GIẢN, THOÁNG ĐÃNG, MÁT MẮT (KHÔNG DÙNG KHỐI MÀU CHÓI)
private final class MinimalistHeaderView: UIView, UITextFieldDelegate {
    private let overlineLabel = UILabel()
    private let countPillLabel = UILabel()
    private let mainTitleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let searchBarCard = UIView()
    private let searchIconView = UIImageView()
    private let searchTextField = UITextField()
    private let clearButton = UIButton(type: .system)

    var onSearchTextChanged: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear

        // Nhãn nhỏ phía trên (Overline)
        overlineLabel.translatesAutoresizingMaskIntoConstraints = false
        overlineLabel.text = "CẨM NANG HỆ THỐNG"
        overlineLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        overlineLabel.textColor = CoolMinimalTheme.accentOcean

        // Nhãn đếm số lượng chuyên mục tinh gọn bên phải
        countPillLabel.translatesAutoresizingMaskIntoConstraints = false
        countPillLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        countPillLabel.textColor = CoolMinimalTheme.accentDeepBlue
        countPillLabel.backgroundColor = CoolMinimalTheme.iceBadgeBg
        countPillLabel.layer.cornerRadius = 10
        countPillLabel.layer.masksToBounds = true
        countPillLabel.isHidden = true

        // Tiêu đề chính sang trọng, sắc nét
        mainTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        mainTitleLabel.text = "Tin Tức & Sửa Lỗi"
        mainTitleLabel.font = UIFont.systemFont(ofSize: 27, weight: .bold)
        mainTitleLabel.textColor = CoolMinimalTheme.inkPrimary

        // Dòng mô tả ngắn gọn, thanh lịch
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Tổng hợp hướng dẫn xử lý sự cố và cấu hình ổn định từ cộng đồng"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = CoolMinimalTheme.inkSecondary
        subtitleLabel.numberOfLines = 2

        // Thanh tìm kiếm trắng sứ phẳng mịn
        searchBarCard.translatesAutoresizingMaskIntoConstraints = false
        CoolMinimalTheme.applyMinimalCard(to: searchBarCard, radius: 13)

        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .medium)
        searchIconView.image = UIImage(systemName: "magnifyingglass", withConfiguration: iconCfg)
        searchIconView.tintColor = CoolMinimalTheme.inkMuted

        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.delegate = self
        searchTextField.font = UIFont.systemFont(ofSize: 14.5, weight: .regular)
        searchTextField.textColor = CoolMinimalTheme.inkPrimary
        searchTextField.tintColor = CoolMinimalTheme.accentOcean
        searchTextField.returnKeyType = .done
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Tìm kiếm hướng dẫn hoặc lỗi...",
            attributes: [
                .foregroundColor: CoolMinimalTheme.inkMuted,
                .font: UIFont.systemFont(ofSize: 14.5, weight: .regular)
            ]
        )
        searchTextField.addTarget(self, action: #selector(handleEditingChanged), for: .editingChanged)

        clearButton.translatesAutoresizingMaskIntoConstraints = false
        let clearCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: clearCfg), for: .normal)
        clearButton.tintColor = CoolMinimalTheme.inkMuted
        clearButton.isHidden = true
        clearButton.addTarget(self, action: #selector(handleClearTapped), for: .touchUpInside)

        searchBarCard.addSubview(searchIconView)
        searchBarCard.addSubview(searchTextField)
        searchBarCard.addSubview(clearButton)

        addSubview(overlineLabel)
        addSubview(countPillLabel)
        addSubview(mainTitleLabel)
        addSubview(subtitleLabel)
        addSubview(searchBarCard)

        NSLayoutConstraint.activate([
            overlineLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            overlineLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),

            countPillLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            countPillLabel.centerYAnchor.constraint(equalTo: overlineLabel.centerYAnchor),
            countPillLabel.heightAnchor.constraint(equalToConstant: 22),

            mainTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            mainTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            mainTitleLabel.topAnchor.constraint(equalTo: overlineLabel.bottomAnchor, constant: 4),

            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            subtitleLabel.topAnchor.constraint(equalTo: mainTitleLabel.bottomAnchor, constant: 4),

            searchBarCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchBarCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            searchBarCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            searchBarCard.heightAnchor.constraint(equalToConstant: 42),
            searchBarCard.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            searchIconView.leadingAnchor.constraint(equalTo: searchBarCard.leadingAnchor, constant: 13),
            searchIconView.centerYAnchor.constraint(equalTo: searchBarCard.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 17),
            searchIconView.heightAnchor.constraint(equalToConstant: 17),

            clearButton.trailingAnchor.constraint(equalTo: searchBarCard.trailingAnchor, constant: -10),
            clearButton.centerYAnchor.constraint(equalTo: searchBarCard.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 24),
            clearButton.heightAnchor.constraint(equalToConstant: 24),

            searchTextField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 9),
            searchTextField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -6),
            searchTextField.centerYAnchor.constraint(equalTo: searchBarCard.centerYAnchor),
            searchTextField.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func handleEditingChanged() {
        let text = searchTextField.text ?? ""
        clearButton.isHidden = text.isEmpty
        onSearchTextChanged?(text)
    }

    @objc private func handleClearTapped() {
        searchTextField.text = ""
        clearButton.isHidden = true
        searchTextField.resignFirstResponder()
        onSearchTextChanged?("")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func updateCount(_ count: Int) {
        if count > 0 {
            countPillLabel.text = "  \(count) chủ đề  "
            countPillLabel.isHidden = false
        } else {
            countPillLabel.isHidden = true
        }
    }
}

// MARK: - 🗂️ DÒNG BÀI VIẾT TỐI GIẢN, SẠCH SẼ (CLEAN EDITORIAL CARD)
private final class GuideTopicRowCell: UITableViewCell {
    static let reuseIdentifier = "GuideTopicRowCell"

    private let cardView = UIView()
    private let numberBadgeView = UIView()
    private let numberLabel = UILabel()

    private let textStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let bottomRowStack = UIStackView()
    private let metaLabel = UILabel()
    private let newDotView = UIView()
    private let newLabel = UILabel()

    private let chevronImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: 0.18, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            self.cardView.backgroundColor = highlighted ? CoolMinimalTheme.surfaceSubtle : CoolMinimalTheme.surfaceWhite
        }
    }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Thẻ trắng sứ tối giản
        cardView.translatesAutoresizingMaskIntoConstraints = false
        CoolMinimalTheme.applyMinimalCard(to: cardView, radius: CoolMinimalTheme.cardCornerRadius)

        // Ô số thứ tự màu xanh băng dịu mắt
        numberBadgeView.translatesAutoresizingMaskIntoConstraints = false
        numberBadgeView.backgroundColor = CoolMinimalTheme.iceBadgeBg
        numberBadgeView.layer.cornerRadius = 12
        if #available(iOS 13.0, tvOS 13.0, *) {
            numberBadgeView.layer.cornerCurve = .continuous
        }

        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        if let desc = UIFont.systemFont(ofSize: 14, weight: .bold).fontDescriptor.withDesign(.rounded) {
            numberLabel.font = UIFont(descriptor: desc, size: 14)
        } else {
            numberLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        }
        numberLabel.textColor = CoolMinimalTheme.accentDeepBlue
        numberLabel.textAlignment = .center
        numberBadgeView.addSubview(numberLabel)

        // Tiêu đề chính gọn gàng
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = CoolMinimalTheme.inkPrimary
        titleLabel.numberOfLines = 2

        // Dòng tóm tắt thanh mảnh
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        subtitleLabel.textColor = CoolMinimalTheme.inkSecondary
        subtitleLabel.numberOfLines = 1

        // Hàng thông tin phụ nhỏ gọn (không dùng hộp màu lòe loẹt)
        bottomRowStack.translatesAutoresizingMaskIntoConstraints = false
        bottomRowStack.axis = .horizontal
        bottomRowStack.spacing = 6
        bottomRowStack.alignment = .center

        newDotView.translatesAutoresizingMaskIntoConstraints = false
        newDotView.backgroundColor = CoolMinimalTheme.accentTeal
        newDotView.layer.cornerRadius = 3
        NSLayoutConstraint.activate([
            newDotView.widthAnchor.constraint(equalToConstant: 6),
            newDotView.heightAnchor.constraint(equalToConstant: 6)
        ])

        newLabel.translatesAutoresizingMaskIntoConstraints = false
        newLabel.text = "Mới nhất •"
        newLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        newLabel.textColor = CoolMinimalTheme.accentTeal

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        metaLabel.textColor = CoolMinimalTheme.inkMuted

        bottomRowStack.addArrangedSubview(newDotView)
        bottomRowStack.addArrangedSubview(newLabel)
        bottomRowStack.addArrangedSubview(metaLabel)

        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.alignment = .leading
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.addArrangedSubview(bottomRowStack)
        textStack.setCustomSpacing(6, after: subtitleLabel)

        // Mũi tên điều hướng mảnh
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        let chevCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevronImageView.image = UIImage(systemName: "chevron.right", withConfiguration: chevCfg)
        chevronImageView.tintColor = CoolMinimalTheme.inkMuted
        chevronImageView.setContentHuggingPriority(.required, for: .horizontal)

        cardView.addSubview(numberBadgeView)
        cardView.addSubview(textStack)
        cardView.addSubview(chevronImageView)
        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            numberBadgeView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            numberBadgeView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 15),
            numberBadgeView.widthAnchor.constraint(equalToConstant: 42),
            numberBadgeView.heightAnchor.constraint(equalToConstant: 42),

            numberLabel.centerXAnchor.constraint(equalTo: numberBadgeView.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: numberBadgeView.centerYAnchor),

            chevronImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevronImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: numberBadgeView.trailingAnchor, constant: 13),
            textStack.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -10),
            textStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])
    }

    func configure(with article: GuideArticle, isTopPriority: Bool) {
        numberLabel.text = String(format: "%02d", article.orderNumber)
        titleLabel.text = article.title
        subtitleLabel.text = article.previewSubtitle
        metaLabel.text = article.cleanSummaryMeta

        newDotView.isHidden = !isTopPriority
        newLabel.isHidden = !isTopPriority
    }
}

// MARK: - 📱 KHUNG HIỂN THỊ ẢNH TỐI GIẢN (KHÔNG VIỀN MÀU RƯỜM RÀ, BO GÓC SẠCH SẼ)
private final class GuideStyledImageView: UIView {
    private let cardContainer = UIView()
    private let imageView = UIImageView()
    private let zoomPill = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let zoomIcon = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private var imageURL: URL?
    private var aspectRatioConstraint: NSLayoutConstraint?
    private var defaultHeightConstraint: NSLayoutConstraint!
    var onTapImage: ((UIImage) -> Void)?

    init(url: URL) {
        self.imageURL = GuideParser.convertToRawGitHubURL(url.absoluteString) ?? url
        super.init(frame: .zero)
        setupViews()
        loadImage()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.backgroundColor = CoolMinimalTheme.surfaceWhite
        cardContainer.layer.cornerRadius = CoolMinimalTheme.mediaCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            cardContainer.layer.cornerCurve = .continuous
        }
        cardContainer.layer.borderWidth = 1.0
        cardContainer.layer.borderColor = CoolMinimalTheme.hairlineBorder.cgColor
        cardContainer.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = CoolMinimalTheme.surfaceSubtle
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
        imageView.addGestureRecognizer(tapGesture)

        // Nút icon kính lúp nhỏ gọn góc dưới bên phải
        zoomPill.translatesAutoresizingMaskIntoConstraints = false
        zoomPill.layer.cornerRadius = 14
        zoomPill.clipsToBounds = true
        zoomPill.isUserInteractionEnabled = false
        zoomPill.isHidden = true

        zoomIcon.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        zoomIcon.image = UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: cfg)
        zoomIcon.tintColor = .white
        zoomPill.contentView.addSubview(zoomIcon)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = CoolMinimalTheme.accentOcean
        activityIndicator.hidesWhenStopped = true

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Không thể tải hình ảnh"
        errorLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        errorLabel.textColor = CoolMinimalTheme.inkSecondary
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("  Thử lại  ", for: .normal)
        retryButton.setTitleColor(CoolMinimalTheme.accentOcean, for: .normal)
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        retryButton.backgroundColor = CoolMinimalTheme.iceBadgeBg
        retryButton.layer.cornerRadius = 12
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(loadImage), for: .touchUpInside)

        cardContainer.addSubview(imageView)
        cardContainer.addSubview(zoomPill)
        cardContainer.addSubview(activityIndicator)
        cardContainer.addSubview(errorLabel)
        cardContainer.addSubview(retryButton)
        addSubview(cardContainer)

        defaultHeightConstraint = cardContainer.heightAnchor.constraint(equalToConstant: 210)
        defaultHeightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardContainer.topAnchor.constraint(equalTo: topAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            defaultHeightConstraint,

            imageView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),

            zoomPill.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -10),
            zoomPill.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -10),
            zoomPill.widthAnchor.constraint(equalToConstant: 28),
            zoomPill.heightAnchor.constraint(equalToConstant: 28),

            zoomIcon.centerXAnchor.constraint(equalTo: zoomPill.contentView.centerXAnchor),
            zoomIcon.centerYAnchor.constraint(equalTo: zoomPill.contentView.centerYAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: cardContainer.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: cardContainer.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: cardContainer.centerYAnchor, constant: -12),

            retryButton.centerXAnchor.constraint(equalTo: cardContainer.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
            retryButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func loadImage() {
        guard let originalURL = imageURL else { return }
        let resolvedURL = GuideParser.convertToRawGitHubURL(originalURL.absoluteString) ?? originalURL

        errorLabel.isHidden = true
        retryButton.isHidden = true
        zoomPill.isHidden = true
        activityIndicator.startAnimating()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let loadedImage: UIImage
                if let nukeImage = try? await ImagePipeline.shared.image(for: resolvedURL) {
                    loadedImage = nukeImage
                } else {
                    var req = URLRequest(url: resolvedURL)
                    req.timeoutInterval = 25
                    req.cachePolicy = .returnCacheDataElseLoad
                    req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
                    req.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
                    let (data, _) = try await URLSession.shared.data(for: req)
                    guard let img = UIImage(data: data) else {
                        throw URLError(.cannotDecodeContentData)
                    }
                    loadedImage = img
                }
                self.applyLoadedImage(loadedImage)
            } catch {
                self.activityIndicator.stopAnimating()
                self.errorLabel.isHidden = false
                self.retryButton.isHidden = false
            }
        }
    }

    private func applyLoadedImage(_ image: UIImage) {
        activityIndicator.stopAnimating()
        errorLabel.isHidden = true
        retryButton.isHidden = true
        zoomPill.isHidden = false

        imageView.alpha = 0
        imageView.image = image

        if image.size.width > 0 && image.size.height > 0 {
            let ratio = image.size.height / image.size.width
            defaultHeightConstraint.isActive = false
            if let oldAspect = aspectRatioConstraint {
                oldAspect.isActive = false
            }
            let newAspect = cardContainer.heightAnchor.constraint(equalTo: cardContainer.widthAnchor, multiplier: ratio)
            newAspect.priority = .required
            newAspect.isActive = true
            aspectRatioConstraint = newAspect
        }

        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.superview?.setNeedsLayout()
        self.superview?.layoutIfNeeded()

        UIView.animate(withDuration: 0.22) {
            self.imageView.alpha = 1
        }
    }

    @objc private func handleImageTap() {
        guard let img = imageView.image else { return }
        onTapImage?(img)
    }
}

// MARK: - ⬇️ KHUNG TẢI VỀ TỐI GIẢN, GỌN GÀNG, CHUYÊN NGHIỆP
private final class GuideDownloadActionCardView: UIView {
    private let downloadURL: URL
    private weak var hostViewController: UIViewController?

    private let cardContainer = UIView()
    private let mainStack = UIStackView()

    private let infoRow = UIStackView()
    private let folderIconView = UIImageView()
    private let noticeTextLabel = UILabel()

    private let downloadButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    private var isDownloading = false

    init(url: URL, hostViewController: UIViewController?) {
        self.downloadURL = url
        self.hostViewController = hostViewController
        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        CoolMinimalTheme.applyMinimalCard(to: cardContainer, radius: CoolMinimalTheme.cardCornerRadius)

        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.spacing = 12

        // Dòng hướng dẫn lưu file gọn gàng phía trên
        infoRow.axis = .horizontal
        infoRow.spacing = 10
        infoRow.alignment = .center

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        folderIconView.image = UIImage(systemName: "arrow.down.doc.fill", withConfiguration: iconCfg)
        folderIconView.tintColor = CoolMinimalTheme.accentOcean
        folderIconView.setContentHuggingPriority(.required, for: .horizontal)

        let rawNotice = "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file"
        let attr = NSMutableAttributedString(
            string: rawNotice,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: CoolMinimalTheme.inkSecondary
            ]
        )
        let nsRange = (rawNotice as NSString).range(of: "Lưu Vào Tệp", options: .caseInsensitive)
        if nsRange.location != NSNotFound {
            attr.addAttributes([
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: CoolMinimalTheme.inkPrimary
            ], range: nsRange)
        }
        noticeTextLabel.attributedText = attr
        noticeTextLabel.numberOfLines = 0

        infoRow.addArrangedSubview(folderIconView)
        infoRow.addArrangedSubview(noticeTextLabel)

        // Nút tải màu Xanh Lam Đậm phẳng hiện đại
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.backgroundColor = CoolMinimalTheme.accentOcean
        downloadButton.setTitleColor(.white, for: .normal)
        downloadButton.tintColor = .white
        downloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 15.5, weight: .semibold)
        let btnIconCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        downloadButton.setImage(UIImage(systemName: "arrow.down.circle.fill", withConfiguration: btnIconCfg), for: .normal)
        downloadButton.setTitle("  Nhấn Vào Đây Để Tải Về", for: .normal)
        downloadButton.layer.cornerRadius = 12
        if #available(iOS 13.0, tvOS 13.0, *) {
            downloadButton.layer.cornerCurve = .continuous
        }
        downloadButton.addTarget(self, action: #selector(handleDownloadButtonTap), for: .touchUpInside)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .white
        spinner.hidesWhenStopped = true
        downloadButton.addSubview(spinner)

        mainStack.addArrangedSubview(infoRow)
        mainStack.addArrangedSubview(downloadButton)
        cardContainer.addSubview(mainStack)
        addSubview(cardContainer)

        NSLayoutConstraint.activate([
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardContainer.topAnchor.constraint(equalTo: topAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            mainStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            mainStack.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            mainStack.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -14),

            downloadButton.heightAnchor.constraint(equalToConstant: 46),

            spinner.trailingAnchor.constraint(equalTo: downloadButton.trailingAnchor, constant: -16),
            spinner.centerYAnchor.constraint(equalTo: downloadButton.centerYAnchor)
        ])
    }

    private func setLoadingState(_ loading: Bool) {
        if loading {
            spinner.startAnimating()
            downloadButton.setImage(nil, for: .normal)
            downloadButton.setTitle("Đang Tải Về...", for: .normal)
            downloadButton.backgroundColor = CoolMinimalTheme.accentDeepBlue
        } else {
            spinner.stopAnimating()
            let btnIconCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            downloadButton.setImage(UIImage(systemName: "arrow.down.circle.fill", withConfiguration: btnIconCfg), for: .normal)
            downloadButton.setTitle("  Nhấn Vào Đây Để Tải Về", for: .normal)
            downloadButton.backgroundColor = CoolMinimalTheme.accentOcean
        }
    }

    @objc private func handleDownloadButtonTap() {
        guard !isDownloading else { return }

        #if !os(tvOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        isDownloading = true
        setLoadingState(true)

        let hostLower = (downloadURL.host ?? "").lowercased()
        let isCloudWebPortal = hostLower.contains("icloud.com")
            || hostLower.contains("drive.google.com")
            || hostLower.contains("mega.nz")
            || hostLower.contains("mediafire.com")
            || hostLower.contains("1drv.ms")
            || hostLower.contains("dropbox.com")

        if isCloudWebPortal && !downloadURL.pathExtension.lowercased().isOne(of: ["ipa", "zip", "mobileconfig", "plist", "deb", "tipa"]) {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard let self = self else { return }
                UIApplication.shared.open(self.downloadURL, options: [:], completionHandler: nil)
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                self.isDownloading = false
                self.setLoadingState(false)
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                self.isDownloading = false
                self.setLoadingState(false)
            }

            do {
                var request = URLRequest(url: self.downloadURL)
                request.timeoutInterval = 60
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

                let (tempLocalURL, response) = try await URLSession.shared.download(for: request)

                if let httpResp = response as? HTTPURLResponse,
                   let mime = httpResp.mimeType?.lowercased(),
                   mime == "text/html",
                   httpResp.value(forHTTPHeaderField: "Content-Disposition") == nil,
                   self.downloadURL.pathExtension.isEmpty {
                    try? FileManager.default.removeItem(at: tempLocalURL)
                    UIApplication.shared.open(self.downloadURL, options: [:], completionHandler: nil)
                    return
                }

                let suggestedName = response.suggestedFilename
                    ?? (self.downloadURL.lastPathComponent.isEmpty ? "Tep_Tai_Ve.bin" : self.downloadURL.lastPathComponent)
                let safeFileName = suggestedName.replacingOccurrences(of: "/", with: "_")
                let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeFileName)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try? FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempLocalURL, to: destinationURL)

                self.presentSaveToFilesSheet(for: destinationURL)
            } catch {
                UIApplication.shared.open(self.downloadURL, options: [:], completionHandler: nil)
            }
        }
    }

    private func presentSaveToFilesSheet(for fileURL: URL) {
        #if !os(tvOS)
        guard let presenter = hostViewController ?? window?.rootViewController else {
            UIApplication.shared.open(downloadURL, options: [:], completionHandler: nil)
            return
        }

        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = downloadButton
            popover.sourceRect = downloadButton.bounds
        }
        presenter.present(activityVC, animated: true)
        #else
        UIApplication.shared.open(downloadURL, options: [:], completionHandler: nil)
        #endif
    }
}

private extension String {
    func isOne(of list: [String]) -> Bool {
        return list.contains(self)
    }
}

// MARK: - 🔍 TRÌNH XEM ẢNH PHÓNG TO TOÀN MÀN HÌNH
private final class GuideImagePreviewController: UIViewController, UIScrollViewDelegate {
    private let image: UIImage
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = image
        imageView.contentMode = .scaleAspectFit

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        closeButton.layer.cornerRadius = 18
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            scrollView.setZoomScale(2.5, animated: true)
        }
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

// MARK: - 📖 TRANG CHI TIẾT BÀI VIẾT (THIẾT KẾ SẠCH SẼ NHƯ TRANG TẠP CHÍ EDITORIAL)
private final class GuideArticleDetailViewController: UIViewController {
    private let article: GuideArticle
    private let topBarView = UIView()
    private let backButton = UIButton(type: .system)
    private let topTopicBadge = UILabel()
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

    init(article: GuideArticle) {
        self.article = article
        super.init(nibName: nil, bundle: nil)
        #if !os(tvOS)
        self.hidesBottomBarWhenPushed = false
        #endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        title = nil
        navigationItem.title = nil
        navigationController?.setNavigationBarHidden(true, animated: false)

        setupBackground()
        setupTopNavigationBar()
        setupScrollView()
        setupCleanTitleCard()
        buildArticleContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func setupBackground() {
        let bgView = SourcesCoolBackgroundView(frame: view.bounds)
        bgView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bgView)
        NSLayoutConstraint.activate([
            bgView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bgView.topAnchor.constraint(equalTo: view.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTopNavigationBar() {
        topBarView.translatesAutoresizingMaskIntoConstraints = false
        topBarView.backgroundColor = .clear

        backButton.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        backButton.setTitle(" Danh mục", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        backButton.tintColor = CoolMinimalTheme.accentOcean
        backButton.setTitleColor(CoolMinimalTheme.accentOcean, for: .normal)
        backButton.backgroundColor = CoolMinimalTheme.surfaceWhite
        backButton.layer.cornerRadius = 16
        backButton.layer.borderWidth = 1.0
        backButton.layer.borderColor = CoolMinimalTheme.hairlineBorder.cgColor
        backButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 14)
        backButton.addTarget(self, action: #selector(handleBackButtonTap), for: .touchUpInside)

        topTopicBadge.translatesAutoresizingMaskIntoConstraints = false
        topTopicBadge.text = String(format: "CHỦ ĐỀ #%02d", article.orderNumber)
        topTopicBadge.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        topTopicBadge.textColor = CoolMinimalTheme.inkMuted

        topBarView.addSubview(backButton)
        topBarView.addSubview(topTopicBadge)
        view.addSubview(topBarView)

        NSLayoutConstraint.activate([
            topBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBarView.heightAnchor.constraint(equalToConstant: 46),

            backButton.leadingAnchor.constraint(equalTo: topBarView.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor),
            backButton.heightAnchor.constraint(equalToConstant: 32),

            topTopicBadge.trailingAnchor.constraint(equalTo: topBarView.trailingAnchor, constant: -20),
            topTopicBadge.centerYAnchor.constraint(equalTo: topBarView.centerYAnchor)
        ])
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 48, right: 0)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 14
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 16, bottom: 24, trailing: 16)

        scrollView.addSubview(contentStackView)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topBarView.bottomAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    /// Khối tiêu đề bài viết trắng sứ sạch sẽ, có điểm nhấn thanh dọc màu xanh biển lạnh
    private func setupCleanTitleCard() {
        let titleCard = UIView()
        titleCard.translatesAutoresizingMaskIntoConstraints = false
        CoolMinimalTheme.applyMinimalCard(to: titleCard, radius: CoolMinimalTheme.cardCornerRadius)

        let accentBar = UIView()
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.backgroundColor = CoolMinimalTheme.accentOcean
        accentBar.layer.cornerRadius = 2

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = article.title
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = CoolMinimalTheme.inkPrimary
        titleLabel.numberOfLines = 0

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = CoolMinimalTheme.dividerLine

        let noteLabel = UILabel()
        noteLabel.translatesAutoresizingMaskIntoConstraints = false
        noteLabel.text = "Lưu ý: Thực hiện tuần tự từng bước bên dưới. Nếu chưa thành công ở lần đầu, hãy kiên nhẫn thử lại."
        noteLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        noteLabel.textColor = CoolMinimalTheme.inkSecondary
        noteLabel.numberOfLines = 0

        titleCard.addSubview(accentBar)
        titleCard.addSubview(titleLabel)
        titleCard.addSubview(divider)
        titleCard.addSubview(noteLabel)

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: titleCard.leadingAnchor, constant: 16),
            accentBar.topAnchor.constraint(equalTo: titleLabel.topAnchor, constant: 2),
            accentBar.bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: -2),
            accentBar.widthAnchor.constraint(equalToConstant: 3.5),

            titleLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: titleCard.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: titleCard.topAnchor, constant: 16),

            divider.leadingAnchor.constraint(equalTo: titleCard.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: titleCard.trailingAnchor, constant: -16),
            divider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            divider.heightAnchor.constraint(equalToConstant: 1),

            noteLabel.leadingAnchor.constraint(equalTo: titleCard.leadingAnchor, constant: 16),
            noteLabel.trailingAnchor.constraint(equalTo: titleCard.trailingAnchor, constant: -16),
            noteLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 10),
            noteLabel.bottomAnchor.constraint(equalTo: titleCard.bottomAnchor, constant: -14)
        ])

        contentStackView.addArrangedSubview(titleCard)
    }

    private func buildArticleContent() {
        if article.blocks.isEmpty {
            let emptyCard = makeTextCardView(for: "Nội dung hướng dẫn đang được cập nhật.", startingStepIndex: 1)
            contentStackView.addArrangedSubview(emptyCard)
            return
        }

        var runningStepNumber = 1

        for block in article.blocks {
            switch block.type {
            case .text(let textContent):
                let linesCount = textContent
                    .components(separatedBy: .newlines)
                    .map { GuideParser.stripLeadingNumberOrBullet(from: $0) }
                    .filter { !$0.isEmpty }
                    .count
                let textCard = makeTextCardView(for: textContent, startingStepIndex: runningStepNumber)
                runningStepNumber += max(linesCount, 1)
                contentStackView.addArrangedSubview(textCard)

            case .image(let imageURL):
                let imageViewCard = GuideStyledImageView(url: imageURL)
                imageViewCard.onTapImage = { [weak self] tappedImage in
                    let previewVC = GuideImagePreviewController(image: tappedImage)
                    self?.present(previewVC, animated: true)
                }
                contentStackView.addArrangedSubview(imageViewCard)

            case .youtube(let videoID):
                let overviewVideoSection = OverviewHostedVideoSectionView(videoID: videoID, parentViewController: self)
                contentStackView.addArrangedSubview(overviewVideoSection)

            case .download(let downloadURL):
                let downloadCard = GuideDownloadActionCardView(url: downloadURL, hostViewController: self)
                contentStackView.addArrangedSubview(downloadCard)
            }
        }
    }

    /// Tạo thẻ đọc hướng dẫn phẳng mịn, phân tách bằng đường kẻ mảnh tinh tế thay vì đóng nhiều hộp rối mắt
    private func makeTextCardView(for rawText: String, startingStepIndex: Int) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        CoolMinimalTheme.applyMinimalCard(to: card, radius: CoolMinimalTheme.cardCornerRadius)

        let innerStack = UIStackView()
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.axis = .vertical
        innerStack.spacing = 0

        let rawLines = rawText.components(separatedBy: .newlines)
        var bulletItems: [String] = []

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let cleanedText = GuideParser.stripLeadingNumberOrBullet(from: trimmed)
            if !cleanedText.isEmpty {
                bulletItems.append(cleanedText)
            }
        }

        for (index, itemText) in bulletItems.enumerated() {
            let stepNum = startingStepIndex + index
            let isLast = (index == bulletItems.count - 1)
            let row = makeCleanStepRow(stepNumber: stepNum, stepText: itemText, showBottomDivider: !isLast)
            innerStack.addArrangedSubview(row)
        }

        card.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4)
        ])

        return card
    }

    private func makeCleanStepRow(stepNumber: Int, stepText: String, showBottomDivider: Bool) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stepCircle = UIView()
        stepCircle.translatesAutoresizingMaskIntoConstraints = false
        stepCircle.backgroundColor = CoolMinimalTheme.iceBadgeBg
        stepCircle.layer.cornerRadius = 11

        let stepNumLabel = UILabel()
        stepNumLabel.translatesAutoresizingMaskIntoConstraints = false
        stepNumLabel.text = "\(stepNumber)"
        stepNumLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        stepNumLabel.textColor = CoolMinimalTheme.accentDeepBlue
        stepNumLabel.textAlignment = .center
        stepCircle.addSubview(stepNumLabel)

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.attributedText = styleInstructionText(stepText)

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = CoolMinimalTheme.dividerLine
        divider.isHidden = !showBottomDivider

        container.addSubview(stepCircle)
        container.addSubview(bodyLabel)
        container.addSubview(divider)

        NSLayoutConstraint.activate([
            stepCircle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stepCircle.topAnchor.constraint(equalTo: container.topAnchor, constant: 13),
            stepCircle.widthAnchor.constraint(equalToConstant: 22),
            stepCircle.heightAnchor.constraint(equalToConstant: 22),

            stepNumLabel.centerXAnchor.constraint(equalTo: stepCircle.centerXAnchor),
            stepNumLabel.centerYAnchor.constraint(equalTo: stepCircle.centerYAnchor),

            bodyLabel.leadingAnchor.constraint(equalTo: stepCircle.trailingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            bodyLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            divider.leadingAnchor.constraint(equalTo: bodyLabel.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])

        return container
    }

    private func styleInstructionText(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.5

        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: CoolMinimalTheme.inkPrimary,
                .paragraphStyle: paragraphStyle
            ]
        )

        let nsString = text as NSString
        var searchRange = NSRange(location: 0, length: nsString.length)
        while searchRange.location < nsString.length {
            let found = nsString.range(of: "→", options: [], range: searchRange)
            if found.location != NSNotFound {
                attr.addAttributes([
                    .foregroundColor: CoolMinimalTheme.accentOcean,
                    .font: UIFont.systemFont(ofSize: 15.5, weight: .bold)
                ], range: found)
                searchRange.location = found.location + found.length
                searchRange.length = nsString.length - searchRange.location
            } else {
                break
            }
        }

        return attr
    }

    @objc private func handleBackButtonTap() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - 🚀 CONTROLLER CHÍNH: SOURCESVIEWCONTROLLER (GIỮ NGUYÊN MỌI CHỨC NĂNG GỐC)
final class SourcesViewController: UICollectionViewController {
    var deepLinkSourceURL: URL? {
        didSet {
            self.handleAddSourceDeepLink()
        }
    }

    private var allArticles: [GuideArticle] = []
    private var filteredArticles: [GuideArticle] = []
    private var currentSearchQuery: String = ""
    private var isLoadingGuides = false
    private var fetchTask: Task<Void, Never>?

    private let guidesTableView = UITableView(frame: .zero, style: .plain)
    private let headerView = MinimalistHeaderView(frame: CGRect(x: 0, y: 0, width: 375, height: 158))
    #if !os(tvOS)
    private let refreshControl = UIRefreshControl()
    #endif

    // Khung trạng thái Đang tải / Lỗi mạng tối giản
    private let stateCardView = UIView()
    private let stateActivityIndicator = UIActivityIndicatorView(style: .medium)
    private let stateTitleLabel = UILabel()
    private let stateSubtitleLabel = UILabel()
    private let stateRetryButton = UIButton(type: .system)

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .light

        self.title = nil
        self.navigationItem.title = nil
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.leftBarButtonItem = nil
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        #endif

        setupGuidesTableViewInterface()
        setupStateOverlayCard()
        setupTableFooterInfo()

        fetchGuidesFromGitHub(showLoadingCard: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let header = guidesTableView.tableHeaderView {
            let targetHeight: CGFloat = 158
            if header.frame.height != targetHeight || header.frame.width != guidesTableView.bounds.width {
                header.frame = CGRect(x: 0, y: 0, width: guidesTableView.bounds.width, height: targetHeight)
                guidesTableView.tableHeaderView = header
            }
        }
    }

    @IBSegueAction
    func makeSourceDetailViewController(_ coder: NSCoder, sender: Any?) -> UIViewController? {
        guard let source = sender as? Source else { return nil }
        return SourceDetailViewController(source: source, coder: coder)
    }

    @IBAction
    func unwindFromAddSource(_ segue: UIStoryboardSegue) {
    }
}

// MARK: - 🎨 THIẾT LẬP GIAO DIỆN & TẢI DỮ LIỆU GITHUB
private extension SourcesViewController {
    func setupGuidesTableViewInterface() {
        collectionView.dataSource = nil
        collectionView.prefetchDataSource = nil
        collectionView.backgroundColor = .clear

        let coolBg = SourcesCoolBackgroundView(frame: UIScreen.main.bounds)
        coolBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        guidesTableView.backgroundView = coolBg
        guidesTableView.backgroundColor = .clear
        guidesTableView.separatorStyle = .none
        guidesTableView.showsVerticalScrollIndicator = true
        guidesTableView.keyboardDismissMode = .onDrag
        guidesTableView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 48, right: 0)
        if #available(iOS 15.0, tvOS 15.0, *) {
            guidesTableView.sectionHeaderTopPadding = 0
        }

        guidesTableView.translatesAutoresizingMaskIntoConstraints = false
        guidesTableView.delegate = self
        guidesTableView.dataSource = self
        guidesTableView.rowHeight = UITableView.automaticDimension
        guidesTableView.estimatedRowHeight = 96
        guidesTableView.register(GuideTopicRowCell.self, forCellReuseIdentifier: GuideTopicRowCell.reuseIdentifier)

        headerView.onSearchTextChanged = { [weak self] query in
            self?.applySearchFilter(query)
        }
        guidesTableView.tableHeaderView = headerView

        #if !os(tvOS)
        refreshControl.tintColor = CoolMinimalTheme.accentOcean
        refreshControl.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        guidesTableView.refreshControl = refreshControl
        #endif

        view.addSubview(guidesTableView)
        NSLayoutConstraint.activate([
            guidesTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            guidesTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            guidesTableView.topAnchor.constraint(equalTo: view.topAnchor),
            guidesTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func applySearchFilter(_ query: String) {
        currentSearchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if currentSearchQuery.isEmpty {
            filteredArticles = allArticles
        } else {
            filteredArticles = allArticles.filter { $0.searchableContent.contains(currentSearchQuery) }
        }
        headerView.updateCount(filteredArticles.count)
        guidesTableView.reloadData()
    }

    func setupTableFooterInfo() {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 48))
        footer.backgroundColor = .clear

        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.text = "Kéo xuống để làm mới dữ liệu hướng dẫn"
        infoLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        infoLabel.textColor = CoolMinimalTheme.inkMuted
        infoLabel.textAlignment = .center

        footer.addSubview(infoLabel)
        NSLayoutConstraint.activate([
            infoLabel.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            infoLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])

        guidesTableView.tableFooterView = footer
    }

    func setupStateOverlayCard() {
        stateCardView.translatesAutoresizingMaskIntoConstraints = false
        CoolMinimalTheme.applyMinimalCard(to: stateCardView, radius: CoolMinimalTheme.cardCornerRadius)

        stateActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        stateActivityIndicator.color = CoolMinimalTheme.accentOcean
        stateActivityIndicator.hidesWhenStopped = true

        stateTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stateTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        stateTitleLabel.textColor = CoolMinimalTheme.inkPrimary
        stateTitleLabel.textAlignment = .center
        stateTitleLabel.numberOfLines = 0

        stateSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stateSubtitleLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        stateSubtitleLabel.textColor = CoolMinimalTheme.inkSecondary
        stateSubtitleLabel.textAlignment = .center
        stateSubtitleLabel.numberOfLines = 0

        stateRetryButton.translatesAutoresizingMaskIntoConstraints = false
        stateRetryButton.setTitle("  Tải lại  ", for: .normal)
        stateRetryButton.setTitleColor(.white, for: .normal)
        stateRetryButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        stateRetryButton.backgroundColor = CoolMinimalTheme.accentOcean
        stateRetryButton.layer.cornerRadius = 10
        stateRetryButton.addTarget(self, action: #selector(handleRetryButtonTap), for: .touchUpInside)

        stateCardView.addSubview(stateActivityIndicator)
        stateCardView.addSubview(stateTitleLabel)
        stateCardView.addSubview(stateSubtitleLabel)
        stateCardView.addSubview(stateRetryButton)
        view.addSubview(stateCardView)

        NSLayoutConstraint.activate([
            stateCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stateCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stateCardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 30),

            stateActivityIndicator.topAnchor.constraint(equalTo: stateCardView.topAnchor, constant: 22),
            stateActivityIndicator.centerXAnchor.constraint(equalTo: stateCardView.centerXAnchor),

            stateTitleLabel.topAnchor.constraint(equalTo: stateActivityIndicator.bottomAnchor, constant: 12),
            stateTitleLabel.leadingAnchor.constraint(equalTo: stateCardView.leadingAnchor, constant: 16),
            stateTitleLabel.trailingAnchor.constraint(equalTo: stateCardView.trailingAnchor, constant: -16),

            stateSubtitleLabel.topAnchor.constraint(equalTo: stateTitleLabel.bottomAnchor, constant: 6),
            stateSubtitleLabel.leadingAnchor.constraint(equalTo: stateCardView.leadingAnchor, constant: 16),
            stateSubtitleLabel.trailingAnchor.constraint(equalTo: stateCardView.trailingAnchor, constant: -16),

            stateRetryButton.topAnchor.constraint(equalTo: stateSubtitleLabel.bottomAnchor, constant: 14),
            stateRetryButton.centerXAnchor.constraint(equalTo: stateCardView.centerXAnchor),
            stateRetryButton.heightAnchor.constraint(equalToConstant: 36),
            stateRetryButton.bottomAnchor.constraint(equalTo: stateCardView.bottomAnchor, constant: -20)
        ])
    }

    @objc func handlePullToRefresh() {
        fetchGuidesFromGitHub(showLoadingCard: false)
    }

    @objc func handleRetryButtonTap() {
        fetchGuidesFromGitHub(showLoadingCard: true)
    }

    func fetchGuidesFromGitHub(showLoadingCard: Bool) {
        guard !isLoadingGuides else { return }

        let cacheKey = "CachedGitHubGuidesText"

        if allArticles.isEmpty, let cachedText = UserDefaults.standard.string(forKey: cacheKey) {
            let cachedArticles = GuideParser.parse(cachedText)
            if !cachedArticles.isEmpty {
                self.allArticles = cachedArticles
                self.applySearchFilter(self.currentSearchQuery)
                self.stateCardView.isHidden = true
            }
        }

        if showLoadingCard && allArticles.isEmpty {
            stateCardView.isHidden = false
            stateActivityIndicator.startAnimating()
            stateTitleLabel.text = "Đang đồng bộ hướng dẫn..."
            stateSubtitleLabel.text = "Vui lòng chờ trong giây lát"
            stateRetryButton.isHidden = true
        }

        isLoadingGuides = true
        fetchTask?.cancel()
        fetchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                self.isLoadingGuides = false
                #if !os(tvOS)
                self.refreshControl.endRefreshing()
                #endif
            }

            guard let rawURL = GuideParser.convertToRawGitHubURL(GuideParser.githubGuideURL) else {
                if self.allArticles.isEmpty {
                    self.showErrorState(message: "Đường dẫn cấu hình không hợp lệ.")
                }
                return
            }

            do {
                var request = URLRequest(url: rawURL)
                request.cachePolicy = showLoadingCard ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData
                request.timeoutInterval = 20

                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    throw URLError(.badServerResponse)
                }

                let rawText = String(decoding: data, as: UTF8.self)

                if rawText == UserDefaults.standard.string(forKey: cacheKey) && !self.allArticles.isEmpty {
                    self.stateCardView.isHidden = true
                    self.stateActivityIndicator.stopAnimating()
                    return
                }

                let parsedArticles = GuideParser.parse(rawText)
                if !parsedArticles.isEmpty {
                    UserDefaults.standard.set(rawText, forKey: cacheKey)
                    self.allArticles = parsedArticles
                    self.applySearchFilter(self.currentSearchQuery)
                    self.stateCardView.isHidden = true
                    self.stateActivityIndicator.stopAnimating()
                } else if self.allArticles.isEmpty {
                    self.showErrorState(message: "Chưa có bài viết hướng dẫn nào.")
                }
            } catch {
                if self.allArticles.isEmpty {
                    self.showErrorState(message: "Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.")
                }
            }
        }
    }

    func showErrorState(message: String) {
        stateCardView.isHidden = false
        stateActivityIndicator.stopAnimating()
        stateTitleLabel.text = "Chưa tải được dữ liệu"
        stateSubtitleLabel.text = message
        stateRetryButton.isHidden = false
    }

    func handleAddSourceDeepLink() {
        guard let url = self.deepLinkSourceURL, self.view.window != nil else { return }
        self.deepLinkSourceURL = nil

        Task {
            do {
                let backgroundContext = DatabaseManager.shared.persistentContainer.newBackgroundContext()
                _ = try await AppManager.shared.fetchSource(sourceURL: url, managedObjectContext: backgroundContext)
            } catch {
                debugLog("DeepLink fetch source ignored or failed: \(error)")
            }
        }
    }
}

// MARK: - 📋 UITABLEVIEW DATASOURCE & DELEGATE
extension SourcesViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredArticles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: GuideTopicRowCell.reuseIdentifier, for: indexPath) as? GuideTopicRowCell else {
            return UITableViewCell()
        }
        let article = filteredArticles[indexPath.row]
        let isTopOverall = (article.id == allArticles.first?.id)
        cell.configure(with: article, isTopPriority: isTopOverall)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard filteredArticles.indices.contains(indexPath.row) else { return }
        let selectedArticle = filteredArticles[indexPath.row]

        #if !os(tvOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif

        let detailVC = GuideArticleDetailViewController(article: selectedArticle)
        if let nav = self.navigationController {
            nav.pushViewController(detailVC, animated: true)
        } else {
            self.present(detailVC, animated: true)
        }
    }
}

// MARK: - 👆 HỖ TRỢ VUỐT TỪ CẠNH TRÁI MÀN HÌNH ĐỂ QUAY LẠI
extension SourcesViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        #if !os(tvOS)
        if gestureRecognizer === self.navigationController?.interactivePopGestureRecognizer {
            return (self.navigationController?.viewControllers.count ?? 0) > 1
        }
        #endif
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
