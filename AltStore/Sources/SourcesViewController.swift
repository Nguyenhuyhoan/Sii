
//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 3/17/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData
import Nuke

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI TAB CÀI ĐẶT)
private struct SourcesCSSTheme {
    static let white = UIColor.white
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0)      // #f8f9fa
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0)     // #e9ecef
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)         // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)      // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)        // #28a745
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0)      // #ff00ff
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0)          // #343a40

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.92) -> rgba(111,66,193,.88))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.92).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.88).cgColor

    static let cornerRadius: CGFloat = 15.0
    static let iPhoneImageCornerRadius: CGFloat = 24.0
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
                let lines = str.components(separatedBy: .newlines)
                count += lines.filter {
                    $0.trimmingCharacters(in: .whitespaces).range(of: #"^\d+\."#, options: .regularExpression) != nil
                }.count
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

    var previewSubtitle: String {
        for block in blocks {
            if case .text(let text) = block.type {
                let firstLine = text
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }
                if let line = firstLine {
                    return line
                }
            }
        }
        return "Nhấn để xem chi tiết hướng dẫn đầy đủ và hình ảnh minh họa..."
    }
}

private enum GuideParser {
    static let githubGuideURL = "https://github.com/Nguyenhuyhoan/Config/blob/main/huongdan.txt"

    /// Tự động chuyển đổi link GitHub `/blob/` hoặc `?raw=true` sang link `raw.githubusercontent.com`
    static func convertToRawGitHubURL(_ urlString: String) -> URL? {
        var cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if cleaned.contains("github.com") && cleaned.contains("/blob/") {
            cleaned = cleaned
                .replacingOccurrences(of: "https://github.com/", with: "https://raw.githubusercontent.com/")
                .replacingOccurrences(of: "http://github.com/", with: "https://raw.githubusercontent.com/")
                .replacingOccurrences(of: "/blob/", with: "/")
        }
        if cleaned.hasSuffix("?raw=true") {
            cleaned = String(cleaned.dropLast("?raw=true".count))
        }

        if let url = URL(string: cleaned) {
            return url
        } else if let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            return URL(string: encoded)
        }
        return nil
    }

    /// Kiểm tra một dòng có phải là link ảnh hợp lệ hay không
    private static func extractImageURL(from line: String) -> URL? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://"),
              !trimmed.contains(" ") else {
            return nil
        }

        let lower = trimmed.lowercased()
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".heic", ".bmp"]
        let isImageExt = imageExtensions.contains {
            lower.hasSuffix($0) || lower.contains("\($0)?") || lower.contains("\($0)#")
        }

        if isImageExt || (lower.contains("github") && lower.contains("/blob/")) {
            return convertToRawGitHubURL(trimmed)
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

    private static func parseContentBlocks(from lines: [String]) -> [GuideContentBlock] {
        var blocks: [GuideContentBlock] = []
        var currentTextBuffer: [String] = []

        func flushTextBuffer() {
            let joined = currentTextBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty {
                blocks.append(GuideContentBlock(type: .text(joined)))
            }
            currentTextBuffer.removeAll()
        }

        for line in lines {
            if let imageURL = extractImageURL(from: line) {
                flushTextBuffer()
                blocks.append(GuideContentBlock(type: .image(imageURL)))
            } else {
                currentTextBuffer.append(line)
            }
        }
        flushTextBuffer()

        return blocks
    }
}

// MARK: - 🏷️ HEADER ĐẦU TRANG CHUẨN TAB CÀI ĐẶT (HERO BANNER + SECTION HEADER GẠCH CHÂN XANH)
private final class GuidesHeroHeaderView: UIView {
    private let heroCard = UIView()
    private let heroGradient = CAGradientLayer()
    private let sectionTitleLabel = UILabel()
    private let underlineView = UIView()
    private let countBadgeButton = UIButton(type: .system)

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

        // 1. Khối Hero Card giống hệt SettingsViewController
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.25

        heroGradient.colors = [SourcesCSSTheme.heroStart, SourcesCSSTheme.heroEnd]
        heroGradient.startPoint = CGPoint(x: 0, y: 0)
        heroGradient.endPoint = CGPoint(x: 1, y: 1)
        heroGradient.cornerRadius = SourcesCSSTheme.cornerRadius
        heroCard.layer.insertSublayer(heroGradient, at: 0)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Hướng Dẫn & Sửa Lỗi"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = SourcesCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 1, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.35

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Cẩm nang khắc phục sự cố & tối ưu hóa trải nghiệm SideStore"
        subLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        subLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.95)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2

        heroCard.addSubview(titleLabel)
        heroCard.addSubview(subLabel)

        // 2. Tiêu đề Section + Gạch chân xanh giống hệt SettingsHeaderFooterView
        sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionTitleLabel.text = "DANH MỤC HƯỚNG DẪN"
        sectionTitleLabel.textColor = SourcesCSSTheme.blue
        sectionTitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)

        underlineView.translatesAutoresizingMaskIntoConstraints = false
        underlineView.backgroundColor = SourcesCSSTheme.blue
        underlineView.layer.cornerRadius = 1.5

        countBadgeButton.translatesAutoresizingMaskIntoConstraints = false
        countBadgeButton.setTitle("  Mới nhất ▲  ", for: .normal)
        countBadgeButton.setTitleColor(SourcesCSSTheme.white, for: .normal)
        countBadgeButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        countBadgeButton.backgroundColor = SourcesCSSTheme.purple
        countBadgeButton.layer.cornerRadius = 11
        countBadgeButton.layer.shadowColor = SourcesCSSTheme.purple.cgColor
        countBadgeButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        countBadgeButton.layer.shadowRadius = 4
        countBadgeButton.layer.shadowOpacity = 0.25
        countBadgeButton.isUserInteractionEnabled = false

        addSubview(heroCard)
        addSubview(sectionTitleLabel)
        addSubview(underlineView)
        addSubview(countBadgeButton)

        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            heroCard.heightAnchor.constraint(equalToConstant: 94),

            titleLabel.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),

            sectionTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            sectionTitleLabel.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 18),

            underlineView.leadingAnchor.constraint(equalTo: sectionTitleLabel.leadingAnchor),
            underlineView.topAnchor.constraint(equalTo: sectionTitleLabel.bottomAnchor, constant: 3),
            underlineView.widthAnchor.constraint(equalToConstant: 38),
            underlineView.heightAnchor.constraint(equalToConstant: 3),
            underlineView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            countBadgeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            countBadgeButton.centerYAnchor.constraint(equalTo: sectionTitleLabel.centerYAnchor),
            countBadgeButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    func updateCount(_ count: Int) {
        if count > 0 {
            countBadgeButton.setTitle("  \(count) bài viết  ", for: .normal)
            countBadgeButton.isHidden = false
        } else {
            countBadgeButton.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        heroGradient.frame = heroCard.bounds
    }
}

// MARK: - 🗂️ THANH TIÊU ĐỀ HƯỚNG DẪN (CARD CELL SANG TRỌNG NHƯ TAB CÀI ĐẶT)
private final class GuideTopicRowCell: UITableViewCell {
    static let reuseIdentifier = "GuideTopicRowCell"

    private let cardView = UIView()
    private let badgeContainer = UIView()
    private let badgeGradient = CAGradientLayer()
    private let badgeIconView = UIImageView()
    private let badgeNumberLabel = UILabel()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let metaStackView = UIStackView()
    private let stepsTagLabel = UILabel()
    private let imagesTagLabel = UILabel()
    private let priorityTagLabel = UILabel()
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

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Khối Card trắng chuẩn CSS
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = SourcesCSSTheme.white
        cardView.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, *) {
            cardView.layer.cornerCurve = .continuous
        }
        cardView.layer.borderWidth = 1.0
        cardView.layer.borderColor = SourcesCSSTheme.border.cgColor
        cardView.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 5)
        cardView.layer.shadowRadius = 12
        cardView.layer.shadowOpacity = 0.08

        // Badge bên trái (Huy hiệu Gradient Xanh - Tím)
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.layer.cornerRadius = 14
        if #available(iOS 13.0, *) {
            badgeContainer.layer.cornerCurve = .continuous
        }
        badgeContainer.layer.masksToBounds = true

        badgeGradient.colors = [SourcesCSSTheme.heroStart, SourcesCSSTheme.heroEnd]
        badgeGradient.startPoint = CGPoint(x: 0, y: 0)
        badgeGradient.endPoint = CGPoint(x: 1, y: 1)
        badgeContainer.layer.insertSublayer(badgeGradient, at: 0)

        badgeIconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        badgeIconView.image = UIImage(systemName: "sparkles", withConfiguration: iconConfig)
        badgeIconView.tintColor = SourcesCSSTheme.white.withAlphaComponent(0.95)
        badgeIconView.contentMode = .scaleAspectFit

        badgeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeNumberLabel.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        badgeNumberLabel.textColor = SourcesCSSTheme.white
        badgeNumberLabel.textAlignment = .center

        badgeContainer.addSubview(badgeIconView)
        badgeContainer.addSubview(badgeNumberLabel)

        // Tiêu đề chính
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 2

        // Phụ đề tóm tắt
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = SourcesCSSTheme.dark.withAlphaComponent(0.75)
        subtitleLabel.numberOfLines = 1

        // Thanh Tags thông tin (Số bước, số ảnh minh họa, nhãn ưu tiên)
        metaStackView.translatesAutoresizingMaskIntoConstraints = false
        metaStackView.axis = .horizontal
        metaStackView.spacing = 6
        metaStackView.alignment = .center

        styleTagLabel(priorityTagLabel, bgColor: SourcesCSSTheme.magenta.withAlphaComponent(0.12), textColor: SourcesCSSTheme.magenta)
        styleTagLabel(stepsTagLabel, bgColor: SourcesCSSTheme.blue.withAlphaComponent(0.10), textColor: SourcesCSSTheme.blue)
        styleTagLabel(imagesTagLabel, bgColor: SourcesCSSTheme.purple.withAlphaComponent(0.10), textColor: SourcesCSSTheme.purple)

        metaStackView.addArrangedSubview(priorityTagLabel)
        metaStackView.addArrangedSubview(stepsTagLabel)
        metaStackView.addArrangedSubview(imagesTagLabel)

        // Nút mũi tên phải
        chevronContainer.translatesAutoresizingMaskIntoConstraints = false
        chevronContainer.backgroundColor = SourcesCSSTheme.light
        chevronContainer.layer.cornerRadius = 14
        chevronContainer.layer.borderWidth = 1.0
        chevronContainer.layer.borderColor = SourcesCSSTheme.border.cgColor

        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        let chevConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        chevronImageView.image = UIImage(systemName: "chevron.right", withConfiguration: chevConfig)
        chevronImageView.tintColor = SourcesCSSTheme.blue
        chevronContainer.addSubview(chevronImageView)

        cardView.addSubview(badgeContainer)
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

            badgeContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            badgeContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            badgeContainer.widthAnchor.constraint(equalToConstant: 46),
            badgeContainer.heightAnchor.constraint(equalToConstant: 46),

            badgeIconView.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeIconView.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 7),
            badgeIconView.widthAnchor.constraint(equalToConstant: 16),
            badgeIconView.heightAnchor.constraint(equalToConstant: 16),

            badgeNumberLabel.topAnchor.constraint(equalTo: badgeIconView.bottomAnchor, constant: 2),
            badgeNumberLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 2),
            badgeNumberLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -2),

            chevronContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevronContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronContainer.widthAnchor.constraint(equalToConstant: 28),
            chevronContainer.heightAnchor.constraint(equalToConstant: 28),

            chevronImageView.centerXAnchor.constraint(equalTo: chevronContainer.centerXAnchor),
            chevronImageView.centerYAnchor.constraint(equalTo: chevronContainer.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(equalTo: chevronContainer.leadingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 13),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            metaStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 8),
            metaStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12)
        ])
    }

    private func styleTagLabel(_ label: UILabel, bgColor: UIColor, textColor: UIColor) {
        label.font = UIFont.systemFont(ofSize: 10.5, weight: .bold)
        label.textColor = textColor
        label.backgroundColor = bgColor
        label.layer.cornerRadius = 6
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
        stepsTagLabel.text = steps > 0 ? "  ✓ \(steps) bước  " : "  ✓ Chi tiết  "

        let imgs = article.imageCount
        if imgs > 0 {
            imagesTagLabel.text = "  🖼 \(imgs) ảnh  "
            imagesTagLabel.isHidden = false
        } else {
            imagesTagLabel.isHidden = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        badgeGradient.frame = badgeContainer.bounds
    }
}

// MARK: - 📱 KHUNG HIỂN THỊ ẢNH BO GÓC CHUẨN IPHONE + VIỀN SANG TRỌNG + CHẠM ĐỂ PHÓNG TO
private final class GuideStyledImageView: UIView {
    private let outerShadowContainer = UIView()
    private let borderContainer = UIView()
    private let imageView = UIImageView()
    private let shimmerActivity = UIActivityIndicatorView(style: .medium)
    private let errorLabel = UILabel()
    private let retryButton = UIButton(type: .system)
    private let zoomBadge = UIView()

    private var imageURL: URL?
    private var aspectRatioConstraint: NSLayoutConstraint?
    private var defaultHeightConstraint: NSLayoutConstraint!
    var onTapImage: ((UIImage) -> Void)?

    init(url: URL) {
        self.imageURL = url
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

        // Lớp đổ bóng 3D bên ngoài
        outerShadowContainer.translatesAutoresizingMaskIntoConstraints = false
        outerShadowContainer.backgroundColor = .clear
        outerShadowContainer.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        outerShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        outerShadowContainer.layer.shadowRadius = 18
        outerShadowContainer.layer.shadowOpacity = 0.20

        // Khung viền kép bo góc chuẩn iPhone (Continuous Squircle)
        borderContainer.translatesAutoresizingMaskIntoConstraints = false
        borderContainer.backgroundColor = SourcesCSSTheme.white
        borderContainer.layer.cornerRadius = SourcesCSSTheme.iPhoneImageCornerRadius
        if #available(iOS 13.0, *) {
            borderContainer.layer.cornerCurve = .continuous
        }
        borderContainer.layer.borderWidth = 2.5
        borderContainer.layer.borderColor = SourcesCSSTheme.blue.withAlphaComponent(0.28).cgColor
        borderContainer.clipsToBounds = true

        // ImageView bên trong bo góc đồng tâm với khung ngoài
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = SourcesCSSTheme.light
        imageView.layer.cornerRadius = SourcesCSSTheme.iPhoneImageCornerRadius - 4
        if #available(iOS 13.0, *) {
            imageView.layer.cornerCurve = .continuous
        }
        imageView.layer.borderWidth = 1.0
        imageView.layer.borderColor = SourcesCSSTheme.border.cgColor
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
        imageView.addGestureRecognizer(tapGesture)

        // Huy hiệu kính lúp nhỏ góc dưới bên phải ảnh
        zoomBadge.translatesAutoresizingMaskIntoConstraints = false
        zoomBadge.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        zoomBadge.layer.cornerRadius = 13
        zoomBadge.isHidden = true
        zoomBadge.isUserInteractionEnabled = false

        let zoomIcon = UIImageView(image: UIImage(systemName: "plus.magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)))
        zoomIcon.translatesAutoresizingMaskIntoConstraints = false
        zoomIcon.tintColor = .white
        zoomBadge.addSubview(zoomIcon)

        shimmerActivity.translatesAutoresizingMaskIntoConstraints = false
        shimmerActivity.color = SourcesCSSTheme.blue
        shimmerActivity.hidesWhenStopped = true

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.text = "Không thể tải hình ảnh minh họa"
        errorLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        errorLabel.textColor = SourcesCSSTheme.dark.withAlphaComponent(0.7)
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("  Thử tải lại ảnh  ", for: .normal)
        retryButton.setTitleColor(SourcesCSSTheme.white, for: .normal)
        retryButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        retryButton.backgroundColor = SourcesCSSTheme.blue
        retryButton.layer.cornerRadius = 12
        retryButton.isHidden = true
        retryButton.addTarget(self, action: #selector(loadImage), for: .touchUpInside)

        borderContainer.addSubview(imageView)
        borderContainer.addSubview(zoomBadge)
        borderContainer.addSubview(shimmerActivity)
        borderContainer.addSubview(errorLabel)
        borderContainer.addSubview(retryButton)
        outerShadowContainer.addSubview(borderContainer)
        addSubview(outerShadowContainer)

        defaultHeightConstraint = borderContainer.heightAnchor.constraint(equalToConstant: 230)
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
            defaultHeightConstraint,

            imageView.leadingAnchor.constraint(equalTo: borderContainer.leadingAnchor, constant: 5),
            imageView.trailingAnchor.constraint(equalTo: borderContainer.trailingAnchor, constant: -5),
            imageView.topAnchor.constraint(equalTo: borderContainer.topAnchor, constant: 5),
            imageView.bottomAnchor.constraint(equalTo: borderContainer.bottomAnchor, constant: -5),

            zoomBadge.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -10),
            zoomBadge.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -10),
            zoomBadge.widthAnchor.constraint(equalToConstant: 26),
            zoomBadge.heightAnchor.constraint(equalToConstant: 26),

            zoomIcon.centerXAnchor.constraint(equalTo: zoomBadge.centerXAnchor),
            zoomIcon.centerYAnchor.constraint(equalTo: zoomBadge.centerYAnchor),

            shimmerActivity.centerXAnchor.constraint(equalTo: borderContainer.centerXAnchor),
            shimmerActivity.centerYAnchor.constraint(equalTo: borderContainer.centerYAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: borderContainer.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: borderContainer.centerYAnchor, constant: -14),
            errorLabel.leadingAnchor.constraint(equalTo: borderContainer.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: borderContainer.trailingAnchor, constant: -16),

            retryButton.centerXAnchor.constraint(equalTo: borderContainer.centerXAnchor),
            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
            retryButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @objc private func loadImage() {
        guard let url = imageURL else { return }
        errorLabel.isHidden = true
        retryButton.isHidden = true
        shimmerActivity.startAnimating()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let loadedImage: UIImage
                if let nukeImage = try? await ImagePipeline.shared.image(for: url) {
                    loadedImage = nukeImage
                } else {
                    var req = URLRequest(url: url)
                    req.timeoutInterval = 20
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
        zoomBadge.isHidden = false

        imageView.alpha = 0
        imageView.image = image

        // Tự động khớp tỷ lệ chiều cao/chiều rộng chuẩn của bức ảnh
        if image.size.width > 0 && image.size.height > 0 {
            let ratio = image.size.height / image.size.width
            defaultHeightConstraint.isActive = false
            if let oldAspect = aspectRatioConstraint {
                oldAspect.isActive = false
            }
            let newAspect = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: ratio)
            newAspect.priority = .required
            newAspect.isActive = true
            aspectRatioConstraint = newAspect
        }

        UIView.animate(withDuration: 0.28) {
            self.imageView.alpha = 1
            self.superview?.layoutIfNeeded()
        }
    }

    @objc private func handleImageTap() {
        guard let img = imageView.image else { return }
        onTapImage?(img)
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

// MARK: - 📖 TRANG CHI TIẾT BÀI HƯỚNG DẪN (ĐỒNG BỘ 100% GIAO DIỆN TAB CÀI ĐẶT)
private final class GuideArticleDetailViewController: UIViewController {
    private let article: GuideArticle
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let heroCard = UIView()
    private let heroGradient = CAGradientLayer()
    private var floatingBackButton: UIButton!

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

    init(article: GuideArticle) {
        self.article = article
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        heroGradient.frame = heroCard.bounds
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

    // Hero Banner của bài viết giống hệt phong cách Tab Cài Đặt
    private func setupHeroHeader() {
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, *) {
            heroCard.layer.cornerCurve = .continuous
        }
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.25

        heroGradient.colors = [SourcesCSSTheme.heroStart, SourcesCSSTheme.heroEnd]
        heroGradient.startPoint = CGPoint(x: 0, y: 0)
        heroGradient.endPoint = CGPoint(x: 1, y: 1)
        heroGradient.cornerRadius = SourcesCSSTheme.cornerRadius
        heroCard.layer.insertSublayer(heroGradient, at: 0)

        let badgePill = UILabel()
        badgePill.translatesAutoresizingMaskIntoConstraints = false
        badgePill.text = "  CHỦ ĐỀ #\(article.orderNumber)  "
        badgePill.font = UIFont.systemFont(ofSize: 11, weight: .heavy)
        badgePill.textColor = SourcesCSSTheme.blue
        badgePill.backgroundColor = SourcesCSSTheme.white
        badgePill.layer.cornerRadius = 10
        badgePill.layer.masksToBounds = true

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = article.title
        titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .heavy)
        titleLabel.textColor = SourcesCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 1, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.35

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Thực hiện lần lượt theo các bước hướng dẫn và hình ảnh bên dưới"
        subLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        subLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.92)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2

        heroCard.addSubview(badgePill)
        heroCard.addSubview(titleLabel)
        heroCard.addSubview(subLabel)

        NSLayoutConstraint.activate([
            badgePill.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            badgePill.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 14),
            badgePill.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: badgePill.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -16),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 16),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -16),
            subLabel.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -16)
        ])

        contentStackView.addArrangedSubview(heroCard)
    }

    private func setupSectionHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        let primaryLabel = UILabel()
        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.text = "CHI TIẾT CÁC BƯỚC THỰC HIỆN"
        primaryLabel.textColor = SourcesCSSTheme.blue
        primaryLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)

        let underline = UIView()
        underline.translatesAutoresizingMaskIntoConstraints = false
        underline.backgroundColor = SourcesCSSTheme.blue
        underline.layer.cornerRadius = 1.5

        headerContainer.addSubview(primaryLabel)
        headerContainer.addSubview(underline)

        NSLayoutConstraint.activate([
            primaryLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 6),
            primaryLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),

            underline.leadingAnchor.constraint(equalTo: primaryLabel.leadingAnchor),
            underline.topAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: 2),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3),
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
            }
        }
    }

    /// Tạo khối Card trắng chứa các bước hướng dẫn, tự động nhận diện dòng đánh số `1.`, `2.` để gắn huy hiệu tròn đẹp mắt
    private func makeTextCardView(for rawText: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = SourcesCSSTheme.white
        card.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, *) {
            card.layer.cornerCurve = .continuous
        }
        card.layer.borderWidth = 1.0
        card.layer.borderColor = SourcesCSSTheme.border.cgColor
        card.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 5)
        card.layer.shadowRadius = 10
        card.layer.shadowOpacity = 0.07

        let innerStack = UIStackView()
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.axis = .vertical
        innerStack.spacing = 12

        // Gộp các dòng bị xuống hàng giữa chừng vào bước đánh số liền trước
        let rawLines = rawText.components(separatedBy: .newlines)
        var logicalParagraphs: [String] = []
        let stepRegex = try? NSRegularExpression(pattern: #"^\s*(\d+)\.\s*(.+)$"#)

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let nsRange = NSRange(location: 0, length: (trimmed as NSString).length)
            let isStepLine = stepRegex?.firstMatch(in: trimmed, options: [], range: nsRange) != nil

            if isStepLine || logicalParagraphs.isEmpty {
                logicalParagraphs.append(trimmed)
            } else {
                // Nếu dòng trước là 1 bước đánh số và dòng hiện tại là phần bị ngắt xuống dòng
                let last = logicalParagraphs.removeLast()
                logicalParagraphs.append(last + " " + trimmed)
            }
        }

        for (index, paragraph) in logicalParagraphs.enumerated() {
            let nsParagraph = paragraph as NSString
            let range = NSRange(location: 0, length: nsParagraph.length)

            if let match = stepRegex?.firstMatch(in: paragraph, options: [], range: range),
               match.numberOfRanges >= 3 {
                let stepNum = nsParagraph.substring(with: match.range(at: 1))
                let stepBody = nsParagraph.substring(with: match.range(at: 2))
                let stepRow = makeStepRow(stepNumber: stepNum, stepText: stepBody)
                innerStack.addArrangedSubview(stepRow)
            } else {
                let label = UILabel()
                label.numberOfLines = 0
                label.attributedText = styleHighlightedInstructionText(paragraph)
                innerStack.addArrangedSubview(label)
            }

            if index < logicalParagraphs.count - 1 {
                let separator = UIView()
                separator.translatesAutoresizingMaskIntoConstraints = false
                separator.backgroundColor = SourcesCSSTheme.border
                separator.heightAnchor.constraint(equalToConstant: 1.0).isActive = true
                innerStack.addArrangedSubview(separator)
            }
        }

        card.addSubview(innerStack)
        NSLayoutConstraint.activate([
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func makeStepRow(stepNumber: String, stepText: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let badge = UILabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = stepNumber
        badge.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        badge.textColor = SourcesCSSTheme.white
        badge.backgroundColor = SourcesCSSTheme.blue
        badge.textAlignment = .center
        badge.layer.cornerRadius = 13
        badge.layer.masksToBounds = true

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.attributedText = styleHighlightedInstructionText(stepText)

        row.addSubview(badge)
        row.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            badge.topAnchor.constraint(equalTo: row.topAnchor, constant: 1),
            badge.widthAnchor.constraint(equalToConstant: 26),
            badge.heightAnchor.constraint(equalToConstant: 26),

            bodyLabel.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 2),
            bodyLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -2)
        ])

        return row
    }

    /// Tự động làm nổi bật mũi tên `→` và các từ khóa quan trọng trong câu hướng dẫn
    private func styleHighlightedInstructionText(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15.5, weight: .medium),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
        )

        // Tô màu xanh nổi bật cho dấu mũi tên điều hướng "→"
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

    // Nút Quay lại cố định góc trên bên trái giống hệt SettingsViewController
    private func setupFloatingBackButton() {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        btn.setTitle(" Quay lại", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        btn.tintColor = SourcesCSSTheme.blue
        btn.setTitleColor(SourcesCSSTheme.blue, for: .normal)
        btn.backgroundColor = SourcesCSSTheme.white.withAlphaComponent(0.95)
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 14)

        btn.layer.cornerRadius = 17
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = SourcesCSSTheme.border.cgColor
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 6
        btn.layer.shadowOpacity = 0.15

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

// MARK: - 🚀 CONTROLLER CHÍNH: SOURCESVIEWCONTROLLER (TRUNG TÂM HƯỚNG DẪN)
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
    private let heroHeaderView = GuidesHeroHeaderView(frame: CGRect(x: 0, y: 0, width: 375, height: 152))
    private let refreshControl = UIRefreshControl()

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

        // 1. Ẩn hoàn toàn Navigation Bar trắng trên cùng giống hệt SettingsViewController
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

        // 3. Tải dữ liệu từ GitHub
        fetchGuidesFromGitHub(showLoadingCard: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let header = guidesTableView.tableHeaderView {
            let targetHeight: CGFloat = 152
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
        // Ẩn các thành phần mặc định của CollectionView gốc
        collectionView.dataSource = nil
        collectionView.prefetchDataSource = nil
        collectionView.backgroundColor = .clear

        // Phủ lớp nền Gradient cố định giống hệt SettingsViewController
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
        guidesTableView.estimatedRowHeight = 108
        guidesTableView.register(GuideTopicRowCell.self, forCellReuseIdentifier: GuideTopicRowCell.reuseIdentifier)

        // Gắn Hero Header
        guidesTableView.tableHeaderView = heroHeaderView

        // Kéo xuống để làm mới hướng dẫn
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
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 54))
        footer.backgroundColor = .clear

        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.text = "Dữ liệu hướng dẫn được đồng bộ trực tiếp từ hệ thống máy chủ\nKéo xuống để cập nhật các hướng dẫn mới nhất"
        infoLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        infoLabel.textColor = SourcesCSSTheme.purple.withAlphaComponent(0.8)
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
        stateCardView.backgroundColor = SourcesCSSTheme.white
        stateCardView.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, *) {
            stateCardView.layer.cornerCurve = .continuous
        }
        stateCardView.layer.borderWidth = 1.0
        stateCardView.layer.borderColor = SourcesCSSTheme.border.cgColor
        stateCardView.layer.shadowColor = SourcesCSSTheme.blue.cgColor
        stateCardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        stateCardView.layer.shadowRadius = 14
        stateCardView.layer.shadowOpacity = 0.12

        stateActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        stateActivityIndicator.color = SourcesCSSTheme.blue
        stateActivityIndicator.hidesWhenStopped = true

        stateTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stateTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        stateTitleLabel.textColor = SourcesCSSTheme.blue
        stateTitleLabel.textAlignment = .center
        stateTitleLabel.numberOfLines = 0

        stateSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        stateSubtitleLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        stateSubtitleLabel.textColor = SourcesCSSTheme.dark.withAlphaComponent(0.8)
        stateSubtitleLabel.textAlignment = .center
        stateSubtitleLabel.numberOfLines = 0

        stateRetryButton.translatesAutoresizingMaskIntoConstraints = false
        stateRetryButton.setTitle("  Tải Lại Hướng Dẫn  ", for: .normal)
        stateRetryButton.setTitleColor(SourcesCSSTheme.white, for: .normal)
        stateRetryButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        stateRetryButton.backgroundColor = SourcesCSSTheme.blue
        stateRetryButton.layer.cornerRadius = 16
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
        isLoadingGuides = true

        if showLoadingCard && articles.isEmpty {
            stateCardView.isHidden = false
            stateActivityIndicator.startAnimating()
            stateTitleLabel.text = "Đang tải danh sách hướng dẫn..."
            stateSubtitleLabel.text = "Vui lòng chờ trong giây lát khi hệ thống đồng bộ nội dung mới nhất."
            stateRetryButton.isHidden = true
        }

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
                self.showErrorState(message: "Đường dẫn cấu hình hướng dẫn không hợp lệ.")
                return
            }

            do {
                var request = URLRequest(url: rawURL)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 20

                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    throw URLError(.badServerResponse)
                }

                let rawText = String(decoding: data, as: UTF8.self)
                let parsedArticles = GuideParser.parse(rawText)

                self.articles = parsedArticles
                self.heroHeaderView.updateCount(parsedArticles.count)
                self.guidesTableView.reloadData()

                if parsedArticles.isEmpty {
                    self.showErrorState(message: "Hiện chưa có bài viết hướng dẫn nào trong tệp cấu hình.")
                } else {
                    self.stateCardView.isHidden = true
                    self.stateActivityIndicator.stopAnimating()
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
        // Giữ tương thích an toàn nếu người dùng mở DeepLink thêm nguồn từ trình duyệt
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

        // Hiệu ứng nhún lò xo giống hệt SettingsViewController khi chạm vào thanh tiêu đề
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(translationX: 5, y: -2).scaledBy(x: 0.98, y: 0.98)
            }) { _ in
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
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
