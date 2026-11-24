

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

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN 100% MÃ WEB CSS CỦA BẠN
private struct SourcesCSSTheme {
    static let white = UIColor.white                                                          // #fff (--white)
    static let pureBlack = UIColor.black                                                      // #000 (Chữ tiêu đề & nội dung)
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0)       // #f8f9fa (--light)
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0)      // #e9ecef (--border)
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)          // #007bff (--blue)
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)       // #6f42c1 (--purple)
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)         // #28a745 (--green)
    static let badgeGreenBorder = UIColor(red: 50/255, green: 196/255, blue: 83/255, alpha: 1.0) // #32c453 (.topic-id-badge border)
    static let magenta = UIColor(red: 230/255, green: 0/255, blue: 230/255, alpha: 1.0)       // #e600e6 (data-tab="1")
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0)           // #343a40 (--dark)

    // Body Gradient: linear-gradient(to right, #f3e0ff, #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Sleek Top Banner Gradient: linear-gradient(125deg, #007bff 0%, #6f42c1 52%, #d600d6 100%)
    static let bannerGradStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0).cgColor
    static let bannerGradMid = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0).cgColor
    static let bannerGradEnd = UIColor(red: 214/255, green: 0/255, blue: 214/255, alpha: 1.0).cgColor

    static let cornerRadius: CGFloat = 15.0        // --radius: 15px
    static let bannerCornerRadius: CGFloat = 18.0  // .sleek-top-banner border-radius: 18px

    /// Trả về đúng 4 màu chủ đạo luân phiên theo chuẩn `.tab-button[data-tab="1..4"]` và `.guide-step-card:nth-child(4n+1..4)`
    static func tabAccentColor(for index: Int) -> UIColor {
        switch index % 4 {
        case 0: return magenta // #e600e6
        case 1: return purple  // #6f42c1
        case 2: return blue    // #007bff
        default: return green  // #28a745
        }
    }

    /// Áp dụng viền 4 cạnh bằng nhau (2px solid var(--border)) + đổ bóng màu chuẩn CSS
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

    /// Áp dụng style cho khung bao trắng lớn (.tab-container & footer)
    static func applyContainerCardStyle(to view: UIView, cornerRadius: CGFloat = SourcesCSSTheme.cornerRadius) {
        view.backgroundColor = SourcesCSSTheme.white
        view.layer.cornerRadius = cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.borderWidth = 0.0
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 20
        view.layer.shadowOpacity = 0.10
    }
}

// MARK: - 🌈 LỚP NỀN BODY GRADIENT NGANG (linear-gradient(to right, #f3e0ff, #e0f7ff))
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
        // Chuẩn CSS: linear-gradient(to right, #f3e0ff, #e0f7ff)
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }
}

// MARK: - 🌟 LỚP NỀN SLEEK TOP BANNER TỰ ĐỘNG PHỦ MÀU 100% (.sleek-top-banner & ::before)
private final class SleekTopBannerGradientView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    private let shineLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBannerLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBannerLayers()
    }

    private func setupBannerLayers() {
        // Màu nền dự phòng đảm bảo không bao giờ trong suốt
        backgroundColor = SourcesCSSTheme.purple

        layer.cornerRadius = SourcesCSSTheme.bannerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            layer.cornerCurve = .continuous
        }
        clipsToBounds = true
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.70).cgColor

        if let gradientLayer = self.layer as? CAGradientLayer {
            // Chuẩn CSS: background: linear-gradient(125deg, #007bff 0%, #6f42c1 52%, #d600d6 100%)
            gradientLayer.colors = [
                SourcesCSSTheme.bannerGradStart,
                SourcesCSSTheme.bannerGradMid,
                SourcesCSSTheme.bannerGradEnd
            ]
            gradientLayer.locations = [0.0, 0.52, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        }

        // Chuẩn CSS .sleek-top-banner::before (Vệt kính chéo skewX(-22deg))
        shineLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.24).cgColor,
            UIColor.clear.cgColor
        ]
        shineLayer.locations = [0.0, 0.5, 1.0]
        shineLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        shineLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        shineLayer.setAffineTransform(CGAffineTransform(a: 1, b: 0, c: -0.40, d: 1, tx: 0, ty: 0))
        layer.insertSublayer(shineLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shineLayer.frame = CGRect(
            x: -bounds.width * 0.15,
            y: -bounds.height * 0.2,
            width: bounds.width * 0.55,
            height: bounds.height * 1.4
        )
        CATransaction.commit()
    }
}

// MARK: - 🏷️ KHỐI BANNER TIÊU ĐỀ DÙNG CHUNG CHO CẢ TRANG CHỦ & TRANG CHI TIẾT (.sleek-top-banner)
private final class SleekTopBannerBoxView: UIView {
    private let shadowContainer = UIView()
    private let gradientBannerView = SleekTopBannerGradientView()

    private let contentStack = UIStackView()
    private let titleRowStack = UIStackView()
    private let iconGlassBox = UIView()
    private let starIconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBannerUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBannerUI()
    }

    private func setupBannerUI() {
        backgroundColor = .clear

        // Đổ bóng chuẩn CSS: box-shadow: 0 10px 22px rgba(111, 66, 193, 0.28)
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.backgroundColor = .clear
        shadowContainer.layer.cornerRadius = SourcesCSSTheme.bannerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            shadowContainer.layer.cornerCurve = .continuous
        }
        shadowContainer.layer.masksToBounds = false
        shadowContainer.layer.shadowColor = SourcesCSSTheme.purple.cgColor
        shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 10)
        shadowContainer.layer.shadowRadius = 16
        shadowContainer.layer.shadowOpacity = 0.28

        gradientBannerView.translatesAutoresizingMaskIntoConstraints = false

        // Icon ngôi sao trong hộp kính (.banner-glass-icon)
        iconGlassBox.translatesAutoresizingMaskIntoConstraints = false
        iconGlassBox.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        iconGlassBox.layer.cornerRadius = 10
        if #available(iOS 13.0, tvOS 13.0, *) {
            iconGlassBox.layer.cornerCurve = .continuous
        }
        iconGlassBox.layer.borderWidth = 1.3
        iconGlassBox.layer.borderColor = UIColor.white.withAlphaComponent(0.70).cgColor
        iconGlassBox.layer.shadowColor = UIColor.black.cgColor
        iconGlassBox.layer.shadowOffset = CGSize(width: 0, height: 3)
        iconGlassBox.layer.shadowRadius = 5
        iconGlassBox.layer.shadowOpacity = 0.15

        starIconImageView.translatesAutoresizingMaskIntoConstraints = false
        let starCfg = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .bold)
        starIconImageView.image = UIImage(systemName: "star", withConfiguration: starCfg)
        starIconImageView.tintColor = SourcesCSSTheme.white
        starIconImageView.contentMode = .scaleAspectFit
        iconGlassBox.addSubview(starIconImageView)

        // Tiêu đề h1 (.sleek-top-banner h1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 21.0, weight: .heavy)
        titleLabel.textColor = SourcesCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.22

        // Hàng tiêu đề (.banner-title-row)
        titleRowStack.translatesAutoresizingMaskIntoConstraints = false
        titleRowStack.axis = .horizontal
        titleRowStack.alignment = .center
        titleRowStack.distribution = .fill
        titleRowStack.spacing = 9
        titleRowStack.addArrangedSubview(iconGlassBox)
        titleRowStack.addArrangedSubview(titleLabel)

        // Phụ đề p (.sleek-top-banner p)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.95)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // Stack tổng căn giữa hoàn toàn
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 4
        contentStack.addArrangedSubview(titleRowStack)
        contentStack.addArrangedSubview(subtitleLabel)

        gradientBannerView.addSubview(contentStack)
        shadowContainer.addSubview(gradientBannerView)
        addSubview(shadowContainer)

        NSLayoutConstraint.activate([
            shadowContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            shadowContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            shadowContainer.topAnchor.constraint(equalTo: topAnchor),
            shadowContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            gradientBannerView.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            gradientBannerView.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            gradientBannerView.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            gradientBannerView.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor),

            iconGlassBox.widthAnchor.constraint(equalToConstant: 30),
            iconGlassBox.heightAnchor.constraint(equalToConstant: 30),
            starIconImageView.centerXAnchor.constraint(equalTo: iconGlassBox.centerXAnchor),
            starIconImageView.centerYAnchor.constraint(equalTo: iconGlassBox.centerYAnchor),

            contentStack.topAnchor.constraint(equalTo: gradientBannerView.topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: gradientBannerView.bottomAnchor, constant: -14),
            contentStack.leadingAnchor.constraint(equalTo: gradientBannerView.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: gradientBannerView.trailingAnchor, constant: -14),

            titleRowStack.leadingAnchor.constraint(greaterThanOrEqualTo: contentStack.leadingAnchor),
            titleRowStack.trailingAnchor.constraint(lessThanOrEqualTo: contentStack.trailingAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
        ])
    }

    func configure(title: String, subtitle: String) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
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
        // Chuẩn CSS: background: linear-gradient(135deg, var(--blue), var(--purple), #f0f)
        gradientLayer.colors = [
            SourcesCSSTheme.blue.cgColor,
            SourcesCSSTheme.purple.cgColor,
            UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - 🎬 KHUNG VIDEO CHUẨN 100% MÃ WEB (.tab-separator + h3 + .video-box-wrap + .video-phone-frame + .video-phone-inner)
private final class WebVideoPhoneFrameGradientView: UIView {
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
        backgroundColor = SourcesCSSTheme.purple
        layer.cornerRadius = 34.0
        if #available(iOS 13.0, tvOS 13.0, *) {
            layer.cornerCurve = .continuous
        }
        clipsToBounds = true

        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        // Chuẩn CSS .video-phone-frame: background: linear-gradient(135deg, var(--blue), var(--purple))
        gradientLayer.colors = [
            SourcesCSSTheme.blue.cgColor,
            SourcesCSSTheme.purple.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

private final class GuideWebStyleVideoSectionView: UIView {
    private let videoID: String
    private let separatorLine = UIView()
    private let headerTitleLabel = UILabel()
    private let videoBoxWrap = UIView()
    private let videoPhoneFrame = WebVideoPhoneFrameGradientView()
    private let videoPhoneInner = UIView()
    private var webView: WKWebView?
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    init(videoID: String) {
        self.videoID = videoID
        super.init(frame: .zero)
        setupVideoSectionUI()
        mountYouTubePlayer()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        webView?.stopLoading()
    }

    private func setupVideoSectionUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        // 1. <hr class="tab-separator">
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = SourcesCSSTheme.border

        // 2. <h3>▶ HƯỚNG DẪN VIDEO</h3>
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerTitleLabel.text = "▶ HƯỚNG DẪN VIDEO"
        headerTitleLabel.font = UIFont.systemFont(ofSize: 19.0, weight: .bold)
        headerTitleLabel.textColor = SourcesCSSTheme.blue
        headerTitleLabel.textAlignment = .center

        // 3. .video-box-wrap (padding: 10px; background: #fff; border: 2px solid #e9ecef; border-radius: 15px; box-shadow: 0 10px 20px rgba(111,66,193,.22))
        videoBoxWrap.translatesAutoresizingMaskIntoConstraints = false
        videoBoxWrap.backgroundColor = SourcesCSSTheme.white
        videoBoxWrap.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            videoBoxWrap.layer.cornerCurve = .continuous
        }
        videoBoxWrap.layer.borderWidth = 2.0
        videoBoxWrap.layer.borderColor = SourcesCSSTheme.border.cgColor
        videoBoxWrap.layer.shadowColor = SourcesCSSTheme.purple.cgColor
        videoBoxWrap.layer.shadowOffset = CGSize(width: 0, height: 10)
        videoBoxWrap.layer.shadowRadius = 15
        videoBoxWrap.layer.shadowOpacity = 0.22

        // 4. .video-phone-frame (padding: 4px; border-radius: 34px; background: linear-gradient(135deg, var(--blue), var(--purple)))
        videoPhoneFrame.translatesAutoresizingMaskIntoConstraints = false

        // 5. .video-phone-inner (aspect-ratio: 9 / 19.5; background: #000; border-radius: 30px; overflow: hidden)
        videoPhoneInner.translatesAutoresizingMaskIntoConstraints = false
        videoPhoneInner.backgroundColor = .black
        videoPhoneInner.layer.cornerRadius = 30.0
        if #available(iOS 13.0, tvOS 13.0, *) {
            videoPhoneInner.layer.cornerCurve = .continuous
        }
        videoPhoneInner.clipsToBounds = true

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = SourcesCSSTheme.blue
        loadingIndicator.startAnimating()

        videoPhoneInner.addSubview(loadingIndicator)
        videoPhoneFrame.addSubview(videoPhoneInner)
        videoBoxWrap.addSubview(videoPhoneFrame)

        addSubview(separatorLine)
        addSubview(headerTitleLabel)
        addSubview(videoBoxWrap)

        NSLayoutConstraint.activate([
            separatorLine.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1.0),

            headerTitleLabel.topAnchor.constraint(equalTo: separatorLine.bottomAnchor, constant: 14),
            headerTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            headerTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            videoBoxWrap.topAnchor.constraint(equalTo: headerTitleLabel.bottomAnchor, constant: 14),
            videoBoxWrap.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoBoxWrap.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoBoxWrap.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            videoPhoneFrame.topAnchor.constraint(equalTo: videoBoxWrap.topAnchor, constant: 10),
            videoPhoneFrame.leadingAnchor.constraint(equalTo: videoBoxWrap.leadingAnchor, constant: 10),
            videoPhoneFrame.trailingAnchor.constraint(equalTo: videoBoxWrap.trailingAnchor, constant: -10),
            videoPhoneFrame.bottomAnchor.constraint(equalTo: videoBoxWrap.bottomAnchor, constant: -10),

            videoPhoneInner.topAnchor.constraint(equalTo: videoPhoneFrame.topAnchor, constant: 4),
            videoPhoneInner.leadingAnchor.constraint(equalTo: videoPhoneFrame.leadingAnchor, constant: 4),
            videoPhoneInner.trailingAnchor.constraint(equalTo: videoPhoneFrame.trailingAnchor, constant: -4),
            videoPhoneInner.bottomAnchor.constraint(equalTo: videoPhoneFrame.bottomAnchor, constant: -4),
            videoPhoneInner.heightAnchor.constraint(equalTo: videoPhoneInner.widthAnchor, multiplier: 19.5 / 9.0),

            loadingIndicator.centerXAnchor.constraint(equalTo: videoPhoneInner.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: videoPhoneInner.centerYAnchor)
        ])
    }

    private func mountYouTubePlayer() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [.all]

        let playerWebView = WKWebView(frame: .zero, configuration: config)
        playerWebView.translatesAutoresizingMaskIntoConstraints = false
        playerWebView.scrollView.isScrollEnabled = false
        playerWebView.scrollView.bounces = false
        playerWebView.isOpaque = false
        playerWebView.backgroundColor = .black
        playerWebView.scrollView.backgroundColor = .black
        playerWebView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        videoPhoneInner.addSubview(playerWebView)
        NSLayoutConstraint.activate([
            playerWebView.leadingAnchor.constraint(equalTo: videoPhoneInner.leadingAnchor),
            playerWebView.trailingAnchor.constraint(equalTo: videoPhoneInner.trailingAnchor),
            playerWebView.topAnchor.constraint(equalTo: videoPhoneInner.topAnchor),
            playerWebView.bottomAnchor.constraint(equalTo: videoPhoneInner.bottomAnchor)
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
            html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
            iframe { width: 100%; height: 100%; border: 0; }
        </style>
        </head>
        <body>
            <iframe
                src="\(embedURL)"
                title="YouTube video player"
                referrerpolicy="strict-origin-when-cross-origin"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowfullscreen>
            </iframe>
        </body>
        </html>
        """

        playerWebView.loadHTMLString(embedHTML, baseURL: URL(string: originDomain))
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
        return "• Nhấn để xem hướng dẫn chi tiết..."
    }
}

private enum GuideParser {
    static let githubGuideURL = "https://raw.githubusercontent.com/Nguyenhuyhoan/Config/main/huongdan.txt"

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

// MARK: - 🏷️ HEADER TRÊN CÙNG CỦA TRANG DANH MỤC (.sleek-top-banner + .features h2)
private final class GuidesHeroHeaderView: UIView {
    private let bannerView = SleekTopBannerBoxView()
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

        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.configure(
            title: "Tin Tức Và Sửa Lỗi",
            subtitle: "Cẩm nang khắc phục sự cố do cộng đồng mạng chia sẻ"
        )

        // Tiêu đề `.features h2`: TỔNG HỢP CÁC DANH MỤC
        sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionTitleLabel.text = "TỔNG HỢP CÁC DANH MỤC"
        sectionTitleLabel.textColor = SourcesCSSTheme.blue
        sectionTitleLabel.textAlignment = .center
        sectionTitleLabel.font = UIFont.systemFont(ofSize: 19.5, weight: .heavy)

        sectionUnderlineView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(bannerView)
        addSubview(sectionTitleLabel)
        addSubview(sectionUnderlineView)

        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            bannerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            bannerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),

            sectionTitleLabel.topAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: 14),
            sectionTitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            sectionTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            sectionTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            sectionUnderlineView.topAnchor.constraint(equalTo: sectionTitleLabel.bottomAnchor, constant: 8),
            sectionUnderlineView.centerXAnchor.constraint(equalTo: centerXAnchor),
            sectionUnderlineView.widthAnchor.constraint(equalToConstant: 60),
            sectionUnderlineView.heightAnchor.constraint(equalToConstant: 3.0),
            sectionUnderlineView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }

    func updateCount(_ count: Int) {
        // Không hiển thị số lượng bài viết theo đúng mã Web
    }
}

// MARK: - 🗂️ THẺ DANH MỤC HƯỚNG DẪN CHUẨN `.tab-button[data-tab="1..4"]` TRONG MÃ WEB
private final class GuideTopicRowCell: UITableViewCell {
    static let reuseIdentifier = "GuideTopicRowCell"

    private let outerContainerSlice = UIView()
    private let cardView = UIView()
    private let badgeContainer = UIView()
    private let badgeStarLabel = UILabel()
    private let badgeNumberLabel = UILabel()

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let pillsStackView = UIStackView()

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
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            self.cardView.alpha = highlighted ? 0.95 : 1.0
        }
    }

    private func setupCell() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // Lớp nền trắng bao ngoài tạo thành khung `.tab-container`
        outerContainerSlice.translatesAutoresizingMaskIntoConstraints = false
        outerContainerSlice.backgroundColor = SourcesCSSTheme.white
        outerContainerSlice.layer.shadowColor = UIColor.black.cgColor
        outerContainerSlice.layer.shadowOffset = CGSize(width: 0, height: 6)
        outerContainerSlice.layer.shadowRadius = 14
        outerContainerSlice.layer.shadowOpacity = 0.06
        contentView.addSubview(outerContainerSlice)

        // Khối `.tab-button` bên trong: Viền 2px solid var(--border) + Đổ bóng màu chuẩn data-tab
        cardView.translatesAutoresizingMaskIntoConstraints = false
        outerContainerSlice.addSubview(cardView)

        // Huy hiệu `.tab-num-badge` (46x46px, border-radius: 12px)
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.layer.cornerRadius = 12
        if #available(iOS 13.0, tvOS 13.0, *) {
            badgeContainer.layer.cornerCurve = .continuous
        }
        badgeContainer.layer.masksToBounds = false

        badgeStarLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeStarLabel.text = "✦"
        badgeStarLabel.font = UIFont.systemFont(ofSize: 10, weight: .heavy)
        badgeStarLabel.textColor = SourcesCSSTheme.white.withAlphaComponent(0.90)
        badgeStarLabel.textAlignment = .center

        badgeNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeNumberLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .heavy)
        badgeNumberLabel.textColor = SourcesCSSTheme.white
        badgeNumberLabel.textAlignment = .center

        badgeContainer.addSubview(badgeStarLabel)
        badgeContainer.addSubview(badgeNumberLabel)

        // Tiêu đề `.tab-card-title` (15.8px, font-weight: 700, color: #000)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 15.8, weight: .bold)
        titleLabel.textColor = SourcesCSSTheme.pureBlack
        titleLabel.numberOfLines = 2

        // Phụ đề `.tab-card-sub` (13px, font-weight: 500, color: var(--dark))
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13.0, weight: .medium)
        subtitleLabel.textColor = SourcesCSSTheme.dark
        subtitleLabel.numberOfLines = 1
        subtitleLabel.lineBreakMode = .byTruncatingTail

        // Hàng huy hiệu nhỏ `.tab-meta-pills`
        pillsStackView.translatesAutoresizingMaskIntoConstraints = false
        pillsStackView.axis = .horizontal
        pillsStackView.spacing = 5
        pillsStackView.alignment = .center

        cardView.addSubview(badgeContainer)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(pillsStackView)

        topSliceConstraint = cardView.topAnchor.constraint(equalTo: outerContainerSlice.topAnchor, constant: 6)
        bottomSliceConstraint = cardView.bottomAnchor.constraint(equalTo: outerContainerSlice.bottomAnchor, constant: -6)

        NSLayoutConstraint.activate([
            outerContainerSlice.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            outerContainerSlice.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            outerContainerSlice.topAnchor.constraint(equalTo: contentView.topAnchor),
            outerContainerSlice.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            cardView.leadingAnchor.constraint(equalTo: outerContainerSlice.leadingAnchor, constant: 7),
            cardView.trailingAnchor.constraint(equalTo: outerContainerSlice.trailingAnchor, constant: -7),
            topSliceConstraint,
            bottomSliceConstraint,

            badgeContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 11),
            badgeContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            badgeContainer.widthAnchor.constraint(equalToConstant: 46),
            badgeContainer.heightAnchor.constraint(equalToConstant: 46),

            badgeStarLabel.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeStarLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 6),

            badgeNumberLabel.topAnchor.constraint(equalTo: badgeStarLabel.bottomAnchor, constant: 0),
            badgeNumberLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 2),
            badgeNumberLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -2),

            titleLabel.leadingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: 11),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -11),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 13),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),

            pillsStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pillsStackView.trailingAnchor.constraint(lessThanOrEqualTo: titleLabel.trailingAnchor),
            pillsStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 5),
            pillsStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -13)
        ])
    }

    private func makeTabPillView(text: String, accentColor: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = SourcesCSSTheme.light
        container.layer.cornerRadius = 7
        container.layer.borderWidth = 1.0
        container.layer.borderColor = SourcesCSSTheme.border.cgColor
        container.layer.masksToBounds = true

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = UIFont.systemFont(ofSize: 10.5, weight: .heavy)
        label.textColor = accentColor

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -7),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2.5),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2.5)
        ])
        return container
    }

    func configure(with article: GuideArticle, rowIndex: Int, totalRows: Int) {
        let accentColor = SourcesCSSTheme.tabAccentColor(for: rowIndex)

        SourcesCSSTheme.applyColoredGlowCardStyle(
            to: cardView,
            accentColor: accentColor,
            cornerRadius: SourcesCSSTheme.cornerRadius,
            shadowOpacity: 0.24
        )

        badgeContainer.backgroundColor = accentColor
        badgeContainer.layer.shadowColor = accentColor.cgColor
        badgeContainer.layer.shadowOffset = CGSize(width: 0, height: 5)
        badgeContainer.layer.shadowRadius = 8
        badgeContainer.layer.shadowOpacity = 0.28

        badgeNumberLabel.text = "#\(article.orderNumber)"
        titleLabel.text = article.title
        subtitleLabel.text = article.previewSubtitle

        // Xây dựng các thẻ `.tab-pill` giống hệt hàm renderAll() trong mã Web
        pillsStackView.arrangedSubviews.forEach {
            pillsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        var pills: [String] = []
        if rowIndex == 0 {
            pills.append("★ MỚI NHẤT")
        }
        pills.append("\(article.stepCount) mục")
        if article.imageCount > 0 {
            pills.append("🖼 \(article.imageCount) ảnh")
        }
        if article.videoCount > 0 {
            pills.append("🎬 \(article.videoCount) video")
        }
        if article.downloadCount > 0 {
            pills.append("⬇️ \(article.downloadCount) tệp")
        }

        for pillText in pills {
            pillsStackView.addArrangedSubview(makeTabPillView(text: pillText, accentColor: accentColor))
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

// MARK: - 📱 KHUNG HIỂN THỊ ẢNH CHUẨN `.guide img` (PADDING 3PX GRADIENT 3 MÀU + BÓNG ĐỔ SÂU)
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

    // Chuẩn CSS .guide img: padding: 3px; border-radius: var(--radius)
    private let borderThickness: CGFloat = 3.0

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

        // Chuẩn CSS .guide img: box-shadow: 0 8px 22px rgba(0,0,0,.35)
        outerShadowContainer.translatesAutoresizingMaskIntoConstraints = false
        outerShadowContainer.backgroundColor = .clear
        outerShadowContainer.layer.shadowColor = UIColor.black.cgColor
        outerShadowContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        outerShadowContainer.layer.shadowRadius = 16
        outerShadowContainer.layer.shadowOpacity = 0.35

        let outerRadius = SourcesCSSTheme.cornerRadius
        borderContainer.translatesAutoresizingMaskIntoConstraints = false
        borderContainer.layer.cornerRadius = outerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            borderContainer.layer.cornerCurve = .continuous
        }
        borderContainer.clipsToBounds = true

        let innerRadius = max(outerRadius - borderThickness, 10.0)
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

// MARK: - ⬇️ NÚT TẢI NỔI KHỐI CHUẨN `.btn-primary` (linear-gradient(135deg, var(--blue), var(--purple)))
private final class ProminentGradientDownloadButton: UIControl {
    private final class ButtonGradientBgView: UIView {
        override class var layerClass: AnyClass { CAGradientLayer.self }
        var gradientLayer: CAGradientLayer? { layer as? CAGradientLayer }
    }

    private let shadowWrap = UIView()
    private let gradientContainer = ButtonGradientBgView()
    private let contentStack = UIStackView()
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
        shadowWrap.layer.shadowColor = UIColor.black.cgColor
        shadowWrap.layer.shadowOffset = CGSize(width: 0, height: 8)
        shadowWrap.layer.shadowRadius = 12
        shadowWrap.layer.shadowOpacity = 0.18

        gradientContainer.translatesAutoresizingMaskIntoConstraints = false
        gradientContainer.isUserInteractionEnabled = false
        gradientContainer.backgroundColor = SourcesCSSTheme.blue
        gradientContainer.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            gradientContainer.layer.cornerCurve = .continuous
        }
        gradientContainer.clipsToBounds = true

        gradientContainer.gradientLayer?.colors = [
            SourcesCSSTheme.blue.cgColor,
            SourcesCSSTheme.purple.cgColor
        ]
        gradientContainer.gradientLayer?.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientContainer.gradientLayer?.endPoint = CGPoint(x: 1.0, y: 1.0)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.isUserInteractionEnabled = false
        contentStack.axis = .horizontal
        contentStack.spacing = 8
        contentStack.alignment = .center

        spinner.color = .white
        spinner.hidesWhenStopped = true

        // Chuẩn mã Web: ☁️ Nhấn Vào Đây Để Tải Về
        titleLabel.text = "☁️ Nhấn Vào Đây Để Tải Về"
        titleLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

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
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: gradientContainer.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: gradientContainer.trailingAnchor, constant: -12)
        ])
    }

    func setLoadingState(_ isLoading: Bool) {
        if isLoading {
            spinner.startAnimating()
            titleLabel.text = "Đang Tải Về..."
            gradientContainer.gradientLayer?.colors = [
                SourcesCSSTheme.purple.cgColor,
                SourcesCSSTheme.blue.cgColor
            ]
        } else {
            spinner.stopAnimating()
            titleLabel.text = "☁️ Nhấn Vào Đây Để Tải Về"
            gradientContainer.gradientLayer?.colors = [
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
            self.shadowWrap.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            self.gradientContainer.alpha = highlighted ? 0.94 : 1.0
        }
    }
}

// MARK: - ⬇️ KHUNG TẢI VỀ CHUẨN `.guide-actions` TRONG MÃ WEB (.btn-outline-glow + .btn-primary)
private final class GuideDownloadActionCardView: UIView {
    private let downloadURL: URL
    private weak var hostViewController: UIViewController?

    private let mainStack = UIStackView()
    private let noticeBannerView = UIView()
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

        // 1. Khung `.btn-outline-glow`: 📁 Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file
        noticeBannerView.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyColoredGlowCardStyle(
            to: noticeBannerView,
            accentColor: SourcesCSSTheme.blue,
            cornerRadius: SourcesCSSTheme.cornerRadius,
            shadowOpacity: 0.25
        )

        noticeTextLabel.translatesAutoresizingMaskIntoConstraints = false
        noticeTextLabel.numberOfLines = 0
        noticeTextLabel.textAlignment = .center
        noticeTextLabel.attributedText = makeNoticeAttributedText()

        noticeBannerView.addSubview(noticeTextLabel)

        // 2. Nút `.btn-primary`: ☁️ Nhấn Vào Đây Để Tải Về
        downloadButton.addTarget(self, action: #selector(handleDownloadButtonTap), for: .touchUpInside)

        NSLayoutConstraint.activate([
            noticeTextLabel.leadingAnchor.constraint(equalTo: noticeBannerView.leadingAnchor, constant: 12),
            noticeTextLabel.trailingAnchor.constraint(equalTo: noticeBannerView.trailingAnchor, constant: -12),
            noticeTextLabel.topAnchor.constraint(equalTo: noticeBannerView.topAnchor, constant: 13),
            noticeTextLabel.bottomAnchor.constraint(equalTo: noticeBannerView.bottomAnchor, constant: -13),

            downloadButton.heightAnchor.constraint(equalToConstant: 50)
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
        // Chuẩn mã Web: 📁 Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file (màu chữ --outline-color: var(--blue))
        let mainText = "📁 Chờ tải xong bạn chọn Lưu Vào Tệp để lưu file"
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3.0
        paragraph.alignment = .center

        let result = NSMutableAttributedString(
            string: mainText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15.5, weight: .bold),
                .foregroundColor: SourcesCSSTheme.blue,
                .paragraphStyle: paragraph
            ]
        )

        let nsMain = mainText as NSString
        let highlightRange = nsMain.range(of: "Lưu Vào Tệp", options: .caseInsensitive)
        if highlightRange.location != NSNotFound {
            result.addAttributes([
                .foregroundColor: SourcesCSSTheme.blue,
                .font: UIFont.systemFont(ofSize: 16.0, weight: .heavy)
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

// MARK: - 🔍 TRÌNH XEM ẢNH PHÓNG TO TOÀN MÀN HÌNH (.lightbox-overlay)
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
        view.backgroundColor = UIColor.black.withAlphaComponent(0.90)

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

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        singleTap.numberOfTapsRequired = 1
        scrollView.addGestureRecognizer(singleTap)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        singleTap.require(toFail: doubleTap)

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

// MARK: - 📖 TRANG CHI TIẾT BÀI HƯỚNG DẪN (CHUẨN 100% KHI NHẤN openTopicDetail TRONG MÃ WEB)
private final class GuideArticleDetailViewController: UIViewController {
    private let article: GuideArticle
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    private let bannerView = SleekTopBannerBoxView()
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
        setupFooterCard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
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
        scrollView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 30, right: 0)

        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 10
        contentStackView.isLayoutMarginsRelativeArrangement = true
        contentStackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 20, trailing: 4)

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

    // Hàng nút `.top-back-row`: `.back-clean-btn` + `.topic-id-badge`
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
        backBtn.layer.shadowOffset = CGSize(width: 0, height: 6)
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
        topicBadge.layer.borderColor = SourcesCSSTheme.badgeGreenBorder.cgColor

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

    // Thanh tiêu đề `.sleek-top-banner` có icon ngôi sao + nền Gradient 125deg chuẩn mã Web
    private func setupCenteredSleekBanner() {
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.configure(
            title: article.title,
            subtitle: "Mọi cách khắc phục không đảm bảo thành công 100%, bạn cần kiên nhẫn và thực hiện lại nhiều lần."
        )
        contentStackView.addArrangedSubview(bannerView)
    }

    // Tiêu đề `.features h2`: HƯỚNG DẪN & KHẮC PHỤC SỰ CỐ + gạch chân xanh 60x3pt ở giữa
    private func setupCenteredSectionHeader() {
        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false

        let primaryLabel = UILabel()
        primaryLabel.translatesAutoresizingMaskIntoConstraints = false
        primaryLabel.text = "HƯỚNG DẪN & KHẮC PHỤC SỰ CỐ"
        primaryLabel.textColor = SourcesCSSTheme.blue
        primaryLabel.textAlignment = .center
        primaryLabel.font = UIFont.systemFont(ofSize: 19.0, weight: .heavy)

        let underline = SourcesCenteredUnderlineView()
        underline.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(primaryLabel)
        headerContainer.addSubview(underline)

        NSLayoutConstraint.activate([
            primaryLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 6),
            primaryLabel.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            primaryLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 8),
            primaryLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -8),

            underline.topAnchor.constraint(equalTo: primaryLabel.bottomAnchor, constant: 8),
            underline.centerXAnchor.constraint(equalTo: headerContainer.centerXAnchor),
            underline.widthAnchor.constraint(equalToConstant: 60),
            underline.heightAnchor.constraint(equalToConstant: 3.0),
            underline.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -6)
        ])

        contentStackView.addArrangedSubview(headerContainer)
    }

    // Khung trắng lớn `.tab-container`
    private func setupWhiteTabContainer() {
        whiteTabContainerCard.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyContainerCardStyle(to: whiteTabContainerCard, cornerRadius: SourcesCSSTheme.cornerRadius)

        guideInnerStackView.translatesAutoresizingMaskIntoConstraints = false
        guideInnerStackView.axis = .vertical
        guideInnerStackView.spacing = 10

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
                    let webStyleVideoSection = GuideWebStyleVideoSectionView(videoID: videoID)
                    guideInnerStackView.addArrangedSubview(webStyleVideoSection)

                case .download(let downloadURL):
                    let downloadCard = GuideDownloadActionCardView(url: downloadURL, hostViewController: self)
                    guideInnerStackView.addArrangedSubview(downloadCard)
                }
            }
        }

        // Đường kẻ phân cách `<hr class="tab-separator">` & Nút `.btn-tertiary` màu Tím ở cuối bài
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = SourcesCSSTheme.border
        separator.heightAnchor.constraint(equalToConstant: 1.0).isActive = true
        guideInnerStackView.addArrangedSubview(separator)

        let bottomBackBtn = UIButton(type: .system)
        bottomBackBtn.translatesAutoresizingMaskIntoConstraints = false
        bottomBackBtn.setTitle("‹ Quay Lại Tổng Hợp Danh Mục", for: .normal)
        bottomBackBtn.setTitleColor(SourcesCSSTheme.white, for: .normal)
        bottomBackBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16.5, weight: .bold)
        bottomBackBtn.backgroundColor = SourcesCSSTheme.purple
        bottomBackBtn.layer.cornerRadius = SourcesCSSTheme.cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            bottomBackBtn.layer.cornerCurve = .continuous
        }
        bottomBackBtn.layer.shadowColor = UIColor.black.cgColor
        bottomBackBtn.layer.shadowOffset = CGSize(width: 0, height: 6)
        bottomBackBtn.layer.shadowRadius = 10
        bottomBackBtn.layer.shadowOpacity = 0.15
        bottomBackBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        bottomBackBtn.addTarget(self, action: #selector(handleBackButtonTap), for: .touchUpInside)

        guideInnerStackView.addArrangedSubview(bottomBackBtn)
    }

    // Khung `<footer>` ở cuối trang chi tiết giống hệt mã Web
    private func setupFooterCard() {
        let footerCard = UIView()
        footerCard.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyContainerCardStyle(to: footerCard, cornerRadius: SourcesCSSTheme.cornerRadius)

        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.text = "Dữ liệu hướng dẫn được đồng bộ trực tiếp từ hệ thống máy chủ GitHub\nNhấn vào từng danh mục để xem hướng dẫn chi tiết & hình ảnh minh họa"
        infoLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        infoLabel.textColor = SourcesCSSTheme.dark
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .center

        footerCard.addSubview(infoLabel)
        NSLayoutConstraint.activate([
            infoLabel.leadingAnchor.constraint(equalTo: footerCard.leadingAnchor, constant: 14),
            infoLabel.trailingAnchor.constraint(equalTo: footerCard.trailingAnchor, constant: -14),
            infoLabel.topAnchor.constraint(equalTo: footerCard.topAnchor, constant: 18),
            infoLabel.bottomAnchor.constraint(equalTo: footerCard.bottomAnchor, constant: -18)
        ])

        contentStackView.addArrangedSubview(footerCard)
    }

    /// Khung bước hướng dẫn (`.guide-step-card`): Viền 4 cạnh bằng nhau (`2px solid var(--border)`), chấm tròn `.step-bullet` đổi 4 màu luân phiên
    private func makeUniformBorderGlowStepCard(stepText: String, colorIndex: Int) -> UIView {
        let accentColor = SourcesCSSTheme.tabAccentColor(for: colorIndex)

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyColoredGlowCardStyle(
            to: card,
            accentColor: accentColor,
            cornerRadius: SourcesCSSTheme.cornerRadius,
            shadowOpacity: 0.16
        )

        let bulletDot = UILabel()
        bulletDot.translatesAutoresizingMaskIntoConstraints = false
        bulletDot.text = "•"
        bulletDot.font = UIFont.systemFont(ofSize: 19, weight: .black)
        bulletDot.textColor = accentColor
        bulletDot.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.attributedText = styleHighlightedInstructionText(stepText)

        card.addSubview(bulletDot)
        card.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            bulletDot.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            bulletDot.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            bulletDot.widthAnchor.constraint(equalToConstant: 14),

            bodyLabel.leadingAnchor.constraint(equalTo: bulletDot.trailingAnchor, constant: 8),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            bodyLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 11),
            bodyLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -11)
        ])

        return card
    }

    /// Làm nổi bật mũi tên `→` màu xanh chuẩn CSS (`<strong style="color:var(--blue)">→</strong>`) và giữ chữ `#000`
    private func styleHighlightedInstructionText(_ text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15.0, weight: .medium),
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
    private let heroHeaderView = GuidesHeroHeaderView(frame: CGRect(x: 0, y: 0, width: 375, height: 154))
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
        updateHeaderAndFooterFramesIfNeeded()
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
    func updateHeaderAndFooterFramesIfNeeded() {
        let tableWidth = guidesTableView.bounds.width
        guard tableWidth > 0 else { return }

        if let header = guidesTableView.tableHeaderView {
            let fittingSize = CGSize(width: tableWidth, height: UIView.layoutFittingCompressedSize.height)
            let calculatedHeight = header.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
            let targetHeight = max(calculatedHeight, 148)
            if abs(header.frame.height - targetHeight) > 1.0 || abs(header.frame.width - tableWidth) > 1.0 {
                header.frame = CGRect(x: 0, y: 0, width: tableWidth, height: targetHeight)
                guidesTableView.tableHeaderView = header
            }
        }
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
        guidesTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
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
            guidesTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            guidesTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func setupTableFooterInfo() {
        let footerWrap = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 92))
        footerWrap.backgroundColor = .clear

        let footerCard = UIView()
        footerCard.translatesAutoresizingMaskIntoConstraints = false
        SourcesCSSTheme.applyContainerCardStyle(to: footerCard, cornerRadius: SourcesCSSTheme.cornerRadius)

        let infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.text = "Dữ liệu hướng dẫn được đồng bộ trực tiếp từ hệ thống máy chủ GitHub\nNhấn vào từng danh mục để xem hướng dẫn chi tiết & hình ảnh minh họa"
        infoLabel.font = UIFont.systemFont(ofSize: 13.0, weight: .semibold)
        infoLabel.textColor = SourcesCSSTheme.dark
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .center

        footerCard.addSubview(infoLabel)
        footerWrap.addSubview(footerCard)

        NSLayoutConstraint.activate([
            footerCard.leadingAnchor.constraint(equalTo: footerWrap.leadingAnchor, constant: 4),
            footerCard.trailingAnchor.constraint(equalTo: footerWrap.trailingAnchor, constant: -4),
            footerCard.topAnchor.constraint(equalTo: footerWrap.topAnchor, constant: 16),
            footerCard.bottomAnchor.constraint(equalTo: footerWrap.bottomAnchor, constant: -4),

            infoLabel.centerXAnchor.constraint(equalTo: footerCard.centerXAnchor),
            infoLabel.centerYAnchor.constraint(equalTo: footerCard.centerYAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: footerCard.leadingAnchor, constant: 14),
            infoLabel.trailingAnchor.constraint(equalTo: footerCard.trailingAnchor, constant: -14)
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
                    self.showErrorState(message: "Không thể tải dữ liệu hướng dẫn.")
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
                cell.transform = CGAffineTransform(translationX: 0, y: -2).scaledBy(x: 0.985, y: 0.985)
            }) { _ in
                UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
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
