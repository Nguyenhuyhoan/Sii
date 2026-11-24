
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

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN 100% MÃ CSS CHỦ ĐẠO CỦA BẠN
private struct SourcesCSSTheme {
    static let white = UIColor.white                                                          // #ffffff (--white)
    static let pureBlack = UIColor.black                                                      // #000000 (Chữ đen tuyền độ tương phản tuyệt đối)
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0)       // #f8f9fa (--light)
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0)      // #e9ecef (--border chuẩn 4 góc đều nhau)
    static let innerBorder = UIColor(red: 222/255, green: 229/255, blue: 240/255, alpha: 1.0) // #dee5f0
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)          // #007bff (--blue)
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)       // #6f42c1 (--purple)
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)         // #28a745 (--green)
    static let magenta = UIColor(red: 230/255, green: 0/255, blue: 230/255, alpha: 1.0)       // #e600e6 (data-tab="1")
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0)           // #343a40 (--dark)

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Sleek Top Banner Gradient 3 tầng bắt mắt (#007bff -> #6f42c1 -> #d600d6)
    static let bannerGradStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0).cgColor
    static let bannerGradMid = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0).cgColor
    static let bannerGradEnd = UIColor(red: 214/255, green: 0/255, blue: 214/255, alpha: 1.0).cgColor

    static let cornerRadius: CGFloat = 15.0
    static let innerCornerRadius: CGFloat = 14.0
    static let iPhoneImageCornerRadius: CGFloat = 18.0

    /// Trả về đúng 4 màu chủ đạo luân phiên theo chuẩn `.tab-button[data-tab="1..4"]` trong CSS của bạn
    static func tabAccentColor(for index: Int) -> UIColor {
        switch index % 4 {
        case 0: return magenta // data-tab="1" (#e600e6)
        case 1: return purple  // data-tab="2" (#6f42c1)
        case 2: return blue    // data-tab="3" (#007bff)
        default: return green  // data-tab="4" (#28a745)
        }
    }

    /// Áp dụng viền 4 góc đều nhau (2pt solid --border) + đổ bóng màu phát sáng chuẩn CSS của bạn
    static func applyColoredGlowCardStyle(
        to view: UIView,
        accentColor: UIColor,
        cornerRadius: CGFloat = SourcesCSSTheme.cornerRadius,
        shadowOpacity: Float = 0.22
    ) {
        view.backgroundColor = SourcesCSSTheme.white
        view.layer.cornerRadius = cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.borderWidth = 2.0
        view.layer.borderColor = SourcesCSSTheme.border.cgColor
        view.layer.shadowColor = accentColor.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 14
        view.layer.shadowOpacity = shadowOpacity
    }

    /// Áp dụng style cho khung bao trắng lớn (.tab-container)
    static func applyContainerCardStyle(to view: UIView, cornerRadius: CGFloat = SourcesCSSTheme.cornerRadius) {
        view.backgroundColor = SourcesCSSTheme.white
        view.layer.cornerRadius = cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.borderWidth = 1.5
        view.layer.borderColor = SourcesCSSTheme.border.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 18
        view.layer.shadowOpacity = 0.08
    }
}

// MARK: - 🎬 CÁC THÀNH PHẦN VIDEO LẤY NGUYÊN BẢN TỪ TAB TỔNG QUAN (NEWSVIEWCONTROLLER)
private enum OverviewVideoCSSTheme {
    static let primary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)      // #007bff (--primary-blue)
    static let secondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)   // #6f42c1 (--primary-purple)
    static let green = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)        // #28a745 (--primary-green)
    static let red = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)          // #dc3545 (--primary-red)
    static let pureBlack = SwiftUI.Color(red: 0/255, green: 0/255, blue: 0/255)        // #000000

    static var accentBarGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var mediaFrameBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                primary.opacity(0.75),
                secondary.opacity(0.55),
                primary.opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let mediaFrameCornerRadius: CGFloat = 47.33
    static let mediaFrameLineWidth: CGFloat = 4.0
    static let cornerRadius: CGFloat = 15.0
    static let innerCornerRadius: CGFloat = 14.0
    static let cardBackground = SwiftUI.Color.white
    static let innerRowBackground = SwiftUI.Color(red: 248/255, green: 249/255, blue: 250/255)
    static let border = SwiftUI.Color(red: 233/255, green: 236/255, blue: 239/255)
    static let innerBorder = SwiftUI.Color(red: 222/255, green: 229/255, blue: 240/255)
}

private struct OverviewSectionHeaderView: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil

    var body: some SwiftUI.View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.14))
                        .frame(width: 24, height: 24)
                    SwiftUI.Image(systemName: icon)
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundColor(color)
                }

                SwiftUI.Text(title.uppercased())
                    .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                    .foregroundColor(OverviewVideoCSSTheme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let statusOK = statusOK {
                    SwiftUI.Image(systemName: statusOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(statusOK ? OverviewVideoCSSTheme.green : OverviewVideoCSSTheme.red)
                        .animation(.spring(), value: statusOK)
                }

                if let trailingView = trailingView {
                    trailingView
                }
            }

            RoundedRectangle(cornerRadius: 2.0)
                .fill(OverviewVideoCSSTheme.primary)
                .frame(width: 60, height: 3.0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct OverviewSkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil
    var footerText: String? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .center, spacing: 12) {
            OverviewSectionHeaderView(
                title: title,
                icon: icon,
                color: color,
                statusOK: statusOK,
                trailingView: trailingView
            )
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 11) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OverviewVideoCSSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: OverviewVideoCSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OverviewVideoCSSTheme.cornerRadius, style: .continuous)
                    .stroke(OverviewVideoCSSTheme.border, lineWidth: 2.0)
            )
            .shadow(color: OverviewVideoCSSTheme.secondary.opacity(0.20), radius: 14, x: 0, y: 8)

            if let footerText = footerText {
                SwiftUI.Text(footerText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(OverviewVideoCSSTheme.pureBlack)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
            }
        }
    }
}

/// Khung phát video dọc tỉ lệ 9:19.5 lấy nguyên bản từ tab Tổng quan (NewsViewController)
private struct OverviewIPhone14VerticalVideoFrameView: SwiftUI.View {
    let videoID: String
    @State private var isVisibleOnScreen: Bool = false
    @State private var shouldMountWebView: Bool = false
    @State private var mountTask: Task<Void, Never>? = nil

    private let iPhone14CornerRadius: CGFloat = OverviewVideoCSSTheme.mediaFrameCornerRadius

    var body: some SwiftUI.View {
        ZStack {
            SwiftUI.Color.black
            if shouldMountWebView {
                OverviewYouTubeVerticalPlayerWebView(
                    videoID: videoID,
                    isVisibleOnScreen: isVisibleOnScreen
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(OverviewVideoCSSTheme.primary)
            }
        }
        .aspectRatio(9.0 / 19.5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: iPhone14CornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: iPhone14CornerRadius, style: .continuous)
                .strokeBorder(
                    OverviewVideoCSSTheme.mediaFrameBorderGradient,
                    lineWidth: OverviewVideoCSSTheme.mediaFrameLineWidth
                )
        )
        .shadow(color: OverviewVideoCSSTheme.secondary.opacity(0.24), radius: 14, x: 0, y: 7)
        .padding(.horizontal, 4)
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

/// WebView nhúng trình phát YouTube tối ưu cho khung dọc 9:19.5 lấy nguyên bản từ tab Tổng quan (NewsViewController)
private struct OverviewYouTubeVerticalPlayerWebView: UIViewRepresentable {
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

/// Mục Video hướng dẫn lấy nguyên bản từ `shortcutVideoGuideSection` của tab Tổng quan
private struct OverviewVideoGuideSectionView: SwiftUI.View {
    let videoID: String

    var body: some SwiftUI.View {
        OverviewSkySectionCard(
            title: "HƯỚNG DẪN VIDEO",
            icon: "play.rectangle.fill",
            color: OverviewVideoCSSTheme.primary
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(OverviewVideoCSSTheme.primary.opacity(0.14))
                            .frame(width: 36, height: 36)
                        SwiftUI.Image(systemName: "sparkles.tv.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(OverviewVideoCSSTheme.primary)
                    }

                    SwiftUI.Text("Xem video hướng dẫn chi tiết bên dưới để thực hiện từng bước trực quan và chính xác nhất.")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(OverviewVideoCSSTheme.pureBlack)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OverviewVideoCSSTheme.innerRowBackground)
                .cornerRadius(OverviewVideoCSSTheme.innerCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: OverviewVideoCSSTheme.innerCornerRadius, style: .continuous)
                        .stroke(OverviewVideoCSSTheme.border, lineWidth: 2.0)
                )

                OverviewIPhone14VerticalVideoFrameView(
                    videoID: videoID
                )
            }
        }
    }
}

/// UIKit Wrapper nhúng hoàn chỉnh phần Video của tab Tổng quan vào StackView của trang chi tiết
private final class OverviewHostedVideoSectionView: UIView {
    private let hostingController: UIHostingController<OverviewVideoGuideSectionView>

    init(videoID: String, parentViewController: UIViewController?) {
        let rootView = OverviewVideoGuideSectionView(videoID: videoID)
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

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (#f3e0ff -> #e0f7ff)
private final class SourcesGradientBackgroundView: UIView {
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
        gradientLayer.colors = [SourcesCSSTheme.bgGradientStart, SourcesCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - ➖ THANH GẠCH CHÂN XANH NẰM CHÍNH GIỮA (60x3pt CHUẨN `.features h2::after` TRONG CSS GỐC)
private final class SourcesCenteredUnderlineView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SourcesCSSTheme.blue
        layer.cornerRadius = 1.5
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = SourcesCSSTheme.blue
        layer.cornerRadius = 1.5
        clipsToBounds = true
    }
}

// MARK: - 🖼️ LỚP KHUNG VIỀN GRADIENT 3 MÀU BAO TRỌN ẢNH (.guide img)
private final class GradientBorderContainerView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradientBorder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradientBorder()
    }

    private func setupGradientBorder() {
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        gradientLayer.colors = [
            SourcesCSSTheme.blue.cgColor,
            SourcesCSSTheme.purple.cgColor,
            SourcesCSSTheme.magenta.cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// Giữ nguyên class này để Storyboard không bao giờ báo lỗi thiếu class khi load Nib
@objc(SourcesFooterView)
private final class SourcesFooterView: TextCollectionReusableView {
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet var textView: UITextView!
}

// MARK: - 📚 MÔ HÌNH DỮ LIỆU & BỘ PHÂN TÍCH HƯỚNG DẪN TỪ GITHUB
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
                    let cleaned = GuideParser.stripLeadingNumberOrBullet(from: line)
                    return "• " + cleaned
                }
            }
        }
        return "• Nhấn để xem chi tiết hướng dẫn đầy đủ và hình ảnh minh họa..."
    }
}

private enum GuideParser {
    static let githubGuideURL = "https://github.com/Nguyenhuyhoan/Config/blob/main/huongdan.txt"

    private enum DetectedLinkType {
        case githubImage(URL)
        case youtubeVideo(String)
        case downloadLink(URL)
    }

    /// Xóa bỏ con số đầu dòng (ví dụ: "1.", "2)", "Bước 1:") hoặc ký tự gạch đầu dòng để chuẩn hóa sang dấu chấm đầu dòng
    static func stripLeadingNumberOrBullet(from line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^(?:(?:\d+[\.\)\:\-]?)|(?:[•\-\*\+]))\s*"#
        if let range = cleaned.range(of: pattern, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Làm sạch các dấu câu dính ở cuối hoặc đầu URL khi tách từ văn bản
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

    /// Tự động chuẩn hóa mọi dạng link GitHub (`github.com/.../blob/...`, `github.com/.../raw/...`, `raw.githubusercontent.com/...`) để tải trực tiếp
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

    /// Tách mã Video ID chuẩn từ mọi định dạng link YouTube (watch?v=, youtu.be/, shorts/, embed/, live/)
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

    /// Kiểm tra xem link có phải là link ảnh trên GitHub hay không
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

    /// Phân loại bất kỳ đường dẫn http/https nào thành: Ảnh GitHub, Video YouTube, hoặc Nút Tải Về
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

    /// Phân tích toàn bộ nội dung file `huongdan.txt` và sắp xếp số trước `TTT` từ lớn nhất đến nhỏ nhất
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

    /// Tách văn bản, link ảnh GitHub, link YouTube và link tải về thành các khối riêng biệt
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

// MARK: - 🏷️ THANH TIÊU ĐỀ TRÊN CÙNG MỚI: GỌN ĐẸP, BẮT MẮT, CĂN GIỮA 100%, BỎ "6 BÀI VIẾT"
private final class GuidesHeroHeaderView: UIView {
    private let bannerShadowWrap = UIView()
    private let bannerClipView = UIView()
    private let bannerGradient = CAGradientLayer()
    private let glassShineLayer = CAGradientLayer()

    private let iconGlassBox = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subLabel = UILabel()

    private let sectionTitleLabel = UILabel()
    private let sectionUnderlineView = SourcesCenteredUnderlineView()

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

        // 1. Sleek Top Banner (Gọn đẹp, phối màu 3 tầng Xanh - Tím - Hồng Neon & Căn giữa 100%)
        bannerShadowWrap.translatesAutoresizingMaskIntoConstraints = false
        bannerShadowWrap.layer.cornerRadius = 18.0
        if #available(iOS 13.0, tvOS 13.0, *) {
            bannerShadowWrap.layer.cornerCurve = .continuous
        }
        bannerShadowWrap.layer.masksToBounds = false
        bannerShadowWrap.layer.shadowColor = SourcesCSSTheme.purple.cgColor
        bannerShadowWrap.layer.shadowOffset = CGSize(width: 0, height: 8)
        bannerShadowWrap.layer.shadowRadius = 16
        bannerShadowWrap.layer.shadowOpacity = 0.28

        bannerClipView.translatesAutoresizingMaskIntoConstraints = false
        bannerClipView.layer.cornerRadius = 18.0
        if #available(iOS 13.0, tvOS 13.0, *) {
            bannerClipView.layer.cornerCurve = .continuous
        }
        bannerClipView.clipsToBounds = true
        bannerClipView.layer.borderWidth = 1.5
        bannerClipView.layer.borderColor = UIColor.white.withAlphaComponent(0.70).cgColor

        bannerGradient.colors = [
            SourcesCSSTheme.bannerGradStart,
            SourcesCSSTheme.bannerGradMid,
            SourcesCSSTheme.bannerGradEnd
        ]
        bannerGradient.locations = [0.0, 0.52, 1.0]
        bannerGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        bannerGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        bannerClipView.layer.insertSublayer(bannerGradient, at: 0)

        // Vệt sáng mặt kính chéo nhẹ
        glassShineLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.20).cgColor,
            UIColor.clear.cgColor
        ]
        glassShineLayer.locations = [0.0, 0.5, 1.0]
        glassShineLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        glassShineLayer.endPoint = CGPoint(x: 1.0, y: 0.3)
        bannerClipView.layer.insertSublayer(glassShineLayer, at: 1)

        // Hàng Tiêu đề + Icon kính nằm chính giữa
        let titleRowStack = UIStackView()
        titleRowStack.translatesAutoresizingMaskIntoConstraints = false
        titleRowStack.axis = .horizontal
        titleRowStack.spacing = 9
        titleRowStack.alignment = .center

        iconGlassBox.translatesAutoresizingMaskIntoConstraints = false
        iconGlassBox.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        iconGlassBox.layer.cornerRadius = 10
        if #available(iOS 13.0, tvOS 13.0, *) {
            iconGlassBox.layer.cornerCurve = .continuous
        }
        iconGlassBox.layer.borderWidth = 1.3
        iconGlassBox.layer.borderColor = UIColor.white.withAlphaComponent(0.70).cgColor

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let starCfg = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .bold)
        iconImageView.image = UIImage(systemName: "star.fill", withConfiguration: starCfg)
            ?? UIImage(systemName: "sparkles", withConfiguration: starCfg)
        iconImageView.tintColor = .white
        iconGlassBox.addSubview(iconImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Tin Tức Và Sửa Lỗi"
        if let roundedDesc = UIFont.systemFont(ofSize: 21.5, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 21.5)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 21.5, weight: .heavy)
        }
        titleLabel.textColor = SourcesCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.24

        titleRowStack.addArrangedSubview(iconGlassBox)
        titleRowStack.addArrangedSubview(titleLabel)

        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Cẩm nang khắc phục sự cố do cộng đồng mạng chia sẻ"
        subLabel.font = UIFont.systemFont(ofSize: 13.2, weight: .medium)
        subLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.95)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2

        bannerClipView.addSubview(titleRowStack)
        bannerClipView.addSubview(subLabel)
        bannerShadowWrap.addSubview(bannerClipView)

        // 2. Tiêu đề `.features h2` CĂN GIỮA + gạch chân xanh 60x3pt ở chính giữa (Đã bỏ hoàn toàn nhãn 6 bài viết)
        sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionTitleLabel.text = "TỔNG HỢP CÁC DANH MỤC"
        sectionTitleLabel.textColor = SourcesCSSTheme.blue
        sectionTitleLabel.textAlignment = .center
        if let roundedSecDesc = UIFont.systemFont(ofSize: 18.5, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            sectionTitleLabel.font = UIFont(descriptor: roundedSecDesc, size: 18.5)
        } else {
            sectionTitleLabel.font = UIFont.systemFont(ofSize: 18.5, weight: .heavy)
        }

        sectionUnderlineView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(bannerShadowWrap)
        addSubview(sectionTitleLabel)
        addSubview(sectionUnderlineView)

        NSLayoutConstraint.activate([
            bannerShadowWrap.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            bannerShadowWrap.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            bannerShadowWrap.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            bannerClipView.leadingAnchor.constraint(equalTo: bannerShadowWrap.leadingAnchor),
            bannerClipView.trailingAnchor.constraint(equalTo: bannerShadowWrap.trailingAnchor),
            bannerClipView.topAnchor.constraint(equalTo: bannerShadowWrap.topAnchor),
            bannerClipView.bottomAnchor.constraint(equalTo: bannerShadowWrap.bottomAnchor),

            iconGlassBox.widthAnchor.constraint(equalToConstant: 30),
            iconGlassBox.heightAnchor.constraint(equalToConstant: 30),
            iconImageView.centerXAnchor.constraint(equalTo: iconGlassBox.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconGlassBox.centerYAnchor),

            titleRowStack.centerXAnchor.constraint(equalTo: bannerClipView.centerXAnchor),
            titleRowStack.topAnchor.constraint(equalTo: bannerClipView.topAnchor, constant: 13),

            subLabel.topAnchor.constraint(equalTo: titleRowStack.bottomAnchor, constant: 4),
            subLabel.leadingAnchor.constraint(equalTo: bannerClipView.leadingAnchor, constant: 12),
            subLabel.trailingAnchor.constraint(equalTo: bannerClipView.trailingAnchor, constant: -12),
            subLabel.bottomAnchor.constraint(equalTo: bannerClipView.bottomAnchor, constant: -13),

            sectionTitleLabel.topAnchor.constraint(equalTo: bannerShadowWrap.bottomAnchor, constant: 15),
            sectionTitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sectionTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            sectionTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            sectionUnderlineView.topAnchor.constraint(equalTo: sectionTitleLabel.bottomAnchor, constant: 6),
            sectionUnderlineView.centerXAnchor.constraint(equalTo: centerXAnchor),
            sectionUnderlineView.widthAnchor.constraint(equalToConstant: 60),
            sectionUnderlineView.heightAnchor.constraint(equalToConstant: 3.0),
            sectionUnderlineView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    func updateCount(_ count: Int) {
        // Đã loại bỏ hoàn toàn nhãn "6 bài hướng dẫn" theo yêu cầu của bạn
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bannerGradient.frame = bannerClipView.bounds
        glassShineLayer.frame = CGRect(
            x: -bannerClipView.bounds.width * 0.25,
            y: 0,
            width: bannerClipView.bounds.width * 0.65,
            height: bannerClipView.bounds.height
        )
        CATransaction.commit()
    }
}

// MARK: - 🗂️ THẺ DANH MỤC HƯỚNG DẪN CHUẨN `.tab-button[data-tab="1..4"]` TRONG CSS GỐC
private final class GuideTopicRowCell: UITableViewCell {
    static let reuseIdentifier = "GuideTopicRowCell"

    private let outerContainerSlice = UIView()
    private let cardView = UIView()
    private let badgeContainer = UIView()
    private let badgeIconView = UIImageView()
    private let badgeNumberLabel = UILabel()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let metaStackView = UIStackView()
    private let priorityTagLabel = UILabel()
    private let stepsTagLabel = UILabel()
    private let imagesTagLabel = UILabel()

    private var topSliceConstraint: NSLayoutConstraint!
    private var bottomSliceConstraint: NSLayoutConstraint!

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
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.5,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.975, y: 0.975) : .identity
            self.cardView.alpha = highlighted ? 0.94 : 1.0
        }
    }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Lớp nền trắng bao ngoài tạo cảm giác 1 khung `.tab-container` sát viền 99%
        outerContainerSlice.translatesAutoresizingMaskIntoConstraints = false
        outerContainerSlice.backgroundColor = SourcesCSSTheme.white
        outerContainerSlice.layer.borderColor = SourcesCSSTheme.border.cgColor
        contentView.addSubview(outerContainerSlice)

        // Khối `.tab-button` bên trong: Viền 4 góc đều nhau 2pt + Đổ bóng phát sáng theo màu Tab
        cardView.translatesAutoresizingMaskIntoConstraints = false
        outerContainerSlice.addSubview(cardView)

        // Huy hiệu số thứ tự (#1, #2...) mang màu của Tab
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.layer.cornerRadius = 12
        if #available(iOS 13.0, tvOS 13.0, *) {
            badgeContainer.layer.cornerCurve = .continuous
        }
        badgeContainer.layer.masksToBounds = false

        badgeIconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 10.5, weight: .bold)
        badgeIconView.image = UIImage(systemName: "sparkles", withConfiguration: iconConfig)
        badgeIconView.tintColor = SourcesCSSTheme.white.withAlphaComponent(0.95)
        badgeIconView.contentMode = .scaleAspectFit

        badgeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeNumberLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .heavy)
        badgeNumberLabel.textColor = SourcesCSSTheme.white
        badgeNumberLabel.textAlignment = .center

        badgeContainer.addSubview(badgeIconView)
        badgeContainer.addSubview(badgeNumberLabel)

        // Tiêu đề chính (Chữ đen tuyền #000000)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 15.8, weight: .bold)
        titleLabel.textColor = SourcesCSSTheme.pureBlack
        titleLabel.numberOfLines = 2

        // Phụ đề tóm tắt
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        subtitleLabel.textColor = SourcesCSSTheme.dark
        subtitleLabel.numberOfLines = 1

        // Thanh Tags thông tin (.tab-pill)
        metaStackView.translatesAutoresizingMaskIntoConstraints = false
        metaStackView.axis = .horizontal
        metaStackView.spacing = 5
        metaStackView.alignment = .center

        metaStackView.addArrangedSubview(priorityTagLabel)
        metaStackView.addArrangedSubview(stepsTagLabel)
        metaStackView.addArrangedSubview(imagesTagLabel)

        cardView.addSubview(badgeContainer)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(metaStackView)

        topSliceConstraint = cardView.topAnchor.constraint(equalTo: outerContainerSlice.topAnchor, constant: 6)
        bottomSliceConstraint = cardView.bottomAnchor.constraint(equalTo: outerContainerSlice.bottomAnchor, constant: -6)

        NSLayoutConstraint.activate([
            outerContainerSlice.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            outerContainerSlice.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            outerContainerSlice.topAnchor.constraint(equalTo: contentView.topAnchor),
            outerContainerSlice.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            cardView.leadingAnchor.constraint(equalTo: outerContainerSlice.leadingAnchor, constant: 8),
            cardView.trailingAnchor.constraint(equalTo: outerContainerSlice.trailingAnchor, constant: -8),
            topSliceConstraint,
            bottomSliceConstraint,

            badgeContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 11),
            badgeContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            badgeContainer.widthAnchor.constraint(equalToConstant: 46),
            badgeContainer.heightAnchor.constraint(equalToConstant: 46),

            badgeIconView.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeIconView.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 7),
            badgeIconView.widthAnchor.constraint(equalToConstant: 12),
            badgeIconView.heightAnchor.constraint(equalToConstant: 12),

            badgeNumberLabel.topAnchor.constraint(equalTo: badgeIconView.bottomAnchor, constant: 2),
            badgeNumberLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 2),
            badgeNumberLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -2),

            titleLabel.leadingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: 11),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -11),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            metaStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaStackView.trailingAnchor.constraint(lessThanOrEqualTo: titleLabel.trailingAnchor),
            metaStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 6),
            metaStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12)
        ])
    }

    private func stylePillLabel(_ label: UILabel, accentColor: UIColor) {
        label.font = UIFont.systemFont(ofSize: 10.5, weight: .heavy)
        label.textColor = accentColor
        label.backgroundColor = SourcesCSSTheme.light
        label.layer.cornerRadius = 7
        label.layer.borderWidth = 1.0
        label.layer.borderColor = SourcesCSSTheme.border.cgColor
        label.layer.masksToBounds = true
    }

    func configure(with article: GuideArticle, rowIndex: Int, totalRows: Int) {
        let accentColor = SourcesCSSTheme.tabAccentColor(for: rowIndex)

        // Áp dụng viền 2pt đều 4 góc + bóng màu phát sáng chuẩn data-tab="1..4"
        SourcesCSSTheme.applyColoredGlowCardStyle(
            to: cardView,
            accentColor: accentColor,
            cornerRadius: SourcesCSSTheme.cornerRadius,
            shadowOpacity: 0.22
        )

        badgeContainer.backgroundColor = accentColor
        badgeContainer.layer.shadowColor = accentColor.cgColor
        badgeContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        badgeContainer.layer.shadowRadius = 8
        badgeContainer.layer.shadowOpacity = 0.28

        badgeNumberLabel.text = "#\(article.orderNumber)"
        titleLabel.text = article.title
        subtitleLabel.text = article.previewSubtitle

        stylePillLabel(priorityTagLabel, accentColor: accentColor)
        stylePillLabel(stepsTagLabel, accentColor: accentColor)
        stylePillLabel(imagesTagLabel, accentColor: accentColor)

        if rowIndex == 0 {
            priorityTagLabel.text = "  ★ MỚI NHẤT  "
            priorityTagLabel.isHidden = false
        } else {
            priorityTagLabel.isHidden = true
        }

        let steps = article.stepCount
        stepsTagLabel.text = steps > 0 ? "  \(steps) mục  " : "  Chi tiết  "

        let imgs = article.imageCount
        let vids = article.videoCount
        let dls = article.downloadCount

        var mediaParts: [String] = []
        if imgs > 0 { mediaParts.append("🖼 \(imgs) ảnh") }
        if vids > 0 { mediaParts.append("🎬 \(vids) video") }
        if dls > 0 { mediaParts.append("⬇️ \(dls) tệp") }

        if !mediaParts.isEmpty {
            imagesTagLabel.text = "  " + mediaParts.joined(separator: " • ") + "  "
            imagesTagLabel.isHidden = false
        } else {
            imagesTagLabel.isHidden = true
        }

        // Bo góc cho khung trắng lớn `.tab-container` ở dòng đầu tiên và dòng cuối cùng
        let isFirst = (rowIndex == 0)
        let isLast = (rowIndex == totalRows - 1)
        topSliceConstraint.constant = isFirst ? 10 : 6
        bottomSliceConstraint.constant = isLast ? -10 : -6

        if isFirst && isLast {
            outerContainerSlice.layer.cornerRadius = SourcesCSSTheme.cornerRadius
            outerContainerSlice.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
        } else if isFirst {
            outerContainerSlice.layer.cornerRadius = SourcesCSSTheme.cornerRadius
            outerContainerSlice.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if isLast {
            outerContainerSlice.layer.cornerRadius = SourcesCSSTheme.cornerRadius
            outerContainerSlice.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            outerContainerSlice.layer.cornerRadius = 0
        }
    }
}

// MARK: - 📱 KHUNG HIỂN THỊ ẢNH CHUẨN `.guide img` (VIỀN GRADIENT 3 MÀU + BÓNG ĐỔ SÂU)
private final class GuideStyledImageView: UIView {
    private let outerShadowContainer = UIView()
    private let borderContainer = GradientBorderContainerView()
    private let innerClipContainer = UIView()
    private let imageView = UIImageView()
    private let shimmerActivity = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private var imageURL: URL?
    private var aspectRatioConstraint: NSLayoutConstraint?
    private var defaultHeightConstraint: NSLayoutConstraint!
    var onTapImage: ((UIImage) -> Void)?

    private let borderThickness: CGFloat = 3.5

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

        outerShadowContainer.translatesAutoresizingMaskIntoConstraints = false
        outerShadowContainer.backgroundColor = .clear
        outerShadowContainer.layer.shadowColor = UIColor.black.cgColor
        outerShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        outerShadowContainer.layer.shadowRadius = 16
        outerShadowContainer.layer.shadowOpacity = 0.28

        let outerRadius = SourcesCSSTheme.cornerRadius
        borderContainer.translatesAutoresizingMaskIntoConstraints = false
        borderContainer.layer.cornerRadius = outerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            borderContainer.layer.cornerCurve = .continuous
        }
        borderContainer.clipsToBounds = true

        let innerRadius = max(outerRadius - borderThickness, 8.0)
        innerClipContainer.translatesAutoresizingMaskIntoConstraints = false
        innerClipContainer.backgroundColor = SourcesCSSTheme.white
        innerClipContainer.layer.cornerRadius = innerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            innerClipContainer.layer.cornerCurve = .continuous
        }
        innerClipContainer.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = SourcesCSSTheme.white
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
        imageView.addGestureRecognizer(tapGesture)

        shimmerActivity.translatesAutoresizingMaskIntoConstraints = false
        shimmerActivity.color = SourcesCSSTheme.blue
        shimmerActivity.hidesWhenStopped = true

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Không thể tải hình ảnh minh họa"
        errorLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        errorLabel.textColor = SourcesCSSTheme.pureBlack
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("  Thử tải lại ảnh  ", for: .normal)
        retryButton.setTitleColor(SourcesCSSTheme.white, for: .normal)
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        retryButton.backgroundColor = SourcesCSSTheme.blue
        retryButton.layer.cornerRadius = 14
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(loadImage), for: .touchUpInside)

        innerClipContainer.addSubview(imageView)
        innerClipContainer.addSubview(shimmerActivity)
        innerClipContainer.addSubview(errorLabel)
        innerClipContainer.addSubview(retryButton)

        borderContainer.addSubview(innerClipContainer)
        outerShadowContainer.addSubview(borderContainer)
        addSubview(outerShadowContainer)

        defaultHeightConstraint = innerClipContainer.heightAnchor.constraint(equalToConstant: 220)
        defaultHeightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            outerShadowContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            outerShadowContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            outerShadowContainer.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            outerShadowContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            borderContainer.leadingAnchor.constraint(equalTo: outerShadowContainer.leadingAnchor),
            borderContainer.trailingAnchor.constraint(equalTo: outerShadowContainer.trailingAnchor),
            borderContainer.topAnchor.constraint(equalTo: outerShadowContainer.topAnchor),
            borderContainer.bottomAnchor.constraint(equalTo: outerShadowContainer.bottomAnchor),

            innerClipContainer.leadingAnchor.constraint(equalTo: borderContainer.leadingAnchor, constant: borderThickness),
            innerClipContainer.trailingAnchor.constraint(equalTo: borderContainer.trailingAnchor, constant: -borderThickness),
            innerClipContainer.topAnchor.constraint(equalTo: borderContainer.topAnchor, constant: borderThickness),
            innerClipContainer.bottomAnchor.constraint(equalTo: borderContainer.bottomAnchor, constant: -borderThickness),
            defaultHeightConstraint,

            imageView.leadingAnchor.constraint(equalTo: innerClipContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: innerClipContainer.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: innerClipContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: innerClipContainer.bottomAnchor),

            shimmerActivity.centerXAnchor.constraint(equalTo: innerClipContainer.centerXAnchor),
            shimmerActivity.centerYAnchor.constraint(equalTo: innerClipContainer.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: innerClipContainer.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: innerClipContainer.centerYAnchor, constant: -14),
            errorLabel.leadingAnchor.constraint(equalTo: innerClipContainer.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: innerClipContainer.trailingAnchor, constant: -16),

            retryButton.centerXAnchor.constraint(equalTo: innerClipContainer.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
            retryButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func loadImage() {
        guard let originalURL = imageURL else { return }
        let resolvedURL = GuideParser.convertToRawGitHubURL(originalURL.absoluteString) ?? originalURL

        errorLabel.isHidden = true
        retryButton.isHidden = true
        shimmerActivity.startAnimating()

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
                self.shimmerActivity.stopAnimating()
                self.errorLabel.isHidden = false
                self.retryButton.isHidden = false
            }
        }
    }

    private func applyLoadedImage(_ image: UIImage) {
        shimmerActivity.stopAnimating()
        errorLabel.isHidden = true
        retryButton.isHidden = true

        imageView.alpha = 0
        imageView.image = image

        if image.size.width > 0 && image.size.height > 0 {
            let ratio = image.size.height / image.size.width
            defaultHeightConstraint.isActive = false
            if let oldAspect = aspectRatioConstraint {
                oldAspect.isActive = false
            }
            let newAspect = innerClipContainer.heightAnchor.constraint(equalTo: innerClipContainer.widthAnchor, multiplier: ratio)
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

// MARK: - ⬇️ NÚT TẢI NỔI KHỐI RÕ NÉT (.btn-primary GRADIENT XANH - TÍM)
private final class ProminentGradientDownloadButton: UIControl {
    private let shadowWrap = UIView()
    private let gradientContainer = UIView()
    private let gradientLayer = CAGradientLayer()
    private let contentStack = UIStackView()
    private let iconImageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let titleLabel = UILabel()

    override var isHighlighted: Bool {
        didSet {
            animateHighlightState(isHighlighted)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        shadowWrap.translatesAutoresizingMaskIntoConstraints = false
        shadowWrap.isUserInteractionEnabled = false
        shadowWrap.backgroundColor = .clear
        shadowWrap.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        shadowWrap.layer.shadowOffset = CGSize(width: 0, height: 6)
        shadowWrap.layer.shadowRadius = 12
        shadowWrap.layer.shadowOpacity = 0.32

        gradientContainer.translatesAutoresizingMaskIntoConstraints = false
        gradientContainer.isUserInteractionEnabled = false
        gradientContainer.backgroundColor = SourcesCSSTheme.blue
        gradientContainer.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            gradientContainer.layer.cornerCurve = .continuous
        }
        gradientContainer.clipsToBounds = true

        gradientLayer.colors = [
            SourcesCSSTheme.blue.cgColor,
            SourcesCSSTheme.purple.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientContainer.layer.insertSublayer(gradientLayer, at: 0)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isUserInteractionEnabled = false
        contentStack.axis = .horizontal
        contentStack.spacing = 10
        contentStack.alignment = .center

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .heavy)
        iconImageView.image = UIImage(systemName: "icloud.and.arrow.down.fill", withConfiguration: iconCfg)
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit

        spinner.color = .white
        spinner.hidesWhenStopped = true

        titleLabel.text = "Nhấn Vào Đây Để Tải Về"
        if let roundedDesc = UIFont.systemFont(ofSize: 16.5, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 16.5)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .heavy)
        }
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        contentStack.addArrangedSubview(iconImageView)
        contentStack.addArrangedSubview(spinner)
        contentStack.addArrangedSubview(titleLabel)

        gradientContainer.addSubview(contentStack)
        shadowWrap.addSubview(gradientContainer)
        addSubview(shadowWrap)

        NSLayoutConstraint.activate([
            shadowWrap.leadingAnchor.constraint(equalTo: leadingAnchor),
            shadowWrap.trailingAnchor.constraint(equalTo: trailingAnchor),
            shadowWrap.topAnchor.constraint(equalTo: topAnchor),
            shadowWrap.bottomAnchor.constraint(equalTo: bottomAnchor),

            gradientContainer.leadingAnchor.constraint(equalTo: shadowWrap.leadingAnchor),
            gradientContainer.trailingAnchor.constraint(equalTo: shadowWrap.trailingAnchor),
            gradientContainer.topAnchor.constraint(equalTo: shadowWrap.topAnchor),
            gradientContainer.bottomAnchor.constraint(equalTo: shadowWrap.bottomAnchor),

            contentStack.centerXAnchor.constraint(equalTo: gradientContainer.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: gradientContainer.centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: gradientContainer.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: gradientContainer.trailingAnchor, constant: -16)
        ])
    }

    func setLoadingState(_ isLoading: Bool) {
        if isLoading {
            iconImageView.isHidden = true
            spinner.startAnimating()
            titleLabel.text = "Đang Tải Về"
            gradientLayer.colors = [
                SourcesCSSTheme.purple.cgColor,
                SourcesCSSTheme.blue.cgColor
            ]
        } else {
            spinner.stopAnimating()
            iconImageView.isHidden = false
            titleLabel.text = "Nhấn Vào Đây Để Tải Về"
            gradientLayer.colors = [
                SourcesCSSTheme.blue.cgColor,
                SourcesCSSTheme.purple.cgColor
            ]
        }
    }

    private func animateHighlightState(_ highlighted: Bool) {
        UIView.animate(
            withDuration: 0.16,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.6,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.shadowWrap.transform = highlighted ? CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
            self.gradientContainer.alpha = highlighted ? 0.92 : 1.0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = gradientContainer.bounds
        CATransaction.commit()
    }
}

// MARK: - ⬇️ KHUNG TẢI VỀ CHUẨN `.guide-actions` (KHUNG HƯỚNG DẪN VIỀN ĐỀU + NÚT TẢI)
private final class GuideDownloadActionCardView: UIView {
    private let downloadURL: URL
    private weak var hostViewController: UIViewController?

    private let mainStack = UIStackView()
    private let noticeBannerView = UIView()
    private let noticeIconView = UIImageView()
    private let noticeTextLabel = UILabel()
    private let downloadButton = ProminentGradientDownloadButton()

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

        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.spacing = 12

        // 1. Khung hướng dẫn viền đều 4 cạnh + bóng xanh dương chuẩn `.btn-outline-glow`
        noticeBannerView.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyColoredGlowCardStyle(
            to: noticeBannerView,
            accentColor: SourcesCSSTheme.blue,
            cornerRadius: SourcesCSSTheme.cornerRadius,
            shadowOpacity: 0.20
        )

        noticeIconView.translatesAutoresizingMaskIntoConstraints = false
        let noticeIconCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        noticeIconView.image = UIImage(systemName: "folder.fill.badge.plus", withConfiguration: noticeIconCfg)
        noticeIconView.tintColor = SourcesCSSTheme.blue
        noticeIconView.contentMode = .scaleAspectFit

        noticeTextLabel.translatesAutoresizingMaskIntoConstraints = false
        noticeTextLabel.numberOfLines = 0
        noticeTextLabel.attributedText = makeNoticeAttributedText()

        noticeBannerView.addSubview(noticeIconView)
        noticeBannerView.addSubview(noticeTextLabel)

        // 2. Nút "Nhấn Vào Đây Để Tải Về"
        downloadButton.addTarget(self, action: #selector(handleDownloadButtonTap), for: .touchUpInside)

        NSLayoutConstraint.activate([
            noticeIconView.leadingAnchor.constraint(equalTo: noticeBannerView.leadingAnchor, constant: 13),
            noticeIconView.centerYAnchor.constraint(equalTo: noticeBannerView.centerYAnchor),
            noticeIconView.widthAnchor.constraint(equalToConstant: 26),
            noticeIconView.heightAnchor.constraint(equalToConstant: 26),

            noticeTextLabel.leadingAnchor.constraint(equalTo: noticeIconView.trailingAnchor, constant: 10),
            noticeTextLabel.trailingAnchor.constraint(equalTo: noticeBannerView.trailingAnchor, constant: -13),
            noticeTextLabel.topAnchor.constraint(equalTo: noticeBannerView.topAnchor, constant: 13),
            noticeTextLabel.bottomAnchor.constraint(equalTo: noticeBannerView.bottomAnchor, constant: -13),

            downloadButton.heightAnchor.constraint(equalToConstant: 52)
        ])

        mainStack.addArrangedSubview(noticeBannerView)
        mainStack.addArrangedSubview(downloadButton)
        addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    private func makeNoticeAttributedText() -> NSAttributedString {
        let mainText = "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file"
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3.5

        let result = NSMutableAttributedString(
            string: mainText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15.0, weight: .bold),
                .foregroundColor: SourcesCSSTheme.pureBlack,
                .paragraphStyle: paragraph
            ]
        )

        let nsMain = mainText as NSString
        let highlightRange = nsMain.range(of: "Lưu Vào Tệp", options: .caseInsensitive)
        if highlightRange.location != NSNotFound {
            result.addAttributes([
                .foregroundColor: SourcesCSSTheme.blue,
                .font: UIFont.systemFont(ofSize: 15.5, weight: .heavy)
            ], range: highlightRange)
        }

        return result
    }

    @objc private func handleDownloadButtonTap() {
        guard !isDownloading else { return }

        #if !os(tvOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif

        UIView.animate(withDuration: 0.12, animations: {
            self.downloadButton.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.6) {
                self.downloadButton.transform = .identity
            }
        }

        isDownloading = true
        downloadButton.setLoadingState(true)

        let hostLower = (downloadURL.host ?? "").lowercased()
        let isCloudWebPortal = hostLower.contains("icloud.com")
            || hostLower.contains("drive.google.com")
            || hostLower.contains("mega.nz")
            || hostLower.contains("mediafire.com")
            || hostLower.contains("1drv.ms")
            || hostLower.contains("dropbox.com")

        if isCloudWebPortal && !downloadURL.pathExtension.lowercased().isOne(of: ["ipa", "zip", "mobileconfig", "plist", "deb", "tipa"]) {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                guard let self = self else { return }
                UIApplication.shared.open(self.downloadURL, options: [:], completionHandler: nil)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self.isDownloading = false
                self.downloadButton.setLoadingState(false)
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                self.isDownloading = false
                self.downloadButton.setLoadingState(false)
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
        view.backgroundColor = UIColor.black.withAlphaComponent(0.92)

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
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        closeButton.layer.cornerRadius = 18
        closeButton.layer.borderWidth = 1.0
        closeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
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

// MARK: - 📖 TRANG CHI TIẾT BÀI HƯỚNG DẪN (THANH TIÊU ĐỀ CĂN GIỮA + KHUNG VIỀN 4 GÓC ĐỀU NHAU & ĐỔ BÓNG MÀU)
private final class GuideArticleDetailViewController: UIViewController {
    private let article: GuideArticle
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    private let bannerShadowWrap = UIView()
    private let bannerClipView = UIView()
    private let bannerGradient = CAGradientLayer()
    private let glassShineLayer = CAGradientLayer()

    private let whiteTabContainerCard = UIView()
    private let guideInnerStackView = UIStackView()

    private var stepCounter: Int = 0

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
        setupScrollView()
        setupTopBackBarRow()
        setupCenteredSleekBanner()
        setupCenteredSectionHeader()
        setupWhiteTabContainer()
        buildArticleContent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bannerGradient.frame = bannerClipView.bounds
        glassShineLayer.frame = CGRect(
            x: -bannerClipView.bounds.width * 0.25,
            y: 0,
            width: bannerClipView.bounds.width * 0.65,
            height: bannerClipView.bounds.height
        )
        CATransaction.commit()
    }

    private func setupBackground() {
        let bgView = SourcesGradientBackgroundView(frame: view.bounds)
        bgView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bgView)
        NSLayoutConstraint.activate([
            bgView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bgView.topAnchor.constraint(equalTo: view.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 50, right: 0)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 12
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 24, trailing: 6)

        scrollView.addSubview(contentStackView)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    // Hàng nút "‹ Quay lại danh mục" + Huy hiệu "✦ CHỦ ĐỀ #..." gọn đẹp trên cùng
    private func setupTopBackBarRow() {
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false

        let backBtn = UIButton(type: .system)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        backBtn.setTitle("‹ Quay lại danh mục", for: .normal)
        backBtn.setTitleColor(SourcesCSSTheme.blue, for: .normal)
        backBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .heavy)
        backBtn.backgroundColor = SourcesCSSTheme.white
        backBtn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        backBtn.layer.cornerRadius = 10
        backBtn.layer.borderWidth = 1.5
        backBtn.layer.borderColor = SourcesCSSTheme.border.cgColor
        backBtn.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        backBtn.layer.shadowOffset = CGSize(width: 0, height: 5)
        backBtn.layer.shadowRadius = 10
        backBtn.layer.shadowOpacity = 0.18
        backBtn.addTarget(self, action: #selector(handleBackButtonTap), for: .touchUpInside)

        let topicBadge = UILabel()
        topicBadge.translatesAutoresizingMaskIntoConstraints = false
        topicBadge.text = "  ✦ CHỦ ĐỀ #\(article.orderNumber)  "
        topicBadge.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        topicBadge.textColor = SourcesCSSTheme.white
        topicBadge.backgroundColor = SourcesCSSTheme.blue
        topicBadge.layer.cornerRadius = 10
        topicBadge.layer.masksToBounds = true
        topicBadge.layer.borderWidth = 1.5
        topicBadge.layer.borderColor = UIColor(red: 50/255, green: 196/255, blue: 83/255, alpha: 1.0).cgColor

        topBar.addSubview(backBtn)
        topBar.addSubview(topicBadge)

        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 2),
            backBtn.topAnchor.constraint(equalTo: topBar.topAnchor),
            backBtn.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            backBtn.heightAnchor.constraint(equalToConstant: 32),

            topicBadge.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -2),
            topicBadge.centerYAnchor.constraint(equalTo: backBtn.centerYAnchor),
            topicBadge.heightAnchor.constraint(equalToConstant: 28)
        ])

        contentStackView.addArrangedSubview(topBar)
    }

    // Thanh tiêu đề bài viết CĂN GIỮA 100%, đồng bộ màu Gradient 3 tầng bắt mắt
    private func setupCenteredSleekBanner() {
        bannerShadowWrap.translatesAutoresizingMaskIntoConstraints = false
        bannerShadowWrap.layer.cornerRadius = 18.0
        if #available(iOS 13.0, tvOS 13.0, *) {
            bannerShadowWrap.layer.cornerCurve = .continuous
        }
        bannerShadowWrap.layer.masksToBounds = false
        bannerShadowWrap.layer.shadowColor = SourcesCSSTheme.purple.cgColor
        bannerShadowWrap.layer.shadowOffset = CGSize(width: 0, height: 8)
        bannerShadowWrap.layer.shadowRadius = 16
        bannerShadowWrap.layer.shadowOpacity = 0.28

        bannerClipView.translatesAutoresizingMaskIntoConstraints = false
        bannerClipView.layer.cornerRadius = 18.0
        if #available(iOS 13.0, tvOS 13.0, *) {
            bannerClipView.layer.cornerCurve = .continuous
        }
        bannerClipView.clipsToBounds = true
        bannerClipView.layer.borderWidth = 1.5
        bannerClipView.layer.borderColor = UIColor.white.withAlphaComponent(0.70).cgColor

        bannerGradient.colors = [
            SourcesCSSTheme.bannerGradStart,
            SourcesCSSTheme.bannerGradMid,
            SourcesCSSTheme.bannerGradEnd
        ]
        bannerGradient.locations = [0.0, 0.52, 1.0]
        bannerGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        bannerGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        bannerClipView.layer.insertSublayer(bannerGradient, at: 0)

        glassShineLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.20).cgColor,
            UIColor.clear.cgColor
        ]
        glassShineLayer.locations = [0.0, 0.5, 1.0]
        glassShineLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        glassShineLayer.endPoint = CGPoint(x: 1.0, y: 0.3)
        bannerClipView.layer.insertSublayer(glassShineLayer, at: 1)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = article.title
        if let roundedDesc = UIFont.systemFont(ofSize: 20, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 20)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        }
        titleLabel.textColor = SourcesCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.24

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Mọi cách khắc phục không đảm bảo thành công 100%, bạn cần kiên nhẫn và thực hiện lại nhiều lần."
        subLabel.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        subLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.95)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 0

        bannerClipView.addSubview(titleLabel)
        bannerClipView.addSubview(subLabel)
        bannerShadowWrap.addSubview(bannerClipView)

        NSLayoutConstraint.activate([
            bannerClipView.leadingAnchor.constraint(equalTo: bannerShadowWrap.leadingAnchor),
            bannerClipView.trailingAnchor.constraint(equalTo: bannerShadowWrap.trailingAnchor),
            bannerClipView.topAnchor.constraint(equalTo: bannerShadowWrap.topAnchor),
            bannerClipView.bottomAnchor.constraint(equalTo: bannerShadowWrap.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: bannerClipView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: bannerClipView.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: bannerClipView.trailingAnchor, constant: -14),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subLabel.leadingAnchor.constraint(equalTo: bannerClipView.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: bannerClipView.trailingAnchor, constant: -14),
            subLabel.bottomAnchor.constraint(equalTo: bannerClipView.bottomAnchor, constant: -14)
        ])

        contentStackView.addArrangedSubview(bannerShadowWrap)
    }

    // Tiêu đề "HƯỚNG DẪN & KHẮC PHỤC SỰ CỐ" căn giữa + gạch chân xanh 60x3pt ở giữa
    private func setupCenteredSectionHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        let primaryLabel = UILabel()
        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.text = "HƯỚNG DẪN & KHẮC PHỤC SỰ CỐ"
        primaryLabel.textColor = SourcesCSSTheme.blue
        primaryLabel.textAlignment = .center
        if let roundedDesc = UIFont.systemFont(ofSize: 18, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            primaryLabel.font = UIFont(descriptor: roundedDesc, size: 18)
        } else {
            primaryLabel.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        }

        let underline = SourcesCenteredUnderlineView()
        underline.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(primaryLabel)
        headerContainer.addSubview(underline)

        NSLayoutConstraint.activate([
            primaryLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            primaryLabel.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            primaryLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 8),
            primaryLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -8),

            underline.topAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: 6),
            underline.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            underline.widthAnchor.constraint(equalToConstant: 60),
            underline.heightAnchor.constraint(equalToConstant: 3.0),
            underline.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4)
        ])

        contentStackView.addArrangedSubview(headerContainer)
    }

    // Khung trắng lớn `.tab-container` bao bọc toàn bộ các bước hướng dẫn
    private func setupWhiteTabContainer() {
        whiteTabContainerCard.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyContainerCardStyle(to: whiteTabContainerCard, cornerRadius: SourcesCSSTheme.cornerRadius)

        guideInnerStackView.translatesAutoresizingMaskIntoConstraints = false
        guideInnerStackView.axis = .vertical
        guideInnerStackView.spacing = 12

        whiteTabContainerCard.addSubview(guideInnerStackView)
        NSLayoutConstraint.activate([
            guideInnerStackView.leadingAnchor.constraint(equalTo: whiteTabContainerCard.leadingAnchor, constant: 9),
            guideInnerStackView.trailingAnchor.constraint(equalTo: whiteTabContainerCard.trailingAnchor, constant: -9),
            guideInnerStackView.topAnchor.constraint(equalTo: whiteTabContainerCard.topAnchor, constant: 12),
            guideInnerStackView.bottomAnchor.constraint(equalTo: whiteTabContainerCard.bottomAnchor, constant: -12)
        ])

        contentStackView.addArrangedSubview(whiteTabContainerCard)
    }

    private func buildArticleContent() {
        stepCounter = 0

        if article.blocks.isEmpty {
            let emptyStep = makeUniformBorderGlowStepCard(stepText: "Nội dung hướng dẫn đang được cập nhật.", colorIndex: 0)
            guideInnerStackView.addArrangedSubview(emptyStep)
        } else {
            for block in article.blocks {
                switch block.type {
                case .text(let textContent):
                    let rawLines = textContent.components(separatedBy: .newlines)
                    for line in rawLines {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { continue }
                        let cleanedText = GuideParser.stripLeadingNumberOrBullet(from: trimmed)
                        if !cleanedText.isEmpty {
                            let stepCard = makeUniformBorderGlowStepCard(stepText: cleanedText, colorIndex: stepCounter)
                            guideInnerStackView.addArrangedSubview(stepCard)
                            stepCounter += 1
                        }
                    }

                case .image(let imageURL):
                    let imageViewCard = GuideStyledImageView(url: imageURL)
                    imageViewCard.onTapImage = { [weak self] tappedImage in
                        let previewVC = GuideImagePreviewController(image: tappedImage)
                        self?.present(previewVC, animated: true)
                    }
                    guideInnerStackView.addArrangedSubview(imageViewCard)

                case .youtube(let videoID):
                    let overviewVideoView = OverviewHostedVideoSectionView(videoID: videoID, parentViewController: self)
                    guideInnerStackView.addArrangedSubview(overviewVideoView)

                case .download(let downloadURL):
                    let downloadCard = GuideDownloadActionCardView(url: downloadURL, hostViewController: self)
                    guideInnerStackView.addArrangedSubview(downloadCard)
                }
            }
        }

        // Đường kẻ phân cách & Nút quay lại ở cuối bài (.btn-tertiary màu Tím)
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = SourcesCSSTheme.border
        separator.heightAnchor.constraint(equalToConstant: 1.0).isActive = true
        guideInnerStackView.addArrangedSubview(separator)

        let bottomBackBtn = UIButton(type: .system)
        bottomBackBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomBackBtn.setTitle("‹ Quay Lại Tổng Hợp Danh Mục", for: .normal)
        bottomBackBtn.setTitleColor(SourcesCSSTheme.white, for: .normal)
        bottomBackBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        bottomBackBtn.backgroundColor = SourcesCSSTheme.purple
        bottomBackBtn.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            bottomBackBtn.layer.cornerCurve = .continuous
        }
        bottomBackBtn.layer.shadowColor = SourcesCSSTheme.purple.cgColor
        bottomBackBtn.layer.shadowOffset = CGSize(width: 0, height: 6)
        bottomBackBtn.layer.shadowRadius = 12
        bottomBackBtn.layer.shadowOpacity = 0.25
        bottomBackBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        bottomBackBtn.addTarget(self, action: #selector(handleBackButtonTap), for: .touchUpInside)

        guideInnerStackView.addArrangedSubview(bottomBackBtn)
    }

    /// Khung bước hướng dẫn (`guide-step-card`): Viền 4 cạnh bằng nhau (`2pt solid --border`), bỏ hoàn toàn viền trái dày, giữ nguyên bóng màu phát sáng
    private func makeUniformBorderGlowStepCard(stepText: String, colorIndex: Int) -> UIView {
        let accentColor = SourcesCSSTheme.tabAccentColor(for: colorIndex)

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyColoredGlowCardStyle(
            to: card,
            accentColor: accentColor,
            cornerRadius: SourcesCSSTheme.cornerRadius,
            shadowOpacity: 0.18
        )

        let bulletDot = UILabel()
        bulletDot.translatesAutoresizingMaskIntoConstraints = false
        bulletDot.text = "•"
        bulletDot.font = UIFont.systemFont(ofSize: 21, weight: .black)
        bulletDot.textColor = accentColor
        bulletDot.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.attributedText = styleHighlightedInstructionText(stepText)

        card.addSubview(bulletDot)
        card.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            bulletDot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 11),
            bulletDot.topAnchor.constraint(equalTo: card.topAnchor, constant: 9),
            bulletDot.widthAnchor.constraint(equalToConstant: 16),

            bodyLabel.leadingAnchor.constraint(equalTo: bulletDot.trailingAnchor, constant: 6),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            bodyLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 11),
            bodyLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -11)
        ])

        return card
    }

    /// Tự động làm nổi bật mũi tên `→` màu xanh chuẩn CSS và giữ chữ đen tuyền `#000000` sắc nét
    private func styleHighlightedInstructionText(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15.2, weight: .medium),
                .foregroundColor: SourcesCSSTheme.pureBlack,
                .paragraphStyle: paragraphStyle
            ]
        )

        let nsString = text as NSString
        var searchRange = NSRange(location: 0, length: nsString.length)
        while searchRange.location < nsString.length {
            let found = nsString.range(of: "→", options: [], range: searchRange)
            if found.location != NSNotFound {
                attr.addAttributes([
                    .foregroundColor: SourcesCSSTheme.blue,
                    .font: UIFont.systemFont(ofSize: 16, weight: .heavy)
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

// MARK: - 🚀 CONTROLLER CHÍNH: SOURCESVIEWCONTROLLER
final class SourcesViewController: UICollectionViewController {
    // Giữ nguyên biến này để tương thích 100% với AppDelegate / SceneDelegate khi build IPA
    var deepLinkSourceURL: URL? {
        didSet {
            self.handleAddSourceDeepLink()
        }
    }

    private var articles: [GuideArticle] = []
    private var isLoadingGuides = false
    private var fetchTask: Task<Void, Never>?

    private let guidesTableView = UITableView(frame: .zero, style: .plain)
    private let heroHeaderView = GuidesHeroHeaderView(frame: CGRect(x: 0, y: 0, width: 375, height: 142))
    #if !os(tvOS)
    private let refreshControl = UIRefreshControl()
    #endif

    // Khung trạng thái Đang tải / Lỗi mạng
    private let stateCardView = UIView()
    private let stateActivityIndicator = UIActivityIndicatorView(style: .large)
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
            let targetHeight: CGFloat = 142
            if header.frame.height != targetHeight || header.frame.width != guidesTableView.bounds.width {
                header.frame = CGRect(x: 0, y: 0, width: guidesTableView.bounds.width, height: targetHeight)
                guidesTableView.tableHeaderView = header
            }
        }
    }

    // Giữ nguyên các @IBSegueAction và @IBAction để Storyboard kết nối hoàn hảo không lỗi
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

        let gradientBg = SourcesGradientBackgroundView(frame: UIScreen.main.bounds)
        gradientBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        guidesTableView.backgroundView = gradientBg
        guidesTableView.backgroundColor = .clear
        guidesTableView.separatorStyle = .none
        guidesTableView.showsVerticalScrollIndicator = true
        guidesTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        if #available(iOS 15.0, tvOS 15.0, *) {
            guidesTableView.sectionHeaderTopPadding = 0
        }

        guidesTableView.translatesAutoresizingMaskIntoConstraints = false
        guidesTableView.delegate = self
        guidesTableView.dataSource = self
        guidesTableView.rowHeight = UITableView.automaticDimension
        guidesTableView.estimatedRowHeight = 112
        guidesTableView.register(GuideTopicRowCell.self, forCellReuseIdentifier: GuideTopicRowCell.reuseIdentifier)

        guidesTableView.tableHeaderView = heroHeaderView

        #if !os(tvOS)
        refreshControl.tintColor = SourcesCSSTheme.blue
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

    func setupTableFooterInfo() {
        let footerWrap = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 84))
        footerWrap.backgroundColor = .clear

        let footerCard = UIView()
        footerCard.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyContainerCardStyle(to: footerCard, cornerRadius: SourcesCSSTheme.cornerRadius)

        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.text = "Dữ liệu hướng dẫn được đồng bộ trực tiếp từ hệ thống máy chủ GitHub\nNhấn vào từng danh mục để xem hướng dẫn chi tiết & hình ảnh minh họa"
        infoLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        infoLabel.textColor = SourcesCSSTheme.dark
        infoLabel.numberOfLines = 2
        infoLabel.textAlignment = .center

        footerCard.addSubview(infoLabel)
        footerWrap.addSubview(footerCard)

        NSLayoutConstraint.activate([
            footerCard.leadingAnchor.constraint(equalTo: footerWrap.leadingAnchor, constant: 4),
            footerCard.trailingAnchor.constraint(equalTo: footerWrap.trailingAnchor, constant: -4),
            footerCard.topAnchor.constraint(equalTo: footerWrap.topAnchor, constant: 12),
            footerCard.bottomAnchor.constraint(equalTo: footerWrap.bottomAnchor, constant: -4),

            infoLabel.centerXAnchor.constraint(equalTo: footerCard.centerXAnchor),
            infoLabel.centerYAnchor.constraint(equalTo: footerCard.centerYAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: footerCard.leadingAnchor, constant: 12),
            infoLabel.trailingAnchor.constraint(equalTo: footerCard.trailingAnchor, constant: -12)
        ])

        guidesTableView.tableFooterView = footerWrap
    }

    func setupStateOverlayCard() {
        stateCardView.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyColoredGlowCardStyle(
            to: stateCardView,
            accentColor: SourcesCSSTheme.blue,
            cornerRadius: SourcesCSSTheme.cornerRadius
        )

        stateActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        stateActivityIndicator.color = SourcesCSSTheme.blue
        stateActivityIndicator.hidesWhenStopped = true

        stateTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stateTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        stateTitleLabel.textColor = SourcesCSSTheme.blue
        stateTitleLabel.textAlignment = .center
        stateTitleLabel.numberOfLines = 0

        stateSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stateSubtitleLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
        stateSubtitleLabel.textColor = SourcesCSSTheme.pureBlack
        stateSubtitleLabel.textAlignment = .center
        stateSubtitleLabel.numberOfLines = 0

        stateRetryButton.translatesAutoresizingMaskIntoConstraints = false
        stateRetryButton.setTitle("  Tải Lại Hướng Dẫn  ", for: .normal)
        stateRetryButton.setTitleColor(SourcesCSSTheme.white, for: .normal)
        stateRetryButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        stateRetryButton.backgroundColor = SourcesCSSTheme.blue
        stateRetryButton.layer.cornerRadius = 18
        stateRetryButton.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        stateRetryButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        stateRetryButton.layer.shadowRadius = 6
        stateRetryButton.layer.shadowOpacity = 0.25
        stateRetryButton.addTarget(self, action: #selector(handleRetryButtonTap), for: .touchUpInside)

        stateCardView.addSubview(stateActivityIndicator)
        stateCardView.addSubview(stateTitleLabel)
        stateCardView.addSubview(stateSubtitleLabel)
        stateCardView.addSubview(stateRetryButton)
        view.addSubview(stateCardView)

        NSLayoutConstraint.activate([
            stateCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stateCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stateCardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),

            stateActivityIndicator.topAnchor.constraint(equalTo: stateCardView.topAnchor, constant: 24),
            stateActivityIndicator.centerXAnchor.constraint(equalTo: stateCardView.centerXAnchor),

            stateTitleLabel.topAnchor.constraint(equalTo: stateActivityIndicator.bottomAnchor, constant: 14),
            stateTitleLabel.leadingAnchor.constraint(equalTo: stateCardView.leadingAnchor, constant: 18),
            stateTitleLabel.trailingAnchor.constraint(equalTo: stateCardView.trailingAnchor, constant: -18),

            stateSubtitleLabel.topAnchor.constraint(equalTo: stateTitleLabel.bottomAnchor, constant: 6),
            stateSubtitleLabel.leadingAnchor.constraint(equalTo: stateCardView.leadingAnchor, constant: 18),
            stateSubtitleLabel.trailingAnchor.constraint(equalTo: stateCardView.trailingAnchor, constant: -18),

            stateRetryButton.topAnchor.constraint(equalTo: stateSubtitleLabel.bottomAnchor, constant: 16),
            stateRetryButton.centerXAnchor.constraint(equalTo: stateCardView.centerXAnchor),
            stateRetryButton.heightAnchor.constraint(equalToConstant: 36),
            stateRetryButton.bottomAnchor.constraint(equalTo: stateCardView.bottomAnchor, constant: -22)
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

        // 1. ⚡ HIỂN THỊ NGAY LẬP TỨC TỪ BỘ NHỚ MÁY (NẾU CÓ)
        if articles.isEmpty, let cachedText = UserDefaults.standard.string(forKey: cacheKey) {
            let cachedArticles = GuideParser.parse(cachedText)
            if !cachedArticles.isEmpty {
                self.articles = cachedArticles
                self.heroHeaderView.updateCount(cachedArticles.count)
                self.guidesTableView.reloadData()
                self.stateCardView.isHidden = true
            }
        }

        if showLoadingCard && articles.isEmpty {
            stateCardView.isHidden = false
            stateActivityIndicator.startAnimating()
            stateTitleLabel.text = "Đang tải danh sách hướng dẫn..."
            stateSubtitleLabel.text = "Vui lòng chờ trong giây lát khi hệ thống đồng bộ nội dung mới nhất."
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
                if self.articles.isEmpty {
                    self.showErrorState(message: "Đường dẫn cấu hình hướng dẫn không hợp lệ.")
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

                if rawText == UserDefaults.standard.string(forKey: cacheKey) && !self.articles.isEmpty {
                    self.stateCardView.isHidden = true
                    self.stateActivityIndicator.stopAnimating()
                    return
                }

                let parsedArticles = GuideParser.parse(rawText)
                if !parsedArticles.isEmpty {
                    UserDefaults.standard.set(rawText, forKey: cacheKey)
                    self.articles = parsedArticles
                    self.heroHeaderView.updateCount(parsedArticles.count)
                    self.guidesTableView.reloadData()
                    self.stateCardView.isHidden = true
                    self.stateActivityIndicator.stopAnimating()
                } else if self.articles.isEmpty {
                    self.showErrorState(message: "Hiện chưa có bài viết hướng dẫn nào trong tệp cấu hình.")
                }
            } catch {
                if self.articles.isEmpty {
                    self.showErrorState(message: "Không thể kết nối tới máy chủ GitHub. Vui lòng kiểm tra kết nối mạng và thử lại.")
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
        return articles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: GuideTopicRowCell.reuseIdentifier, for: indexPath) as? GuideTopicRowCell else {
            return UITableViewCell()
        }
        let article = articles[indexPath.row]
        cell.configure(with: article, rowIndex: indexPath.row, totalRows: articles.count)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard articles.indices.contains(indexPath.row) else { return }
        let selectedArticle = articles[indexPath.row]

        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(translationX: 4, y: -2).scaledBy(x: 0.98, y: 0.98)
            }) { _ in
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                    cell.transform = .identity
                }, completion: nil)
            }
        }

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
