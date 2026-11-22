
//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 9/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import SafariServices

// MARK: - Models
struct FixGuideStep: Decodable {
    let type: String?
    let content: String?
    let url: String?
    let caption: String?
}

struct FixGuideItem: Decodable {
    let id: String?
    let title: String?
    let category: String?
    let summary: String?
    let steps: [FixGuideStep]?
}

struct FixGuidesResponse: Decodable {
    let guides: [FixGuideItem]?
    
    init(from decoder: Decoder) throws {
        if let singleContainer = try? decoder.singleValueContainer(),
           let array = try? singleContainer.decode([FixGuideItem].self) {
            self.guides = array
            return
        }
        let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
        self.guides = try keyedContainer.decodeIfPresent([FixGuideItem].self, forKey: .guides)
    }
    
    enum CodingKeys: String, CodingKey {
        case guides
    }
}

// MARK: - Custom Image Loader (Memory + Disk Cache)
final class GuideImageLoader {
    static let shared = GuideImageLoader()
    private let cache = NSCache<NSString, UIImage>()
    
    func loadImage(from urlString: String, into imageView: UIImageView, completion: ((UIImage?) -> Void)? = nil) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cached = cache.object(forKey: trimmed as NSString) {
            imageView.image = cached
            completion?(cached)
            return
        }
        
        guard let url = URL(string: trimmed) else {
            completion?(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion?(nil) }
                return
            }
            self?.cache.setObject(image, forKey: trimmed as NSString)
            DispatchQueue.main.async {
                imageView.image = image
                completion?(image)
            }
        }.resume()
    }
}

// MARK: - SourcesViewController (Tab "Sửa lỗi")
final class SourcesViewController: UICollectionViewController
{
    private let jsonURLString = "https://raw.githubusercontent.com/dabeecao/sualoi/refs/heads/main/fixes.json"
    private let pageGradientLayer = CAGradientLayer()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private var guides: [FixGuideItem] = []
    private let scrollView = UIScrollView()
    private let refreshControl = UIRefreshControl()
    private let cardsStackView = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Khóa cứng giao diện Sáng (Light Mode) để đồng bộ tuyệt đối với CSS
        self.overrideUserInterfaceStyle = .light
        self.impactFeedback.prepare()
        
        // Tắt CollectionView mặc định để dựng giao diện CSS chuẩn
        self.collectionView.dataSource = nil
        self.collectionView.delegate = nil
        self.collectionView.isScrollEnabled = false
        self.collectionView.backgroundColor = .clear
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        setupBackgroundGradient()
        setupMainLayout()
        fetchFixGuides()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        pageGradientLayer.frame = self.view.bounds
    }
    
    // MARK: - Background Gradient (#f3e0ff -> #e0f7ff)
    private func setupBackgroundGradient()
    {
        pageGradientLayer.colors = [
            UIColor(red: 0.953, green: 0.878, blue: 1.0, alpha: 1.0).cgColor, // #f3e0ff
            UIColor(red: 0.878, green: 0.969, blue: 1.0, alpha: 1.0).cgColor  // #e0f7ff
        ]
        pageGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        pageGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        pageGradientLayer.frame = self.view.bounds
        self.view.layer.insertSublayer(pageGradientLayer, at: 0)
    }
    
    // MARK: - Main UI Construction
    private func setupMainLayout()
    {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        refreshControl.tintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        refreshControl.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        scrollView.refreshControl = refreshControl
        self.view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let rootStack = UIStackView()
        rootStack.axis = .vertical
        rootStack.spacing = 18
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rootStack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            rootStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            rootStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            rootStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            rootStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        // 1. HERO HEADER BANNER (.header trong CSS + Ánh sáng 3D)
        rootStack.addArrangedSubview(makeHeroBanner())
        
        // 2. SECTION HEADER: TỔNG HỢP CÁC DANH MỤC
        rootStack.addArrangedSubview(makeSectionHeader(title: "TỔNG HỢP CÁC DANH MỤC"))
        
        // 3. LOADING & STATUS
        loadingIndicator.color = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        loadingIndicator.hidesWhenStopped = true
        rootStack.addArrangedSubview(loadingIndicator)
        
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = UIColor(red: 0.42, green: 0.46, blue: 0.49, alpha: 1.0)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        rootStack.addArrangedSubview(statusLabel)
        
        // 4. DANH SÁCH THẺ SỬA LỖI (.app-list / .app-card)
        cardsStackView.axis = .vertical
        cardsStackView.spacing = 12
        cardsStackView.translatesAutoresizingMaskIntoConstraints = false
        rootStack.addArrangedSubview(cardsStackView)
    }
    
    // MARK: - Hero Banner (#007bff -> #6f42c1 + Ambient 3D Orbs)
    private func makeHeroBanner() -> UIView
    {
        let banner = FixHeaderGradientView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.layer.cornerRadius = 18
        banner.layer.cornerCurve = .continuous
        banner.layer.shadowColor = UIColor(red: 0.0, green: 0.35, blue: 0.90, alpha: 1.0).cgColor
        banner.layer.shadowOpacity = 0.22
        banner.layer.shadowOffset = CGSize(width: 0, height: 8)
        banner.layer.shadowRadius = 18
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Tin Tức Và Sửa Lỗi"
        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Tổng hợp chia sẻ cách sửa lỗi khi sử dụng"
        subtitleLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        banner.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: banner.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -18)
        ])
        
        return banner
    }
    
    // MARK: - Section Title Header (.category-section h2::after)
    private func makeSectionHeader(title: String) -> UIView
    {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13.5, weight: .heavy)
        label.textColor = UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let underline = UIView()
        underline.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // #007bff
        underline.layer.cornerRadius = 1.5
        underline.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        container.addSubview(underline)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            underline.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
            underline.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3),
            underline.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Fetch JSON Data
    @objc private func handlePullToRefresh()
    {
        fetchFixGuides()
    }
    
    private func fetchFixGuides()
    {
        if guides.isEmpty {
            loadingIndicator.startAnimating()
        }
        statusLabel.isHidden = true
        
        guard let url = URL(string: jsonURLString) else {
            loadingIndicator.stopAnimating()
            refreshControl.endRefreshing()
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loadingIndicator.stopAnimating()
                self.refreshControl.endRefreshing()
                
                if let error = error {
                    if self.guides.isEmpty {
                        self.statusLabel.text = "Không thể tải dữ liệu sửa lỗi.\n(\(error.localizedDescription))\nKéo xuống để thử lại."
                        self.statusLabel.isHidden = false
                    }
                    return
                }
                
                guard let data = data else { return }
                do {
                    let decoded = try JSONDecoder().decode(FixGuidesResponse.self, from: data)
                    self.guides = decoded.guides ?? []
                    self.renderGuideCards()
                } catch {
                    if self.guides.isEmpty {
                        self.statusLabel.text = "Định dạng dữ liệu không hợp lệ.\nKéo xuống để thử lại."
                        self.statusLabel.isHidden = false
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Render Guide Cards (.app-card)
    private func renderGuideCards()
    {
        cardsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        guard !guides.isEmpty else {
            statusLabel.text = "Hiện chưa có bài viết hướng dẫn nào."
            statusLabel.isHidden = false
            return
        }
        
        statusLabel.isHidden = true
        
        for (index, item) in guides.enumerated() {
            let card = makeGuideCard(for: item, index: index)
            cardsStackView.addArrangedSubview(card)
        }
    }
    
    private func makeGuideCard(for item: FixGuideItem, index: Int) -> UIView
    {
        let cardControl = FixCardButtonControl()
        cardControl.tag = index
        cardControl.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        cardControl.layer.cornerRadius = 18
        cardControl.layer.cornerCurve = .continuous
        cardControl.layer.borderWidth = 1.0
        cardControl.layer.borderColor = UIColor.white.cgColor
        cardControl.layer.shadowColor = UIColor(red: 0.15, green: 0.10, blue: 0.38, alpha: 1.0).cgColor
        cardControl.layer.shadowOpacity = 0.065
        cardControl.layer.shadowOffset = CGSize(width: 0, height: 6)
        cardControl.layer.shadowRadius = 14
        cardControl.translatesAutoresizingMaskIntoConstraints = false
        cardControl.addTarget(self, action: #selector(handleCardTapped(_:)), for: .touchUpInside)
        
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 12
        hStack.isUserInteractionEnabled = false
        hStack.translatesAutoresizingMaskIntoConstraints = false
        cardControl.addSubview(hStack)
        
        // Thumbnail / Icon bên trái
        let thumbContainer = UIView()
        thumbContainer.backgroundColor = UIColor(red: 0.91, green: 0.95, blue: 1.0, alpha: 1.0)
        thumbContainer.layer.cornerRadius = 13
        thumbContainer.layer.cornerCurve = .continuous
        thumbContainer.clipsToBounds = true
        thumbContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            thumbContainer.widthAnchor.constraint(equalToConstant: 48),
            thumbContainer.heightAnchor.constraint(equalToConstant: 48)
        ])
        
        let thumbImageView = UIImageView()
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.tintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbContainer.addSubview(thumbImageView)
        
        if let firstImageStep = item.steps?.first(where: { ($0.type ?? "").lowercased() == "image" && ($0.url ?? "").isEmpty == false }),
           let imageURL = firstImageStep.url {
            NSLayoutConstraint.activate([
                thumbImageView.topAnchor.constraint(equalTo: thumbContainer.topAnchor),
                thumbImageView.leadingAnchor.constraint(equalTo: thumbContainer.leadingAnchor),
                thumbImageView.trailingAnchor.constraint(equalTo: thumbContainer.trailingAnchor),
                thumbImageView.bottomAnchor.constraint(equalTo: thumbContainer.bottomAnchor)
            ])
            thumbImageView.image = UIImage(systemName: "wrench.and.screwdriver.fill")
            GuideImageLoader.shared.loadImage(from: imageURL, into: thumbImageView)
        } else {
            thumbImageView.image = UIImage(systemName: "wrench.and.screwdriver.fill")
            thumbImageView.contentMode = .scaleAspectFit
            NSLayoutConstraint.activate([
                thumbImageView.centerXAnchor.constraint(equalTo: thumbContainer.centerXAnchor),
                thumbImageView.centerYAnchor.constraint(equalTo: thumbContainer.centerYAnchor),
                thumbImageView.widthAnchor.constraint(equalToConstant: 22),
                thumbImageView.heightAnchor.constraint(equalToConstant: 22)
            ])
        }
        
        // Khối thông tin: Category badge + Title + Summary
        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.alignment = .leading
        vStack.spacing = 4
        vStack.translatesAutoresizingMaskIntoConstraints = false
        
        if let category = item.category, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let badgeBox = UIView()
            badgeBox.backgroundColor = UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0)
            badgeBox.layer.cornerRadius = 6
            badgeBox.translatesAutoresizingMaskIntoConstraints = false
            
            let badgeLabel = UILabel()
            badgeLabel.text = category.uppercased()
            badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
            badgeLabel.textColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeBox.addSubview(badgeLabel)
            
            NSLayoutConstraint.activate([
                badgeLabel.topAnchor.constraint(equalTo: badgeBox.topAnchor, constant: 2.5),
                badgeLabel.bottomAnchor.constraint(equalTo: badgeBox.bottomAnchor, constant: -2.5),
                badgeLabel.leadingAnchor.constraint(equalTo: badgeBox.leadingAnchor, constant: 6),
                badgeLabel.trailingAnchor.constraint(equalTo: badgeBox.trailingAnchor, constant: -6)
            ])
            vStack.addArrangedSubview(badgeBox)
        }
        
        let titleLabel = UILabel()
        titleLabel.text = item.title ?? "Hướng dẫn sửa lỗi"
        titleLabel.font = .systemFont(ofSize: 15.5, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
        titleLabel.numberOfLines = 2
        vStack.addArrangedSubview(titleLabel)
        
        if let summary = item.summary, !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let summaryLabel = UILabel()
            summaryLabel.text = summary
            summaryLabel.font = .systemFont(ofSize: 12.5, weight: .regular)
            summaryLabel.textColor = UIColor(red: 0.42, green: 0.47, blue: 0.55, alpha: 1.0)
            summaryLabel.numberOfLines = 2
            vStack.addArrangedSubview(summaryLabel)
        }
        
        // Mũi tên chuyển trang (.arrow-icon trong CSS)
        let arrowIcon = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrowIcon.tintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // #007bff
        arrowIcon.contentMode = .scaleAspectFit
        arrowIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arrowIcon.widthAnchor.constraint(equalToConstant: 14),
            arrowIcon.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        hStack.addArrangedSubview(thumbContainer)
        hStack.addArrangedSubview(vStack)
        hStack.addArrangedSubview(arrowIcon)
        
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: cardControl.topAnchor, constant: 13),
            hStack.leadingAnchor.constraint(equalTo: cardControl.leadingAnchor, constant: 13),
            hStack.trailingAnchor.constraint(equalTo: cardControl.trailingAnchor, constant: -14),
            hStack.bottomAnchor.constraint(equalTo: cardControl.bottomAnchor, constant: -13)
        ])
        
        return cardControl
    }
    
    @objc private func handleCardTapped(_ sender: UIControl)
    {
        impactFeedback.impactOccurred()
        let index = sender.tag
        guard index >= 0 && index < guides.count else { return }
        let selectedGuide = guides[index]
        
        let detailVC = FixGuideDetailViewController(guide: selectedGuide)
        self.navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - FixGuideDetailViewController (Trang chi tiết bài viết .detail-page trong CSS)
final class FixGuideDetailViewController: UIViewController
{
    private let guide: FixGuideItem
    private let pageGradientLayer = CAGradientLayer()
    
    init(guide: FixGuideItem)
    {
        self.guide = guide
        super.init(nibName: nil, bundle: nil)
        self.overrideUserInterfaceStyle = .light
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        setupBackgroundGradient()
        setupDetailUI()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        pageGradientLayer.frame = self.view.bounds
    }
    
    private func setupBackgroundGradient()
    {
        pageGradientLayer.colors = [
            UIColor(red: 0.953, green: 0.878, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 0.878, green: 0.969, blue: 1.0, alpha: 1.0).cgColor
        ]
        pageGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        pageGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        pageGradientLayer.frame = self.view.bounds
        self.view.layer.insertSublayer(pageGradientLayer, at: 0)
    }
    
    private func setupDetailUI()
    {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        self.view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        // 1. HEADER CHI TIẾT CÓ NÚT BACK TRÒN (.header + .back-button trong CSS)
        mainStack.addArrangedSubview(makeDetailHeaderBanner())
        
        // 2. KHỐI NỘI DUNG TRẮNG (.detail-page trong CSS + Viền kính ngọc trai)
        let detailCard = UIView()
        detailCard.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        detailCard.layer.cornerRadius = 18
        detailCard.layer.cornerCurve = .continuous
        detailCard.layer.borderWidth = 1.0
        detailCard.layer.borderColor = UIColor.white.cgColor
        detailCard.layer.shadowColor = UIColor(red: 0.15, green: 0.10, blue: 0.38, alpha: 1.0).cgColor
        detailCard.layer.shadowOpacity = 0.065
        detailCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        detailCard.layer.shadowRadius = 14
        detailCard.translatesAutoresizingMaskIntoConstraints = false
        
        let stepsStack = UIStackView()
        stepsStack.axis = .vertical
        stepsStack.spacing = 14
        stepsStack.translatesAutoresizingMaskIntoConstraints = false
        detailCard.addSubview(stepsStack)
        
        NSLayoutConstraint.activate([
            stepsStack.topAnchor.constraint(equalTo: detailCard.topAnchor, constant: 18),
            stepsStack.leadingAnchor.constraint(equalTo: detailCard.leadingAnchor, constant: 16),
            stepsStack.trailingAnchor.constraint(equalTo: detailCard.trailingAnchor, constant: -16),
            stepsStack.bottomAnchor.constraint(equalTo: detailCard.bottomAnchor, constant: -20)
        ])
        
        // Tiêu đề phụ trong bài
        if let summary = guide.summary, !summary.isEmpty {
            let summaryBox = UIView()
            summaryBox.backgroundColor = UIColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)
            summaryBox.layer.cornerRadius = 11
            summaryBox.layer.borderWidth = 1
            summaryBox.layer.borderColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.18).cgColor
            summaryBox.translatesAutoresizingMaskIntoConstraints = false
            
            let sumLabel = UILabel()
            sumLabel.text = summary
            sumLabel.font = .systemFont(ofSize: 13.5, weight: .semibold)
            sumLabel.textColor = UIColor(red: 0.0, green: 0.36, blue: 0.75, alpha: 1.0)
            sumLabel.numberOfLines = 0
            sumLabel.translatesAutoresizingMaskIntoConstraints = false
            summaryBox.addSubview(sumLabel)
            
            NSLayoutConstraint.activate([
                sumLabel.topAnchor.constraint(equalTo: summaryBox.topAnchor, constant: 10),
                sumLabel.leadingAnchor.constraint(equalTo: summaryBox.leadingAnchor, constant: 12),
                sumLabel.trailingAnchor.constraint(equalTo: summaryBox.trailingAnchor, constant: -12),
                sumLabel.bottomAnchor.constraint(equalTo: summaryBox.bottomAnchor, constant: -10)
            ])
            stepsStack.addArrangedSubview(summaryBox)
        }
        
        // Render từng bước (text & image)
        for step in (guide.steps ?? []) {
            let stepType = (step.type ?? "text").lowercased()
            if stepType == "image", let imgURL = step.url, !imgURL.isEmpty {
                stepsStack.addArrangedSubview(makeImageStepView(url: imgURL, caption: step.caption))
            } else if let textContent = step.content, !textContent.isEmpty {
                stepsStack.addArrangedSubview(makeTextStepView(content: textContent))
            }
        }
        
        mainStack.addArrangedSubview(detailCard)
    }
    
    private func makeDetailHeaderBanner() -> UIView
    {
        let banner = FixHeaderGradientView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.layer.cornerRadius = 18
        banner.layer.cornerCurve = .continuous
        banner.layer.shadowColor = UIColor(red: 0.0, green: 0.35, blue: 0.90, alpha: 1.0).cgColor
        banner.layer.shadowOpacity = 0.22
        banner.layer.shadowOffset = CGSize(width: 0, height: 8)
        banner.layer.shadowRadius = 18
        
        // Nút Back tròn mờ (.back-button trong CSS)
        let backButton = UIButton(type: .system)
        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        backButton.layer.cornerRadius = 17
        backButton.layer.borderWidth = 0.5
        backButton.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        backButton.tintColor = .white
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(handleBackButton), for: .touchUpInside)
        
        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.alignment = .center
        vStack.spacing = 6
        vStack.translatesAutoresizingMaskIntoConstraints = false
        
        if let cat = guide.category, !cat.isEmpty {
            let catLabel = UILabel()
            catLabel.text = cat.uppercased()
            catLabel.font = .systemFont(ofSize: 10.5, weight: .bold)
            catLabel.textColor = UIColor.white.withAlphaComponent(0.9)
            vStack.addArrangedSubview(catLabel)
        }
        
        let titleLabel = UILabel()
        titleLabel.text = guide.title ?? "Chi tiết sửa lỗi"
        titleLabel.font = .systemFont(ofSize: 18.5, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        vStack.addArrangedSubview(titleLabel)
        
        banner.addSubview(vStack)
        banner.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: banner.topAnchor, constant: 14),
            backButton.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 14),
            backButton.widthAnchor.constraint(equalToConstant: 34),
            backButton.heightAnchor.constraint(equalToConstant: 34),
            
            vStack.topAnchor.constraint(equalTo: banner.topAnchor, constant: 16),
            vStack.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            vStack.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -42),
            vStack.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -16),
            banner.heightAnchor.constraint(greaterThanOrEqualToConstant: 66)
        ])
        
        return banner
    }
    
    private func makeTextStepView(content: String) -> UIView
    {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = [.link]
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        
        let attrString = NSMutableAttributedString(
            string: content,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: UIColor(red: 0.13, green: 0.15, blue: 0.20, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
        )
        textView.attributedText = attrString
        textView.linkTextAttributes = [
            .foregroundColor: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return textView
    }
    
    private func makeImageStepView(url: String, caption: String?) -> UIView
    {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6
        container.alignment = .fill
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let imageWrapper = UIView()
        imageWrapper.backgroundColor = UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
        imageWrapper.layer.cornerRadius = 12
        imageWrapper.layer.borderWidth = 1
        imageWrapper.layer.borderColor = UIColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1.0).cgColor
        imageWrapper.clipsToBounds = true
        imageWrapper.translatesAutoresizingMaskIntoConstraints = false
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageWrapper.addSubview(imageView)
        
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        spinner.startAnimating()
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        imageWrapper.addSubview(spinner)
        
        let heightConstraint = imageWrapper.heightAnchor.constraint(equalToConstant: 210)
        heightConstraint.priority = .defaultHigh
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: imageWrapper.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageWrapper.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageWrapper.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageWrapper.bottomAnchor),
            heightConstraint,
            
            spinner.centerXAnchor.constraint(equalTo: imageWrapper.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: imageWrapper.centerYAnchor)
        ])
        
        GuideImageLoader.shared.loadImage(from: url, into: imageView) { [weak imageWrapper] loadedImage in
            spinner.stopAnimating()
            guard let img = loadedImage, let wrapper = imageWrapper, img.size.width > 0 else { return }
            let ratio = img.size.height / img.size.width
            let width = wrapper.bounds.width > 0 ? wrapper.bounds.width : (UIScreen.main.bounds.width - 64)
            let targetHeight = min(max(width * ratio, 140), 520)
            heightConstraint.constant = targetHeight
            wrapper.superview?.setNeedsLayout()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap(_:)))
        imageView.addGestureRecognizer(tapGesture)
        
        container.addArrangedSubview(imageWrapper)
        
        if let cap = caption, !cap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let capLabel = UILabel()
            capLabel.text = cap
            capLabel.font = .italicSystemFont(ofSize: 12.5)
            capLabel.textColor = UIColor(red: 0.42, green: 0.46, blue: 0.49, alpha: 1.0)
            capLabel.textAlignment = .center
            capLabel.numberOfLines = 0
            container.addArrangedSubview(capLabel)
        }
        
        return container
    }
    
    @objc private func handleImageTap(_ gesture: UITapGestureRecognizer)
    {
        guard let imgView = gesture.view as? UIImageView, let image = imgView.image else { return }
        let viewer = FullscreenImagePreviewController(image: image)
        viewer.modalPresentationStyle = .overFullScreen
        viewer.modalTransitionStyle = .crossDissolve
        self.present(viewer, animated: true)
    }
    
    @objc private func handleBackButton()
    {
        self.navigationController?.popViewController(animated: true)
    }
}

// MARK: - Fullscreen Image Zoom Preview
private final class FullscreenImagePreviewController: UIViewController, UIScrollViewDelegate
{
    private let previewImage: UIImage
    private let imageView = UIImageView()
    
    init(image: UIImage) {
        self.previewImage = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.92)
        
        let scrollView = UIScrollView(frame: self.view.bounds)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.delegate = self
        self.view.addSubview(scrollView)
        
        imageView.image = previewImage
        imageView.contentMode = .scaleAspectFit
        imageView.frame = scrollView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(imageView)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        closeBtn.layer.cornerRadius = 18
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(dismissPreview), for: .touchUpInside)
        self.view.addSubview(closeBtn)
        
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeBtn.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -18),
            closeBtn.widthAnchor.constraint(equalToConstant: 36),
            closeBtn.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissPreview))
        scrollView.addGestureRecognizer(tap)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    @objc private func dismissPreview() {
        self.dismiss(animated: true)
    }
}

// MARK: - Helper Gradient & Card Control Classes (Ánh sáng 3D + Nhấn đàn hồi)
private final class FixHeaderGradientView: UIView
{
    private let gradientLayer = CAGradientLayer()
    private let topRightGlowOrb = CAShapeLayer()
    private let bottomLeftGlowOrb = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.clipsToBounds = true
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        
        gradientLayer.colors = [
            UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor,   // #007bff
            UIColor(red: 0.435, green: 0.259, blue: 0.757, alpha: 1.0).cgColor // #6f42c1
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.layer.insertSublayer(gradientLayer, at: 0)
        
        // 2 Vòng sáng 3D trang trí tạo chiều sâu sang trọng
        topRightGlowOrb.fillColor = UIColor.white.withAlphaComponent(0.11).cgColor
        bottomLeftGlowOrb.fillColor = UIColor.white.withAlphaComponent(0.08).cgColor
        self.layer.insertSublayer(topRightGlowOrb, above: gradientLayer)
        self.layer.insertSublayer(bottomLeftGlowOrb, above: gradientLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = self.bounds
        let b = self.bounds
        topRightGlowOrb.path = UIBezierPath(ovalIn: CGRect(x: b.width - 75, y: -40, width: 135, height: 135)).cgPath
        bottomLeftGlowOrb.path = UIBezierPath(ovalIn: CGRect(x: -35, y: b.height - 50, width: 105, height: 105)).cgPath
    }
}

private final class FixCardButtonControl: UIControl
{
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.24, delay: 0, usingSpringWithDamping: 0.68, initialSpringVelocity: 0.6, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.968, y: 0.968) : .identity
                self.alpha = self.isHighlighted ? 0.94 : 1.0
            }
        }
    }
}
