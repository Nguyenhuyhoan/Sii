
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

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (PHIÊN BẢN ULTRA-ELEGANT GIỮ NGUYÊN TÔNG XANH - TÍM CHỦ ĐẠO)
private struct SourcesCSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                       // #000000
    static let deepInk = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0)         // #0F172A (Đen than sang trọng cho tiêu đề)
    static let slateSubtitle = UIColor(red: 62/255, green: 76/255, blue: 99/255, alpha: 1.0)   // #3E4C63 (Xám đá thanh lịch cho phụ đề)
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)        // #f5f8ff (Đồng bộ innerRowBackground)
    static let pearlTop = UIColor.white.cgColor
    static let pearlBottom = UIColor(red: 250/255, green: 252/255, blue: 255/255, alpha: 1.0).cgColor
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)       // #dce2ec (Viền chuẩn toàn hệ thống)
    static let innerBorder = UIColor(red: 222/255, green: 229/255, blue: 240/255, alpha: 1.0)  // #dee5f0
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)           // #007bff (--primary-blue)
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)        // #6f42c1 (--primary-purple)
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)          // #28a745 (--primary-green)
    static let magenta = UIColor(red: 214/255, green: 51/255, blue: 132/255, alpha: 1.0)       // #d63384 (Hồng Berry thanh lịch)
    static let dark = UIColor.black                                                            // #000000

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.95) -> rgba(111,66,193,.92))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.95).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.92).cgColor

    // Gradient cho Icon trên cùng "Tin Tức Và Sửa Lỗi"
    static let pinkGradientStart = UIColor(red: 255/255, green: 90/255, blue: 165/255, alpha: 1.0).cgColor
    static let pinkGradientEnd = UIColor(red: 236/255, green: 38/255, blue: 143/255, alpha: 1.0).cgColor

    static let cornerRadius: CGFloat = 20.0
    static let innerCornerRadius: CGFloat = 14.0
    static let iPhoneImageCornerRadius: CGFloat = 22.0

    /// Áp dụng phong cách Thẻ Ngọc Trai (Soft Ambient + Tinted Blue Glow + Viền mảnh tinh tế)
    static func applyCardStyle(to view: UIView, cornerRadius: CGFloat = SourcesCSSTheme.cornerRadius) {
        view.backgroundColor = SourcesCSSTheme.white
        view.layer.cornerRadius = cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.borderWidth = 0.9
        view.layer.borderColor = SourcesCSSTheme.border.withAlphaComponent(0.9).cgColor
        view.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 18
        view.layer.shadowOpacity = 0.085
    }
}

// MARK: - 🎬 CÁC THÀNH PHẦN VIDEO LẤY NGUYÊN BẢN TỪ TAB TỔNG QUAN (NEWSVIEWCONTROLLER)
private enum OverviewVideoCSSTheme {
    static let primary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)      // #007bff (--primary-blue)
    static let secondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)   // #6f42c1 (--primary-purple)
    static let green = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)        // #28a745 (--primary-green)
    static let red = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)          // #dc3545 (--primary-red)
    static let pureBlack = SwiftUI.Color(red: 15/255, green: 23/255, blue: 42/255)     // #0F172A

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
    static let mediaFrameLineWidth: CGFloat = 3.5
    static let cornerRadius: CGFloat = 20.0
    static let innerCornerRadius: CGFloat = 14.0
    static let cardBackground = SwiftUI.Color.white
    static let innerRowBackground = SwiftUI.Color(red: 245/255, green: 248/255, blue: 255/255)
    static let border = SwiftUI.Color(red: 220/255, green: 226/255, blue: 236/255)
    static let innerBorder = SwiftUI.Color(red: 222/255, green: 229/255, blue: 240/255)
}

private struct OverviewSectionHeaderView: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 4) {
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
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(OverviewVideoCSSTheme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let statusOK = statusOK {
                    SwiftUI.Image(systemName: statusOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(statusOK ? OverviewVideoCSSTheme.green : OverviewVideoCSSTheme.red)
                        .animation(.spring(), value: statusOK)
                }

                Spacer(minLength: 4)

                if let trailingView = trailingView {
                    trailingView
                }
            }

            RoundedRectangle(cornerRadius: 1.75)
                .fill(OverviewVideoCSSTheme.accentBarGradient)
                .frame(width: 38, height: 3.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 9) {
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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OverviewVideoCSSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: OverviewVideoCSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: OverviewVideoCSSTheme.cornerRadius, style: .continuous)
                    .stroke(OverviewVideoCSSTheme.border, lineWidth: 0.9)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
            .shadow(color: OverviewVideoCSSTheme.primary.opacity(0.08), radius: 18, x: 0, y: 8)

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
        .shadow(color: OverviewVideoCSSTheme.secondary.opacity(0.22), radius: 16, x: 0, y: 8)
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
                        .stroke(OverviewVideoCSSTheme.innerBorder, lineWidth: 1)
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

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (KHÔNG BỊ TRẮNG KHI CUỘN XUỐNG DƯỚI)
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

// MARK: - ➖ THANH GẠCH CHÂN GRADIENT XANH - TÍM (38x3.5pt ĐỒNG BỘ)
private final class SourcesAccentUnderlineView: UIView {
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
        gradientLayer.colors = [SourcesCSSTheme.blue.cgColor, SourcesCSSTheme.purple.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        layer.cornerRadius = 1.75
        clipsToBounds = true
    }
}

// MARK: - 🖼️ LỚP KHUNG VIỀN GRADIENT TỰ ĐỘNG CO GIÃN 100% THEO KÍCH THƯỚC ẢNH
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
            SourcesCSSTheme.blue.withAlphaComponent(0.82).cgColor,
            SourcesCSSTheme.purple.withAlphaComponent(0.68).cgColor,
            SourcesCSSTheme.blue.withAlphaComponent(0.82).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - 💊 NHÃN PILL TAG HIỆN ĐẠI (THAY CHO KHOẢNG TRẮNG THỦ CÔNG, CÓ ĐỆM & VIỀN MẢNH)
private final class GuidePillTagView: UIView {
    private let label = UILabel()

    init(bgColor: UIColor, textColor: UIColor, borderColor: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = bgColor
        layer.cornerRadius = 8
        if #available(iOS 13.0, tvOS 13.0, *) {
            layer.cornerCurve = .continuous
        }
        layer.borderWidth = 0.8
        layer.borderColor = borderColor.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        if let roundedDesc = UIFont.systemFont(ofSize: 10.5, weight: .bold).fontDescriptor.withDesign(.rounded) {
            label.font = UIFont(descriptor: roundedDesc, size: 10.5)
        } else {
            label.font = UIFont.systemFont(ofSize: 10.5, weight: .bold)
        }
        label.textColor = textColor
        label.textAlignment = .center

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3.5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3.5)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setText(_ text: String?) {
        label.text = text
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
                    return cleaned
                }
            }
        }
        return "Nhấn để xem chi tiết hướng dẫn đầy đủ và hình ảnh minh họa..."
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

    /// Xóa bỏ con số đầu dòng (ví dụ: "1.", "2)", "Bước 1:") hoặc ký tự gạch đầu dòng để chuẩn hóa
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

        // 1. Chuyển https://github.com/user/repo/blob/branch/path -> https://raw.githubusercontent.com/user/repo/branch/path
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

        // 2. Chuẩn hóa link raw.githubusercontent.com nếu có chứa /refs/heads/ hoặc ?raw=true
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

        // 1. Ưu tiên kiểm tra link Video YouTube trước
        if let ytID = extractYouTubeVideoID(from: cleaned) {
            return .youtubeVideo(ytID)
        }

        // 2. Kiểm tra link ảnh GitHub
        if let ghImageURL = extractGitHubImageURL(from: cleaned) {
            return .githubImage(ghImageURL)
        }

        // 3. Mọi link khác: Nếu là link file trên GitHub (không phải ảnh) thì tự chuyển sang raw URL để tải thẳng file, còn lại giữ nguyên URL
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

        // Regex nhận diện tiêu đề dạng: "1TTT: Hướng Dẫn..." hoặc "25TTT: ..."
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
                // Bỏ qua các dòng ký tự kết thúc rác như "….,,,"
                if !trimmed.isEmpty && trimmed.range(of: #"^[.,…\s]+$"#, options: .regularExpression) != nil {
                    continue
                }
                if currentNumber != nil {
                    currentLines.append(line)
                }
            }
        }

        finalizeCurrentArticle()

        // Sắp xếp giảm dần: Tiêu đề nào có số trước TTT lớn nhất đứng đầu tiên, tiếp tục lớn thứ 2...
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

            // Trường hợp 1: Cả dòng chỉ là một đường dẫn URL
            if let directLink = classifyURL(from: strippedLine) {
                flushTextBuffer()
                appendDetectedLink(directLink)
                continue
            }

            // Trường hợp 2: Trong dòng văn bản có chứa đường dẫn URL (inline)
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

// MARK: - 🏷️ HEADER ĐẦU TRANG CHUẨN ULTRA-ELEGANT (HERO BANNER ÁNH SÁNG KÉP + THANH TÌM KIẾM KÍNH MỜ)
private final class GuidesHeroHeaderView: UIView, UITextFieldDelegate {
    private let heroCard = UIView()
    private let heroClipView = UIView()
    private let heroGradient = CAGradientLayer()
    private let decorCircleTopRight = UIView()
    private let decorCircleBottomLeft = UIView()
    private let topGlossLine = UIView()

    private let heroIconBadge = UIView()
    private let heroIconGradient = CAGradientLayer()
    private let heroIconView = UIImageView()
    private let subPillContainer = UIView()

    // Thanh tìm kiếm Kính Mờ (Floating Glass Search Pill)
    private let searchContainer = UIView()
    private let searchIconView = UIImageView()
    private let searchTextField = UITextField()
    private let clearSearchButton = UIButton(type: .system)

    private let sectionIconBox = UIView()
    private let sectionIconView = UIImageView()
    private let sectionTitleLabel = UILabel()
    private let underlineView = SourcesAccentUnderlineView()
    private let countBadgeButton = UIButton(type: .system)
    private let countBadgeGradient = CAGradientLayer()

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

        // 1. Khối Hero Card với chiều sâu ánh sáng cực quang (Aurora Light)
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = SourcesCSSTheme.cornerRadius + 2
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroCard.layer.cornerCurve = .continuous
        }
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 10)
        heroCard.layer.shadowRadius = 20
        heroCard.layer.shadowOpacity = 0.25

        heroClipView.translatesAutoresizingMaskIntoConstraints = false
        heroClipView.layer.cornerRadius = SourcesCSSTheme.cornerRadius + 2
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroClipView.layer.cornerCurve = .continuous
        }
        heroClipView.clipsToBounds = true
        heroClipView.layer.borderWidth = 1.2
        heroClipView.layer.borderColor = UIColor.white.withAlphaComponent(0.38).cgColor

        heroGradient.colors = [SourcesCSSTheme.heroStart, SourcesCSSTheme.heroEnd]
        heroGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        heroGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        heroClipView.layer.insertSublayer(heroGradient, at: 0)

        // Vòng tròn ánh sáng trang trí góc trên bên phải
        decorCircleTopRight.translatesAutoresizingMaskIntoConstraints = false
        decorCircleTopRight.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        decorCircleTopRight.layer.cornerRadius = 65
        decorCircleTopRight.isUserInteractionEnabled = false
        heroClipView.addSubview(decorCircleTopRight)

        // Quầng sáng mềm góc dưới bên trái tạo chiều sâu 3D
        decorCircleBottomLeft.translatesAutoresizingMaskIntoConstraints = false
        decorCircleBottomLeft.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        decorCircleBottomLeft.layer.cornerRadius = 50
        decorCircleBottomLeft.isUserInteractionEnabled = false
        heroClipView.addSubview(decorCircleBottomLeft)

        // Viền phản chiếu ánh sáng mép trên (Specular Highlight)
        topGlossLine.translatesAutoresizingMaskIntoConstraints = false
        topGlossLine.backgroundColor = UIColor.white.withAlphaComponent(0.35)
        topGlossLine.isUserInteractionEnabled = false
        heroClipView.addSubview(topGlossLine)

        // Hàng Tiêu đề + Icon trên cùng "Tin Tức Và Sửa Lỗi"
        let titleStack = UIStackView()
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .horizontal
        titleStack.spacing = 10
        titleStack.alignment = .center

        heroIconBadge.translatesAutoresizingMaskIntoConstraints = false
        heroIconBadge.layer.cornerRadius = 11
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroIconBadge.layer.cornerCurve = .continuous
        }
        heroIconBadge.layer.masksToBounds = true
        heroIconBadge.layer.borderWidth = 1.2
        heroIconBadge.layer.borderColor = UIColor.white.withAlphaComponent(0.75).cgColor

        heroIconGradient.colors = [SourcesCSSTheme.pinkGradientStart, SourcesCSSTheme.pinkGradientEnd]
        heroIconGradient.startPoint = CGPoint(x: 0, y: 0)
        heroIconGradient.endPoint = CGPoint(x: 1, y: 1)
        heroIconBadge.layer.insertSublayer(heroIconGradient, at: 0)

        heroIconView.translatesAutoresizingMaskIntoConstraints = false
        let heroSymConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        heroIconView.image = UIImage(systemName: "newspaper.fill", withConfiguration: heroSymConfig)
            ?? UIImage(systemName: "book.fill", withConfiguration: heroSymConfig)
        heroIconView.tintColor = .white
        heroIconBadge.addSubview(heroIconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Tin Tức Và Sửa Lỗi"
        if let roundedDesc = UIFont.systemFont(ofSize: 22.5, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 22.5)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 22.5, weight: .heavy)
        }
        titleLabel.textColor = SourcesCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.25

        titleStack.addArrangedSubview(heroIconBadge)
        titleStack.addArrangedSubview(titleLabel)

        // Phụ đề bọc trong viên thuốc kính mờ (Frosted Glass Pill)
        subPillContainer.translatesAutoresizingMaskIntoConstraints = false
        subPillContainer.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        subPillContainer.layer.cornerRadius = 12
        if #available(iOS 13.0, tvOS 13.0, *) {
            subPillContainer.layer.cornerCurve = .continuous
        }
        subPillContainer.layer.borderWidth = 0.8
        subPillContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "✦ Cẩm nang khắc phục sự cố do cộng đồng mạng chia sẻ"
        subLabel.font = UIFont.systemFont(ofSize: 12.8, weight: .semibold)
        subLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.98)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 1
        subLabel.adjustsFontSizeToFitWidth = true
        subLabel.minimumScaleFactor = 0.85

        subPillContainer.addSubview(subLabel)
        heroClipView.addSubview(titleStack)
        heroClipView.addSubview(subPillContainer)
        heroCard.addSubview(heroClipView)

        // 2. Thanh tìm kiếm nhanh dạng viên thuốc (Floating Pill Search Bar)
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        searchContainer.layer.cornerRadius = 15
        if #available(iOS 13.0, tvOS 13.0, *) {
            searchContainer.layer.cornerCurve = .continuous
        }
        searchContainer.layer.borderWidth = 1.0
        searchContainer.layer.borderColor = SourcesCSSTheme.border.cgColor
        searchContainer.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        searchContainer.layer.shadowOffset = CGSize(width: 0, height: 5)
        searchContainer.layer.shadowRadius = 12
        searchContainer.layer.shadowOpacity = 0.065

        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        let searchIconCfg = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .bold)
        searchIconView.image = UIImage(systemName: "magnifyingglass", withConfiguration: searchIconCfg)
        searchIconView.tintColor = SourcesCSSTheme.blue

        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.delegate = self
        searchTextField.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        searchTextField.textColor = SourcesCSSTheme.deepInk
        searchTextField.tintColor = SourcesCSSTheme.blue
        searchTextField.returnKeyType = .done
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Tìm kiếm nhanh hướng dẫn, mã lỗi, từ khóa...",
            attributes: [
                .foregroundColor: SourcesCSSTheme.slateSubtitle.withAlphaComponent(0.7),
                .font: UIFont.systemFont(ofSize: 13.8, weight: .regular)
            ]
        )
        searchTextField.addTarget(self, action: #selector(handleSearchEditingChanged), for: .editingChanged)

        clearSearchButton.translatesAutoresizingMaskIntoConstraints = false
        let clearCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        clearSearchButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: clearCfg), for: .normal)
        clearSearchButton.tintColor = SourcesCSSTheme.slateSubtitle.withAlphaComponent(0.6)
        clearSearchButton.isHidden = true
        clearSearchButton.addTarget(self, action: #selector(handleClearSearch), for: .touchUpInside)

        searchContainer.addSubview(searchIconView)
        searchContainer.addSubview(searchTextField)
        searchContainer.addSubview(clearSearchButton)

        // 3. Tiêu đề Section + Hộp Icon + Gạch chân Gradient Xanh-Tím 38x3.5pt
        sectionIconBox.translatesAutoresizingMaskIntoConstraints = false
        sectionIconBox.backgroundColor = SourcesCSSTheme.blue.withAlphaComponent(0.14)
        sectionIconBox.layer.cornerRadius = 7
        if #available(iOS 13.0, tvOS 13.0, *) {
            sectionIconBox.layer.cornerCurve = .continuous
        }

        sectionIconView.translatesAutoresizingMaskIntoConstraints = false
        let secIconConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .heavy)
        sectionIconView.image = UIImage(systemName: "square.grid.2x2.fill", withConfiguration: secIconConfig)
        sectionIconView.tintColor = SourcesCSSTheme.blue
        sectionIconBox.addSubview(sectionIconView)

        sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionTitleLabel.text = "TỔNG HỢP CÁC DANH MỤC"
        sectionTitleLabel.textColor = SourcesCSSTheme.blue
        if let roundedSecDesc = UIFont.systemFont(ofSize: 15, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            sectionTitleLabel.font = UIFont(descriptor: roundedSecDesc, size: 15)
        } else {
            sectionTitleLabel.font = UIFont(ofSize: 15, weight: .heavy)
        }

        underlineView.translatesAutoresizingMaskIntoConstraints = false

        countBadgeButton.translatesAutoresizingMaskIntoConstraints = false
        countBadgeButton.setTitle("  Mới nhất ▲  ", for: .normal)
        countBadgeButton.setTitleColor(SourcesCSSTheme.white, for: .normal)
        if let roundedBadgeDesc = UIFont.systemFont(ofSize: 11.5, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            countBadgeButton.titleLabel?.font = UIFont(descriptor: roundedBadgeDesc, size: 11.5)
        } else {
            countBadgeButton.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .heavy)
        }
        countBadgeButton.layer.cornerRadius = 11
        countBadgeButton.layer.masksToBounds = true
        countBadgeButton.isUserInteractionEnabled = false

        countBadgeGradient.colors = [SourcesCSSTheme.blue.cgColor, SourcesCSSTheme.purple.cgColor]
        countBadgeGradient.startPoint = CGPoint(x: 0, y: 0.5)
        countBadgeGradient.endPoint = CGPoint(x: 1, y: 0.5)
        countBadgeButton.layer.insertSublayer(countBadgeGradient, at: 0)

        addSubview(heroCard)
        addSubview(searchContainer)
        addSubview(sectionIconBox)
        addSubview(sectionTitleLabel)
        addSubview(underlineView)
        addSubview(countBadgeButton)

        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            heroCard.heightAnchor.constraint(equalToConstant: 102),

            heroClipView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor),
            heroClipView.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor),
            heroClipView.topAnchor.constraint(equalTo: heroCard.topAnchor),
            heroClipView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor),

            topGlossLine.leadingAnchor.constraint(equalTo: heroClipView.leadingAnchor, constant: 18),
            topGlossLine.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: -18),
            topGlossLine.topAnchor.constraint(equalTo: heroClipView.topAnchor),
            topGlossLine.heightAnchor.constraint(equalToConstant: 1.0),

            decorCircleTopRight.widthAnchor.constraint(equalToConstant: 130),
            decorCircleTopRight.heightAnchor.constraint(equalToConstant: 130),
            decorCircleTopRight.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: 35),
            decorCircleTopRight.topAnchor.constraint(equalTo: heroClipView.topAnchor, constant: -45),

            decorCircleBottomLeft.widthAnchor.constraint(equalToConstant: 100),
            decorCircleBottomLeft.heightAnchor.constraint(equalToConstant: 100),
            decorCircleBottomLeft.leadingAnchor.constraint(equalTo: heroClipView.leadingAnchor, constant: -30),
            decorCircleBottomLeft.bottomAnchor.constraint(equalTo: heroClipView.bottomAnchor, constant: 45),

            heroIconBadge.widthAnchor.constraint(equalToConstant: 34),
            heroIconBadge.heightAnchor.constraint(equalToConstant: 34),
            heroIconView.centerXAnchor.constraint(equalTo: heroIconBadge.centerXAnchor),
            heroIconView.centerYAnchor.constraint(equalTo: heroIconBadge.centerYAnchor),

            titleStack.centerXAnchor.constraint(equalTo: heroClipView.centerXAnchor),
            titleStack.topAnchor.constraint(equalTo: heroClipView.topAnchor, constant: 16),

            subPillContainer.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 8),
            subPillContainer.centerXAnchor.constraint(equalTo: heroClipView.centerXAnchor),
            subPillContainer.leadingAnchor.constraint(greaterThanOrEqualTo: heroClipView.leadingAnchor, constant: 14),
            subPillContainer.trailingAnchor.constraint(lessThanOrEqualTo: heroClipView.trailingAnchor, constant: -14),
            subPillContainer.heightAnchor.constraint(equalToConstant: 24),

            subLabel.leadingAnchor.constraint(equalTo: subPillContainer.leadingAnchor, constant: 12),
            subLabel.trailingAnchor.constraint(equalTo: subPillContainer.trailingAnchor, constant: -12),
            subLabel.centerYAnchor.constraint(equalTo: subPillContainer.centerYAnchor),

            // Search Bar constraints
            searchContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            searchContainer.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 12),
            searchContainer.heightAnchor.constraint(equalToConstant: 42),

            searchIconView.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 14),
            searchIconView.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 18),
            searchIconView.heightAnchor.constraint(equalToConstant: 18),

            clearSearchButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -10),
            clearSearchButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            clearSearchButton.widthAnchor.constraint(equalToConstant: 26),
            clearSearchButton.heightAnchor.constraint(equalToConstant: 26),

            searchTextField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 9),
            searchTextField.trailingAnchor.constraint(equalTo: clearSearchButton.leadingAnchor, constant: -6),
            searchTextField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchTextField.heightAnchor.constraint(equalToConstant: 36),

            // Section Header constraints
            sectionIconBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            sectionIconBox.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 14),
            sectionIconBox.widthAnchor.constraint(equalToConstant: 24),
            sectionIconBox.heightAnchor.constraint(equalToConstant: 24),

            sectionIconView.centerXAnchor.constraint(equalTo: sectionIconBox.centerXAnchor),
            sectionIconView.centerYAnchor.constraint(equalTo: sectionIconBox.centerYAnchor),

            sectionTitleLabel.leadingAnchor.constraint(equalTo: sectionIconBox.trailingAnchor, constant: 8),
            sectionTitleLabel.centerYAnchor.constraint(equalTo: sectionIconBox.centerYAnchor),

            underlineView.leadingAnchor.constraint(equalTo: sectionIconBox.leadingAnchor),
            underlineView.topAnchor.constraint(equalTo: sectionIconBox.bottomAnchor, constant: 5),
            underlineView.widthAnchor.constraint(equalToConstant: 38),
            underlineView.heightAnchor.constraint(equalToConstant: 3.5),
            underlineView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            countBadgeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            countBadgeButton.centerYAnchor.constraint(equalTo: sectionIconBox.centerYAnchor),
            countBadgeButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    @objc private func handleSearchEditingChanged() {
        let query = searchTextField.text ?? ""
        clearSearchButton.isHidden = query.isEmpty
        onSearchTextChanged?(query)
    }

    @objc private func handleClearSearch() {
        searchTextField.text = ""
        clearSearchButton.isHidden = true
        searchTextField.resignFirstResponder()
        onSearchTextChanged?("")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func updateCount(_ count: Int) {
        if count > 0 {
            countBadgeButton.setTitle("  \(count) bài viết  ", for: .normal)
            countBadgeButton.isHidden = false
            setNeedsLayout()
            layoutIfNeeded()
        } else {
            countBadgeButton.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        heroGradient.frame = heroClipView.bounds
        heroIconGradient.frame = heroIconBadge.bounds
        countBadgeGradient.frame = countBadgeButton.bounds
    }
}

private extension UIFont {
    convenience init(ofSize size: CGFloat, weight: UIFont.Weight) {
        let sys = UIFont.systemFont(ofSize: size, weight: weight)
        self.init(descriptor: sys.fontDescriptor, size: size)
    }
}

// MARK: - 🗂️ THANH TIÊU ĐỀ HƯỚNG DẪN (THẺ NGỌC TRAI + HUY HIỆU PHA LÊ 3D + PILL TAGS)
private final class GuideTopicRowCell: UITableViewCell {
    static let reuseIdentifier = "GuideTopicRowCell"

    private let cardView = UIView()
    private let cardPearlGradient = CAGradientLayer()
    private let topHighlightLine = UIView()

    // Huy hiệu Pha lê 2 lớp (Halo + Crystal Core)
    private let badgeHaloView = UIView()
    private let badgeContainer = UIView()
    private let badgeGradient = CAGradientLayer()
    private let badgeShineView = UIView()
    private let badgeIconView = UIImageView()
    private let badgeNumberLabel = UILabel()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let metaStackView = UIStackView()

    private let priorityTagView = GuidePillTagView(
        bgColor: SourcesCSSTheme.magenta.withAlphaComponent(0.11),
        textColor: SourcesCSSTheme.magenta,
        borderColor: SourcesCSSTheme.magenta.withAlphaComponent(0.28)
    )
    private let stepsTagView = GuidePillTagView(
        bgColor: SourcesCSSTheme.blue.withAlphaComponent(0.10),
        textColor: SourcesCSSTheme.blue,
        borderColor: SourcesCSSTheme.blue.withAlphaComponent(0.24)
    )
    private let mediaTagView = GuidePillTagView(
        bgColor: SourcesCSSTheme.purple.withAlphaComponent(0.10),
        textColor: SourcesCSSTheme.purple,
        borderColor: SourcesCSSTheme.purple.withAlphaComponent(0.24)
    )

    private let chevronContainer = UIView()
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
        UIView.animate(
            withDuration: 0.24,
            delay: 0,
            usingSpringWithDamping: 0.72,
            initialSpringVelocity: 0.5,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.968, y: 0.968) : .identity
            self.cardView.alpha = highlighted ? 0.95 : 1.0
            self.chevronContainer.backgroundColor = highlighted ? SourcesCSSTheme.blue.withAlphaComponent(0.15) : SourcesCSSTheme.light
        }
    }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Khối Card Ngọc Trai chuẩn CSS
        cardView.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyCardStyle(to: cardView, cornerRadius: SourcesCSSTheme.cornerRadius)

        cardPearlGradient.colors = [SourcesCSSTheme.pearlTop, SourcesCSSTheme.pearlBottom]
        cardPearlGradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        cardPearlGradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        cardPearlGradient.cornerRadius = SourcesCSSTheme.cornerRadius
        cardView.layer.insertSublayer(cardPearlGradient, at: 0)

        topHighlightLine.translatesAutoresizingMaskIntoConstraints = false
        topHighlightLine.backgroundColor = UIColor.white
        topHighlightLine.isUserInteractionEnabled = false
        cardView.addSubview(topHighlightLine)

        // Vòng hào quang mờ (Soft Halo) quanh Huy hiệu bên trái
        badgeHaloView.translatesAutoresizingMaskIntoConstraints = false
        badgeHaloView.backgroundColor = SourcesCSSTheme.blue.withAlphaComponent(0.08)
        badgeHaloView.layer.cornerRadius = 17
        if #available(iOS 13.0, tvOS 13.0, *) {
            badgeHaloView.layer.cornerCurve = .continuous
        }
        badgeHaloView.layer.borderWidth = 0.8
        badgeHaloView.layer.borderColor = SourcesCSSTheme.purple.withAlphaComponent(0.18).cgColor

        // Viên Pha lê Gradient Xanh - Tím bên trong
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.layer.cornerRadius = 14
        if #available(iOS 13.0, tvOS 13.0, *) {
            badgeContainer.layer.cornerCurve = .continuous
        }
        badgeContainer.layer.masksToBounds = true
        badgeContainer.layer.borderWidth = 1.0
        badgeContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.38).cgColor

        badgeGradient.colors = [SourcesCSSTheme.heroStart, SourcesCSSTheme.heroEnd]
        badgeGradient.startPoint = CGPoint(x: 0, y: 0)
        badgeGradient.endPoint = CGPoint(x: 1, y: 1)
        badgeContainer.layer.insertSublayer(badgeGradient, at: 0)

        // Ánh sáng phản chiếu góc trên của viên pha lê
        badgeShineView.translatesAutoresizingMaskIntoConstraints = false
        badgeShineView.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        badgeShineView.layer.cornerRadius = 16
        badgeShineView.isUserInteractionEnabled = false
        badgeContainer.addSubview(badgeShineView)

        badgeIconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .bold)
        badgeIconView.image = UIImage(systemName: "sparkles", withConfiguration: iconConfig)
        badgeIconView.tintColor = SourcesCSSTheme.white.withAlphaComponent(0.96)
        badgeIconView.contentMode = .scaleAspectFit

        badgeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        if let roundedNumDesc = UIFont.systemFont(ofSize: 13, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            badgeNumberLabel.font = UIFont(descriptor: roundedNumDesc, size: 13)
        } else {
            badgeNumberLabel.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        }
        badgeNumberLabel.textColor = SourcesCSSTheme.white
        badgeNumberLabel.textAlignment = .center

        badgeContainer.addSubview(badgeIconView)
        badgeContainer.addSubview(badgeNumberLabel)
        badgeHaloView.addSubview(badgeContainer)

        // Tiêu đề chính (Đen than sang trọng #0F172A, bo tròn nhẹ)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        if let roundedTitleDesc = UIFont.systemFont(ofSize: 16.5, weight: .bold).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedTitleDesc, size: 16.5)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .bold)
        }
        titleLabel.textColor = SourcesCSSTheme.deepInk
        titleLabel.numberOfLines = 2

        // Phụ đề tóm tắt (Xám đá thanh lịch #3E4C63 tạo độ tương phản chính-phụ)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13.2, weight: .medium)
        subtitleLabel.textColor = SourcesCSSTheme.slateSubtitle
        subtitleLabel.numberOfLines = 1

        // Thanh Pill Tags thông tin
        metaStackView.translatesAutoresizingMaskIntoConstraints = false
        metaStackView.axis = .horizontal
        metaStackView.spacing = 6
        metaStackView.alignment = .center

        metaStackView.addArrangedSubview(priorityTagView)
        metaStackView.addArrangedSubview(stepsTagView)
        metaStackView.addArrangedSubview(mediaTagView)

        // Nút mũi tên phải tinh tế
        chevronContainer.translatesAutoresizingMaskIntoConstraints = false
        chevronContainer.backgroundColor = SourcesCSSTheme.light
        chevronContainer.layer.cornerRadius = 15
        if #available(iOS 13.0, tvOS 13.0, *) {
            chevronContainer.layer.cornerCurve = .continuous
        }
        chevronContainer.layer.borderWidth = 1.0
        chevronContainer.layer.borderColor = SourcesCSSTheme.innerBorder.cgColor

        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        let chevConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        chevronImageView.image = UIImage(systemName: "chevron.right", withConfiguration: chevConfig)
        chevronImageView.tintColor = SourcesCSSTheme.blue
        chevronContainer.addSubview(chevronImageView)

        cardView.addSubview(badgeHaloView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(metaStackView)
        cardView.addSubview(chevronContainer)
        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6.5),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6.5),

            topHighlightLine.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            topHighlightLine.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            topHighlightLine.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 1),
            topHighlightLine.heightAnchor.constraint(equalToConstant: 1),

            badgeHaloView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 13),
            badgeHaloView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            badgeHaloView.widthAnchor.constraint(equalToConstant: 54),
            badgeHaloView.heightAnchor.constraint(equalToConstant: 54),

            badgeContainer.centerXAnchor.constraint(equalTo: badgeHaloView.centerXAnchor),
            badgeContainer.centerYAnchor.constraint(equalTo: badgeHaloView.centerYAnchor),
            badgeContainer.widthAnchor.constraint(equalToConstant: 46),
            badgeContainer.heightAnchor.constraint(equalToConstant: 46),

            badgeShineView.widthAnchor.constraint(equalToConstant: 38),
            badgeShineView.heightAnchor.constraint(equalToConstant: 38),
            badgeShineView.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: 14),
            badgeShineView.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: -16),

            badgeIconView.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeIconView.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 7),
            badgeIconView.widthAnchor.constraint(equalToConstant: 15),
            badgeIconView.heightAnchor.constraint(equalToConstant: 15),

            badgeNumberLabel.topAnchor.constraint(equalTo: badgeIconView.bottomAnchor, constant: 2),
            badgeNumberLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 2),
            badgeNumberLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -2),

            chevronContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevronContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronContainer.widthAnchor.constraint(equalToConstant: 30),
            chevronContainer.heightAnchor.constraint(equalToConstant: 30),

            chevronImageView.centerXAnchor.constraint(equalTo: chevronContainer.centerXAnchor),
            chevronImageView.centerYAnchor.constraint(equalTo: chevronContainer.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: badgeHaloView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: chevronContainer.leadingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            metaStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaStackView.trailingAnchor.constraint(lessThanOrEqualTo: chevronContainer.leadingAnchor, constant: -8),
            metaStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 9),
            metaStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -13)
        ])
    }

    func configure(with article: GuideArticle, isTopPriority: Bool) {
        badgeNumberLabel.text = "#\(article.orderNumber)"
        titleLabel.text = article.title
        subtitleLabel.text = "✦ " + article.previewSubtitle

        if isTopPriority {
            priorityTagView.setText("★ MỚI NHẤT")
            priorityTagView.isHidden = false
        } else {
            priorityTagView.isHidden = true
        }

        let steps = article.stepCount
        stepsTagView.setText(steps > 0 ? "• \(steps) mục" : "• Chi tiết")

        let imgs = article.imageCount
        let vids = article.videoCount
        let dls = article.downloadCount

        var mediaParts: [String] = []
        if imgs > 0 { mediaParts.append("🖼 \(imgs) ảnh") }
        if vids > 0 { mediaParts.append("🎬 \(vids) video") }
        if dls > 0 { mediaParts.append("⬇️ \(dls) tệp") }

        if !mediaParts.isEmpty {
            mediaTagView.setText(mediaParts.joined(separator: " • "))
            mediaTagView.isHidden = false
        } else {
            mediaTagView.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cardPearlGradient.frame = cardView.bounds
        badgeGradient.frame = badgeContainer.bounds
        CATransaction.commit()
    }
}

// MARK: - 📱 KHUNG HIỂN THỊ ẢNH NGHỆ THUẬT (GALLERY ART FRAME VIỀN KÉP + NHÃN KÍNH MỜ PHÓNG TO)
private final class GuideStyledImageView: UIView {
    private let outerShadowContainer = UIView()
    private let borderContainer = GradientBorderContainerView()
    private let whiteMatteContainer = UIView()
    private let innerClipContainer = UIView()
    private let imageView = UIImageView()
    private let zoomBadgeBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let zoomBadgeLabel = UILabel()
    private let shimmerActivity = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    private var imageURL: URL?
    private var aspectRatioConstraint: NSLayoutConstraint?
    private var defaultHeightConstraint: NSLayoutConstraint!
    var onTapImage: ((UIImage) -> Void)?

    // Viền kép thanh mảnh: 2.2pt Gradient ngoài + 2.0pt Đệm trắng ngọc trai bên trong
    private let gradientBorderThickness: CGFloat = 2.2
    private let whiteMatteThickness: CGFloat = 2.0

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
        outerShadowContainer.layer.shadowColor = SourcesCSSTheme.purple.cgColor
        outerShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        outerShadowContainer.layer.shadowRadius = 18
        outerShadowContainer.layer.shadowOpacity = 0.20

        let outerRadius = SourcesCSSTheme.iPhoneImageCornerRadius
        borderContainer.translatesAutoresizingMaskIntoConstraints = false
        borderContainer.layer.cornerRadius = outerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            borderContainer.layer.cornerCurve = .continuous
        }
        borderContainer.clipsToBounds = true

        let matteRadius = max(outerRadius - gradientBorderThickness, 10.0)
        whiteMatteContainer.translatesAutoresizingMaskIntoConstraints = false
        whiteMatteContainer.backgroundColor = SourcesCSSTheme.white
        whiteMatteContainer.layer.cornerRadius = matteRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            whiteMatteContainer.layer.cornerCurve = .continuous
        }
        whiteMatteContainer.clipsToBounds = true

        let innerRadius = max(matteRadius - whiteMatteThickness, 8.0)
        innerClipContainer.translatesAutoresizingMaskIntoConstraints = false
        innerClipContainer.backgroundColor = SourcesCSSTheme.light
        innerClipContainer.layer.cornerRadius = innerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            innerClipContainer.layer.cornerCurve = .continuous
        }
        innerClipContainer.clipsToBounds = true

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = SourcesCSSTheme.light
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
        imageView.addGestureRecognizer(tapGesture)

        // Nhãn Kính Mờ nhỏ ở góc dưới bên phải bức ảnh ("🔍 Chạm để phóng to")
        zoomBadgeBlurView.translatesAutoresizingMaskIntoConstraints = false
        zoomBadgeBlurView.layer.cornerRadius = 11
        if #available(iOS 13.0, tvOS 13.0, *) {
            zoomBadgeBlurView.layer.cornerCurve = .continuous
        }
        zoomBadgeBlurView.clipsToBounds = true
        zoomBadgeBlurView.layer.borderWidth = 0.6
        zoomBadgeBlurView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        zoomBadgeBlurView.isUserInteractionEnabled = false
        zoomBadgeBlurView.isHidden = true

        zoomBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomBadgeLabel.text = "🔍 Chạm để phóng to"
        zoomBadgeLabel.font = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
        zoomBadgeLabel.textColor = .white
        zoomBadgeBlurView.contentView.addSubview(zoomBadgeLabel)

        shimmerActivity.translatesAutoresizingMaskIntoConstraints = false
        shimmerActivity.color = SourcesCSSTheme.blue
        shimmerActivity.hidesWhenStopped = true

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Không thể tải hình ảnh minh họa"
        errorLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        errorLabel.textColor = SourcesCSSTheme.deepInk
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
        innerClipContainer.addSubview(zoomBadgeBlurView)
        innerClipContainer.addSubview(shimmerActivity)
        innerClipContainer.addSubview(errorLabel)
        innerClipContainer.addSubview(retryButton)

        whiteMatteContainer.addSubview(innerClipContainer)
        borderContainer.addSubview(whiteMatteContainer)
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

            whiteMatteContainer.leadingAnchor.constraint(equalTo: borderContainer.leadingAnchor, constant: gradientBorderThickness),
            whiteMatteContainer.trailingAnchor.constraint(equalTo: borderContainer.trailingAnchor, constant: -gradientBorderThickness),
            whiteMatteContainer.topAnchor.constraint(equalTo: borderContainer.topAnchor, constant: gradientBorderThickness),
            whiteMatteContainer.bottomAnchor.constraint(equalTo: borderContainer.bottomAnchor, constant: -gradientBorderThickness),

            innerClipContainer.leadingAnchor.constraint(equalTo: whiteMatteContainer.leadingAnchor, constant: whiteMatteThickness),
            innerClipContainer.trailingAnchor.constraint(equalTo: whiteMatteContainer.trailingAnchor, constant: -whiteMatteThickness),
            innerClipContainer.topAnchor.constraint(equalTo: whiteMatteContainer.topAnchor, constant: whiteMatteThickness),
            innerClipContainer.bottomAnchor.constraint(equalTo: whiteMatteContainer.bottomAnchor, constant: -whiteMatteThickness),
            defaultHeightConstraint,

            imageView.leadingAnchor.constraint(equalTo: innerClipContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: innerClipContainer.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: innerClipContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: innerClipContainer.bottomAnchor),

            zoomBadgeBlurView.trailingAnchor.constraint(equalTo: innerClipContainer.trailingAnchor, constant: -10),
            zoomBadgeBlurView.bottomAnchor.constraint(equalTo: innerClipContainer.bottomAnchor, constant: -10),
            zoomBadgeBlurView.heightAnchor.constraint(equalToConstant: 22),

            zoomBadgeLabel.leadingAnchor.constraint(equalTo: zoomBadgeBlurView.contentView.leadingAnchor, constant: 9),
            zoomBadgeLabel.trailingAnchor.constraint(equalTo: zoomBadgeBlurView.contentView.trailingAnchor, constant: -9),
            zoomBadgeLabel.centerYAnchor.constraint(equalTo: zoomBadgeBlurView.contentView.centerYAnchor),

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
        zoomBadgeBlurView.isHidden = true
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
        zoomBadgeBlurView.isHidden = false

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

        UIView.animate(withDuration: 0.25) {
            self.imageView.alpha = 1
        }
    }

    @objc private func handleImageTap() {
        guard let img = imageView.image else { return }
        #if !os(tvOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
        onTapImage?(img)
    }
}

// MARK: - ⬇️ NÚT TẢI NỔI KHỐI RÕ NÉT (GRADIENT XANH - TÍM ĐẬM ĐÀ, VIỀN SÁNG TRÊN, CHỮ TRẮNG SẮC NÉT)
private final class ProminentGradientDownloadButton: UIControl {
    private let shadowWrap = UIView()
    private let gradientContainer = UIView()
    private let gradientLayer = CAGradientLayer()
    private let topInnerGlow = UIView()
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
        shadowWrap.layer.shadowOffset = CGSize(width: 0, height: 7)
        shadowWrap.layer.shadowRadius = 14
        shadowWrap.layer.shadowOpacity = 0.34

        gradientContainer.translatesAutoresizingMaskIntoConstraints = false
        gradientContainer.isUserInteractionEnabled = false
        gradientContainer.backgroundColor = SourcesCSSTheme.blue
        gradientContainer.layer.cornerRadius = 16
        if #available(iOS 13.0, tvOS 13.0, *) {
            gradientContainer.layer.cornerCurve = .continuous
        }
        gradientContainer.clipsToBounds = true
        gradientContainer.layer.borderWidth = 1.2
        gradientContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor

        gradientLayer.colors = [
            SourcesCSSTheme.blue.cgColor,
            SourcesCSSTheme.purple.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientContainer.layer.insertSublayer(gradientLayer, at: 0)

        topInnerGlow.translatesAutoresizingMaskIntoConstraints = false
        topInnerGlow.backgroundColor = UIColor.white.withAlphaComponent(0.32)
        topInnerGlow.isUserInteractionEnabled = false
        gradientContainer.addSubview(topInnerGlow)

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
        if let roundedDesc = UIFont.systemFont(ofSize: 17, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 17)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .heavy)
        }
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        titleLabel.layer.shadowRadius = 2.5
        titleLabel.layer.shadowOpacity = 0.28

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

            topInnerGlow.leadingAnchor.constraint(equalTo: gradientContainer.leadingAnchor, constant: 16),
            topInnerGlow.trailingAnchor.constraint(equalTo: gradientContainer.trailingAnchor, constant: -16),
            topInnerGlow.topAnchor.constraint(equalTo: gradientContainer.topAnchor),
            topInnerGlow.heightAnchor.constraint(equalToConstant: 1.0),

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
            self.shadowWrap.transform = highlighted ? CGAffineTransform(scaleX: 0.955, y: 0.955) : .identity
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

// MARK: - ⬇️ KHUNG TẢI VỀ (HIỆN CỐ ĐỊNH HƯỚNG DẪN TRÊN NÚT + NÚT TẢI NỔI BẬT RÕ NÉT)
private final class GuideDownloadActionCardView: UIView {
    private let downloadURL: URL
    private weak var hostViewController: UIViewController?

    private let cardContainer = UIView()
    private let mainStack = UIStackView()

    // Khung thông báo hiện cố định phía trên nút tải: “Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file”
    private let noticeBannerView = UIView()
    private let noticeIconBox = UIView()
    private let noticeIconView = UIImageView()
    private let noticeTextLabel = UILabel()

    // Nút tải nổi bật rõ nét: “Nhấn Vào Đây Để Tải Về” -> khi nhấn đổi thành “Đang Tải Về”
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

        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyCardStyle(to: cardContainer, cornerRadius: SourcesCSSTheme.cornerRadius)

        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.spacing = 12

        // 1. Dòng chữ cố định phía trên nút tải: "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file"
        noticeBannerView.translatesAutoresizingMaskIntoConstraints = false
        noticeBannerView.backgroundColor = SourcesCSSTheme.light
        noticeBannerView.layer.cornerRadius = SourcesCSSTheme.innerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            noticeBannerView.layer.cornerCurve = .continuous
        }
        noticeBannerView.layer.borderWidth = 1.0
        noticeBannerView.layer.borderColor = SourcesCSSTheme.blue.withAlphaComponent(0.28).cgColor

        noticeIconBox.translatesAutoresizingMaskIntoConstraints = false
        noticeIconBox.backgroundColor = SourcesCSSTheme.blue.withAlphaComponent(0.13)
        noticeIconBox.layer.cornerRadius = 10
        if #available(iOS 13.0, tvOS 13.0, *) {
            noticeIconBox.layer.cornerCurve = .continuous
        }

        noticeIconView.translatesAutoresizingMaskIntoConstraints = false
        let noticeIconCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        noticeIconView.image = UIImage(systemName: "folder.fill.badge.plus", withConfiguration: noticeIconCfg)
        noticeIconView.tintColor = SourcesCSSTheme.blue
        noticeIconView.contentMode = .scaleAspectFit
        noticeIconBox.addSubview(noticeIconView)

        noticeTextLabel.translatesAutoresizingMaskIntoConstraints = false
        noticeTextLabel.numberOfLines = 0
        noticeTextLabel.attributedText = makeNoticeAttributedText()

        noticeBannerView.addSubview(noticeIconBox)
        noticeBannerView.addSubview(noticeTextLabel)

        // 2. Nút "Nhấn Vào Đây Để Tải Về" ở ngay bên dưới
        downloadButton.addTarget(self, action: #selector(handleDownloadButtonTap), for: .touchUpInside)

        NSLayoutConstraint.activate([
            noticeIconBox.leadingAnchor.constraint(equalTo: noticeBannerView.leadingAnchor, constant: 12),
            noticeIconBox.centerYAnchor.constraint(equalTo: noticeBannerView.centerYAnchor),
            noticeIconBox.widthAnchor.constraint(equalToConstant: 34),
            noticeIconBox.heightAnchor.constraint(equalToConstant: 34),

            noticeIconView.centerXAnchor.constraint(equalTo: noticeIconBox.centerXAnchor),
            noticeIconView.centerYAnchor.constraint(equalTo: noticeIconBox.centerYAnchor),

            noticeTextLabel.leadingAnchor.constraint(equalTo: noticeIconBox.trailingAnchor, constant: 10),
            noticeTextLabel.trailingAnchor.constraint(equalTo: noticeBannerView.trailingAnchor, constant: -12),
            noticeTextLabel.topAnchor.constraint(equalTo: noticeBannerView.topAnchor, constant: 12),
            noticeTextLabel.bottomAnchor.constraint(equalTo: noticeBannerView.bottomAnchor, constant: -12),

            downloadButton.heightAnchor.constraint(equalToConstant: 54)
        ])

        mainStack.addArrangedSubview(noticeBannerView)
        mainStack.addArrangedSubview(downloadButton)

        cardContainer.addSubview(mainStack)
        addSubview(cardContainer)

        NSLayoutConstraint.activate([
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardContainer.topAnchor.constraint(equalTo: topAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            mainStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 14),
            mainStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            mainStack.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            mainStack.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -14)
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
                .foregroundColor: SourcesCSSTheme.deepInk,
                .paragraphStyle: paragraph
            ]
        )

        let nsMain = mainText as NSString
        let highlightRange = nsMain.range(of: "Lưu Vào Tệp", options: .caseInsensitive)
        if highlightRange.location != NSNotFound {
            result.addAttributes([
                .foregroundColor: SourcesCSSTheme.blue,
                .font: UIFont.systemFont(ofSize: 15.3, weight: .heavy)
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

        // Hiệu ứng nhấn nảy rõ ràng và chuyển chữ thành "Đang Tải Về"
        UIView.animate(withDuration: 0.12, animations: {
            self.downloadButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
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

// MARK: - 🔍 TRÌNH XEM ẢNH PHÓNG TO TOÀN MÀN HÌNH (NỀN KÍNH MỜ DARK BLUR + VUỐT NHẸ ĐỂ ĐÓNG)
private final class GuideImagePreviewController: UIViewController, UIScrollViewDelegate {
    private let image: UIImage
    private let blurBackgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeBlurContainer = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
    private let closeButton = UIButton(type: .system)
    private let hintPillLabel = UILabel()

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

        blurBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurBackgroundView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = image
        imageView.contentMode = .scaleAspectFit

        closeBlurContainer.translatesAutoresizingMaskIntoConstraints = false
        closeBlurContainer.layer.cornerRadius = 19
        closeBlurContainer.clipsToBounds = true
        closeBlurContainer.layer.borderWidth = 0.8
        closeBlurContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        closeBlurContainer.contentView.addSubview(closeButton)

        hintPillLabel.translatesAutoresizingMaskIntoConstraints = false
        hintPillLabel.text = "  Chạm đúp để phóng to • Vuốt xuống để đóng  "
        hintPillLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        hintPillLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        hintPillLabel.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        hintPillLabel.layer.cornerRadius = 12
        hintPillLabel.layer.masksToBounds = true

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        #if !os(tvOS)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        view.addGestureRecognizer(panGesture)
        #endif

        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
        view.addSubview(closeBlurContainer)
        view.addSubview(hintPillLabel)

        NSLayoutConstraint.activate([
            blurBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            blurBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),

            closeBlurContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeBlurContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeBlurContainer.widthAnchor.constraint(equalToConstant: 38),
            closeBlurContainer.heightAnchor.constraint(equalToConstant: 38),

            closeButton.leadingAnchor.constraint(equalTo: closeBlurContainer.contentView.leadingAnchor),
            closeButton.trailingAnchor.constraint(equalTo: closeBlurContainer.contentView.trailingAnchor),
            closeButton.topAnchor.constraint(equalTo: closeBlurContainer.contentView.topAnchor),
            closeButton.bottomAnchor.constraint(equalTo: closeBlurContainer.contentView.bottomAnchor),

            hintPillLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintPillLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            hintPillLabel.heightAnchor.constraint(equalToConstant: 26)
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

    #if !os(tvOS)
    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        guard scrollView.zoomScale == 1.0 else { return }
        let translation = gesture.translation(in: view)
        let verticalDrag = max(0, translation.y)

        switch gesture.state {
        case .changed:
            let progress = min(verticalDrag / 220.0, 1.0)
            let scale = 1.0 - (progress * 0.14)
            imageView.transform = CGAffineTransform(translationX: translation.x * 0.3, y: verticalDrag).scaledBy(x: scale, y: scale)
            blurBackgroundView.alpha = 1.0 - (progress * 0.5)
        case .ended, .cancelled:
            if verticalDrag > 105 {
                dismissSelf()
            } else {
                UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.5) {
                    self.imageView.transform = .identity
                    self.blurBackgroundView.alpha = 1.0
                }
            }
        default:
            break
        }
    }
    #endif

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

// MARK: - 📖 TRANG CHI TIẾT BÀI HƯỚNG DẪN (TIMELINE LIÊN KẾT + STICKY GLASS BAR + NÚT KÍNH MỜ)
private final class GuideArticleDetailViewController: UIViewController, UIScrollViewDelegate {
    private let article: GuideArticle
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let heroCard = UIView()
    private let heroClipView = UIView()
    private let heroGradient = CAGradientLayer()

    // Nút Quay lại Kính Mờ & Thanh tiêu đề Kính Mờ tự hiện khi cuộn xuống
    private let stickyTopBlurBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
    private let stickyTitleLabel = UILabel()
    private let floatingBackBlurWrap = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
    private var floatingBackButton: UIButton!

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
        setupHeroHeader()
        setupSectionHeader()
        buildArticleContent()
        setupStickyGlassBarAndBackButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        heroGradient.frame = heroClipView.bounds
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
        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset = UIEdgeInsets(top: 48, left: 0, bottom: 50, right: 0)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 24, trailing: 16)

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

    private func setupHeroHeader() {
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = SourcesCSSTheme.cornerRadius + 2
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroCard.layer.cornerCurve = .continuous
        }
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 9)
        heroCard.layer.shadowRadius = 18
        heroCard.layer.shadowOpacity = 0.25

        heroClipView.translatesAutoresizingMaskIntoConstraints = false
        heroClipView.layer.cornerRadius = SourcesCSSTheme.cornerRadius + 2
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroClipView.layer.cornerCurve = .continuous
        }
        heroClipView.clipsToBounds = true
        heroClipView.layer.borderWidth = 1.2
        heroClipView.layer.borderColor = UIColor.white.withAlphaComponent(0.36).cgColor

        heroGradient.colors = [SourcesCSSTheme.heroStart, SourcesCSSTheme.heroEnd]
        heroGradient.startPoint = CGPoint(x: 0, y: 0)
        heroGradient.endPoint = CGPoint(x: 1, y: 1)
        heroClipView.layer.insertSublayer(heroGradient, at: 0)

        let decorCircle = UIView()
        decorCircle.translatesAutoresizingMaskIntoConstraints = false
        decorCircle.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        decorCircle.layer.cornerRadius = 60
        decorCircle.isUserInteractionEnabled = false
        heroClipView.addSubview(decorCircle)

        let badgePill = GuidePillTagView(
            bgColor: SourcesCSSTheme.white,
            textColor: SourcesCSSTheme.blue,
            borderColor: UIColor.white
        )
        badgePill.setText("✦ CHỦ ĐỀ #\(article.orderNumber)")

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = article.title
        if let roundedDesc = UIFont.systemFont(ofSize: 21, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 21)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .heavy)
        }
        titleLabel.textColor = SourcesCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.26

        let subContainer = UIView()
        subContainer.translatesAutoresizingMaskIntoConstraints = false
        subContainer.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        subContainer.layer.cornerRadius = 12
        if #available(iOS 13.0, tvOS 13.0, *) {
            subContainer.layer.cornerCurve = .continuous
        }
        subContainer.layer.borderWidth = 0.8
        subContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Mọi cách khắc phục không đảm bảo thành công 100%, bạn cần kiên nhẫn và thực hiện lại nhiều lần."
        subLabel.font = UIFont.systemFont(ofSize: 12.8, weight: .semibold)
        subLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.96)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 0
        subContainer.addSubview(subLabel)

        heroClipView.addSubview(badgePill)
        heroClipView.addSubview(titleLabel)
        heroClipView.addSubview(subContainer)
        heroCard.addSubview(heroClipView)

        NSLayoutConstraint.activate([
            heroClipView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor),
            heroClipView.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor),
            heroClipView.topAnchor.constraint(equalTo: heroCard.topAnchor),
            heroClipView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor),

            decorCircle.widthAnchor.constraint(equalToConstant: 120),
            decorCircle.heightAnchor.constraint(equalToConstant: 120),
            decorCircle.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: 35),
            decorCircle.topAnchor.constraint(equalTo: heroClipView.topAnchor, constant: -45),

            badgePill.centerXAnchor.constraint(equalTo: heroClipView.centerXAnchor),
            badgePill.topAnchor.constraint(equalTo: heroClipView.topAnchor, constant: 15),

            titleLabel.topAnchor.constraint(equalTo: badgePill.bottomAnchor, constant: 9),
            titleLabel.leadingAnchor.constraint(equalTo: heroClipView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: -16),

            subContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subContainer.leadingAnchor.constraint(equalTo: heroClipView.leadingAnchor, constant: 14),
            subContainer.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: -14),
            subContainer.bottomAnchor.constraint(equalTo: heroClipView.bottomAnchor, constant: -15),

            subLabel.leadingAnchor.constraint(equalTo: subContainer.leadingAnchor, constant: 10),
            subLabel.trailingAnchor.constraint(equalTo: subContainer.trailingAnchor, constant: -10),
            subLabel.topAnchor.constraint(equalTo: subContainer.topAnchor, constant: 8),
            subLabel.bottomAnchor.constraint(equalTo: subContainer.bottomAnchor, constant: -8)
        ])

        contentStackView.addArrangedSubview(heroCard)
    }

    private func setupSectionHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        let iconBox = UIView()
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        iconBox.backgroundColor = SourcesCSSTheme.blue.withAlphaComponent(0.14)
        iconBox.layer.cornerRadius = 7
        if #available(iOS 13.0, tvOS 13.0, *) {
            iconBox.layer.cornerCurve = .continuous
        }

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .heavy)
        iconView.image = UIImage(systemName: "wrench.and.screwdriver.fill", withConfiguration: iconConfig)
        iconView.tintColor = SourcesCSSTheme.blue
        iconBox.addSubview(iconView)

        let primaryLabel = UILabel()
        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.text = "HƯỚNG DẪN & KHẮC PHỤC SỰ CỐ"
        primaryLabel.textColor = SourcesCSSTheme.blue
        if let roundedDesc = UIFont.systemFont(ofSize: 15, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            primaryLabel.font = UIFont(descriptor: roundedDesc, size: 15)
        } else {
            primaryLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        }

        let underline = SourcesAccentUnderlineView()
        underline.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(iconBox)
        headerContainer.addSubview(primaryLabel)
        headerContainer.addSubview(underline)

        NSLayoutConstraint.activate([
            iconBox.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 4),
            iconBox.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            iconBox.widthAnchor.constraint(equalToConstant: 24),
            iconBox.heightAnchor.constraint(equalToConstant: 24),

            iconView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            primaryLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 8),
            primaryLabel.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            underline.leadingAnchor.constraint(equalTo: iconBox.leadingAnchor),
            underline.topAnchor.constraint(equalTo: iconBox.bottomAnchor, constant: 5),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3.5),
            underline.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -2)
        ])

        contentStackView.addArrangedSubview(headerContainer)
    }

    private func buildArticleContent() {
        if article.blocks.isEmpty {
            let emptyCard = makeTextCardView(for: "Nội dung hướng dẫn đang được cập nhật.")
            contentStackView.addArrangedSubview(emptyCard)
            return
        }

        for (idx, block) in article.blocks.enumerated() {
            let blockView: UIView
            switch block.type {
            case .text(let textContent):
                blockView = makeTextCardView(for: textContent)

            case .image(let imageURL):
                let imageViewCard = GuideStyledImageView(url: imageURL)
                imageViewCard.onTapImage = { [weak self] tappedImage in
                    let previewVC = GuideImagePreviewController(image: tappedImage)
                    self?.present(previewVC, animated: true)
                }
                blockView = imageViewCard

            case .youtube(let videoID):
                blockView = OverviewHostedVideoSectionView(videoID: videoID, parentViewController: self)

            case .download(let downloadURL):
                blockView = GuideDownloadActionCardView(url: downloadURL, hostViewController: self)
            }

            // Hiệu ứng Cascade xuất hiện mượt mà cho từng khối nội dung
            blockView.alpha = 0
            blockView.transform = CGAffineTransform(translationX: 0, y: 12)
            contentStackView.addArrangedSubview(blockView)

            UIView.animate(
                withDuration: 0.36,
                delay: Double(min(idx, 6)) * 0.045,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.4,
                options: [.allowUserInteraction]
            ) {
                blockView.alpha = 1
                blockView.transform = .identity
            }
        }
    }

    /// Tạo khối Card trắng chứa các bước hướng dẫn theo kiểu Dòng Thời Gian Liên Kết (Connected Timeline Steps)
    private func makeTextCardView(for rawText: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyCardStyle(to: card, cornerRadius: SourcesCSSTheme.cornerRadius)

        let innerStack = UIStackView()
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.axis = .vertical
        innerStack.spacing = 10

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
            let isLastItem = (index == bulletItems.count - 1)
            let bulletRow = makeBulletRow(stepText: itemText, isLast: isLastItem)
            innerStack.addArrangedSubview(bulletRow)
        }

        card.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        return card
    }

    private func makeBulletRow(stepText: String, isLast: Bool) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = SourcesCSSTheme.light
        row.layer.cornerRadius = SourcesCSSTheme.innerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            row.layer.cornerCurve = .continuous
        }
        row.layer.borderWidth = 1.0
        row.layer.borderColor = SourcesCSSTheme.innerBorder.cgColor

        // Thanh dọc điểm nhấn mảnh bên trái (Accent Left Bar)
        let leftAccentBar = SourcesAccentUnderlineView()
        leftAccentBar.translatesAutoresizingMaskIntoConstraints = false
        leftAccentBar.alpha = 0.65

        // Hạt Ngọc tròn màu Xanh - Tím tinh tế thay cho dấu chấm chữ đơn điệu
        let gemOuterCircle = UIView()
        gemOuterCircle.translatesAutoresizingMaskIntoConstraints = false
        gemOuterCircle.backgroundColor = SourcesCSSTheme.blue.withAlphaComponent(0.15)
        gemOuterCircle.layer.cornerRadius = 9

        let gemInnerDot = UIView()
        gemInnerDot.translatesAutoresizingMaskIntoConstraints = false
        gemInnerDot.backgroundColor = SourcesCSSTheme.blue
        gemInnerDot.layer.cornerRadius = 4
        gemOuterCircle.addSubview(gemInnerDot)

        // Đường nối dọc mảnh giữa các bước (nếu chưa phải bước cuối)
        let connectorLine = UIView()
        connectorLine.translatesAutoresizingMaskIntoConstraints = false
        connectorLine.backgroundColor = SourcesCSSTheme.blue.withAlphaComponent(0.18)
        connectorLine.isHidden = isLast

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.attributedText = styleHighlightedInstructionText(stepText)

        row.addSubview(leftAccentBar)
        row.addSubview(connectorLine)
        row.addSubview(gemOuterCircle)
        row.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            leftAccentBar.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            leftAccentBar.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            leftAccentBar.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10),
            leftAccentBar.widthAnchor.constraint(equalToConstant: 3.0),

            gemOuterCircle.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            gemOuterCircle.topAnchor.constraint(equalTo: row.topAnchor, constant: 13),
            gemOuterCircle.widthAnchor.constraint(equalToConstant: 18),
            gemOuterCircle.heightAnchor.constraint(equalToConstant: 18),

            gemInnerDot.centerXAnchor.constraint(equalTo: gemOuterCircle.centerXAnchor),
            gemInnerDot.centerYAnchor.constraint(equalTo: gemOuterCircle.centerYAnchor),
            gemInnerDot.widthAnchor.constraint(equalToConstant: 8),
            gemInnerDot.heightAnchor.constraint(equalToConstant: 8),

            connectorLine.centerXAnchor.constraint(equalTo: gemOuterCircle.centerXAnchor),
            connectorLine.topAnchor.constraint(equalTo: gemOuterCircle.bottomAnchor, constant: 2),
            connectorLine.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),
            connectorLine.widthAnchor.constraint(equalToConstant: 1.5),

            bodyLabel.leadingAnchor.constraint(equalTo: gemOuterCircle.trailingAnchor, constant: 10),
            bodyLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            bodyLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            bodyLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12)
        ])

        return row
    }

    /// Tự động làm nổi bật mũi tên `→` màu xanh chuẩn và giữ chữ Đen Than (`deepInk`) sắc nét
    private func styleHighlightedInstructionText(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.2

        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15.2, weight: .medium),
                .foregroundColor: SourcesCSSTheme.deepInk,
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

    // Thanh Kính Mờ trên cùng (Sticky Glass Top Bar) & Nút Quay lại Kính Mờ
    private func setupStickyGlassBarAndBackButton() {
        stickyTopBlurBar.translatesAutoresizingMaskIntoConstraints = false
        stickyTopBlurBar.alpha = 0
        stickyTopBlurBar.layer.borderWidth = 0.5
        stickyTopBlurBar.layer.borderColor = SourcesCSSTheme.border.cgColor

        stickyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stickyTitleLabel.text = article.title
        if let roundedDesc = UIFont.systemFont(ofSize: 14.5, weight: .bold).fontDescriptor.withDesign(.rounded) {
            stickyTitleLabel.font = UIFont(descriptor: roundedDesc, size: 14.5)
        } else {
            stickyTitleLabel.font = UIFont.systemFont(ofSize: 14.5, weight: .bold)
        }
        stickyTitleLabel.textColor = SourcesCSSTheme.deepInk
        stickyTitleLabel.textAlignment = .center
        stickyTitleLabel.lineBreakMode = .byTruncatingTail
        stickyTopBlurBar.contentView.addSubview(stickyTitleLabel)

        view.addSubview(stickyTopBlurBar)

        // Nút Quay lại bọc Kính Mờ thật (UIVisualEffectView)
        floatingBackBlurWrap.translatesAutoresizingMaskIntoConstraints = false
        floatingBackBlurWrap.layer.cornerRadius = 17
        if #available(iOS 13.0, tvOS 13.0, *) {
            floatingBackBlurWrap.layer.cornerCurve = .continuous
        }
        floatingBackBlurWrap.clipsToBounds = true
        floatingBackBlurWrap.layer.borderWidth = 1.0
        floatingBackBlurWrap.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor

        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
        btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        btn.setTitle(" Quay lại", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        btn.tintColor = SourcesCSSTheme.blue
        btn.setTitleColor(SourcesCSSTheme.blue, for: .normal)
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.65)
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 14)

        btn.addTarget(self, action: #selector(handleBackButtonTap), for: .touchUpInside)
        floatingBackBlurWrap.contentView.addSubview(btn)

        let shadowContainer = UIView()
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.backgroundColor = .clear
        shadowContainer.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowContainer.layer.shadowRadius = 10
        shadowContainer.layer.shadowOpacity = 0.14
        shadowContainer.addSubview(floatingBackBlurWrap)
        view.addSubview(shadowContainer)

        NSLayoutConstraint.activate([
            stickyTopBlurBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stickyTopBlurBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stickyTopBlurBar.topAnchor.constraint(equalTo: view.topAnchor),
            stickyTopBlurBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 46),

            stickyTitleLabel.leadingAnchor.constraint(equalTo: shadowContainer.trailingAnchor, constant: 10),
            stickyTitleLabel.trailingAnchor.constraint(equalTo: stickyTopBlurBar.contentView.trailingAnchor, constant: -16),
            stickyTitleLabel.centerYAnchor.constraint(equalTo: shadowContainer.centerYAnchor),

            shadowContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            shadowContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            shadowContainer.heightAnchor.constraint(equalToConstant: 34),

            floatingBackBlurWrap.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            floatingBackBlurWrap.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            floatingBackBlurWrap.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            floatingBackBlurWrap.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor),

            btn.leadingAnchor.constraint(equalTo: floatingBackBlurWrap.contentView.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: floatingBackBlurWrap.contentView.trailingAnchor),
            btn.topAnchor.constraint(equalTo: floatingBackBlurWrap.contentView.topAnchor),
            btn.bottomAnchor.constraint(equalTo: floatingBackBlurWrap.contentView.bottomAnchor)
        ])

        self.floatingBackButton = btn
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let adjustedOffsetY = scrollView.contentOffset.y + scrollView.contentInset.top
        let targetAlpha = min(max((adjustedOffsetY - 85.0) / 45.0, 0.0), 1.0)
        stickyTopBlurBar.alpha = targetAlpha
    }

    @objc private func handleBackButtonTap() {
        #if !os(tvOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - 🚀 CONTROLLER CHÍNH: SOURCESVIEWCONTROLLER (GIAO DIỆN ULTRA-ELEGANT + CHỨC NĂNG ĐẦY ĐỦ)
final class SourcesViewController: UICollectionViewController {
    // Giữ nguyên biến này để tương thích 100% với AppDelegate / SceneDelegate khi build IPA
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
    private var animatedIndexPaths = Set<IndexPath>()

    private let guidesTableView = UITableView(frame: .zero, style: .plain)
    private let heroHeaderView = GuidesHeroHeaderView(frame: CGRect(x: 0, y: 0, width: 375, height: 214))
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

        // Khoá giao diện Sáng (Light Mode) để hiển thị rõ nét nhất trên nền thẻ ngọc trai
        overrideUserInterfaceStyle = .light

        // 1. Ẩn hoàn toàn Navigation Bar trắng trên cùng giống hệt SettingsViewController & NewsViewController
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

        // 2. Thiết lập giao diện Bảng Hướng Dẫn chuẩn CSS Theme
        setupGuidesTableViewInterface()
        setupStateOverlayCard()
        setupTableFooterInfo()

        // 3. Hiển thị tức thì từ Cache (nếu có) và kiểm tra ngầm từ GitHub
        fetchGuidesFromGitHub(showLoadingCard: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let header = guidesTableView.tableHeaderView {
            let targetHeight: CGFloat = 214
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
        guidesTableView.keyboardDismissMode = .onDrag
        guidesTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        if #available(iOS 15.0, tvOS 15.0, *) {
            guidesTableView.sectionHeaderTopPadding = 0
        }

        guidesTableView.translatesAutoresizingMaskIntoConstraints = false
        guidesTableView.delegate = self
        guidesTableView.dataSource = self
        guidesTableView.rowHeight = UITableView.automaticDimension
        guidesTableView.estimatedRowHeight = 114
        guidesTableView.register(GuideTopicRowCell.self, forCellReuseIdentifier: GuideTopicRowCell.reuseIdentifier)

        heroHeaderView.onSearchTextChanged = { [weak self] query in
            self?.applySearchFilter(query)
        }
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

    func applySearchFilter(_ query: String) {
        currentSearchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if currentSearchQuery.isEmpty {
            filteredArticles = allArticles
        } else {
            filteredArticles = allArticles.filter { $0.searchableContent.contains(currentSearchQuery) }
        }
        heroHeaderView.updateCount(filteredArticles.count)
        guidesTableView.reloadData()
    }

    func setupTableFooterInfo() {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 58))
        footer.backgroundColor = .clear

        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.text = "✦ Dữ liệu hướng dẫn được đồng bộ trực tiếp từ hệ thống máy chủ\nKéo xuống để cập nhật các hướng dẫn mới nhất"
        infoLabel.font = UIFont.systemFont(ofSize: 12.2, weight: .semibold)
        infoLabel.textColor = SourcesCSSTheme.slateSubtitle
        infoLabel.numberOfLines = 2
        infoLabel.textAlignment = .center

        footer.addSubview(infoLabel)
        NSLayoutConstraint.activate([
            infoLabel.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            infoLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -16)
        ])

        guidesTableView.tableFooterView = footer
    }

    func setupStateOverlayCard() {
        stateCardView.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyCardStyle(to: stateCardView, cornerRadius: SourcesCSSTheme.cornerRadius)

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
        stateSubtitleLabel.textColor = SourcesCSSTheme.slateSubtitle
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
            stateCardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 45),

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
        animatedIndexPaths.removeAll()
        fetchGuidesFromGitHub(showLoadingCard: false)
    }

    @objc func handleRetryButtonTap() {
        animatedIndexPaths.removeAll()
        fetchGuidesFromGitHub(showLoadingCard: true)
    }

    func fetchGuidesFromGitHub(showLoadingCard: Bool) {
        guard !isLoadingGuides else { return }

        let cacheKey = "CachedGitHubGuidesText"

        // 1. ⚡ HIỂN THỊ NGAY LẬP TỨC TỪ BỘ NHỚ MÁY (NẾU CÓ)
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
                if self.allArticles.isEmpty {
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
                    self.showErrorState(message: "Hiện chưa có bài viết hướng dẫn nào trong tệp cấu hình.")
                }
            } catch {
                if self.allArticles.isEmpty {
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
        return filteredArticles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: GuideTopicRowCell.reuseIdentifier, for: indexPath) as? GuideTopicRowCell else {
            return UITableViewCell()
        }
        let article = filteredArticles[indexPath.row]
        let isNewestOverall = (article.id == allArticles.first?.id)
        cell.configure(with: article, isTopPriority: isNewestOverall)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard !animatedIndexPaths.contains(indexPath) else { return }
        animatedIndexPaths.insert(indexPath)

        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 14)
        UIView.animate(
            withDuration: 0.38,
            delay: Double(min(indexPath.row, 6)) * 0.035,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.4,
            options: [.allowUserInteraction]
        ) {
            cell.alpha = 1
            cell.transform = .identity
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard filteredArticles.indices.contains(indexPath.row) else { return }
        let selectedArticle = filteredArticles[indexPath.row]

        #if !os(tvOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif

        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(translationX: 3, y: -2).scaledBy(x: 0.98, y: 0.98)
            }) { _ in
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.58, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
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
