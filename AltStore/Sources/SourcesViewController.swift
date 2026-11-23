
//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 3/17/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
@preconcurrency import WebKit
import CoreData
import Nuke

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI TOÀN BỘ ỨNG DỤNG & CHỮ ĐEN TUYỀN)
private struct SourcesCSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                      // #000000 (Chữ đen tuyền độ tương phản tuyệt đối)
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)       // #f5f8ff (Đồng bộ innerRowBackground)
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)      // #dce2ec (Viền chuẩn toàn hệ thống)
    static let innerBorder = UIColor(red: 222/255, green: 229/255, blue: 240/255, alpha: 1.0) // #dee5f0
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)          // #007bff (--primary-blue)
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)       // #6f42c1 (--primary-purple)
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)         // #28a745 (--primary-green)
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0)       // #ff00ff
    static let dark = UIColor.black                                                           // #000000

    // 🌸 Màu Hồng Phấn / Hồng Đào nổi bật dành riêng cho hệ thống Icon của Tin Tức & Sửa Lỗi
    static let pastelPink = UIColor(red: 255/255, green: 105/255, blue: 180/255, alpha: 1.0)  // #FF69B4 (Hot Pastel Pink)
    static let vibrantPink = UIColor(red: 255/255, green: 45/255, blue: 135/255, alpha: 1.0)  // #FF2D87 (Vibrant Rose Pink)
    static let softPinkBg = UIColor(red: 255/255, green: 235/255, blue: 245/255, alpha: 1.0)  // #FFEBF5 (Nền hồng phấn dịu)
    static let softPinkBorder = UIColor(red: 255/255, green: 182/255, blue: 218/255, alpha: 1.0)

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.95) -> rgba(111,66,193,.92))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.95).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.92).cgColor

    // Pink Icon Gradient (Hồng phấn -> Hồng đào đậm sang trọng, cực nổi bật)
    static let pinkGradientStart = UIColor(red: 255/255, green: 90/255, blue: 165/255, alpha: 1.0).cgColor
    static let pinkGradientEnd = UIColor(red: 236/255, green: 38/255, blue: 143/255, alpha: 1.0).cgColor

    static let cornerRadius: CGFloat = 18.0
    static let innerCornerRadius: CGFloat = 14.0
    static let iPhoneImageCornerRadius: CGFloat = 22.0
    static let videoFrameCornerRadius: CGFloat = 47.33
    static let mediaFrameLineWidth: CGFloat = 4.0

    /// Áp dụng đổ bóng kép (Ambient + Tinted Blue Glow) chuẩn đồng bộ với các màn hình trước
    static func applyCardStyle(to view: UIView, cornerRadius: CGFloat = SourcesCSSTheme.cornerRadius) {
        view.backgroundColor = SourcesCSSTheme.white
        view.layer.cornerRadius = cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.borderWidth = 1.1
        view.layer.borderColor = SourcesCSSTheme.border.cgColor
        view.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.layer.shadowRadius = 14
        view.layer.shadowOpacity = 0.09
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

// MARK: - ➖ THANH GẠCH CHÂN GRADIENT HỒNG PHẤN - TÍM (38x3.5pt ĐỒNG BỘ TOÀN HỆ THỐNG)
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
        gradientLayer.colors = [SourcesCSSTheme.vibrantPink.cgColor, SourcesCSSTheme.purple.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        layer.cornerRadius = 1.75
        clipsToBounds = true
    }
}

// MARK: - 🖼️ LỚP KHUNG VIỀN GRADIENT TỰ ĐỘNG CO GIÃN 100% THEO KÍCH THƯỚC ẢNH & VIDEO
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
            SourcesCSSTheme.blue.withAlphaComponent(0.78).cgColor,
            SourcesCSSTheme.vibrantPink.withAlphaComponent(0.68).cgColor,
            SourcesCSSTheme.blue.withAlphaComponent(0.78).cgColor
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

    /// Kiểm tra xem link có phải là link ảnh trên GitHub hay không (theo đúng yêu cầu: link ảnh GitHub hiện ảnh, link khác hiện nút tải về)
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

        // Hỗ trợ cả link ảnh đính kèm trực tiếp trên GitHub dạng github.com/user-attachments/assets/...
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

// MARK: - 🏷️ HEADER ĐẦU TRANG CHUẨN (HERO BANNER + ICON HỒNG PHẤN NỔI BẬT)
private final class GuidesHeroHeaderView: UIView {
    private let heroCard = UIView()
    private let heroClipView = UIView()
    private let heroGradient = CAGradientLayer()
    private let decorCircle = UIView()
    private let heroIconBadge = UIView()
    private let heroIconGradient = CAGradientLayer()
    private let heroIconView = UIImageView()

    private let sectionIconBox = UIView()
    private let sectionIconGradient = CAGradientLayer()
    private let sectionIconView = UIImageView()
    private let sectionTitleLabel = UILabel()
    private let underlineView = SourcesAccentUnderlineView()
    private let countBadgeButton = UIButton(type: .system)
    private let countBadgeGradient = CAGradientLayer()

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

        // 1. Khối Hero Card đồng bộ 100% với CSSHeroBannerView của NewsViewController
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroCard.layer.cornerCurve = .continuous
        }
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 7)
        heroCard.layer.shadowRadius = 14
        heroCard.layer.shadowOpacity = 0.26

        heroClipView.translatesAutoresizingMaskIntoConstraints = false
        heroClipView.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroClipView.layer.cornerCurve = .continuous
        }
        heroClipView.clipsToBounds = true
        heroClipView.layer.borderWidth = 1.2
        heroClipView.layer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor

        heroGradient.colors = [SourcesCSSTheme.heroStart, SourcesCSSTheme.heroEnd]
        heroGradient.startPoint = CGPoint(x: 0, y: 0)
        heroGradient.endPoint = CGPoint(x: 1, y: 1)
        heroClipView.layer.insertSublayer(heroGradient, at: 0)

        // Vòng tròn ánh sáng trang trí góc trên bên phải
        decorCircle.translatesAutoresizingMaskIntoConstraints = false
        decorCircle.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        decorCircle.layer.cornerRadius = 60
        decorCircle.isUserInteractionEnabled = false
        heroClipView.addSubview(decorCircle)

        // Hàng Tiêu đề + Icon Hồng Phấn nổi bật
        let titleStack = UIStackView()
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .horizontal
        titleStack.spacing = 9
        titleStack.alignment = .center

        heroIconBadge.translatesAutoresizingMaskIntoConstraints = false
        heroIconBadge.layer.cornerRadius = 16
        heroIconBadge.layer.masksToBounds = true
        heroIconBadge.layer.borderWidth = 1.2
        heroIconBadge.layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor

        heroIconGradient.colors = [SourcesCSSTheme.pinkGradientStart, SourcesCSSTheme.pinkGradientEnd]
        heroIconGradient.startPoint = CGPoint(x: 0, y: 0)
        heroIconGradient.endPoint = CGPoint(x: 1, y: 1)
        heroIconBadge.layer.insertSublayer(heroIconGradient, at: 0)

        heroIconView.translatesAutoresizingMaskIntoConstraints = false
        let heroSymConfig = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .bold)
        heroIconView.image = UIImage(systemName: "newspaper.fill", withConfiguration: heroSymConfig)
            ?? UIImage(systemName: "book.fill", withConfiguration: heroSymConfig)
        heroIconView.tintColor = .white
        heroIconBadge.addSubview(heroIconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Tin Tức Và Sửa Lỗi"
        if let roundedDesc = UIFont.systemFont(ofSize: 23, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 23)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 23, weight: .heavy)
        }
        titleLabel.textColor = SourcesCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.28

        titleStack.addArrangedSubview(heroIconBadge)
        titleStack.addArrangedSubview(titleLabel)

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Cẩm nang khắc phục sự cố do cộng đồng mạng chia sẻ"
        subLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        subLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.96)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2

        heroClipView.addSubview(titleStack)
        heroClipView.addSubview(subLabel)
        heroCard.addSubview(heroClipView)

        // 2. Tiêu đề Section + Hộp Icon Hồng Phấn + Gạch chân Gradient
        sectionIconBox.translatesAutoresizingMaskIntoConstraints = false
        sectionIconBox.layer.cornerRadius = 7.5
        if #available(iOS 13.0, tvOS 13.0, *) {
            sectionIconBox.layer.cornerCurve = .continuous
        }
        sectionIconBox.layer.masksToBounds = true

        sectionIconGradient.colors = [SourcesCSSTheme.pinkGradientStart, SourcesCSSTheme.pinkGradientEnd]
        sectionIconGradient.startPoint = CGPoint(x: 0, y: 0)
        sectionIconGradient.endPoint = CGPoint(x: 1, y: 1)
        sectionIconBox.layer.insertSublayer(sectionIconGradient, at: 0)

        sectionIconView.translatesAutoresizingMaskIntoConstraints = false
        let secIconConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .heavy)
        sectionIconView.image = UIImage(systemName: "sparkles.rectangle.stack.fill", withConfiguration: secIconConfig)
            ?? UIImage(systemName: "square.grid.2x2.fill", withConfiguration: secIconConfig)
        sectionIconView.tintColor = SourcesCSSTheme.white
        sectionIconBox.addSubview(sectionIconView)

        sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionTitleLabel.text = "TỔNG HỢP CÁC DANH MỤC"
        sectionTitleLabel.textColor = SourcesCSSTheme.blue
        if let roundedSecDesc = UIFont.systemFont(ofSize: 15, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            sectionTitleLabel.font = UIFont(descriptor: roundedSecDesc, size: 15)
        } else {
            sectionTitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        }

        underlineView.translatesAutoresizingMaskIntoConstraints = false

        countBadgeButton.translatesAutoresizingMaskIntoConstraints = false
        countBadgeButton.setTitle("  Mới nhất ▲  ", for: .normal)
        countBadgeButton.setTitleColor(SourcesCSSTheme.white, for: .normal)
        countBadgeButton.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .heavy)
        countBadgeButton.layer.cornerRadius = 11
        countBadgeButton.layer.masksToBounds = true
        countBadgeButton.isUserInteractionEnabled = false

        countBadgeGradient.colors = [SourcesCSSTheme.pinkGradientStart, SourcesCSSTheme.pinkGradientEnd]
        countBadgeGradient.startPoint = CGPoint(x: 0, y: 0.5)
        countBadgeGradient.endPoint = CGPoint(x: 1, y: 0.5)
        countBadgeButton.layer.insertSublayer(countBadgeGradient, at: 0)

        addSubview(heroCard)
        addSubview(sectionIconBox)
        addSubview(sectionTitleLabel)
        addSubview(underlineView)
        addSubview(countBadgeButton)

        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            heroCard.heightAnchor.constraint(equalToConstant: 96),

            heroClipView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor),
            heroClipView.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor),
            heroClipView.topAnchor.constraint(equalTo: heroCard.topAnchor),
            heroClipView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor),

            decorCircle.widthAnchor.constraint(equalToConstant: 120),
            decorCircle.heightAnchor.constraint(equalToConstant: 120),
            decorCircle.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: 35),
            decorCircle.topAnchor.constraint(equalTo: heroClipView.topAnchor, constant: -45),

            heroIconBadge.widthAnchor.constraint(equalToConstant: 32),
            heroIconBadge.heightAnchor.constraint(equalToConstant: 32),
            heroIconView.centerXAnchor.constraint(equalTo: heroIconBadge.centerXAnchor),
            heroIconView.centerYAnchor.constraint(equalTo: heroIconBadge.centerYAnchor),

            titleStack.centerXAnchor.constraint(equalTo: heroClipView.centerXAnchor),
            titleStack.topAnchor.constraint(equalTo: heroClipView.topAnchor, constant: 16),

            subLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: heroClipView.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: -14),

            sectionIconBox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            sectionIconBox.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 18),
            sectionIconBox.widthAnchor.constraint(equalToConstant: 25),
            sectionIconBox.heightAnchor.constraint(equalToConstant: 25),

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
        sectionIconGradient.frame = sectionIconBox.bounds
        countBadgeGradient.frame = countBadgeButton.bounds
    }
}

// MARK: - 🗂️ THANH TIÊU ĐỀ HƯỚNG DẪN (CARD CELL SANG TRỌNG + ICON HỒNG PHẤN NỔI BẬT)
private final class GuideTopicRowCell: UITableViewCell {
    static let reuseIdentifier = "GuideTopicRowCell"

    private let cardView = UIView()
    private let badgeShadowView = UIView()
    private let badgeContainer = UIView()
    private let badgeGradient = CAGradientLayer()
    private let badgeIconView = UIImageView()
    private let badgeNumberLabel = UILabel()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let metaStackView = UIStackView()
    private let priorityTagLabel = UILabel()
    private let stepsTagLabel = UILabel()
    private let mediaTagLabel = UILabel()
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
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.5, options: [.allowUserInteraction, .beginFromCurrentState]) {
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            self.cardView.alpha = highlighted ? 0.94 : 1.0
        }
    }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Khối Card trắng chuẩn CSS đồng bộ 100%
        cardView.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyCardStyle(to: cardView, cornerRadius: SourcesCSSTheme.cornerRadius)

        // Đổ bóng hồng phấn cho Badge Icon bên trái
        badgeShadowView.translatesAutoresizingMaskIntoConstraints = false
        badgeShadowView.backgroundColor = .clear
        badgeShadowView.layer.shadowColor = SourcesCSSTheme.vibrantPink.cgColor
        badgeShadowView.layer.shadowOffset = CGSize(width: 0, height: 4)
        badgeShadowView.layer.shadowRadius = 8
        badgeShadowView.layer.shadowOpacity = 0.32

        // Badge bên trái (Huy hiệu Gradient Hồng Phấn nổi bật)
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.layer.cornerRadius = 14
        if #available(iOS 13.0, tvOS 13.0, *) {
            badgeContainer.layer.cornerCurve = .continuous
        }
        badgeContainer.layer.masksToBounds = true
        badgeContainer.layer.borderWidth = 1.2
        badgeContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor

        badgeGradient.colors = [SourcesCSSTheme.pinkGradientStart, SourcesCSSTheme.pinkGradientEnd]
        badgeGradient.startPoint = CGPoint(x: 0, y: 0)
        badgeGradient.endPoint = CGPoint(x: 1, y: 1)
        badgeContainer.layer.insertSublayer(badgeGradient, at: 0)

        badgeIconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        badgeIconView.image = UIImage(systemName: "wand.and.stars", withConfiguration: iconConfig)
            ?? UIImage(systemName: "sparkles", withConfiguration: iconConfig)
        badgeIconView.tintColor = SourcesCSSTheme.white
        badgeIconView.contentMode = .scaleAspectFit

        badgeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeNumberLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .heavy)
        badgeNumberLabel.textColor = SourcesCSSTheme.white
        badgeNumberLabel.textAlignment = .center

        badgeContainer.addSubview(badgeIconView)
        badgeContainer.addSubview(badgeNumberLabel)
        badgeShadowView.addSubview(badgeContainer)

        // Tiêu đề chính (Chữ đen tuyền #000000)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .bold)
        titleLabel.textColor = SourcesCSSTheme.pureBlack
        titleLabel.numberOfLines = 2

        // Phụ đề tóm tắt (Chữ đen tuyền rõ nét)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13.2, weight: .medium)
        subtitleLabel.textColor = SourcesCSSTheme.pureBlack
        subtitleLabel.numberOfLines = 1

        // Thanh Tags thông tin
        metaStackView.translatesAutoresizingMaskIntoConstraints = false
        metaStackView.axis = .horizontal
        metaStackView.spacing = 6
        metaStackView.alignment = .center

        styleTagLabel(priorityTagLabel, bgColor: SourcesCSSTheme.vibrantPink.withAlphaComponent(0.14), textColor: SourcesCSSTheme.vibrantPink)
        styleTagLabel(stepsTagLabel, bgColor: SourcesCSSTheme.blue.withAlphaComponent(0.12), textColor: SourcesCSSTheme.blue)
        styleTagLabel(mediaTagLabel, bgColor: SourcesCSSTheme.purple.withAlphaComponent(0.12), textColor: SourcesCSSTheme.purple)

        metaStackView.addArrangedSubview(priorityTagLabel)
        metaStackView.addArrangedSubview(stepsTagLabel)
        metaStackView.addArrangedSubview(mediaTagLabel)

        // Nút mũi tên phải màu hồng phấn
        chevronContainer.translatesAutoresizingMaskIntoConstraints = false
        chevronContainer.backgroundColor = SourcesCSSTheme.softPinkBg
        chevronContainer.layer.cornerRadius = 15
        chevronContainer.layer.borderWidth = 1.0
        chevronContainer.layer.borderColor = SourcesCSSTheme.softPinkBorder.cgColor

        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        let chevConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .bold)
        chevronImageView.image = UIImage(systemName: "chevron.right", withConfiguration: chevConfig)
        chevronImageView.tintColor = SourcesCSSTheme.vibrantPink
        chevronContainer.addSubview(chevronImageView)

        cardView.addSubview(badgeShadowView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(metaStackView)
        cardView.addSubview(chevronContainer)
        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            badgeShadowView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            badgeShadowView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            badgeShadowView.widthAnchor.constraint(equalToConstant: 48),
            badgeShadowView.heightAnchor.constraint(equalToConstant: 48),

            badgeContainer.leadingAnchor.constraint(equalTo: badgeShadowView.leadingAnchor),
            badgeContainer.trailingAnchor.constraint(equalTo: badgeShadowView.trailingAnchor),
            badgeContainer.topAnchor.constraint(equalTo: badgeShadowView.topAnchor),
            badgeContainer.bottomAnchor.constraint(equalTo: badgeShadowView.bottomAnchor),

            badgeIconView.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeIconView.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 8),
            badgeIconView.widthAnchor.constraint(equalToConstant: 16),
            badgeIconView.heightAnchor.constraint(equalToConstant: 16),

            badgeNumberLabel.topAnchor.constraint(equalTo: badgeIconView.bottomAnchor, constant: 2),
            badgeNumberLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 2),
            badgeNumberLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -2),

            chevronContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevronContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronContainer.widthAnchor.constraint(equalToConstant: 30),
            chevronContainer.heightAnchor.constraint(equalToConstant: 30),

            chevronImageView.centerXAnchor.constraint(equalTo: chevronContainer.centerXAnchor),
            chevronImageView.centerYAnchor.constraint(equalTo: chevronContainer.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: badgeShadowView.trailingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(equalTo: chevronContainer.leadingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            metaStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            metaStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -13)
        ])
    }

    private func styleTagLabel(_ label: UILabel, bgColor: UIColor, textColor: UIColor) {
        label.font = UIFont.systemFont(ofSize: 10.5, weight: .heavy)
        label.textColor = textColor
        label.backgroundColor = bgColor
        label.layer.cornerRadius = 7
        label.layer.masksToBounds = true
    }

    func configure(with article: GuideArticle, isTopPriority: Bool) {
        badgeNumberLabel.text = "#\(article.orderNumber)"
        titleLabel.text = article.title
        subtitleLabel.text = article.previewSubtitle

        if isTopPriority {
            priorityTagLabel.text = "  ★ MỚI NHẤT  "
            priorityTagLabel.isHidden = false
        } else {
            priorityTagLabel.isHidden = true
        }

        let steps = article.stepCount
        stepsTagLabel.text = steps > 0 ? "  • \(steps) mục  " : "  • Chi tiết  "

        let imgs = article.imageCount
        let vids = article.videoCount
        let dls = article.downloadCount

        var mediaParts: [String] = []
        if imgs > 0 { mediaParts.append("🖼 \(imgs) ảnh") }
        if vids > 0 { mediaParts.append("🎬 \(vids) video") }
        if dls > 0 { mediaParts.append("⬇️ \(dls) tệp") }

        if !mediaParts.isEmpty {
            mediaTagLabel.text = "  " + mediaParts.joined(separator: " • ") + "  "
            mediaTagLabel.isHidden = false
        } else {
            mediaTagLabel.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        badgeGradient.frame = badgeContainer.bounds
    }
}

// MARK: - 📱 KHUNG HIỂN THỊ ẢNH GITHUB VIỀN ĐẬM GRADIENT BAO TRỌN 100% 4 CẠNH ẢNH MỌI LÚC
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

    private let borderThickness: CGFloat = 4.0

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
        outerShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 7)
        outerShadowContainer.layer.shadowRadius = 15
        outerShadowContainer.layer.shadowOpacity = 0.24

        let outerRadius = SourcesCSSTheme.iPhoneImageCornerRadius
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
        shimmerActivity.color = SourcesCSSTheme.vibrantPink
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
        retryButton.backgroundColor = SourcesCSSTheme.vibrantPink
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

// MARK: - 🎬 KHUNG VIDEO YOUTUBE DỌC 9:19.5 CHUẨN IPHONE 14 (ĐỒNG BỘ 100% VỚI NEWSVIEWCONTROLLER)
private final class GuideYouTubeVideoFrameView: UIView, WKNavigationDelegate {
    private let videoID: String
    private let cardContainer = UIView()
    private let headerRow = UIView()
    private let iconBox = UIView()
    private let iconGradient = CAGradientLayer()
    private let iconImageView = UIImageView()
    private let headerTextLabel = UILabel()

    private let outerShadowContainer = UIView()
    private let borderContainer = GradientBorderContainerView()
    private let innerClipContainer = UIView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private var webView: WKWebView?

    private let borderThickness: CGFloat = SourcesCSSTheme.mediaFrameLineWidth
    private let frameCornerRadius: CGFloat = SourcesCSSTheme.videoFrameCornerRadius

    init(videoID: String) {
        self.videoID = videoID
        super.init(frame: .zero)
        setupViews()
        mountPlayerWebView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        webView?.navigationDelegate = nil
        webView?.stopLoading()
    }

    private func setupViews() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // Card bao ngoài giống hệt SkySectionCard của mục Video trong NewsViewController
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyCardStyle(to: cardContainer, cornerRadius: SourcesCSSTheme.cornerRadius)

        // Hàng chú thích phía trên video
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.backgroundColor = SourcesCSSTheme.light
        headerRow.layer.cornerRadius = SourcesCSSTheme.innerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            headerRow.layer.cornerCurve = .continuous
        }
        headerRow.layer.borderWidth = 1.0
        headerRow.layer.borderColor = SourcesCSSTheme.innerBorder.cgColor

        iconBox.translatesAutoresizingMaskIntoConstraints = false
        iconBox.layer.cornerRadius = 10
        if #available(iOS 13.0, tvOS 13.0, *) {
            iconBox.layer.cornerCurve = .continuous
        }
        iconBox.layer.masksToBounds = true

        iconGradient.colors = [SourcesCSSTheme.pinkGradientStart, SourcesCSSTheme.pinkGradientEnd]
        iconGradient.startPoint = CGPoint(x: 0, y: 0)
        iconGradient.endPoint = CGPoint(x: 1, y: 1)
        iconBox.layer.insertSublayer(iconGradient, at: 0)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let symConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        iconImageView.image = UIImage(systemName: "play.tv.fill", withConfiguration: symConfig)
            ?? UIImage(systemName: "play.rectangle.fill", withConfiguration: symConfig)
        iconImageView.tintColor = .white
        iconBox.addSubview(iconImageView)

        headerTextLabel.translatesAutoresizingMaskIntoConstraints = false
        headerTextLabel.text = "Video hướng dẫn chi tiết (Nhấn trực tiếp vào khung bên dưới để phát video)"
        headerTextLabel.font = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
        headerTextLabel.textColor = SourcesCSSTheme.pureBlack
        headerTextLabel.numberOfLines = 0

        headerRow.addSubview(iconBox)
        headerRow.addSubview(headerTextLabel)

        // Khung điện thoại iPhone 14 tỉ lệ 9:19.5 bo góc 47.33pt + viền Gradient 4pt giống hệt IPhone14VerticalVideoFrameView
        outerShadowContainer.translatesAutoresizingMaskIntoConstraints = false
        outerShadowContainer.backgroundColor = .clear
        outerShadowContainer.layer.shadowColor = SourcesCSSTheme.purple.cgColor
        outerShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 7)
        outerShadowContainer.layer.shadowRadius = 14
        outerShadowContainer.layer.shadowOpacity = 0.24

        borderContainer.translatesAutoresizingMaskIntoConstraints = false
        borderContainer.layer.cornerRadius = frameCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            borderContainer.layer.cornerCurve = .continuous
        }
        borderContainer.clipsToBounds = true

        let innerRadius = max(frameCornerRadius - borderThickness, 20.0)
        innerClipContainer.translatesAutoresizingMaskIntoConstraints = false
        innerClipContainer.backgroundColor = .black
        innerClipContainer.layer.cornerRadius = innerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            innerClipContainer.layer.cornerCurve = .continuous
        }
        innerClipContainer.clipsToBounds = true

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = SourcesCSSTheme.vibrantPink
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.startAnimating()

        innerClipContainer.addSubview(loadingIndicator)
        borderContainer.addSubview(innerClipContainer)
        outerShadowContainer.addSubview(borderContainer)

        cardContainer.addSubview(headerRow)
        cardContainer.addSubview(outerShadowContainer)
        addSubview(cardContainer)

        // Tỉ lệ khung dọc chuẩn 9:19.5 (height = width * 19.5 / 9.0)
        let aspectConstraint = borderContainer.heightAnchor.constraint(equalTo: borderContainer.widthAnchor, multiplier: 19.5 / 9.0)
        aspectConstraint.priority = .required

        NSLayoutConstraint.activate([
            cardContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardContainer.topAnchor.constraint(equalTo: topAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            headerRow.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            headerRow.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 14),
            headerRow.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),

            iconBox.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor, constant: 12),
            iconBox.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            iconBox.widthAnchor.constraint(equalToConstant: 36),
            iconBox.heightAnchor.constraint(equalToConstant: 36),

            iconImageView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            headerTextLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 10),
            headerTextLabel.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor, constant: -12),
            headerTextLabel.topAnchor.constraint(equalTo: headerRow.topAnchor, constant: 12),
            headerTextLabel.bottomAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: -12),

            outerShadowContainer.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 14),
            outerShadowContainer.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 18),
            outerShadowContainer.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -18),
            outerShadowContainer.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -16),

            borderContainer.leadingAnchor.constraint(equalTo: outerShadowContainer.leadingAnchor),
            borderContainer.trailingAnchor.constraint(equalTo: outerShadowContainer.trailingAnchor),
            borderContainer.topAnchor.constraint(equalTo: outerShadowContainer.topAnchor),
            borderContainer.bottomAnchor.constraint(equalTo: outerShadowContainer.bottomAnchor),
            aspectConstraint,

            innerClipContainer.leadingAnchor.constraint(equalTo: borderContainer.leadingAnchor, constant: borderThickness),
            innerClipContainer.trailingAnchor.constraint(equalTo: borderContainer.trailingAnchor, constant: -borderThickness),
            innerClipContainer.topAnchor.constraint(equalTo: borderContainer.topAnchor, constant: borderThickness),
            innerClipContainer.bottomAnchor.constraint(equalTo: borderContainer.bottomAnchor, constant: -borderThickness),

            loadingIndicator.centerXAnchor.constraint(equalTo: innerClipContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: innerClipContainer.centerYAnchor)
        ])
    }

    private func mountPlayerWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [.all]
        config.suppressesIncrementalRendering = false

        let playerWebView = WKWebView(frame: .zero, configuration: config)
        playerWebView.translatesAutoresizingMaskIntoConstraints = false
        playerWebView.navigationDelegate = self
        playerWebView.scrollView.isScrollEnabled = false
        playerWebView.scrollView.bounces = false
        playerWebView.isOpaque = false
        playerWebView.backgroundColor = .clear
        playerWebView.scrollView.backgroundColor = .clear
        playerWebView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        innerClipContainer.insertSubview(playerWebView, belowSubview: loadingIndicator)
        NSLayoutConstraint.activate([
            playerWebView.leadingAnchor.constraint(equalTo: innerClipContainer.leadingAnchor),
            playerWebView.trailingAnchor.constraint(equalTo: innerClipContainer.trailingAnchor),
            playerWebView.topAnchor.constraint(equalTo: innerClipContainer.topAnchor),
            playerWebView.bottomAnchor.constraint(equalTo: innerClipContainer.bottomAnchor)
        ])
        self.webView = playerWebView

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

        playerWebView.loadHTMLString(embedHTML, baseURL: URL(string: originDomain))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadingIndicator.stopAnimating()
    }

    func pauseVideoPlayback() {
        webView?.evaluateJavaScript(
            "var iframe = document.querySelector('iframe'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage('{\"event\":\"command\",\"func\":\"pauseVideo\",\"args\":\"\"}', '*'); }",
            completionHandler: nil
        )
        if #available(iOS 15.0, tvOS 15.0, *) {
            webView?.pauseAllMediaPlayback()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconGradient.frame = iconBox.bounds
    }
}

// MARK: - ⬇️ KHUNG NÚT "NHẤN VÀO ĐÂY ĐỂ TẢI VỀ" + KHU VỰC HƯỚNG DẪN LƯU VÀO TỆP RÕ NÉT
private final class GuideDownloadActionCardView: UIView {
    private let downloadURL: URL
    private weak var hostViewController: UIViewController?

    private let cardContainer = UIView()
    private let mainStack = UIStackView()

    // Hàng thông tin tệp phía trên nút
    private let infoRow = UIView()
    private let iconBox = UIView()
    private let iconGradient = CAGradientLayer()
    private let iconImageView = UIImageView()
    private let fileTitleLabel = UILabel()
    private let fileSubtitleLabel = UILabel()

    // Nút bấm chính "Nhấn vào đây để tải về"
    private let downloadButton = UIButton(type: .system)
    private let buttonGradient = CAGradientLayer()

    // Khu vực hiển thị rõ nét dòng chữ "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file"
    private let noticeBannerView = UIView()
    private let noticeIconView = UIImageView()
    private let noticeTextLabel = UILabel()
    private let progressActivity = UIActivityIndicatorView(style: .medium)

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

        // 1. Khối thông tin tệp đính kèm
        infoRow.translatesAutoresizingMaskIntoConstraints = false
        infoRow.backgroundColor = SourcesCSSTheme.light
        infoRow.layer.cornerRadius = SourcesCSSTheme.innerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            infoRow.layer.cornerCurve = .continuous
        }
        infoRow.layer.borderWidth = 1.0
        infoRow.layer.borderColor = SourcesCSSTheme.innerBorder.cgColor

        iconBox.translatesAutoresizingMaskIntoConstraints = false
        iconBox.layer.cornerRadius = 12
        if #available(iOS 13.0, tvOS 13.0, *) {
            iconBox.layer.cornerCurve = .continuous
        }
        iconBox.layer.masksToBounds = true

        iconGradient.colors = [SourcesCSSTheme.pinkGradientStart, SourcesCSSTheme.pinkGradientEnd]
        iconGradient.startPoint = CGPoint(x: 0, y: 0)
        iconGradient.endPoint = CGPoint(x: 1, y: 1)
        iconBox.layer.insertSublayer(iconGradient, at: 0)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        iconImageView.image = UIImage(systemName: "arrow.down.doc.fill", withConfiguration: iconCfg)
        iconImageView.tintColor = .white
        iconBox.addSubview(iconImageView)

        fileTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        fileTitleLabel.text = resolvedDisplayFileName()
        fileTitleLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
        fileTitleLabel.textColor = SourcesCSSTheme.pureBlack
        fileTitleLabel.numberOfLines = 1

        fileSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        fileSubtitleLabel.text = "Tệp đính kèm / Liên kết hỗ trợ sửa lỗi"
        fileSubtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        fileSubtitleLabel.textColor = SourcesCSSTheme.vibrantPink
        fileSubtitleLabel.numberOfLines = 1

        infoRow.addSubview(iconBox)
        infoRow.addSubview(fileTitleLabel)
        infoRow.addSubview(fileSubtitleLabel)

        NSLayoutConstraint.activate([
            iconBox.leadingAnchor.constraint(equalTo: infoRow.leadingAnchor, constant: 12),
            iconBox.centerYAnchor.constraint(equalTo: infoRow.centerYAnchor),
            iconBox.widthAnchor.constraint(equalToConstant: 44),
            iconBox.heightAnchor.constraint(equalToConstant: 44),

            iconImageView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            fileTitleLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 12),
            fileTitleLabel.trailingAnchor.constraint(equalTo: infoRow.trailingAnchor, constant: -12),
            fileTitleLabel.topAnchor.constraint(equalTo: infoRow.topAnchor, constant: 12),

            fileSubtitleLabel.leadingAnchor.constraint(equalTo: fileTitleLabel.leadingAnchor),
            fileSubtitleLabel.trailingAnchor.constraint(equalTo: fileTitleLabel.trailingAnchor),
            fileSubtitleLabel.topAnchor.constraint(equalTo: fileTitleLabel.bottomAnchor, constant: 3),
            fileSubtitleLabel.bottomAnchor.constraint(equalTo: infoRow.bottomAnchor, constant: -12)
        ])

        // 2. Nút "Nhấn vào đây để tải về" đồng bộ giao diện, đổ bóng đẹp
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        let btnIconCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .heavy)
        downloadButton.setImage(UIImage(systemName: "icloud.and.arrow.down.fill", withConfiguration: btnIconCfg), for: .normal)
        downloadButton.setTitle("  Nhấn vào đây để tải về", for: .normal)
        downloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .heavy)
        downloadButton.tintColor = .white
        downloadButton.setTitleColor(.white, for: .normal)
        downloadButton.layer.cornerRadius = 14
        if #available(iOS 13.0, tvOS 13.0, *) {
            downloadButton.layer.cornerCurve = .continuous
        }
        downloadButton.layer.masksToBounds = false
        downloadButton.layer.shadowColor = SourcesCSSTheme.vibrantPink.cgColor
        downloadButton.layer.shadowOffset = CGSize(width: 0, height: 5)
        downloadButton.layer.shadowRadius = 10
        downloadButton.layer.shadowOpacity = 0.32

        buttonGradient.colors = [
            SourcesCSSTheme.vibrantPink.cgColor,
            SourcesCSSTheme.purple.cgColor,
            SourcesCSSTheme.blue.cgColor
        ]
        buttonGradient.startPoint = CGPoint(x: 0, y: 0.5)
        buttonGradient.endPoint = CGPoint(x: 1, y: 0.5)
        buttonGradient.cornerRadius = 14
        downloadButton.layer.insertSublayer(buttonGradient, at: 0)

        downloadButton.addTarget(self, action: #selector(handleDownloadButtonTap), for: .touchUpInside)

        // 3. Khu vực thông báo dễ nhìn khi nhấn tải về: “Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file”
        noticeBannerView.translatesAutoresizingMaskIntoConstraints = false
        noticeBannerView.backgroundColor = SourcesCSSTheme.softPinkBg
        noticeBannerView.layer.cornerRadius = 14
        if #available(iOS 13.0, tvOS 13.0, *) {
            noticeBannerView.layer.cornerCurve = .continuous
        }
        noticeBannerView.layer.borderWidth = 1.5
        noticeBannerView.layer.borderColor = SourcesCSSTheme.vibrantPink.withAlphaComponent(0.55).cgColor
        noticeBannerView.isHidden = true

        noticeIconView.translatesAutoresizingMaskIntoConstraints = false
        let noticeIconCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        noticeIconView.image = UIImage(systemName: "folder.fill.badge.plus", withConfiguration: noticeIconCfg)
        noticeIconView.tintColor = SourcesCSSTheme.vibrantPink
        noticeIconView.contentMode = .scaleAspectFit

        noticeTextLabel.translatesAutoresizingMaskIntoConstraints = false
        noticeTextLabel.numberOfLines = 0
        noticeTextLabel.attributedText = makeNoticeAttributedText(
            mainText: "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file",
            subStatus: nil
        )

        progressActivity.translatesAutoresizingMaskIntoConstraints = false
        progressActivity.color = SourcesCSSTheme.vibrantPink
        progressActivity.hidesWhenStopped = true

        noticeBannerView.addSubview(noticeIconView)
        noticeBannerView.addSubview(noticeTextLabel)
        noticeBannerView.addSubview(progressActivity)

        NSLayoutConstraint.activate([
            downloadButton.heightAnchor.constraint(equalToConstant: 50),

            noticeIconView.leadingAnchor.constraint(equalTo: noticeBannerView.leadingAnchor, constant: 13),
            noticeIconView.centerYAnchor.constraint(equalTo: noticeBannerView.centerYAnchor),
            noticeIconView.widthAnchor.constraint(equalToConstant: 26),
            noticeIconView.heightAnchor.constraint(equalToConstant: 26),

            progressActivity.trailingAnchor.constraint(equalTo: noticeBannerView.trailingAnchor, constant: -13),
            progressActivity.centerYAnchor.constraint(equalTo: noticeBannerView.centerYAnchor),

            noticeTextLabel.leadingAnchor.constraint(equalTo: noticeIconView.trailingAnchor, constant: 10),
            noticeTextLabel.trailingAnchor.constraint(equalTo: progressActivity.leadingAnchor, constant: -8),
            noticeTextLabel.topAnchor.constraint(equalTo: noticeBannerView.topAnchor, constant: 13),
            noticeTextLabel.bottomAnchor.constraint(equalTo: noticeBannerView.bottomAnchor, constant: -13)
        ])

        mainStack.addArrangedSubview(infoRow)
        mainStack.addArrangedSubview(downloadButton)
        mainStack.addArrangedSubview(noticeBannerView)

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

    private func resolvedDisplayFileName() -> String {
        let lastComp = downloadURL.lastPathComponent.removingPercentEncoding ?? downloadURL.lastPathComponent
        if !lastComp.isEmpty && lastComp != "/" && lastComp.contains(".") {
            return "Tệp: \(lastComp)"
        }
        if let host = downloadURL.host {
            return "Liên kết tải về (\(host))"
        }
        return "Tệp tải về hỗ trợ sửa lỗi"
    }

    private func makeNoticeAttributedText(mainText: String, subStatus: String?) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3.5

        let result = NSMutableAttributedString(
            string: mainText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15.2, weight: .bold),
                .foregroundColor: SourcesCSSTheme.pureBlack,
                .paragraphStyle: paragraph
            ]
        )

        // Tô nổi bật cụm từ "Lưu Vào Tệp" để người dùng nhìn thấy ngay lập tức
        let nsMain = mainText as NSString
        let highlightRange = nsMain.range(of: "Lưu Vào Tệp", options: .caseInsensitive)
        if highlightRange.location != NSNotFound {
            result.addAttributes([
                .foregroundColor: SourcesCSSTheme.vibrantPink,
                .font: UIFont.systemFont(ofSize: 15.5, weight: .heavy)
            ], range: highlightRange)
        }

        if let sub = subStatus, !sub.isEmpty {
            let subAttr = NSAttributedString(
                string: "\n" + sub,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 13.0, weight: .semibold),
                    .foregroundColor: SourcesCSSTheme.blue,
                    .paragraphStyle: paragraph
                ]
            )
            result.append(subAttr)
        }

        return result
    }

    @objc private func handleDownloadButtonTap() {
        // Hiệu ứng nhún lò xo khi nhấn nút
        UIView.animate(withDuration: 0.12, animations: {
            self.downloadButton.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5) {
                self.downloadButton.transform = .identity
            }
        }

        // Hiện ngay lập tức khu vực chữ dễ nhìn: “Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file”
        if noticeBannerView.isHidden {
            noticeBannerView.alpha = 0
            noticeBannerView.isHidden = false
            UIView.animate(withDuration: 0.25) {
                self.noticeBannerView.alpha = 1
                self.setNeedsLayout()
                self.layoutIfNeeded()
                self.hostViewController?.view.setNeedsLayout()
                self.hostViewController?.view.layoutIfNeeded()
            }
        }

        let hostLower = (downloadURL.host ?? "").lowercased()
        let isCloudWebPortal = hostLower.contains("icloud.com")
            || hostLower.contains("drive.google.com")
            || hostLower.contains("mega.nz")
            || hostLower.contains("mediafire.com")
            || hostLower.contains("1drv.ms")
            || hostLower.contains("dropbox.com")

        if isCloudWebPortal && !downloadURL.pathExtension.lowercased().isOne(of: ["ipa", "zip", "mobileconfig", "plist", "deb", "tipa"]) {
            noticeTextLabel.attributedText = makeNoticeAttributedText(
                mainText: "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file",
                subStatus: "• Đang mở trang tải tệp..."
            )
            UIApplication.shared.open(downloadURL, options: [:], completionHandler: nil)
            return
        }

        guard !isDownloading else { return }
        isDownloading = true
        progressActivity.startAnimating()
        noticeTextLabel.attributedText = makeNoticeAttributedText(
            mainText: "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file",
            subStatus: "• Đang tải tệp về thiết bị, vui lòng chờ..."
        )

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            defer {
                self.isDownloading = false
                self.progressActivity.stopAnimating()
            }

            do {
                var request = URLRequest(url: self.downloadURL)
                request.timeoutInterval = 60
                request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

                let (tempLocalURL, response) = try await URLSession.shared.download(for: request)

                // Nếu đường dẫn trả về là một trang web HTML thông thường (không phải tệp đính kèm), mở bằng trình duyệt để người dùng tải
                if let httpResp = response as? HTTPURLResponse,
                   let mime = httpResp.mimeType?.lowercased(),
                   mime == "text/html",
                   httpResp.value(forHTTPHeaderField: "Content-Disposition") == nil,
                   self.downloadURL.pathExtension.isEmpty {
                    try? FileManager.default.removeItem(at: tempLocalURL)
                    self.noticeTextLabel.attributedText = self.makeNoticeAttributedText(
                        mainText: "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file",
                        subStatus: "• Đang chuyển hướng tới trang tải tệp..."
                    )
                    UIApplication.shared.open(self.downloadURL, options: [:], completionHandler: nil)
                    return
                }

                // Đặt lại tên file chuẩn để khi bấm "Lưu vào Tệp" có đúng tên và đuôi file
                let suggestedName = response.suggestedFilename
                    ?? (self.downloadURL.lastPathComponent.isEmpty ? "Tep_Tai_Ve.bin" : self.downloadURL.lastPathComponent)
                let safeFileName = suggestedName.replacingOccurrences(of: "/", with: "_")
                let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(safeFileName)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try? FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempLocalURL, to: destinationURL)

                self.noticeTextLabel.attributedText = self.makeNoticeAttributedText(
                    mainText: "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file",
                    subStatus: "✓ Đã tải xong! Hãy chọn \"Lưu vào Tệp\" trong bảng vừa hiện lên."
                )

                self.presentSaveToFilesSheet(for: destinationURL)
            } catch {
                // Nếu tải trực tiếp gặp lỗi CORS/Redirect phức tạp, tự động mở bằng Safari để đảm bảo luôn tải được
                self.noticeTextLabel.attributedText = self.makeNoticeAttributedText(
                    mainText: "Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file",
                    subStatus: "• Đang mở trình duyệt để tải tệp..."
                )
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

    override func layoutSubviews() {
        super.layoutSubviews()
        iconGradient.frame = iconBox.bounds
        buttonGradient.frame = downloadButton.bounds
    }
}

private extension String {
    func isOne(of list: [String]) -> Bool {
        return list.contains(self)
    }
}

// MARK: - 🔍 TRÌNH XEM ẢNH PHÓNG TO TOÀN MÀN HÌNH (PINCH TO ZOOM)
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
        closeButton.backgroundColor = SourcesCSSTheme.vibrantPink.withAlphaComponent(0.85)
        closeButton.layer.cornerRadius = 18
        closeButton.layer.borderWidth = 1.0
        closeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
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

// MARK: - 📖 TRANG CHI TIẾT BÀI HƯỚNG DẪN (ĐỒNG BỘ 100% VỚI NEWSVIEWCONTROLLER & SETTINGSVIEWCONTROLLER)
private final class GuideArticleDetailViewController: UIViewController {
    private let article: GuideArticle
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let heroCard = UIView()
    private let heroClipView = UIView()
    private let heroGradient = CAGradientLayer()
    private let sectionIconBox = UIView()
    private let sectionIconGradient = CAGradientLayer()
    private var floatingBackButton: UIButton!
    private var activeVideoViews: [GuideYouTubeVideoFrameView] = []

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
        setupFloatingBackButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for videoView in activeVideoViews {
            videoView.pauseVideoPlayback()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        heroGradient.frame = heroClipView.bounds
        sectionIconGradient.frame = sectionIconBox.bounds
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
        scrollView.contentInset = UIEdgeInsets(top: 46, left: 0, bottom: 50, right: 0)

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

    // Hero Banner của bài viết đồng bộ với CSSHeroBannerView
    private func setupHeroHeader() {
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroCard.layer.cornerCurve = .continuous
        }
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 7)
        heroCard.layer.shadowRadius = 14
        heroCard.layer.shadowOpacity = 0.26

        heroClipView.translatesAutoresizingMaskIntoConstraints = false
        heroClipView.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            heroClipView.layer.cornerCurve = .continuous
        }
        heroClipView.clipsToBounds = true
        heroClipView.layer.borderWidth = 1.2
        heroClipView.layer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor

        heroGradient.colors = [SourcesCSSTheme.heroStart, SourcesCSSTheme.heroEnd]
        heroGradient.startPoint = CGPoint(x: 0, y: 0)
        heroGradient.endPoint = CGPoint(x: 1, y: 1)
        heroClipView.layer.insertSublayer(heroGradient, at: 0)

        let decorCircle = UIView()
        decorCircle.translatesAutoresizingMaskIntoConstraints = false
        decorCircle.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        decorCircle.layer.cornerRadius = 60
        decorCircle.isUserInteractionEnabled = false
        heroClipView.addSubview(decorCircle)

        let badgePill = UILabel()
        badgePill.translatesAutoresizingMaskIntoConstraints = false
        badgePill.text = "  ✦ CHỦ ĐỀ #\(article.orderNumber)  "
        badgePill.font = UIFont.systemFont(ofSize: 11.5, weight: .heavy)
        badgePill.textColor = SourcesCSSTheme.vibrantPink
        badgePill.backgroundColor = SourcesCSSTheme.white
        badgePill.layer.cornerRadius = 10
        badgePill.layer.masksToBounds = true

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
        titleLabel.layer.shadowOpacity = 0.28

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Mọi cách khắc phục không đảm bảo thành công 100%, bạn cần kiên nhẫn và thực hiện lại nhiều lần."
        subLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        subLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.95)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 0

        heroClipView.addSubview(badgePill)
        heroClipView.addSubview(titleLabel)
        heroClipView.addSubview(subLabel)
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
            badgePill.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: badgePill.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: heroClipView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: -16),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: heroClipView.leadingAnchor, constant: 16),
            subLabel.trailingAnchor.constraint(equalTo: heroClipView.trailingAnchor, constant: -16),
            subLabel.bottomAnchor.constraint(equalTo: heroClipView.bottomAnchor, constant: -16)
        ])

        contentStackView.addArrangedSubview(heroCard)
    }

    private func setupSectionHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        sectionIconBox.translatesAutoresizingMaskIntoConstraints = false
        sectionIconBox.layer.cornerRadius = 7.5
        if #available(iOS 13.0, tvOS 13.0, *) {
            sectionIconBox.layer.cornerCurve = .continuous
        }
        sectionIconBox.layer.masksToBounds = true

        sectionIconGradient.colors = [SourcesCSSTheme.pinkGradientStart, SourcesCSSTheme.pinkGradientEnd]
        sectionIconGradient.startPoint = CGPoint(x: 0, y: 0)
        sectionIconGradient.endPoint = CGPoint(x: 1, y: 1)
        sectionIconBox.layer.insertSublayer(sectionIconGradient, at: 0)

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .heavy)
        iconView.image = UIImage(systemName: "wrench.and.screwdriver.fill", withConfiguration: iconConfig)
        iconView.tintColor = SourcesCSSTheme.white
        sectionIconBox.addSubview(iconView)

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

        headerContainer.addSubview(sectionIconBox)
        headerContainer.addSubview(primaryLabel)
        headerContainer.addSubview(underline)

        NSLayoutConstraint.activate([
            sectionIconBox.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 4),
            sectionIconBox.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            sectionIconBox.widthAnchor.constraint(equalToConstant: 25),
            sectionIconBox.heightAnchor.constraint(equalToConstant: 25),

            iconView.centerXAnchor.constraint(equalTo: sectionIconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: sectionIconBox.centerYAnchor),

            primaryLabel.leadingAnchor.constraint(equalTo: sectionIconBox.trailingAnchor, constant: 8),
            primaryLabel.centerYAnchor.constraint(equalTo: sectionIconBox.centerYAnchor),

            underline.leadingAnchor.constraint(equalTo: sectionIconBox.leadingAnchor),
            underline.topAnchor.constraint(equalTo: sectionIconBox.bottomAnchor, constant: 5),
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

        for block in article.blocks {
            switch block.type {
            case .text(let textContent):
                let card = makeTextCardView(for: textContent)
                contentStackView.addArrangedSubview(card)

            case .image(let imageURL):
                let imageViewCard = GuideStyledImageView(url: imageURL)
                imageViewCard.onTapImage = { [weak self] tappedImage in
                    let previewVC = GuideImagePreviewController(image: tappedImage)
                    self?.present(previewVC, animated: true)
                }
                contentStackView.addArrangedSubview(imageViewCard)

            case .youtube(let videoID):
                let youtubeCard = GuideYouTubeVideoFrameView(videoID: videoID)
                activeVideoViews.append(youtubeCard)
                contentStackView.addArrangedSubview(youtubeCard)

            case .download(let downloadURL):
                let downloadCard = GuideDownloadActionCardView(url: downloadURL, hostViewController: self)
                contentStackView.addArrangedSubview(downloadCard)
            }
        }
    }

    /// Tạo khối Card trắng chứa các dòng hướng dẫn, thay toàn bộ số đầu dòng bằng dấu chấm đầu dòng
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

        for itemText in bulletItems {
            let bulletRow = makeBulletRow(stepText: itemText)
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

    private func makeBulletRow(stepText: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = SourcesCSSTheme.light
        row.layer.cornerRadius = SourcesCSSTheme.innerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            row.layer.cornerCurve = .continuous
        }
        row.layer.borderWidth = 1.0
        row.layer.borderColor = SourcesCSSTheme.innerBorder.cgColor

        // Dấu chấm đầu dòng màu Hồng Phấn nổi bật
        let bulletDot = UILabel()
        bulletDot.translatesAutoresizingMaskIntoConstraints = false
        bulletDot.text = "•"
        bulletDot.font = UIFont.systemFont(ofSize: 22, weight: .black)
        bulletDot.textColor = SourcesCSSTheme.vibrantPink
        bulletDot.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.attributedText = styleHighlightedInstructionText(stepText)

        row.addSubview(bulletDot)
        row.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            bulletDot.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 10),
            bulletDot.topAnchor.constraint(equalTo: row.topAnchor, constant: 9),
            bulletDot.widthAnchor.constraint(equalToConstant: 18),

            bodyLabel.leadingAnchor.constraint(equalTo: bulletDot.trailingAnchor, constant: 6),
            bodyLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
            bodyLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 12),
            bodyLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -12)
        ])

        return row
    }

    /// Tự động làm nổi bật mũi tên `→` và giữ chữ đen tuyền `#000000` sắc nét
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
                    .foregroundColor: SourcesCSSTheme.vibrantPink,
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

    // Nút Quay lại cố định góc trên bên trái giống hệt SettingsViewController & NewsViewController
    private func setupFloatingBackButton() {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        btn.setTitle(" Quay lại", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        btn.tintColor = SourcesCSSTheme.vibrantPink
        btn.setTitleColor(SourcesCSSTheme.vibrantPink, for: .normal)
        btn.backgroundColor = SourcesCSSTheme.white.withAlphaComponent(0.95)
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 14)

        btn.layer.cornerRadius = 17
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = SourcesCSSTheme.softPinkBorder.cgColor
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 6
        btn.layer.shadowOpacity = 0.14

        btn.addTarget(self, action: #selector(handleBackButtonTap), for: .touchUpInside)
        view.addSubview(btn)

        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            btn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            btn.heightAnchor.constraint(equalToConstant: 34)
        ])

        self.floatingBackButton = btn
    }

    @objc private func handleBackButtonTap() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - 🚀 CONTROLLER CHÍNH: SOURCESVIEWCONTROLLER (TRUNG TÂM TIN TỨC & SỬA LỖI)
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
    private let heroHeaderView = GuidesHeroHeaderView(frame: CGRect(x: 0, y: 0, width: 375, height: 158))
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

    override init(collectionViewLayout layout: UICollectionViewLayout) {
        super.init(collectionViewLayout: layout)
        configurePinkTabBarIcon()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configurePinkTabBarIcon()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        configurePinkTabBarIcon()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Đổi icon TabBar của Tin Tức & Sửa Lỗi sang màu hồng phấn nổi bật
        configurePinkTabBarIcon()

        // Khoá giao diện Sáng (Light Mode) để chữ đen tuyền luôn hiển thị rõ nét nhất trên nền thẻ trắng
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
        configurePinkTabBarIcon()
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

// MARK: - 🎨 THIẾT LẬP GIAO DIỆN, ICON HỒNG PHẤN & TẢI DỮ LIỆU GITHUB
private extension SourcesViewController {
    /// Tạo và áp dụng Icon màu Hồng Phấn nổi bật cho cả trạng thái bình thường và khi đang chọn trên TabBar
    func configurePinkTabBarIcon() {
        #if !os(tvOS)
        let normalSymbolCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let selectedSymbolCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)

        let baseNormal = UIImage(systemName: "newspaper.fill", withConfiguration: normalSymbolCfg)
            ?? UIImage(systemName: "book.fill", withConfiguration: normalSymbolCfg)
        let baseSelected = UIImage(systemName: "newspaper.fill", withConfiguration: selectedSymbolCfg)
            ?? UIImage(systemName: "book.fill", withConfiguration: selectedSymbolCfg)

        if let normalImg = baseNormal?.withTintColor(SourcesCSSTheme.pastelPink, renderingMode: .alwaysOriginal),
           let selectedImg = baseSelected?.withTintColor(SourcesCSSTheme.vibrantPink, renderingMode: .alwaysOriginal) {
            self.tabBarItem.image = normalImg
            self.tabBarItem.selectedImage = selectedImg
            self.navigationController?.tabBarItem.image = normalImg
            self.navigationController?.tabBarItem.selectedImage = selectedImg
        }
        #endif
    }

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
        refreshControl.tintColor = SourcesCSSTheme.vibrantPink
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
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 58))
        footer.backgroundColor = .clear

        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.text = "Dữ liệu hướng dẫn được đồng bộ trực tiếp từ hệ thống máy chủ\nKéo xuống để cập nhật các hướng dẫn mới nhất"
        infoLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        infoLabel.textColor = SourcesCSSTheme.pureBlack
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
        stateActivityIndicator.color = SourcesCSSTheme.vibrantPink
        stateActivityIndicator.hidesWhenStopped = true

        stateTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stateTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        stateTitleLabel.textColor = SourcesCSSTheme.vibrantPink
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
        stateRetryButton.backgroundColor = SourcesCSSTheme.vibrantPink
        stateRetryButton.layer.cornerRadius = 18
        stateRetryButton.layer.shadowColor = SourcesCSSTheme.vibrantPink.cgColor
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
        cell.configure(with: article, isTopPriority: indexPath.row == 0)
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
