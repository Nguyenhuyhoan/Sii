
//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import Intents
import IntentsUI
import SafariServices
import UniformTypeIdentifiers
import SwiftUI

import AltStoreCore
import Roxas
import Minimuxer

extension SettingsViewController {
    private enum Section: Int, CaseIterable {
        case appleID, activeTeam, backgroundRefresh, cellularRefresh, appLimit, useMainProfile, patreon, pairingFile, errorLog, customizations, instructions, troubleshooting
    }

    private enum InstructionLink: Int, CaseIterable {
        case step1, step2, step3
        var url: URL {
            switch self {
            case .step1: return URL(string: "https://Getting-Started/#installing-wireguard")!
            case .step2: return URL(string: "https://Getting-Started/#generate-the-pairing-file")!
            case .step3: return URL(string: "https://Getting-Started/#install-sidestore")!
            }
        }
    }

    private enum TroubleshootingRow: Int, CaseIterable {
        case resetAll, clearCache, EnforceFallback
    }
}

final class SettingsViewController: UITableViewController {
    private var account: Account?
    private var team: Team?
    private var isFetchingPatrons = true
    private var fetchPatronsError: Error?

    private var debugTapCount = 0
    private var showDebugSection = false

    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    @IBOutlet private var cellularRefreshSwitch: UISwitch!
    @IBOutlet private var appLimitSwitch: UISwitch!
    @IBOutlet private var useMainProfileSwitch: UISwitch!

    @IBOutlet private var signOutBarButtonItem: UIBarButtonItem!
    @IBOutlet private var footerView: UIView!
    @IBOutlet private var signOutButton: UIButton!
    @IBOutlet private var versionLabel: UILabel!

    @IBOutlet var mastodonButton: UIButton!
    @IBOutlet var threadsButton: UIButton!
    @IBOutlet var twitterButton: UIButton!
    @IBOutlet var githubButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Đồng bộ thanh Navigation Bar kính mờ (.site-header) từ ThemeManager
        applyCSSNavigationBar(tintColor: AppUI.Colors.blue, transparentEdge: true)

        let bgView = UIView(frame: view.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bgView.applyCSSBodyGradient()
        tableView.backgroundView = bgView
        tableView.backgroundColor = .clear
        tableView.separatorColor = AppUI.Colors.border
        footerView.backgroundColor = .clear

        // Đồng bộ màu các nút gạt UISwitch theo bảng màu CSS
        [backgroundRefreshSwitch, cellularRefreshSwitch, appLimitSwitch, useMainProfileSwitch].forEach {
            $0?.onTintColor = AppUI.Colors.green
            $0?.tintColor = AppUI.Colors.border
        }

        // Làm đẹp các nút Icon mạng xã hội (Mastodon, Threads, Twitter, GitHub) từ ThemeManager
        [mastodonButton, threadsButton, twitterButton, githubButton].forEach {
            $0?.applyCSSSocialIconStyle()
        }

        // Nút Sign Out theo chuẩn nút CSS (.btn-color-1 / destructive)
        signOutButton.configuration = nil
        signOutButton.applyCSSButton(title: AppStrings.Settings.signOut, style: .destructiveRed, fontSize: 16)

        tableView.register(SettingsHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "HeaderView")
        tableView.register(SettingsHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: "FooterView")

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapVersionLabel(_:)))
        versionLabel.addGestureRecognizer(tapGesture)
        versionLabel.isUserInteractionEnabled = true

        NotificationCenter.default.addObserver(self, selector: #selector(didUpdatePatrons(_:)), name: PatreonAPI.didUpdatePatronsNotification, object: nil)
        update()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.backgroundView?.updateCSSBodyGradientFrame()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchPatronsIfNeeded()
        update()
    }
}

private extension SettingsViewController {
    var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        var build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        if let index = build.range(of: ".", options: .backwards)?.upperBound {
            build = String(build[index...])
        }
        return version == build ? "SideStore \(version)" : "SideStore \(version) (\(build))"
    }

    var iosVersionText: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        var versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion)"
        if osVersion.patchVersion != 0 { versionString += ".\(osVersion.patchVersion)" }
        let buildString = Self.osBuildString() ?? "Unknown"
        return "\(UIDevice.current.systemName) \(versionString) (\(buildString))"
    }

    static func osBuildString() -> String? {
        var size: Int = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    func update() {
        account = DatabaseManager.shared.activeAccount()
        team = DatabaseManager.shared.activeTeam()

        navigationItem.rightBarButtonItem = (account == nil) ? nil : signOutBarButtonItem

        versionLabel.numberOfLines = 0
        versionLabel.attributedText = UILabel.makeCSSVersionAttributedString(appVersion: appVersionText, iosVersion: iosVersionText)

        backgroundRefreshSwitch.isOn = UserDefaults.standard.isBackgroundRefreshEnabled
        cellularRefreshSwitch.isOn = UserDefaults.standard.isCellularRefreshEnabled
        appLimitSwitch.isOn = UserDefaults.standard.isAppLimitDisabled
        useMainProfileSwitch.isOn = UserDefaults.standard.useMainProfile

        signOutButton.isHidden = (account == nil)

        footerView.layoutIfNeeded()
        let height = footerView.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height)).height
        footerView.frame.size.height = height
        tableView.tableFooterView = footerView

        tableView.reloadData()
    }

    func signIn() {
        guard Minimuxer.ready() else {
            let alert = UIAlertController(
                title: AppStrings.Settings.noPairingFileTitle,
                message: AppStrings.Settings.noPairingFileMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: RSTSystemLocalizedString("OK"), style: .default))
            present(alert, animated: true)
            return
        }

        AppManager.shared.authenticate(presentingViewController: self) { result in
            DispatchQueue.main.async {
                switch result {
                case .failure(AuthenticationError.cancelled): break
                case .failure(let error):
                    ToastView(error: error, opensLog: true).show(in: self.navigationController?.view ?? self.view)
                case .success:
                    self.update()
                }
            }
        }
    }

    @IBAction func signOut(_ sender: Any) {
        let alert = UIAlertController(
            title: AppStrings.Settings.signOutConfirmTitle,
            message: AppStrings.Settings.signOutConfirmMessage,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: AppStrings.Settings.signOut, style: .destructive) { _ in
            DatabaseManager.shared.signOut { error in
                DispatchQueue.main.async {
                    if let error { ToastView(error: error, opensLog: true).show(in: self) }
                    self.update()
                }
            }
        })
        alert.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel))
        present(alert, animated: true)
    }

    @IBAction func toggleBackgroundRefresh(_ sender: UISwitch) {
        UserDefaults.standard.isBackgroundRefreshEnabled = sender.isOn
    }

    @IBAction func toggleCellularRefresh(_ sender: UISwitch) {
        UserDefaults.standard.isCellularRefreshEnabled = sender.isOn
    }

    @IBAction func toggleAppLimit(_ sender: UISwitch) {
        guard sender.isOn else {
            UserDefaults.standard.isAppLimitDisabled = false
            return
        }
        let alert = UIAlertController(
            title: AppStrings.Settings.removeAppLimitTitle,
            message: AppStrings.Settings.removeAppLimitMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel) { _ in
            sender.setOn(false, animated: true)
        })
        alert.addAction(UIAlertAction(title: AppStrings.Settings.removeAppLimitConfirm, style: .default) { _ in
            UserDefaults.standard.isAppLimitDisabled = true
        })
        present(alert, animated: true)
    }

    @IBAction func toggleUseMainProfile(_ sender: UISwitch) {
        guard sender.isOn else {
            UserDefaults.standard.useMainProfile = false
            return
        }
        let alert = UIAlertController(
            title: AppStrings.Settings.useMainProfileTitle,
            message: AppStrings.Settings.useMainProfileMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel) { _ in
            sender.setOn(false, animated: true)
        })
        alert.addAction(UIAlertAction(title: AppStrings.Settings.useMainProfileConfirm, style: .default) { _ in
            UserDefaults.standard.useMainProfile = true
        })
        present(alert, animated: true)
    }

    @IBAction func openMastodon(_ sender: UIButton) { open(URL(string: "https://fosstodon.org/@sidestore")!, sender: sender) }
    @IBAction func openThreads(_ sender: UIButton) { open(URL(string: "https://www.threads.net/@sidestore.io")!, sender: sender) }
    @IBAction func openTwitter(_ sender: UIButton) { open(URL(string: "https://twitter.com/SideStore_io")!, sender: sender) }
    @IBAction func openGitHub(_ sender: UIButton) { open(URL(string: "https://github.com/SideStore/SideStore")!, sender: sender) }

    func open(_ url: URL, sender: Any?) {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = AppUI.Colors.blue
        present(safariVC, animated: true)
    }

    @objc func resetPairingFile(_ sender: Any) {
        let docPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .xml, .propertyList, .item], asCopy: true)
        docPicker.delegate = self
        docPicker.allowsMultipleSelection = false
        present(docPicker, animated: true)
    }

    func resetAll() {
        let alert = UIAlertController(
            title: AppStrings.Settings.resetConfirmTitle,
            message: AppStrings.Settings.resetConfirmMessage,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: AppStrings.Settings.resetAllAction, style: .destructive) { _ in
            AppManager.shared.resetAll()
        })
        alert.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel))
        present(alert, animated: true)
    }

    func clearCache() {
        let alert = UIAlertController(
            title: AppStrings.Settings.clearCacheConfirmTitle,
            message: AppStrings.Settings.clearCacheConfirmMessage,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: AppStrings.Settings.clearCacheAction, style: .destructive) { _ in
            AppManager.shared.clearCache()
        })
        alert.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel))
        present(alert, animated: true)
    }

    func enforceFallback() {
        let isEnforced = UserDefaults.standard.enforceRefreshFallback
        let title = isEnforced ? AppStrings.Settings.disableFallbackTitle : AppStrings.Settings.enableFallbackTitle
        let message = isEnforced ? AppStrings.Settings.disableFallbackMessage : AppStrings.Settings.enableFallbackMessage
        let actionTitle = isEnforced ? AppStrings.Settings.disableFallbackAction : AppStrings.Settings.enableFallbackAction

        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: actionTitle, style: .destructive) { _ in
            UserDefaults.standard.enforceRefreshFallback.toggle()
            self.tableView.reloadSections(IndexSet(integer: Section.troubleshooting.rawValue), with: .automatic)
        })
        alert.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel))
        present(alert, animated: true)
    }

    func fetchPatronsIfNeeded() {
        guard PatreonAPI.shared.isAuthenticated else { return }
        PatreonAPI.shared.updatePatrons { result in
            DispatchQueue.main.async {
                self.isFetchingPatrons = false
                if case .failure(let error) = result { self.fetchPatronsError = error }
                self.tableView.reloadSections([Section.patreon.rawValue], with: .none)
            }
        }
    }

    @objc func didUpdatePatrons(_ notification: Notification) {
        DispatchQueue.main.async {
            self.tableView.reloadSections([Section.patreon.rawValue], with: .none)
        }
    }

    @objc func didTapVersionLabel(_ gesture: UITapGestureRecognizer) {
        UIPasteboard.general.string = "\(appVersionText)\n\(iosVersionText)"
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        UIView.transition(with: versionLabel, duration: 0.2, options: .transitionCrossDissolve) {
            self.versionLabel.attributedText = UILabel.makeCSSCopiedAttributedString(copiedText: AppStrings.Common.copied())
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            UIView.transition(with: self.versionLabel, duration: 0.25, options: .transitionCrossDissolve) {
                self.versionLabel.attributedText = UILabel.makeCSSVersionAttributedString(appVersion: self.appVersionText, iosVersion: self.iosVersionText)
            }
        }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension SettingsViewController {
    override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section.allCases[section] {
        case .activeTeam where team == nil: return 0
        case .appLimit where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return 0
        case .useMainProfile where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return 0
        case .patreon: return 0
        default: return super.tableView(tableView, numberOfRowsInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section.allCases[section] {
        case .activeTeam where team == nil: return nil
        case .appLimit where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return nil
        case .useMainProfile where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return nil
        case .patreon: return nil
        default: return super.tableView(tableView, titleForHeaderInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section.allCases[section] {
        case .activeTeam where team == nil: return nil
        case .appLimit where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return nil
        case .useMainProfile where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return nil
        case .patreon: return nil
        default: return super.tableView(tableView, titleForFooterInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section.allCases[section] {
        case .activeTeam where team == nil: return .leastNormalMagnitude
        case .appLimit where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return .leastNormalMagnitude
        case .useMainProfile where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return .leastNormalMagnitude
        case .patreon: return .leastNormalMagnitude
        default: return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch Section.allCases[section] {
        case .activeTeam where team == nil: return .leastNormalMagnitude
        case .appLimit where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return .leastNormalMagnitude
        case .useMainProfile where !(Bundle.main.alt_bundleIdentifier?.contains("SideStore") ?? false): return .leastNormalMagnitude
        case .patreon: return .leastNormalMagnitude
        default: return super.tableView(tableView, heightForFooterInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = self.tableView(tableView, titleForHeaderInSection: section) else { return nil }
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderView") as! SettingsHeaderFooterView
        view.configure(with: title, style: .header)
        view.textLabel?.textColor = AppUI.Colors.blue
        view.textLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        return view
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let text = self.tableView(tableView, titleForFooterInSection: section) else { return nil }
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FooterView") as! SettingsHeaderFooterView
        view.configure(with: text, style: .footer)
        view.textLabel?.textColor = AppUI.Colors.dark.withAlphaComponent(0.75)
        return view
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.applyCSSTableCellStyle()

        switch Section.allCases[indexPath.section] {
        case .appleID:
            if let account {
                cell.textLabel?.text = account.name
                cell.detailTextLabel?.text = account.appleID
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
            } else {
                cell.textLabel?.text = AppStrings.Settings.signInWithAppleID
                cell.textLabel?.textColor = AppUI.Colors.blue
                cell.detailTextLabel?.text = nil
                cell.accessoryType = .none
            }

        case .activeTeam:
            if let team {
                cell.textLabel?.text = team.name
                cell.detailTextLabel?.text = team.type.localizedDescription
                cell.accessoryType = .disclosureIndicator
            }

        case .pairingFile:
            cell.textLabel?.text = AppStrings.Settings.resetPairingFile
            cell.textLabel?.textColor = AppUI.Colors.blue

        case .troubleshooting:
            switch TroubleshootingRow.allCases[indexPath.row] {
            case .resetAll:
                cell.textLabel?.text = AppStrings.Settings.resetAllRow
                cell.textLabel?.textColor = AppUI.Colors.red
            case .clearCache:
                cell.textLabel?.text = AppStrings.Settings.clearCacheRow
                cell.textLabel?.textColor = AppUI.Colors.blue
            case .EnforceFallback:
                let isEnforced = UserDefaults.standard.enforceRefreshFallback
                cell.textLabel?.text = isEnforced ? AppStrings.Settings.disableFallbackRow : AppStrings.Settings.enableFallbackRow
                cell.textLabel?.textColor = isEnforced ? AppUI.Colors.green : AppUI.Colors.orange
            }

        default: break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section.allCases[indexPath.section] {
        case .appleID:
            if account == nil { signIn() }

        case .pairingFile:
            resetPairingFile(tableView)

        case .instructions:
            let link = InstructionLink.allCases[indexPath.row]
            open(link.url, sender: tableView.cellForRow(at: indexPath))

        case .troubleshooting:
            switch TroubleshootingRow.allCases[indexPath.row] {
            case .resetAll: resetAll()
            case .clearCache: clearCache()
            case .EnforceFallback: enforceFallback()
            }

        default: break
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension SettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            let data = try Data(contentsOf: url)
            if let docDir = FileManager.default.documentsDirectory {
                try? data.write(to: docDir.appendingPathComponent("ALTPairingFile.mobiledevicepairing"), options: .atomic)
            }
            AppManager.shared.installPairingFile(data: data) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        ToastView(error: error, opensLog: true).show(in: self)
                    } else {
                        let alert = UIAlertController(title: AppStrings.Settings.pairingSuccessTitle, message: nil, preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: RSTSystemLocalizedString("OK"), style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        } catch {
            ToastView(error: error, opensLog: true).show(in: self)
        }
    }
}
