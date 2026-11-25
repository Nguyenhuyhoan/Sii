//
//  BrowseViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import Combine
import CoreData
import UniformTypeIdentifiers
@preconcurrency import Nuke

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME CHO TAB "KHO IPA & KÝ CÀI"
private struct IPAHubCSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                 // #000000
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)   // #f5f8ff
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)  // #dce2ec
    static let innerBorder = UIColor(red: 222/255, green: 229/255, blue: 240/255, alpha: 1.0)
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)      // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)   // #6f42c1
    static let indigo = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1.0)    // #5856d6
    static let teal = UIColor(red: 23/255, green: 162/255, blue: 184/255, alpha: 1.0)     // #17a2b8
    static let orange = UIColor(red: 253/255, green: 126/255, blue: 20/255, alpha: 1.0)   // #fd7e14
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)     // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)       // #dc3545
    static let magenta = UIColor(red: 232/255, green: 30/255, blue: 99/255, alpha: 1.0)   // #e91e63

    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.95).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.92).cgColor

    static let cornerRadius: CGFloat = 18.0
}

private final class IPAHubGradientBackgroundView: UIView {
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
        gradientLayer.colors = [IPAHubCSSTheme.bgGradientStart, IPAHubCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - 📦 MÔ HÌNH FILE IPA ĐÃ LƯU
private struct LocalIPAFileItem {
    let fileURL: URL
    let fileName: String
    let fileSizeBytes: Int64
    let modificationDate: Date
    let isFromLinkedDownloadsFolder: Bool

    var formattedSize: String {
        let mb = Double(fileSizeBytes) / (1024.0 * 1024.0)
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024.0)
        }
        return String(format: "%.1f MB", max(mb, 0.1))
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: modificationDate)
    }
}

// MARK: - 📥 TRÌNH QUẢN LÝ TẢI FILE IPA CÓ TIẾN TRÌNH %
private final class IPADownloadTaskDelegate: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((Double, Int64, Int64) -> Void)?
    var onCompletion: ((Result<URL, Error>) -> Void)?

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        let fraction: Double
        if totalBytesExpectedToWrite > 0 {
            fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            fraction = 0.0
        }
        DispatchQueue.main.async {
            self.onProgress?(fraction, totalBytesWritten, totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Di chuyển ngay file tạm sang thư mục tạm an toàn trước khi URLSession xóa location
        let tempCopyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Completed_\(UUID().uuidString).ipa")
        do {
            if FileManager.default.fileExists(atPath: tempCopyURL.path) {
                try FileManager.default.removeItem(at: tempCopyURL)
            }
            try FileManager.default.moveItem(at: location, to: tempCopyURL)
            DispatchQueue.main.async {
                self.onCompletion?(.success(tempCopyURL))
            }
        } catch {
            DispatchQueue.main.async {
                self.onCompletion?(.failure(error))
            }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onCompletion?(.failure(error))
            }
        }
    }
}

// ============================================================================
// MARK: - 🚀 BROWSEVIEWCONTROLLER: TAB "KHO IPA (TẢI VỀ & KÝ CÀI TRỰC TIẾP)"
// ============================================================================

class BrowseViewController: UICollectionViewController
{
    // Giữ nguyên các thuộc tính & hàm khởi tạo gốc để tương thích 100% với Storyboard / FeaturedViewController / SourceDetailViewController
    let source: Source?

    var category: StoreCategory?

    var searchPredicate: NSPredicate?

    @IBOutlet private var sourcesBarButtonItem: UIBarButtonItem!

    // MARK: - Thuộc tính Giao diện Kho IPA
    private let backgroundView = IPAHubGradientBackgroundView(frame: .zero)
    private let mainScrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let heroCard = UIView()
    private let heroGradientLayer = CAGradientLayer()
    private let heroCountBadgeLabel = UILabel()

    // Khối 1: Tải IPA trực tiếp từ Link URL hoặc từ Nguồn
    private let urlTextField = UITextField()
    private let fileNameTextField = UITextField()
    private let downloadButton = UIButton(type: .system)
    private let downloadButtonGradient = CAGradientLayer()
    private let downloadProgressBox = UIView()
    private let downloadProgressView = UIProgressView(progressViewStyle: .default)
    private let downloadProgressLabel = UILabel()
    private let cancelDownloadButton = UIButton(type: .system)

    // Khối 2: Liên kết Thư mục Tải về (Downloads) của iOS
    private let folderLinkStatusLabel = UILabel()

    // Khối 3: Danh sách các file IPA sẵn sàng Ký & Cài
    private let ipaListHeaderCountLabel = UILabel()
    private let ipaCardsStack = UIStackView()

    // Trạng thái tải & ký cài
    private var activeDownloadSession: URLSession?
    private var activeDownloadTask: URLSessionDownloadTask?
    private var isDownloadingIPA = false
    private var ipaItems: [LocalIPAFileItem] = []
    private var installingProgressByPath: [String: Progress] = [:]
    private var progressObservations: [String: NSKeyValueObservation] = [:]

    private enum PickerMode {
        case importIPAFile
        case linkIOSDownloadsFolder
        case exportIPAToIOSDownloads
    }
    private var currentPickerMode: PickerMode = .importIPAFile
    private static let linkedDownloadsBookmarkKey = "SideStore_LinkedIOSDownloadsFolderBookmark"

    // MARK: - Khởi tạo tương thích hoàn toàn với Project gốc

    init()
    {
        self.source = nil
        self.category = nil
        let layout = UICollectionViewFlowLayout()
        super.init(collectionViewLayout: layout)
    }

    init?(source: Source?, coder: NSCoder)
    {
        self.source = source
        self.category = nil
        super.init(coder: coder)
    }

    init?(category: StoreCategory?, coder: NSCoder)
    {
        self.source = nil
        self.category = category
        super.init(coder: coder)
    }

    required init?(coder: NSCoder)
    {
        self.source = nil
        self.category = nil
        super.init(coder: coder)
    }

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

    // MARK: - Vòng đời ViewController

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .light
        self.navigationController?.setNavigationBarHidden(true, animated: false)

        // Tắt hiển thị collectionView gốc để phủ giao diện Kho IPA CSS Theme toàn màn hình
        self.collectionView.backgroundColor = .clear
        self.collectionView.isScrollEnabled = false

        ensureIPADownloadsDirectoryExists()
        setupIPAHubUI()
        reloadIPAFileList()
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.overrideUserInterfaceStyle = .light
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        reloadIPAFileList()
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        heroGradientLayer.frame = heroCard.bounds
        downloadButtonGradient.frame = downloadButton.bounds
    }

    // MARK: - 📁 Quản lý Thư mục Lưu trữ IPA

    /// Thư mục kho IPA nội bộ của ứng dụng (hiển thị trong ứng dụng Tệp -> Trên iPhone -> SideStore -> IPA_Downloads)
    private var internalIPADownloadsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("IPA_Downloads", isDirectory: true)
    }

    private func ensureIPADownloadsDirectoryExists() {
        let dir = internalIPADownloadsDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Đọc URL thư mục "Tải về" (Downloads) của iOS đã được người dùng cấp quyền bookmark
    private func resolveLinkedIOSDownloadsFolder() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: Self.linkedDownloadsBookmarkKey) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale {
            _ = url.startAccessingSecurityScopedResource()
            if let refreshedData = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(refreshedData, forKey: Self.linkedDownloadsBookmarkKey)
            }
            url.stopAccessingSecurityScopedResource()
        }
        return url
    }

    // MARK: - 🎨 Xây dựng Giao diện Kho IPA Chuẩn CSS Theme

    private func loadAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let lastIcon = files.last,
           let image = UIImage(named: lastIcon) {
            return image
        }
        return UIImage(named: "AppIcon60x60") ?? UIImage(named: "AppIcon")
    }

    private func setupIPAHubUI()
    {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        mainScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.alwaysBounceVertical = true
        mainScrollView.showsVerticalScrollIndicator = false
        mainScrollView.backgroundColor = .clear
        mainScrollView.keyboardDismissMode = .interactive
        mainScrollView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 36, right: 0)
        view.addSubview(mainScrollView)

        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = IPAHubCSSTheme.blue
        refreshControl.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        mainScrollView.refreshControl = refreshControl

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        mainScrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            mainScrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: mainScrollView.topAnchor, constant: 4),
            contentStack.leadingAnchor.constraint(equalTo: mainScrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: mainScrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: mainScrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: mainScrollView.widthAnchor, constant: -32)
        ])

        // 1. Hero Banner
        setupHeroBanner()

        // 2. Section 1: Tải IPA trực tiếp từ Link hoặc từ Nguồn
        contentStack.addArrangedSubview(makeSectionHeader(
            title: "TẢI FILE .IPA TRỰC TIẾP VỀ MÁY",
            icon: "cloud.bolt.fill",
            accentColor: IPAHubCSSTheme.blue
        ))
        setupDirectDownloadCard()

        // 3. Section 2: Thư mục Tải về (Downloads) của iOS
        contentStack.addArrangedSubview(makeSectionHeader(
            title: "THƯ MỤC TẢI VỀ (DOWNLOADS) CỦA IOS",
            icon: "folder.fill.badge.gearshape",
            accentColor: IPAHubCSSTheme.purple
        ))
        setupIOSDownloadsBridgeCard()

        // 4. Section 3: Danh sách File IPA sẵn sàng Ký & Cài
        contentStack.addArrangedSubview(makeSectionHeader(
            title: "KHO FILE .IPA SẴN SÀNG KÝ & CÀI ĐẶT",
            icon: "shippingbox.and.arrow.backward.fill",
            accentColor: IPAHubCSSTheme.teal
        ))

        ipaCardsStack.axis = .vertical
        ipaCardsStack.spacing = 10
        ipaCardsStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(ipaCardsStack)
    }

    private func setupHeroBanner()
    {
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = IPAHubCSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = IPAHubCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 7)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.28

        heroGradientLayer.colors = [IPAHubCSSTheme.heroStart, IPAHubCSSTheme.heroEnd]
        heroGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        heroGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        heroGradientLayer.cornerRadius = IPAHubCSSTheme.cornerRadius
        heroGradientLayer.borderWidth = 1.2
        heroGradientLayer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
        heroCard.layer.insertSublayer(heroGradientLayer, at: 0)

        let iconBadge = UIView()
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.backgroundColor = UIColor.white.withAlphaComponent(0.20)
        iconBadge.layer.cornerRadius = 11
        iconBadge.layer.borderWidth = 1.0
        iconBadge.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor

        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        if let appIcon = loadAppIcon() {
            iconImageView.image = appIcon
            iconImageView.layer.cornerRadius = 8
            iconImageView.clipsToBounds = true
        } else {
            let symConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            iconImageView.image = UIImage(systemName: "arrow.down.doc.fill", withConfiguration: symConfig)
            iconImageView.tintColor = .white
        }
        iconBadge.addSubview(iconImageView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Kho IPA & Ký Cài"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = IPAHubCSSTheme.white
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.28

        let verifiedIcon = UIImageView()
        verifiedIcon.translatesAutoresizingMaskIntoConstraints = false
        let verifiedConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        verifiedIcon.image = UIImage(systemName: "checkmark.seal.fill", withConfiguration: verifiedConfig)
        verifiedIcon.tintColor = UIColor(red: 140/255, green: 255/255, blue: 195/255, alpha: 1.0)

        let titleStack = UIStackView(arrangedSubviews: [iconBadge, titleLabel, verifiedIcon])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 9

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "✨ Tải ứng dụng .IPA về thư mục Tải về của iOS & Ký cài đặt trực tiếp tại chỗ"
        subLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        subLabel.textColor = IPAHubCSSTheme.white.withAlphaComponent(0.96)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2

        let pillView = UIView()
        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.backgroundColor = UIColor.white.withAlphaComponent(0.20)
        pillView.layer.cornerRadius = 12
        pillView.layer.borderWidth = 1.0
        pillView.layer.borderColor = UIColor.white.withAlphaComponent(0.38).cgColor

        heroCountBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        heroCountBadgeLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        heroCountBadgeLabel.textColor = IPAHubCSSTheme.white
        heroCountBadgeLabel.textAlignment = .center
        heroCountBadgeLabel.text = "📦 Đang kiểm tra kho file .IPA..."
        pillView.addSubview(heroCountBadgeLabel)

        heroCard.addSubview(titleStack)
        heroCard.addSubview(subLabel)
        heroCard.addSubview(pillView)

        NSLayoutConstraint.activate([
            iconBadge.widthAnchor.constraint(equalToConstant: 34),
            iconBadge.heightAnchor.constraint(equalToConstant: 34),

            iconImageView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 26),
            iconImageView.heightAnchor.constraint(equalToConstant: 26),

            titleStack.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleStack.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 14),

            subLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),

            pillView.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 9),
            pillView.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            pillView.leadingAnchor.constraint(greaterThanOrEqualTo: heroCard.leadingAnchor, constant: 12),
            pillView.trailingAnchor.constraint(lessThanOrEqualTo: heroCard.trailingAnchor, constant: -12),
            pillView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -12),
            pillView.heightAnchor.constraint(equalToConstant: 24),

            heroCountBadgeLabel.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 10),
            heroCountBadgeLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -10),
            heroCountBadgeLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor)
        ])

        contentStack.addArrangedSubview(heroCard)
    }

    private func setupDirectDownloadCard()
    {
        let card = makeWhiteCardContainer()

        // Ô nhập Link URL .ipa
        let urlInputBox = UIView()
        urlInputBox.translatesAutoresizingMaskIntoConstraints = false
        urlInputBox.backgroundColor = IPAHubCSSTheme.light
        urlInputBox.layer.cornerRadius = 12
        urlInputBox.layer.borderWidth = 1.0
        urlInputBox.layer.borderColor = IPAHubCSSTheme.innerBorder.cgColor

        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.placeholder = "Dán link tải trực tiếp file .ipa (https://...)"
        urlTextField.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        urlTextField.textColor = IPAHubCSSTheme.pureBlack
        urlTextField.clearButtonMode = .whileEditing
        urlTextField.keyboardType = .URL
        urlTextField.autocapitalizationType = .none
        urlTextField.autocorrectionType = .no
        urlTextField.returnKeyType = .done
        urlTextField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)
        urlInputBox.addSubview(urlTextField)

        // Ô đặt tên file tùy chọn + Nút Dán nhanh & Nút Chọn từ Nguồn
        let nameInputBox = UIView()
        nameInputBox.translatesAutoresizingMaskIntoConstraints = false
        nameInputBox.backgroundColor = IPAHubCSSTheme.light
        nameInputBox.layer.cornerRadius = 12
        nameInputBox.layer.borderWidth = 1.0
        nameInputBox.layer.borderColor = IPAHubCSSTheme.innerBorder.cgColor

        fileNameTextField.translatesAutoresizingMaskIntoConstraints = false
        fileNameTextField.placeholder = "Tên file lưu (Tùy chọn, VD: YouTube_19.ipa)"
        fileNameTextField.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        fileNameTextField.textColor = IPAHubCSSTheme.pureBlack
        fileNameTextField.clearButtonMode = .whileEditing
        fileNameTextField.autocorrectionType = .no
        fileNameTextField.returnKeyType = .done
        fileNameTextField.addTarget(self, action: #selector(dismissKeyboard), for: .editingDidEndOnExit)
        nameInputBox.addSubview(fileNameTextField)

        // Hàng nút phụ trợ: [📋 Dán Link] + [📚 Chọn App từ Nguồn đã thêm]
        let pasteBtn = makeActionPillButton(
            title: "📋 Dán Link",
            color: IPAHubCSSTheme.blue,
            action: #selector(handlePasteURLTapped)
        )
        let pickFromSourceBtn = makeActionPillButton(
            title: "📚 Chọn từ Nguồn App",
            color: IPAHubCSSTheme.purple,
            action: #selector(handlePickAppFromSourcesTapped)
        )

        let helperRow = UIStackView(arrangedSubviews: [pasteBtn, pickFromSourceBtn])
        helperRow.translatesAutoresizingMaskIntoConstraints = false
        helperRow.axis = .horizontal
        helperRow.distribution = .fillEqually
        helperRow.spacing = 8

        // Hộp hiển thị tiến trình đang tải (ẩn khi chưa tải)
        downloadProgressBox.translatesAutoresizingMaskIntoConstraints = false
        downloadProgressBox.backgroundColor = IPAHubCSSTheme.blue.withAlphaComponent(0.08)
        downloadProgressBox.layer.cornerRadius = 12
        downloadProgressBox.layer.borderWidth = 1.0
        downloadProgressBox.layer.borderColor = IPAHubCSSTheme.blue.withAlphaComponent(0.28).cgColor
        downloadProgressBox.isHidden = true

        downloadProgressView.translatesAutoresizingMaskIntoConstraints = false
        downloadProgressView.progressTintColor = IPAHubCSSTheme.blue
        downloadProgressView.trackTintColor = IPAHubCSSTheme.border
        downloadProgressView.layer.cornerRadius = 3
        downloadProgressView.clipsToBounds = true

        downloadProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        downloadProgressLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        downloadProgressLabel.textColor = IPAHubCSSTheme.blue
        downloadProgressLabel.text = "Đang chuẩn bị tải..."

        cancelDownloadButton.translatesAutoresizingMaskIntoConstraints = false
        cancelDownloadButton.setTitle("Hủy", for: .normal)
        cancelDownloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .heavy)
        cancelDownloadButton.setTitleColor(IPAHubCSSTheme.red, for: .normal)
        cancelDownloadButton.addTarget(self, action: #selector(handleCancelDownloadTapped), for: .touchUpInside)

        downloadProgressBox.addSubview(downloadProgressLabel)
        downloadProgressBox.addSubview(cancelDownloadButton)
        downloadProgressBox.addSubview(downloadProgressView)

        // Nút chính: TẢI VỀ KHO & LƯU FILE .IPA
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        downloadButton.setTitle("  ⬇️ TẢI VỀ KHO & LƯU FILE .IPA  ", for: .normal)
        downloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        downloadButton.setTitleColor(IPAHubCSSTheme.white, for: .normal)
        downloadButton.layer.cornerRadius = 13
        downloadButton.layer.masksToBounds = false
        downloadButton.layer.shadowColor = IPAHubCSSTheme.blue.cgColor
        downloadButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        downloadButton.layer.shadowRadius = 10
        downloadButton.layer.shadowOpacity = 0.28

        downloadButtonGradient.colors = [IPAHubCSSTheme.heroStart, IPAHubCSSTheme.heroEnd]
        downloadButtonGradient.startPoint = CGPoint(x: 0, y: 0.5)
        downloadButtonGradient.endPoint = CGPoint(x: 1, y: 0.5)
        downloadButtonGradient.cornerRadius = 13
        downloadButton.layer.insertSublayer(downloadButtonGradient, at: 0)
        downloadButton.addTarget(self, action: #selector(handleStartDownloadTapped), for: .touchUpInside)

        let innerStack = UIStackView(arrangedSubviews: [
            urlInputBox,
            nameInputBox,
            helperRow,
            downloadProgressBox,
            downloadButton
        ])
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.axis = .vertical
        innerStack.spacing = 10
        card.addSubview(innerStack)

        NSLayoutConstraint.activate([
            urlInputBox.heightAnchor.constraint(equalToConstant: 42),
            urlTextField.leadingAnchor.constraint(equalTo: urlInputBox.leadingAnchor, constant: 12),
            urlTextField.trailingAnchor.constraint(equalTo: urlInputBox.trailingAnchor, constant: -12),
            urlTextField.centerYAnchor.constraint(equalTo: urlInputBox.centerYAnchor),

            nameInputBox.heightAnchor.constraint(equalToConstant: 40),
            fileNameTextField.leadingAnchor.constraint(equalTo: nameInputBox.leadingAnchor, constant: 12),
            fileNameTextField.trailingAnchor.constraint(equalTo: nameInputBox.trailingAnchor, constant: -12),
            fileNameTextField.centerYAnchor.constraint(equalTo: nameInputBox.centerYAnchor),

            helperRow.heightAnchor.constraint(equalToConstant: 36),

            downloadProgressLabel.topAnchor.constraint(equalTo: downloadProgressBox.topAnchor, constant: 10),
            downloadProgressLabel.leadingAnchor.constraint(equalTo: downloadProgressBox.leadingAnchor, constant: 12),
            downloadProgressLabel.trailingAnchor.constraint(lessThanOrEqualTo: cancelDownloadButton.leadingAnchor, constant: -8),

            cancelDownloadButton.centerYAnchor.constraint(equalTo: downloadProgressLabel.centerYAnchor),
            cancelDownloadButton.trailingAnchor.constraint(equalTo: downloadProgressBox.trailingAnchor, constant: -12),

            downloadProgressView.topAnchor.constraint(equalTo: downloadProgressLabel.bottomAnchor, constant: 8),
            downloadProgressView.leadingAnchor.constraint(equalTo: downloadProgressBox.leadingAnchor, constant: 12),
            downloadProgressView.trailingAnchor.constraint(equalTo: downloadProgressBox.trailingAnchor, constant: -12),
            downloadProgressView.heightAnchor.constraint(equalToConstant: 6),
            downloadProgressView.bottomAnchor.constraint(equalTo: downloadProgressBox.bottomAnchor, constant: -10),

            downloadButton.heightAnchor.constraint(equalToConstant: 46),

            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        contentStack.addArrangedSubview(card)
    }

    private func setupIOSDownloadsBridgeCard()
    {
        let card = makeWhiteCardContainer()

        let statusBox = UIView()
        statusBox.translatesAutoresizingMaskIntoConstraints = false
        statusBox.backgroundColor = IPAHubCSSTheme.light
        statusBox.layer.cornerRadius = 12
        statusBox.layer.borderWidth = 1.0
        statusBox.layer.borderColor = IPAHubCSSTheme.innerBorder.cgColor

        folderLinkStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        folderLinkStatusLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        folderLinkStatusLabel.textColor = IPAHubCSSTheme.pureBlack
        folderLinkStatusLabel.numberOfLines = 0
        statusBox.addSubview(folderLinkStatusLabel)

        let importFileBtn = makeActionPillButton(
            title: "📂 Lấy .IPA từ Tải về iOS",
            color: IPAHubCSSTheme.blue,
            action: #selector(handleImportIPAFromFilesTapped)
        )
        let linkFolderBtn = makeActionPillButton(
            title: "🔗 Liên kết Thư mục Tải về",
            color: IPAHubCSSTheme.teal,
            action: #selector(handleLinkIOSDownloadsFolderTapped)
        )

        let btnRow = UIStackView(arrangedSubviews: [importFileBtn, linkFolderBtn])
        btnRow.translatesAutoresizingMaskIntoConstraints = false
        btnRow.axis = .horizontal
        btnRow.distribution = .fillEqually
        btnRow.spacing = 8

        let vStack = UIStackView(arrangedSubviews: [statusBox, btnRow])
        vStack.translatesAutoresizingMaskIntoConstraints = false
        vStack.axis = .vertical
        vStack.spacing = 10
        card.addSubview(vStack)

        NSLayoutConstraint.activate([
            folderLinkStatusLabel.topAnchor.constraint(equalTo: statusBox.topAnchor, constant: 10),
            folderLinkStatusLabel.leadingAnchor.constraint(equalTo: statusBox.leadingAnchor, constant: 12),
            folderLinkStatusLabel.trailingAnchor.constraint(equalTo: statusBox.trailingAnchor, constant: -12),
            folderLinkStatusLabel.bottomAnchor.constraint(equalTo: statusBox.bottomAnchor, constant: -10),

            btnRow.heightAnchor.constraint(equalToConstant: 38),

            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13)
        ])

        contentStack.addArrangedSubview(card)
    }

    // MARK: - 🧱 Các hàm tạo UI Component chuẩn CSS Theme

    private func makeWhiteCardContainer() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = IPAHubCSSTheme.white
        container.layer.cornerRadius = IPAHubCSSTheme.cornerRadius
        container.layer.borderWidth = 1.1
        container.layer.borderColor = IPAHubCSSTheme.border.cgColor
        container.layer.shadowColor = IPAHubCSSTheme.blue.cgColor
        container.layer.shadowOffset = CGSize(width: 0, height: 5)
        container.layer.shadowRadius = 11
        container.layer.shadowOpacity = 0.08
        return container
    }

    private func makeSectionHeader(title: String, icon: String, accentColor: UIColor) -> UIView {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.backgroundColor = .clear

        let iconBox = UIView()
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        iconBox.backgroundColor = accentColor.withAlphaComponent(0.14)
        iconBox.layer.cornerRadius = 6.5

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 11.5, weight: .heavy)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = accentColor
        iconBox.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .heavy)
        titleLabel.textColor = accentColor

        let underline = UIView()
        underline.translatesAutoresizingMaskIntoConstraints = false
        underline.backgroundColor = accentColor
        underline.layer.cornerRadius = 1.75

        wrapper.addSubview(iconBox)
        wrapper.addSubview(titleLabel)
        wrapper.addSubview(underline)

        NSLayoutConstraint.activate([
            iconBox.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            iconBox.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 2),
            iconBox.widthAnchor.constraint(equalToConstant: 22),
            iconBox.heightAnchor.constraint(equalToConstant: 22),

            iconView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -4),

            underline.leadingAnchor.constraint(equalTo: iconBox.leadingAnchor),
            underline.topAnchor.constraint(equalTo: iconBox.bottomAnchor, constant: 4),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3.5),
            underline.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -2)
        ])

        return wrapper
    }

    private func makeActionPillButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        btn.titleLabel?.adjustsFontSizeToFitWidth = true
        btn.titleLabel?.minimumScaleFactor = 0.8
        btn.setTitleColor(color, for: .normal)
        btn.backgroundColor = color.withAlphaComponent(0.11)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = color.withAlphaComponent(0.28).cgColor
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - 🔄 Quét & Hiển thị Danh sách File .IPA

    @objc private func handlePullToRefresh() {
        reloadIPAFileList()
        mainScrollView.refreshControl?.endRefreshing()
    }

    private func reloadIPAFileList()
    {
        ensureIPADownloadsDirectoryExists()
        var collected: [LocalIPAFileItem] = []
        var seenFileNames = Set<String>()

        // 1. Quét thư mục Kho IPA nội bộ (Documents/IPA_Downloads)
        let internalDir = internalIPADownloadsDirectory
        if let urls = try? FileManager.default.contentsOfDirectory(
            at: internalDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) {
            for url in urls where url.pathExtension.lowercased() == "ipa" {
                let res = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let size = Int64(res?.fileSize ?? 0)
                let date = res?.contentModificationDate ?? Date()
                collected.append(LocalIPAFileItem(
                    fileURL: url,
                    fileName: url.lastPathComponent,
                    fileSizeBytes: size,
                    modificationDate: date,
                    isFromLinkedDownloadsFolder: false
                ))
                seenFileNames.insert(url.lastPathComponent.lowercased())
            }
        }

        // 2. Quét thư mục Tải về (Downloads) của iOS nếu người dùng đã liên kết
        if let linkedFolder = resolveLinkedIOSDownloadsFolder() {
            let accessing = linkedFolder.startAccessingSecurityScopedResource()
            defer {
                if accessing { linkedFolder.stopAccessingSecurityScopedResource() }
            }
            if let urls = try? FileManager.default.contentsOfDirectory(
                at: linkedFolder,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) {
                for url in urls where url.pathExtension.lowercased() == "ipa" {
                    guard !seenFileNames.contains(url.lastPathComponent.lowercased()) else { continue }
                    let res = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let size = Int64(res?.fileSize ?? 0)
                    let date = res?.contentModificationDate ?? Date()
                    collected.append(LocalIPAFileItem(
                        fileURL: url,
                        fileName: url.lastPathComponent,
                        fileSizeBytes: size,
                        modificationDate: date,
                        isFromLinkedDownloadsFolder: true
                    ))
                }
            }
            folderLinkStatusLabel.text = "✅ Đã liên kết trực tiếp với thư mục [\(linkedFolder.lastPathComponent)] của iOS. Mọi file .IPA trong thư mục này sẽ tự động hiện ở bên dưới để Ký & Cài ngay!"
        } else {
            folderLinkStatusLabel.text = "💡 Mẹo: Bạn có thể bấm [Lấy .IPA từ Tải về iOS] để chọn lẻ từng file .ipa, hoặc bấm [Liên kết Thư mục Tải về] để quét toàn bộ file .IPA bạn đã tải bằng Safari."
        }

        // Sắp xếp file mới nhất lên đầu
        collected.sort { $0.modificationDate > $1.modificationDate }
        self.ipaItems = collected

        // Cập nhật số lượng trên Hero Banner
        let totalSizeMB = collected.reduce(0.0) { $0 + (Double($1.fileSizeBytes) / (1024.0 * 1024.0)) }
        heroCountBadgeLabel.text = String(format: "📦 Đang lưu trữ: %d file .IPA (Tổng %.1f MB)", collected.count, totalSizeMB)

        rebuildIPACardsList()
    }

    private func rebuildIPACardsList()
    {
        for subview in ipaCardsStack.arrangedSubviews {
            ipaCardsStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        if ipaItems.isEmpty {
            let emptyCard = makeWhiteCardContainer()
            let emptyLabel = UILabel()
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            emptyLabel.text = "📭 Chưa có file .IPA nào trong kho.\nHãy dán link tải ở trên hoặc bấm [📂 Lấy .IPA từ Tải về iOS] để đưa ứng dụng vào đây và Ký cài ngay!"
            emptyLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
            emptyLabel.textColor = IPAHubCSSTheme.pureBlack.withAlphaComponent(0.75)
            emptyLabel.textAlignment = .center
            emptyLabel.numberOfLines = 0
            emptyCard.addSubview(emptyLabel)

            NSLayoutConstraint.activate([
                emptyLabel.topAnchor.constraint(equalTo: emptyCard.topAnchor, constant: 22),
                emptyLabel.leadingAnchor.constraint(equalTo: emptyCard.leadingAnchor, constant: 16),
                emptyLabel.trailingAnchor.constraint(equalTo: emptyCard.trailingAnchor, constant: -16),
                emptyLabel.bottomAnchor.constraint(equalTo: emptyCard.bottomAnchor, constant: -22)
            ])
            ipaCardsStack.addArrangedSubview(emptyCard)
            return
        }

        for (index, item) in ipaItems.enumerated() {
            let card = makeIPAItemCard(item: item, index: index)
            ipaCardsStack.addArrangedSubview(card)
        }
    }

    private func makeIPAItemCard(item: LocalIPAFileItem, index: Int) -> UIView
    {
        let card = makeWhiteCardContainer()

        // Icon hộp IPA bên trái
        let badgeBox = UIView()
        badgeBox.translatesAutoresizingMaskIntoConstraints = false
        let accent = item.isFromLinkedDownloadsFolder ? IPAHubCSSTheme.purple : IPAHubCSSTheme.blue
        badgeBox.backgroundColor = accent.withAlphaComponent(0.14)
        badgeBox.layer.cornerRadius = 11
        badgeBox.layer.borderWidth = 1.0
        badgeBox.layer.borderColor = accent.withAlphaComponent(0.28).cgColor

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        iconView.image = UIImage(systemName: "app.gift.fill", withConfiguration: cfg)
        iconView.tintColor = accent
        badgeBox.addSubview(iconView)

        // Tên file IPA đen tuyền
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = item.fileName
        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        nameLabel.textColor = IPAHubCSSTheme.pureBlack
        nameLabel.numberOfLines = 2

        // Thông tin Dung lượng + Ngày tải + Nguồn
        let sourceTag = item.isFromLinkedDownloadsFolder ? "Thư mục Tải về iOS" : "Kho IPA SideStore"
        let metaLabel = UILabel()
        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.text = "💾 \(item.formattedSize)  •  🕒 \(item.formattedDate)  •  📁 \(sourceTag)"
        metaLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        metaLabel.textColor = IPAHubCSSTheme.pureBlack.withAlphaComponent(0.75)
        metaLabel.numberOfLines = 2

        // Thanh tiến trình Ký & Cài (nếu file này đang được ký cài)
        let installStatusBox = UIView()
        installStatusBox.translatesAutoresizingMaskIntoConstraints = false
        installStatusBox.backgroundColor = IPAHubCSSTheme.green.withAlphaComponent(0.10)
        installStatusBox.layer.cornerRadius = 10
        installStatusBox.layer.borderWidth = 1.0
        installStatusBox.layer.borderColor = IPAHubCSSTheme.green.withAlphaComponent(0.32).cgColor

        let installStatusLabel = UILabel()
        installStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        installStatusLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        installStatusLabel.textColor = IPAHubCSSTheme.green
        installStatusBox.addSubview(installStatusLabel)

        if let activeProgress = installingProgressByPath[item.fileURL.path] {
            installStatusBox.isHidden = false
            let pct = Int(activeProgress.fractionCompleted * 100)
            installStatusLabel.text = "⏳ Đang ký chứng chỉ & cài đặt trực tiếp... (\(pct)%)"
        } else {
            installStatusBox.isHidden = true
        }

        // Hàng 3 nút thao tác: [⚡ Ký & Cài Đặt] | [📤 Lưu ra Tải về iOS] | [🗑️ Xóa]
        let signInstallBtn = UIButton(type: .system)
        signInstallBtn.translatesAutoresizingMaskIntoConstraints = false
        let isInstalling = (installingProgressByPath[item.fileURL.path] != nil)
        signInstallBtn.setTitle(isInstalling ? "⏳ Đang Ký Cài..." : "⚡ Ký & Cài Đặt", for: .normal)
        signInstallBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        signInstallBtn.setTitleColor(IPAHubCSSTheme.white, for: .normal)
        signInstallBtn.backgroundColor = isInstalling ? IPAHubCSSTheme.orange : IPAHubCSSTheme.green
        signInstallBtn.layer.cornerRadius = 10
        signInstallBtn.tag = index
        signInstallBtn.isEnabled = !isInstalling
        signInstallBtn.addTarget(self, action: #selector(handleSignAndInstallIPATapped(_:)), for: .touchUpInside)

        let saveToFilesBtn = UIButton(type: .system)
        saveToFilesBtn.translatesAutoresizingMaskIntoConstraints = false
        saveToFilesBtn.setTitle("📤 Lưu vào Tệp", for: .normal)
        saveToFilesBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        saveToFilesBtn.setTitleColor(IPAHubCSSTheme.blue, for: .normal)
        saveToFilesBtn.backgroundColor = IPAHubCSSTheme.blue.withAlphaComponent(0.11)
        saveToFilesBtn.layer.cornerRadius = 10
        saveToFilesBtn.layer.borderWidth = 1.0
        saveToFilesBtn.layer.borderColor = IPAHubCSSTheme.blue.withAlphaComponent(0.28).cgColor
        saveToFilesBtn.tag = index
        saveToFilesBtn.addTarget(self, action: #selector(handleExportIPAToFilesTapped(_:)), for: .touchUpInside)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteBtn.setTitle("🗑️", for: .normal)
        deleteBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        deleteBtn.setTitleColor(IPAHubCSSTheme.red, for: .normal)
        deleteBtn.backgroundColor = IPAHubCSSTheme.red.withAlphaComponent(0.11)
        deleteBtn.layer.cornerRadius = 10
        deleteBtn.layer.borderWidth = 1.0
        deleteBtn.layer.borderColor = IPAHubCSSTheme.red.withAlphaComponent(0.28).cgColor
        deleteBtn.tag = index
        deleteBtn.addTarget(self, action: #selector(handleDeleteIPATapped(_:)), for: .touchUpInside)

        let actionRow = UIStackView(arrangedSubviews: [signInstallBtn, saveToFilesBtn, deleteBtn])
        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.axis = .horizontal
        actionRow.spacing = 8

        card.addSubview(badgeBox)
        card.addSubview(nameLabel)
        card.addSubview(metaLabel)
        card.addSubview(installStatusBox)
        card.addSubview(actionRow)

        NSLayoutConstraint.activate([
            badgeBox.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            badgeBox.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            badgeBox.widthAnchor.constraint(equalToConstant: 40),
            badgeBox.heightAnchor.constraint(equalToConstant: 40),

            iconView.centerXAnchor.constraint(equalTo: badgeBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: badgeBox.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: badgeBox.trailingAnchor, constant: 11),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),

            metaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),

            installStatusBox.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 8),
            installStatusBox.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            installStatusBox.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),

            installStatusLabel.topAnchor.constraint(equalTo: installStatusBox.topAnchor, constant: 7),
            installStatusLabel.leadingAnchor.constraint(equalTo: installStatusBox.leadingAnchor, constant: 10),
            installStatusLabel.trailingAnchor.constraint(equalTo: installStatusBox.trailingAnchor, constant: -10),
            installStatusLabel.bottomAnchor.constraint(equalTo: installStatusBox.bottomAnchor, constant: -7),

            actionRow.topAnchor.constraint(equalTo: installStatusBox.bottomAnchor, constant: 10),
            actionRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
            actionRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),
            actionRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
            actionRow.heightAnchor.constraint(equalToConstant: 38),

            deleteBtn.widthAnchor.constraint(equalToConstant: 42),
            saveToFilesBtn.widthAnchor.constraint(equalToConstant: 115)
        ])

        return card
    }

    // ========================================================================
    // MARK: - ⚡ TÍNH NĂNG 1: TẢI FILE .IPA TỪ LINK URL HOẶC TỪ NGUỒN APP
    // ========================================================================

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func handlePasteURLTapped() {
        if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !pasted.isEmpty {
            urlTextField.text = pasted
            if (fileNameTextField.text ?? "").isEmpty, let url = URL(string: pasted) {
                let last = url.lastPathComponent
                if last.lowercased().hasSuffix(".ipa") {
                    fileNameTextField.text = last
                }
            }
        }
    }

    /// Cho phép chọn nhanh một ứng dụng từ các Nguồn (Sources) đã thêm để lấy link tải file .IPA về lưu trữ
    @objc private func handlePickAppFromSourcesTapped()
    {
        let context = DatabaseManager.shared.viewContext
        var storeApps: [StoreApp] = []
        context.performAndWait {
            let request = StoreApp.fetchRequest() as NSFetchRequest<StoreApp>
            request.predicate = StoreApp.visibleAppsPredicate
            request.sortDescriptors = [NSSortDescriptor(keyPath: \StoreApp.name, ascending: true)]
            storeApps = (try? context.fetch(request)) ?? []
        }

        guard !storeApps.isEmpty else {
            showSimpleAlert(
                title: "Chưa có Ứng dụng trong Nguồn",
                message: "Hiện chưa có ứng dụng nào trong danh sách Nguồn. Bạn có thể dán trực tiếp link tải .IPA vào ô phía trên nhé!"
            )
            return
        }

        let sheet = UIAlertController(
            title: "📚 Chọn Ứng dụng từ Nguồn để tải file .IPA",
            message: "Chọn ứng dụng bên dưới để tự động điền Link tải .IPA gốc về lưu trong máy:",
            preferredStyle: .actionSheet
        )

        for app in storeApps.prefix(35) {
            guard let downloadURL = app.latestSupportedVersion?.downloadURL else { continue }
            let versionStr = app.latestSupportedVersion?.localizedVersion ?? ""
            let title = versionStr.isEmpty ? app.name : "\(app.name) (v\(versionStr))"
            sheet.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self else { return }
                self.urlTextField.text = downloadURL.absoluteString
                let sanitizedName = app.name.replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: " ", with: "_")
                self.fileNameTextField.text = versionStr.isEmpty ? "\(sanitizedName).ipa" : "\(sanitizedName)_v\(versionStr).ipa"
            })
        }

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    @objc private func handleStartDownloadTapped()
    {
        dismissKeyboard()
        guard !isDownloadingIPA else { return }

        guard let rawURL = urlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty,
              let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https") else {
            showSimpleAlert(
                title: "Link tải chưa hợp lệ",
                message: "Vui lòng dán một đường dẫn tải file .IPA hợp lệ (bắt đầu bằng https:// hoặc http://)."
            )
            return
        }

        var targetName = fileNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if targetName.isEmpty {
            let candidate = url.lastPathComponent
            if !candidate.isEmpty && candidate != "/" {
                targetName = candidate
            } else {
                targetName = "App_\(Int(Date().timeIntervalSince1970)).ipa"
            }
        }
        if !targetName.lowercased().hasSuffix(".ipa") {
            targetName += ".ipa"
        }

        startDownloadingIPA(from: url, preferredFileName: targetName)
    }

    private func startDownloadingIPA(from url: URL, preferredFileName: String)
    {
        isDownloadingIPA = true
        downloadButton.isEnabled = false
        downloadButton.alpha = 0.65
        downloadProgressBox.isHidden = false
        downloadProgressView.progress = 0.0
        downloadProgressLabel.text = "⏳ Đang kết nối máy chủ tải \(preferredFileName)..."

        let delegate = IPADownloadTaskDelegate()
        delegate.onProgress = { [weak self] (fraction, written, expected) in
            guard let self else { return }
            self.downloadProgressView.progress = Float(fraction)
            let writtenMB = Double(written) / (1024.0 * 1024.0)
            if expected > 0 {
                let totalMB = Double(expected) / (1024.0 * 1024.0)
                let pct = Int(fraction * 100)
                self.downloadProgressLabel.text = String(format: "⬇️ Đang tải: %d%% (%.1f MB / %.1f MB)", pct, writtenMB, totalMB)
            } else {
                self.downloadProgressLabel.text = String(format: "⬇️ Đang tải: %.1f MB...", writtenMB)
            }
        }

        delegate.onCompletion = { [weak self] result in
            guard let self else { return }
            self.isDownloadingIPA = false
            self.downloadButton.isEnabled = true
            self.downloadButton.alpha = 1.0
            self.downloadProgressBox.isHidden = true
            self.activeDownloadTask = nil
            self.activeDownloadSession?.finishTasksAndInvalidate()
            self.activeDownloadSession = nil

            switch result {
            case .failure(let error):
                if (error as NSError).code == NSURLErrorCancelled { return }
                self.showSimpleAlert(title: "Tải file .IPA thất bại", message: error.localizedDescription)

            case .success(let tempFileURL):
                self.finalizeDownloadedIPA(tempFileURL: tempFileURL, preferredFileName: preferredFileName)
            }
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        self.activeDownloadSession = session
        self.activeDownloadTask = task
        task.resume()
    }

    @objc private func handleCancelDownloadTapped() {
        activeDownloadTask?.cancel()
        activeDownloadSession?.invalidateAndCancel()
        activeDownloadTask = nil
        activeDownloadSession = nil
        isDownloadingIPA = false
        downloadButton.isEnabled = true
        downloadButton.alpha = 1.0
        downloadProgressBox.isHidden = true
    }

    private func finalizeDownloadedIPA(tempFileURL: URL, preferredFileName: String)
    {
        ensureIPADownloadsDirectoryExists()
        let sanitized = preferredFileName.replacingOccurrences(of: "/", with: "_")
        var destinationURL = internalIPADownloadsDirectory.appendingPathComponent(sanitized)

        // Nếu trùng tên file cũ thì thêm hậu tố thời gian để không làm mất bản cũ
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let base = (sanitized as NSString).deletingPathExtension
            destinationURL = internalIPADownloadsDirectory.appendingPathComponent("\(base)_\(Int(Date().timeIntervalSince1970)).ipa")
        }

        do {
            try FileManager.default.moveItem(at: tempFileURL, to: destinationURL)

            // Nếu người dùng đã liên kết thư mục Tải về (Downloads) của iOS, tự động chép 1 bản sang thư mục Tải về của iOS luôn!
            var copiedToIOSDownloads = false
            if let linkedFolder = resolveLinkedIOSDownloadsFolder() {
                let accessing = linkedFolder.startAccessingSecurityScopedResource()
                defer { if accessing { linkedFolder.stopAccessingSecurityScopedResource() } }
                let externalTarget = linkedFolder.appendingPathComponent(destinationURL.lastPathComponent)
                if !FileManager.default.fileExists(atPath: externalTarget.path) {
                    try? FileManager.default.copyItem(at: destinationURL, to: externalTarget)
                    copiedToIOSDownloads = true
                }
            }

            reloadIPAFileList()

            let alert = UIAlertController(
                title: "✅ Đã tải xong file .IPA!",
                message: copiedToIOSDownloads
                    ? "File [\(destinationURL.lastPathComponent)] đã được lưu vào Kho IPA và đồng bộ thẳng ra thư mục Tải về của iOS.\nBạn có muốn Ký & Cài đặt ngay bây giờ không?"
                    : "File [\(destinationURL.lastPathComponent)] đã được lưu vào Kho IPA.\nBạn có thể Ký & Cài đặt ngay hoặc Lưu ra thư mục Tải về của iOS:",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "⚡ Ký & Cài Đặt Ngay", style: .default) { [weak self] _ in
                self?.signAndInstallIPA(at: destinationURL)
            })

            if !copiedToIOSDownloads {
                alert.addAction(UIAlertAction(title: "📤 Lưu ra Thư mục Tải về iOS", style: .default) { [weak self] _ in
                    self?.exportIPAFileToIOSFiles(fileURL: destinationURL)
                })
            }

            alert.addAction(UIAlertAction(title: "Để sau", style: .cancel))
            present(alert, animated: true)

        } catch {
            showSimpleAlert(title: "Lỗi lưu file .IPA", message: error.localizedDescription)
        }
    }

    // ========================================================================
    // MARK: - 📂 TÍNH NĂNG 2: NHẬP & LIÊN KẾT THƯ MỤC TẢI VỀ (DOWNLOADS) CỦA IOS
    // ========================================================================

    @objc private func handleImportIPAFromFilesTapped()
    {
        currentPickerMode = .importIPAFile
        let types: [UTType] = [UTType.ipa, UTType(filenameExtension: "ipa") ?? .data]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    @objc private func handleLinkIOSDownloadsFolderTapped()
    {
        currentPickerMode = .linkIOSDownloadsFolder
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func exportIPAFileToIOSFiles(fileURL: URL)
    {
        currentPickerMode = .exportIPAToIOSDownloads
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    // ========================================================================
    // MARK: - ⚡ TÍNH NĂNG 3: KÝ CHỨNG CHỈ & CÀI ĐẶT TRỰC TIẾP NGAY TRONG TAB
    // ========================================================================

    @objc private func handleSignAndInstallIPATapped(_ sender: UIButton)
    {
        let idx = sender.tag
        guard idx >= 0 && idx < ipaItems.count else { return }
        let item = ipaItems[idx]
        signAndInstallIPA(at: item.fileURL)
    }

    private func signAndInstallIPA(at fileURL: URL)
    {
        // Nếu file nằm ở thư mục Tải về của iOS bên ngoài Sandbox, ta copy nhanh vào vùng đệm nội bộ trước khi đưa vào Pipeline ký
        var installTargetURL = fileURL
        var securityScopedFolder: URL? = nil

        if !fileURL.path.hasPrefix(internalIPADownloadsDirectory.path) {
            securityScopedFolder = resolveLinkedIOSDownloadsFolder()
            _ = securityScopedFolder?.startAccessingSecurityScopedResource()
            _ = fileURL.startAccessingSecurityScopedResource()

            ensureIPADownloadsDirectoryExists()
            let localCopy = internalIPADownloadsDirectory.appendingPathComponent(fileURL.lastPathComponent)
            if !FileManager.default.fileExists(atPath: localCopy.path) {
                try? FileManager.default.copyItem(at: fileURL, to: localCopy)
            }
            if FileManager.default.fileExists(atPath: localCopy.path) {
                installTargetURL = localCopy
            }

            fileURL.stopAccessingSecurityScopedResource()
            securityScopedFolder?.stopAccessingSecurityScopedResource()
        }

        let keyPath = fileURL.path
        guard installingProgressByPath[keyPath] == nil else { return }

        // Gọi trực tiếp AppManager.shared.install(.ipa(installTargetURL))
        // -> Kích hoạt đầy đủ Cài App Thông Minh (UserCustomizationOperation) + Tự động 4G + Ký chứng chỉ!
        let group = AppManager.shared.install(.ipa(installTargetURL), presentingViewController: self) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.installingProgressByPath.removeValue(forKey: keyPath)
                self.progressObservations.removeValue(forKey: keyPath)
                self.reloadIPAFileList()

                switch result {
                case .failure(let error) where error is CancellationError:
                    break
                case .failure(let error):
                    let toastView = ToastView(error: error, opensLog: true)
                    toastView.show(in: self)
                case .success(let installedApp):
                    let alert = UIAlertController(
                        title: "🎉 Ký & Cài Đặt Thành Công!",
                        message: "Ứng dụng [\(installedApp.name)] đã được ký chứng chỉ và cài đặt hoàn tất vào máy của bạn.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "Mở Ứng dụng ngay", style: .default) { _ in
                        UIApplication.shared.open(installedApp.openAppURL)
                    })
                    alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }

        installingProgressByPath[keyPath] = group.progress
        let observation = group.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.rebuildIPACardsList()
            }
        }
        progressObservations[keyPath] = observation
        rebuildIPACardsList()
    }

    @objc private func handleExportIPAToFilesTapped(_ sender: UIButton)
    {
        let idx = sender.tag
        guard idx >= 0 && idx < ipaItems.count else { return }
        let item = ipaItems[idx]
        exportIPAFileToIOSFiles(fileURL: item.fileURL)
    }

    @objc private func handleDeleteIPATapped(_ sender: UIButton)
    {
        let idx = sender.tag
        guard idx >= 0 && idx < ipaItems.count else { return }
        let item = ipaItems[idx]

        let alert = UIAlertController(
            title: "Xóa file .IPA?",
            message: "Bạn có chắc muốn xóa file [\(item.fileName)] (\(item.formattedSize)) khỏi kho lưu trữ không?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Xóa", style: .destructive) { [weak self] _ in
            guard let self else { return }
            if item.isFromLinkedDownloadsFolder, let folder = self.resolveLinkedIOSDownloadsFolder() {
                let acc = folder.startAccessingSecurityScopedResource()
                try? FileManager.default.removeItem(at: item.fileURL)
                if acc { folder.stopAccessingSecurityScopedResource() }
            } else {
                try? FileManager.default.removeItem(at: item.fileURL)
            }
            self.reloadIPAFileList()
        })
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    private func showSimpleAlert(title: String, message: String)
    {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đã hiểu", style: .default))
        present(alert, animated: true)
    }
}

// ============================================================================
// MARK: - 📂 XỬ LÝ UIDOCUMENTPICKER (NHẬP IPA & LIÊN KẾT THƯ MỤC TẢI VỀ IOS)
// ============================================================================

extension BrowseViewController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard !urls.isEmpty else { return }

        switch currentPickerMode {
        case .importIPAFile:
            ensureIPADownloadsDirectoryExists()
            var lastImportedURL: URL?
            for srcURL in urls {
                let destURL = internalIPADownloadsDirectory.appendingPathComponent(srcURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try? FileManager.default.removeItem(at: destURL)
                }
                do {
                    try FileManager.default.copyItem(at: srcURL, to: destURL)
                    lastImportedURL = destURL
                } catch {
                    debugLog("[IPAHub] Failed to import IPA: \(error)")
                }
            }
            reloadIPAFileList()

            if let imported = lastImportedURL, urls.count == 1 {
                let alert = UIAlertController(
                    title: "✅ Đã thêm vào Kho IPA",
                    message: "Đã nhập [\(imported.lastPathComponent)] vào kho. Bạn có muốn Ký & Cài đặt luôn không?",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "⚡ Ký & Cài Đặt Ngay", style: .default) { [weak self] _ in
                    self?.signAndInstallIPA(at: imported)
                })
                alert.addAction(UIAlertAction(title: "Để sau", style: .cancel))
                present(alert, animated: true)
            }

        case .linkIOSDownloadsFolder:
            guard let folderURL = urls.first else { return }
            let accessing = folderURL.startAccessingSecurityScopedResource()
            defer { if accessing { folderURL.stopAccessingSecurityScopedResource() } }

            if let bookmarkData = try? folderURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(bookmarkData, forKey: Self.linkedDownloadsBookmarkKey)
                reloadIPAFileList()
                showSimpleAlert(
                    title: "🔗 Đã liên kết Thư mục!",
                    message: "Đã kết nối với thư mục [\(folderURL.lastPathComponent)]. Từ giờ mọi file .IPA trong thư mục này sẽ hiện trực tiếp trong tab Kho IPA để bạn Ký & Cài đặt ngay!"
                )
            }

        case .exportIPAToIOSDownloads:
            showSimpleAlert(
                title: "✅ Đã lưu vào Tệp (iOS)",
                message: "File .IPA đã được xuất ra thư mục bạn chọn trong ứng dụng Tệp của iOS."
            )
        }
    }
}
