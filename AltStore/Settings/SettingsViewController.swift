
//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import CoreData
import SwiftUI
import UniformTypeIdentifiers
import AltStoreCore
import Minimuxer
import Roxas

extension SettingsViewController
{
    private enum Section: Int, CaseIterable
    {
        case signIn
        case refreshAttempts
        case errorLog
        case account
        case patreon
        case instructions
        case server
        case backgroundRefresh
        caselegacyDeactivation
        case appLimit
        case reset
        case debug
        case activeAppIDs
    }
    
    private enum AccountRow: Int, CaseIterable
    {
        case appleID
        case activeTeam
        case certificates
    }
    
    private enum PatreonRow: Int, CaseIterable
    {
        case patreonAccount
        case aboutPatreon
    }

    private enum ServerRow: Int, CaseIterable
    {
        case anisetteServer
        case jitServer
    }

    private enum ResetRow: Int, CaseIterable
    {
        case clearCache
        case resetAll
        case resetPairing
        case resetAdiPb
    }
}

final class SettingsViewController: UITableViewController, RunsAsync
{
    private lazy var dataSource = self.makeDataSource()
    
    private var activeAppIDs = [AppID]()
    private var activeProfile: Team?
    
    @IBOutlet private var footerView: UIView!
    @IBOutlet private var versionLabel: UILabel!
    @IBOutlet private var termsOfUseButton: UIButton!
    @IBOutlet private var privacyPolicyButton: UIButton!
    
    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    @IBOutlet private var legacyDeactivationSwitch: UISwitch!
    @IBOutlet private var appLimitSwitch: UISwitch!
    @IBOutlet private var useMainProfileSwitch: UISwitch!
    
    private let pageGradientLayer = CAGradientLayer()
    private let heroBannerGradientLayer = CAGradientLayer()
    private let topRightGlowOrb = CAShapeLayer()
    private let bottomLeftGlowOrb = CAShapeLayer()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    // MARK: - UIViewController
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Khóa cứng giao diện Sáng (Light Mode) đồng bộ CSS
        self.overrideUserInterfaceStyle = .light
        self.impactFeedback.prepare()
        
        // Thiết lập nền Gradient toàn trang (#f3e0ff -> #e0f7ff)
        let bgView = UIView(frame: self.view.bounds)
        self.pageGradientLayer.colors = [
            UIColor(red: 0.953, green: 0.878, blue: 1.0, alpha: 1.0).cgColor, // #f3e0ff
            UIColor(red: 0.878, green: 0.969, blue: 1.0, alpha: 1.0).cgColor  // #e0f7ff
        ]
        self.pageGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.pageGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.pageGradientLayer.frame = self.view.bounds
        bgView.layer.insertSublayer(self.pageGradientLayer, at: 0)
        self.tableView.backgroundView = bgView
        self.tableView.backgroundColor = .clear
        self.tableView.separatorColor = UIColor(red: 0.91, green: 0.93, blue: 0.97, alpha: 1.0)
        
        // Ẩn thanh Navigation Bar mặc định để dùng Hero Banner giống trang Tổng quan & Sửa lỗi
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Khởi tạo Hero Header Banner đầu trang Cài đặt
        self.setupHeroTableHeader()
        
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.6.1"
        self.versionLabel?.text = "Phiên bản SideStore \(appVersion) • Giao diện Tiếng Việt"
        self.versionLabel?.textColor = UIColor(red: 0.42, green: 0.46, blue: 0.49, alpha: 1.0)
        self.versionLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
        
        // Ẩn hai nút tiếng Anh Terms of Use & Privacy Policy ở dưới chân trang
        self.termsOfUseButton?.isHidden = true
        self.privacyPolicyButton?.isHidden = true
        
        self.backgroundRefreshSwitch?.onTintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        self.legacyDeactivationSwitch?.onTintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        self.appLimitSwitch?.onTintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        self.useMainProfileSwitch?.onTintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        
        self.tableView.register(AppIDTableViewCell.nib, forCellReuseIdentifier: "AppIDCell")
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.didFetchAccount(_:)), name: AppManager.didFetchSourceNotification, object: nil)
        
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        self.fetchAppIDs()
        self.update()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.pageGradientLayer.frame = self.tableView.bounds
        if let header = self.tableView.tableHeaderView, let banner = header.viewWithTag(9901) {
            self.heroBannerGradientLayer.frame = banner.bounds
            let b = banner.bounds
            self.topRightGlowOrb.path = UIBezierPath(ovalIn: CGRect(x: b.width - 75, y: -40, width: 135, height: 135)).cgPath
            self.bottomLeftGlowOrb.path = UIBezierPath(ovalIn: CGRect(x: -35, y: b.height - 50, width: 105, height: 105)).cgPath
        }
    }
    
    // MARK: - Hero Header Banner (.header trong CSS + Ánh sáng 3D)
    private func setupHeroTableHeader()
    {
        let headerWrapper = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 106))
        headerWrapper.backgroundColor = .clear
        
        let bannerContainer = UIView()
        bannerContainer.tag = 9901
        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.layer.cornerRadius = 18
        bannerContainer.layer.cornerCurve = .continuous
        bannerContainer.clipsToBounds = false
        bannerContainer.layer.shadowColor = UIColor(red: 0.0, green: 0.35, blue: 0.90, alpha: 1.0).cgColor
        bannerContainer.layer.shadowOpacity = 0.22
        bannerContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        bannerContainer.layer.shadowRadius = 18
        headerWrapper.addSubview(bannerContainer)
        
        let clipView = UIView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        clipView.layer.cornerRadius = 18
        clipView.layer.cornerCurve = .continuous
        clipView.layer.borderWidth = 1.0
        clipView.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        clipView.clipsToBounds = true
        bannerContainer.addSubview(clipView)
        
        self.heroBannerGradientLayer.colors = [
            UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor,     // #007bff
            UIColor(red: 0.435, green: 0.259, blue: 0.757, alpha: 1.0).cgColor // #6f42c1
        ]
        self.heroBannerGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.heroBannerGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        clipView.layer.insertSublayer(self.heroBannerGradientLayer, at: 0)
        
        // 2 Vòng sáng 3D trang trí tạo chiều sâu sang trọng
        self.topRightGlowOrb.fillColor = UIColor.white.withAlphaComponent(0.11).cgColor
        self.bottomLeftGlowOrb.fillColor = UIColor.white.withAlphaComponent(0.08).cgColor
        clipView.layer.insertSublayer(self.topRightGlowOrb, above: self.heroBannerGradientLayer)
        clipView.layer.insertSublayer(self.bottomLeftGlowOrb, above: self.heroBannerGradientLayer)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Cài Đặt Hệ Thống"
        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Tài khoản Apple ID, chứng chỉ, máy chủ & tùy chỉnh nâng cao"
        subtitleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        bannerContainer.addSubview(stack)
        
        NSLayoutConstraint.activate([
            bannerContainer.topAnchor.constraint(equalTo: headerWrapper.topAnchor, constant: 8),
            bannerContainer.leadingAnchor.constraint(equalTo: headerWrapper.leadingAnchor, constant: 16),
            bannerContainer.trailingAnchor.constraint(equalTo: headerWrapper.trailingAnchor, constant: -16),
            bannerContainer.bottomAnchor.constraint(equalTo: headerWrapper.bottomAnchor, constant: -6),
            
            clipView.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
            clipView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
            clipView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
            clipView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor),
            
            stack.centerYAnchor.constraint(equalTo: bannerContainer.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -16)
        ])
        
        self.tableView.tableHeaderView = headerWrapper
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "showSignIn":
            let navigationController = segue.destination as! UINavigationController
            let viewController = navigationController.viewControllers[0] as! SignInViewController
            viewController.completionHandler = {
                self.dismiss(animated: true, completion: nil)
            }
            
        case "showRefreshAttempts": break
        default: break
        }
    }
}

private extension SettingsViewController
{
    func makeDataSource() -> RSTFetchedResultsTableViewDataSource<AppID>
    {
        let fetchRequest: NSFetchRequest<AppID> = AppID.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \AppID.expirationDate, ascending: true),
                                        NSSortDescriptor(keyPath: \AppID.bundleIdentifier, ascending: true)]
        
        if let team = DatabaseManager.shared.activeTeam()
        {
            fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(AppID.team), team)
        }
        else
        {
            fetchRequest.predicate = NSPredicate(value: false)
        }
        
        let dataSource = RSTFetchedResultsTableViewDataSource(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.cellConfigurationHandler = { (cell, appID, indexPath) in
            let cell = cell as! AppIDTableViewCell
            cell.nameLabel.text = appID.name
            cell.nameLabel.font = .systemFont(ofSize: 15, weight: .bold)
            cell.nameLabel.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
            
            cell.bundleIdentifierLabel.text = appID.bundleIdentifier
            cell.bundleIdentifierLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
            cell.bundleIdentifierLabel.textColor = UIColor(red: 0.42, green: 0.47, blue: 0.55, alpha: 1.0)
            
            cell.expirationDateButton.isUserInteractionEnabled = false
            
            if let expirationDate = appID.expirationDate
            {
                cell.expirationDateButton.isHidden = false
                
                let expirationDays = expirationDate.numberOfCalendarDays(since: Date())
                if expirationDays > 0
                {
                    let title = "\(expirationDays) NGÀY"
                    cell.expirationDateButton.setTitle(title, for: .normal)
                }
                else
                {
                    let formatter = DateComponentsFormatter()
                    formatter.unitsStyle = .full
                    formatter.allowedUnits = [.minute, .hour]
                    formatter.maximumUnitCount = 1
                    
                    let currentDate = Date()
                    if currentDate > expirationDate
                    {
                        cell.expirationDateButton.setTitle("HẾT HẠN", for: .normal)
                    }
                    else if var timeLeftText = formatter.string(from: currentDate, to: expirationDate)
                    {
                        timeLeftText = timeLeftText
                            .replacingOccurrences(of: "hours", with: "GIỜ")
                            .replacingOccurrences(of: "hour", with: "GIỜ")
                            .replacingOccurrences(of: "minutes", with: "PHÚT")
                            .replacingOccurrences(of: "minute", with: "PHÚT")
                            .uppercased()
                        cell.expirationDateButton.setTitle(timeLeftText, for: .normal)
                    }
                }
            }
            else
            {
                cell.expirationDateButton.isHidden = true
            }
        }
        
        return dataSource
    }
    
    func fetchAppIDs()
    {
        guard let team = DatabaseManager.shared.activeTeam() else { return }
        
        AppManager.shared.fetchAppIDs(team: team) { (result) in
            do
            {
                let (_, context) = try result.get()
                try context.save()
                
                DispatchQueue.main.async {
                    self.update()
                }
            }
            catch
            {
                print("Failed to fetch App IDs:", error)
            }
        }
    }
    
    func update()
    {
        self.activeProfile = DatabaseManager.shared.activeTeam()
        
        if let team = self.activeProfile
        {
            self.dataSource.predicate = NSPredicate(format: "%K == %@", #keyPath(AppID.team), team)
        }
        else
        {
            self.dataSource.predicate = NSPredicate(value: false)
        }
        
        self.backgroundRefreshSwitch?.isOn = UserDefaults.standard.isBackgroundRefreshEnabled
        self.legacyDeactivationSwitch?.isOn = UserDefaults.standard.isLegacyDeactivationSupported
        self.appLimitSwitch?.isOn = UserDefaults.standard.isAppLimitDisabled
        
        self.tableView.reloadData()
    }
    
    @objc func didFetchAccount(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.update()
        }
    }
}

private extension SettingsViewController
{
    @IBAction func toggleBackgroundRefresh(_ sender: UISwitch)
    {
        UserDefaults.standard.isBackgroundRefreshEnabled = sender.isOn
    }
    
    @IBAction func toggleLegacyDeactivation(_ sender: UISwitch)
    {
        UserDefaults.standard.isLegacyDeactivationSupported = sender.isOn
    }
    
    @IBAction func toggleAppLimit(_ sender: UISwitch)
    {
        UserDefaults.standard.isAppLimitDisabled = sender.isOn
    }
    
    @IBAction func signOut(_ sender: Any?)
    {
        let signOutAlertViewController = SignOutAlertViewController() { [weak self] shouldConfirmSignOut, shouldUntrust Device in
            guard let self else { return }

            if shouldConfirmSignOut {
                DatabaseManager.shared.signOut(untrust: shouldUntrustDevice) { (error) in
                    DispatchQueue.main.async {
                        if let error = error
                        {
                            let toastView = ToastView(error: error)
                            toastView.show(in: self.navigationController?.view ?? self.view)
                        }
                        self.update()
                    }
                }
            }
        }
        
        self.present(signOutAlertViewController.alertController, animated: true, completion: nil)
    }
    
    @IBAction func resetAppCache(_ sender: Any?)
    {
        let alertController = UIAlertController(title: "Bạn có chắc chắn muốn xóa bộ nhớ đệm ứng dụng?", message: "Các tệp tạm thời và dữ liệu lưu đệm của ứng dụng sẽ bị xóa để giải phóng dung lượng.", preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Xóa bộ nhớ đệm", style: .destructive) { (action) in
            AppManager.shared.clearAppCache { (result) in
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.show(in: self.navigationController?.view ?? self.view)
                        
                    case .success:
                        let alert = UIAlertController(title: "Đã xóa bộ nhớ đệm", message: "Bộ nhớ đệm đã được dọn dẹp hoàn tất.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Đóng", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        })
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel, handler: nil))
        
        if let popover = alertController.popoverPresentationController, let senderView = sender as? UIView {
            popover.sourceView = senderView
            popover.sourceRect = senderView.bounds
        }
        
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func resetAllSettings(_ sender: Any?)
    {
        let alertController = UIAlertController(title: "Khôi phục toàn bộ cài đặt gốc?", message: "Mọi thiết lập tùy chỉnh trong SideStore sẽ quay về trạng thái mặc định ban đầu.", preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Đặt lại toàn bộ cài đặt", style: .destructive) { (action) in
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            UserDefaults.standard.synchronize()
            self.update()
        })
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel, handler: nil))
        
        if let popover = alertController.popoverPresentationController, let senderView = sender as? UIView {
            popover.sourceView = senderView
            popover.sourceRect = senderView.bounds
        }
        
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func resetPairingFile(_ sender: Any?)
    {
        let alertController = UIAlertController(
            title: "Đặt lại tệp ghép đôi (Pairing File)?",
            message: "Tệp ghép đôi hiện tại sẽ bị xóa và ứng dụng sẽ mở trình chọn tệp để bạn nạp tệp ghép đôi mới (hỗ trợ cả tệp tạo từ iOS 27 hoặc từ máy tính).",
            preferredStyle: .actionSheet
        )
        alertController.addAction(UIAlertAction(title: "Chọn tệp ghép đôi mới", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Minimuxer.resetPairingFile()
            
            let documentPicker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item, .propertyList, .data], asCopy: true)
            } else {
                documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item", "public.data", "com.apple.property-list"], in: .import)
            }
            documentPicker.delegate = self
            self.present(documentPicker, animated: true)
        })
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel, handler: nil))
        
        if let popover = alertController.popoverPresentationController, let senderView = sender as? UIView {
            popover.sourceView = senderView
            popover.sourceRect = senderView.bounds
        }
        
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction func resetAdiPb(_ sender: Any?)
    {
        let resetAdiAlertViewController = ResetAdiAlertViewController { [weak self] shouldResetConfirmed in
            guard let self else { return }
            if shouldResetConfirmed {
                Keychain.shared.resetAdiPb()
            }
        }
        self.present(resetAdiAlertViewController.alertController, animated: true, completion: nil)
    }
}

extension SettingsViewController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        do {
            try Minimuxer.importPairingFile(url)
            let alert = UIAlertController(title: "Thành công", message: "Đã nạp tệp ghép đôi (Pairing File) mới thành công!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: " Tuyệt vời", style: .default))
            self.present(alert, animated: true)
        } catch {
            let toastView = ToastView(error: error)
            toastView.show(in: self.navigationController?.view ?? self.view)
        }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let sectionType = Section.allCases[section]
        switch sectionType
        {
        case .signIn:
            return (DatabaseManager.shared.activeAccount() == nil) ? 1 : 0
            
        case .account:
            return (DatabaseManager.shared.activeAccount() != nil) ? AccountRow.allCases.count : 0
            
        case .patreon:
            // Ẩn hoàn toàn mục Patreon không cần thiết để trang Cài đặt gọn đẹp
            return 0
            
        case .instructions:
            // Đã tích hợp hướng dẫn chi tiết ở tab Tổng quan
            return 0
            
        case .activeAppIDs:
            guard let count = self.dataSource.fetchedResultsController.sections?.first?.numberOfObjects, count > 0 else { return 0 }
            return count
            
        case .debug:
            return 1
            
        default:
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let rowCount = self.tableView(tableView, numberOfRowsInSection: section)
        if rowCount == 0 {
            return 0.01
        }
        guard self.sectionHeaderTitle(for: Section.allCases[section]) != nil else {
            return 8
        }
        return 38
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let rowCount = self.tableView(tableView, numberOfRowsInSection: section)
        guard rowCount > 0 else { return nil }
        
        let sectionType = Section.allCases[section]
        guard let title = self.sectionHeaderTitle(for: sectionType) else { return nil }
        
        let container = UIView()
        container.backgroundColor = .clear
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13, weight: .heavy)
        label.textColor = UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let underline = UIView()
        underline.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // #007bff
        underline.layer.cornerRadius = 1.5
        underline.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(label)
        container.addSubview(underline)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: underline.topAnchor, constant: -4),
            
            underline.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            underline.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            underline.widthAnchor.constraint(equalToConstant: 36),
            underline.heightAnchor.constraint(equalToConstant: 3)
        ])
        
        return container
    }
    
    private func sectionHeaderTitle(for section: Section) -> String?
    {
        switch section
        {
        case .signIn:
            return "TÀI KHOẢN APPLE ID"
        case .refreshAttempts:
            return "NHẬT KÝ & CHẨN ĐOÁN"
        case .errorLog:
            return nil
        case .account:
            return "TÀI KHOẢN & CHỨNG CHỈ"
        case .patreon, .instructions:
            return nil
        case .server:
            return "MÁY CHỦ ANISETTE & JIT"
        case .backgroundRefresh:
            return "TỰ ĐỘNG LÀM MỚI & TÙY CHỌN"
        case .legacyDeactivation, .appLimit:
            return nil
        case .reset:
            return "KHÔI PHỤC & GHÉP ĐÔI (PAIRING)"
        case .debug:
            return "TÙY CHỈNH NÂNG CAO"
        case .activeAppIDs:
            if let team = self.activeProfile, team.type == .free, let count = self.dataSource.fetchedResultsController.sections?.first?.numberOfObjects
            {
                return "DANH SÁCH APP ID ĐANG HOẠT ĐỘNG (\(count)/10)"
            }
            return "DANH SÁCH APP ID ĐANG HOẠT ĐỘNG"
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        return nil
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        let rowCount = self.tableView(tableView, numberOfRowsInSection: section)
        guard rowCount > 0 else { return nil }
        
        let sectionType = Section.allCases[section]
        switch sectionType
        {
        case .backgroundRefresh:
            return "Tự động gia hạn các ứng dụng đã cài đặt ở chế độ nền khi kết nối Wi-Fi hoặc LocalDevVPN."
        case .legacyDeactivation:
            return "Cho phép hủy kích hoạt ứng dụng để nhường suất (slot) cho ứng dụng khác trên tài khoản Apple miễn phí."
        case .appLimit:
            return "Gỡ bỏ giới hạn tối đa 3 ứng dụng của tài khoản phát triển miễn phí (áp dụng trên các thiết bị hỗ trợ MacDirtyCow / KFD)."
        case .activeAppIDs:
            return "Tài khoản miễn phí chỉ được đăng ký tối đa 10 App ID mỗi tuần. Các App ID sẽ tự động giải phóng sau 7 ngày."
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int)
    {
        if let footer = view as? UITableViewHeaderFooterView {
            footer.textLabel?.textColor = UIColor(red: 0.42, green: 0.46, blue: 0.49, alpha: 1.0)
            footer.textLabel?.font = .systemFont(ofSize: 12, weight: .regular)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .activeAppIDs:
            let appIDIndexPath = IndexPath(row: indexPath.row, section: 0)
            let cell = self.dataSource.tableView(tableView, cellForRowAt: appIDIndexPath)
            styleCardCell(cell)
            return cell
            
        case .signIn:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            cell.textLabel?.text = "Đăng nhập bằng Apple ID"
            cell.textLabel?.font = .systemFont(ofSize: 15.5, weight: .bold)
            cell.textLabel?.textColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            styleCardCell(cell)
            return cell
            
        case .refreshAttempts:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            cell.textLabel?.text = "Lịch sử làm mới ứng dụng"
            cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            cell.textLabel?.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
            styleCardCell(cell)
            return cell
            
        case .errorLog:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            cell.textLabel?.text = "Nhật ký lỗi hệ thống (Error Logs)"
            cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            cell.textLabel?.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
            styleCardCell(cell)
            return cell
            
        case .account:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            styleCardCell(cell)
            
            let account = DatabaseManager.shared.activeAccount()
            let team = DatabaseManager.shared.activeTeam()
            
            let row = AccountRow.allCases[indexPath.row]
            switch row
            {
            case .appleID:
                cell.textLabel?.text = "Tài khoản Apple ID"
                cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                cell.textLabel?.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
                cell.detailTextLabel?.text = account?.appleID ?? "Chưa đăng nhập"
                cell.detailTextLabel?.textColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
                cell.detailTextLabel?.font = .systemFont(ofSize: 13.5, weight: .medium)
                
            case .activeTeam:
                cell.textLabel?.text = "Nhóm phát triển (Team)"
                cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                cell.textLabel?.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
                cell.detailTextLabel?.text = team?.name ?? "Không có"
                cell.detailTextLabel?.textColor = UIColor(red: 0.42, green: 0.46, blue: 0.49, alpha: 1.0)
                cell.detailTextLabel?.font = .systemFont(ofSize: 13.5, weight: .medium)
                
            case .certificates:
                cell.textLabel?.text = "Quản lý chứng chỉ ký"
                cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                cell.textLabel?.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
                cell.detailTextLabel?.text = self.activeProfile?.activeCertificate?.serialNumber != nil ? "Đang hoạt động" : "Chi tiết"
                cell.detailTextLabel?.textColor = UIColor(red: 0.08, green: 0.56, blue: 0.24, alpha: 1.0)
                cell.detailTextLabel?.font = .systemFont(ofSize: 13.5, weight: .semibold)
            }
            
            return cell

        case .server:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            styleCardCell(cell)
            let row = ServerRow.allCases[indexPath.row]
            switch row {
            case .anisetteServer:
                cell.textLabel?.text = "Máy chủ xác thực Anisette"
                cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                cell.textLabel?.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
            case .jitServer:
                cell.textLabel?.text = "Cấu hình máy chủ SideJIT"
                cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                cell.textLabel?.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
            }
            return cell
            
        case .backgroundRefresh:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            styleCardCell(cell)
            findAndTranslateLabels(in: cell, replacement: "Làm mới ứng dụng trong nền")
            return cell
            
        case .legacyDeactivation:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            styleCardCell(cell)
            findAndTranslateLabels(in: cell, replacement: "Cho phép hủy kích hoạt ứng dụng")
            return cell
            
        case .appLimit:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            styleCardCell(cell)
            findAndTranslateLabels(in: cell, replacement: "Gỡ giới hạn 3 ứng dụng (MDC)")
            return cell
            
        case .reset:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            styleCardCell(cell)
            if let row = ResetRow(rawValue: indexPath.row) {
                switch row {
                case .clearCache:
                    cell.textLabel?.text = "Xóa bộ nhớ đệm (Clear Cache)"
                    cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                    cell.textLabel?.textColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
                case .resetAll:
                    cell.textLabel?.text = "Đặt lại toàn bộ cài đặt"
                    cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                    cell.textLabel?.textColor = UIColor(red: 0.86, green: 0.20, blue: 0.25, alpha: 1.0)
                case .resetPairing:
                    cell.textLabel?.text = "Đặt lại tệp ghép đôi (Pairing File)"
                    cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                    cell.textLabel?.textColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
                case .resetAdiPb:
                    cell.textLabel?.text = "Đặt lại dữ liệu định danh (adi.pb)"
                    cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
                    cell.textLabel?.textColor = UIColor(red: 0.86, green: 0.20, blue: 0.25, alpha: 1.0)
                }
            }
            return cell
            
        case .debug:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            styleCardCell(cell)
            cell.textLabel?.text = "Tùy chỉnh nâng cao (Customizations)"
            cell.textLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
            cell.textLabel?.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
            return cell
            
        default:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            styleCardCell(cell)
            return cell
        }
    }
    
    // MARK: - Helper Styling for White CSS Cards (Viền kính ngọc trai + Bóng đổ Indigo)
    private func styleCardCell(_ cell: UITableViewCell)
    {
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        cell.contentView.backgroundColor = .clear
        cell.layer.borderWidth = 0.5
        cell.layer.borderColor = UIColor.white.cgColor
        
        let selectedBg = UIView()
        selectedBg.backgroundColor = UIColor(red: 0.91, green: 0.95, blue: 1.0, alpha: 0.9)
        cell.selectedBackgroundView = selectedBg
    }
    
    private func findAndTranslateLabels(in view: UIView, replacement: String)
    {
        for subview in view.subviews {
            if let label = subview as? UILabel {
                label.text = replacement
                label.font = .systemFont(ofSize: 15, weight: .semibold)
                label.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
                return
            }
            findAndTranslateLabels(in: subview, replacement: replacement)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .activeAppIDs: return UITableView.automaticDimension
        default: return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)
        impactFeedback.impactOccurred()
        
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.975, y: 0.975)
            }) { _ in
                UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.6, options: .allowUserInteraction, animations: {
                    cell.transform = .identity
                }, completion: nil)
            }
        }
        
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .account:
            let row = AccountRow.allCases[indexPath.row]
            switch row
            {
            case .appleID:
                self.signOut(tableView.cellForRow(at: indexPath))
                
            case .activeTeam:
                let controller = TeamsView().makeViewController()
                self.navigationController?.pushViewController(controller, animated: true)
                
            case .certificates:
                let controller = CertificatesView().makeViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            }
            
        case .server:
            let row = ServerRow.allCases[indexPath.row]
            switch row
            {
            case .anisetteServer:
                let controller = AnisetteDataView().makeViewController()
                self.navigationController?.pushViewController(controller, animated: true)
                
            case .jitServer:
                let controller = SideJITServerConfigView().makeViewController()
                self.navigationController?.pushViewController(controller, animated: true)
            }
            
        case .reset:
            guard let row = ResetRow(rawValue: indexPath.row) else { break }
            let cell = tableView.cellForRow(at: indexPath)
            switch row
            {
            case .clearCache:
                self.resetAppCache(cell)
            case .resetAll:
                self.resetAllSettings(cell)
            case .resetPairing:
                self.resetPairingFile(cell)
            case .resetAdiPb:
                self.resetAdiPb(cell)
            }
            
        case .debug:
            let controller = UserCustomizationsView().makeViewController()
            self.navigationController?.pushViewController(controller, animated: true)
            
        default: break
        }
    }
}
