
//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import StoreKit
import Intents
import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication
import Minimuxer
import Nuke
import SemanticVersion

extension SettingsViewController
{
    private enum Section: Int, CaseIterable
    {
        case appleID
        case patreon
        case pairingFile
        case refreshAttempts
        case errorLog
        case jit
        case app
        case userCustomizations
        case debug
    }
    
    private enum AppleIDRow: Int, CaseIterable
    {
        case account
        case activeProfile
        case server
    }
    
    private enum PatreonRow: Int, CaseIterable
    {
        case account
        case about
    }
    
    private enum PairingFileRow: Int, CaseIterable
    {
        case reset
        case export
        case test
    }
    
    private enum JITRow: Int, CaseIterable
    {
        case customUrl
    }
    
    private enum AppRow: Int, CaseIterable
    {
        case backgroundRefresh
        case siriShortcuts
        case appIcon
    }
    
    private enum DebugRow: Int, CaseIterable
    {
        case clearCache
        case appGrouping
        case enforceThreeAppLimit
        case syncTrustedSources
        case resetAllSettings
    }
}

class SettingsViewController: UITableViewController
{
    private var prototypeAboutPatreonCell: AboutPatreonTableViewCell!
    
    private var patrons = [Patron]()
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }()
    
    @IBOutlet private var accountLabel: UILabel!
    @IBOutlet private var signInButton: UIButton!
    @IBOutlet private var activeTeamLabel: UILabel!
    @IBOutlet private var serverHeaderTextView: UITextView!
    @IBOutlet private var serverFooterTextView: UITextView!
    @IBOutlet private var anisetteServerButton: UIButton!
    
    @IBOutlet private var patreonAccountLabel: UILabel!
    @IBOutlet private var patreonButton: UIButton!
    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    @IBOutlet private var clearCacheButton: UIButton!
    @IBOutlet private var appGroupingSwitch: UISwitch!
    @IBOutlet private var enforceThreeAppLimitSwitch: UISwitch!
    @IBOutlet private var syncTrustedSourcesSwitch: UISwitch!
    @IBOutlet private var resetPairingFileButton: UIButton!
    @IBOutlet private var exportPairingFileButton: UIButton!
    @IBOutlet private var testPairingFileButton: UIButton!
    @IBOutlet private var resetAllSettingsButton: UIButton!
    @IBOutlet private var jitURLTextField: UITextField!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.prototypeAboutPatreonCell = AboutPatreonTableViewCell.instantiate(with: AboutPatreonTableViewCell.nib!)
        self.prototypeAboutPatreonCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.tableView.backgroundColor = .altBackground
        
        self.tableView.register(AboutPatreonTableViewCell.nib, forCellReuseIdentifier: "AboutPatreonCell")
        self.tableView.register(RefreshAttemptTableViewCell.self, forCellReuseIdentifier: "RefreshAttemptCell")
        self.tableView.register(PatreonGoalTableViewHeaderView.self, forHeaderFooterViewReuseIdentifier: "PatreonHeaderView")
        self.tableView.register(SettingsFooterView.nib, forHeaderFooterViewReuseIdentifier: "FooterView")
        
        self.signInButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        self.patreonButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        self.clearCacheButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SettingsViewController.dismissKeyboard))
        tapGestureRecognizer.cancelsTouchesInView = false
        self.tableView.addGestureRecognizer(tapGestureRecognizer)
        
        self.serverHeaderTextView.textContainerInset = .zero
        self.serverHeaderTextView.textContainer.lineFragmentPadding = 0
        self.serverFooterTextView.textContainerInset = .zero
        self.serverFooterTextView.textContainer.lineFragmentPadding = 0
        
        self.jitURLTextField.text = UserDefaults.standard.textFieldJITURL
        self.jitURLTextField.delegate = self

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        
        let headerString = AppStrings.Settings.Server.headerDescription
        let headerAttributedString = NSMutableAttributedString(string: headerString, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .footnote),
            .foregroundColor: UIColor.systemGray,
            .paragraphStyle: paragraphStyle
        ])
        
        if let linkRange = headerString.range(of: AppStrings.Settings.Server.hostYourOwnLink)
        {
            headerAttributedString.addAttributes([
                .link: URL(string: "https://wiki.sidestore.io/guides/custom-anisette/")!
            ], range: NSRange(linkRange, in: headerString))
        }
        self.serverHeaderTextView.attributedText = headerAttributedString
        
        let footerString = AppStrings.Settings.Server.footerDescription
        let footerAttributedString = NSMutableAttributedString(string: footerString, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .footnote),
            .foregroundColor: UIColor.systemGray,
            .paragraphStyle: paragraphStyle
        ])
        self.serverFooterTextView.attributedText = footerAttributedString
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.didUpdatePatrons(_:)), name: AppManager.didUpdatePatronsNotification, object: nil)
        
        self.fetchPatrons()
        self.prepareAnisetteServerMenu()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.update()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let insets = self.tableView.separatorInset
        let width = self.tableView.bounds.width - (insets.left + insets.right)
        
        if self.prototypeAboutPatreonCell.contentView.bounds.size.width != width
        {
            self.prototypeAboutPatreonCell.contentView.bounds.size.width = width
            self.tableView.reloadData()
        }
    }
}

private extension SettingsViewController
{
    func update()
    {
        if let team = DatabaseManager.shared.activeTeam()
        {
            self.accountLabel.text = "\(team.account.name) (\(team.account.appleID))"
            self.signInButton.setTitle(AppStrings.Settings.signOut, for: .normal)
            self.signInButton.tintColor = .refreshRed
            
            self.activeTeamLabel.text = "\(team.name) (\(team.type.localizedDescription))"
        }
        else
        {
            self.accountLabel.text = AppStrings.Settings.none
            self.signInButton.setTitle(AppStrings.Settings.signIn, for: .normal)
            self.signInButton.tintColor = .altPrimary
            
            self.activeTeamLabel.text = AppStrings.Settings.none
        }
        
        if PatreonAPI.shared.isAuthenticated
        {
            if let account = DatabaseManager.shared.patreonAccount()
            {
                self.patreonAccountLabel.text = account.name
            }
            else
            {
                self.patreonAccountLabel.text = AppStrings.Settings.none
            }
            
            self.patreonButton.setTitle(AppStrings.Settings.unlinkPatreon, for: .normal)
            self.patreonButton.tintColor = .refreshRed
        }
        else
        {
            self.patreonAccountLabel.text = AppStrings.Settings.none
            self.patreonButton.setTitle(AppStrings.Settings.linkPatreon, for: .normal)
            self.patreonButton.tintColor = .altPrimary
        }
        
        self.backgroundRefreshSwitch.isOn = UserDefaults.standard.isBackgroundRefreshEnabled
        self.appGroupingSwitch.isOn = !UserDefaults.standard.isAppGroupingDisabled
        self.enforceThreeAppLimitSwitch.isOn = UserDefaults.shared.enforceThreeAppLimit
        self.syncTrustedSourcesSwitch.isOn = UserDefaults.standard.syncTrustedSources
        
        self.tableView.reloadData()
    }
    
    func fetchPatrons()
    {
        DispatchQueue.global().async {
            let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
            context.performAndWait {
                let fetchRequest = Patron.fetchRequest() as NSFetchRequest<Patron>
                fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(Patron.name), ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))]
                
                do
                {
                    let patrons = try context.fetch(fetchRequest)
                    
                    DispatchQueue.main.async {
                        self.patrons = patrons
                        
                        UIView.performWithoutAnimation {
                            self.tableView.reloadSections([Section.patreon.rawValue], with: .none)
                        }
                    }
                }
                catch
                {
                    print("Failed to fetch Patrons:", error)
                }
            }
        }
        
        AppManager.shared.updatePatronsIfNeeded()
    }
    
    func prepareAnisetteServerMenu()
    {
        self.anisetteServerButton.showsMenuAsPrimaryAction = true
        self.anisetteServerButton.changesSelectionAsPrimaryAction = true
        
        let currentURL = UserDefaults.standard.menuAnisetteURL
        var isCustomSelected = !AnisetteServer.currentServers.contains(where: { $0.url == currentURL })
        
        // Check if currentURL is empty (initial state)
        if currentURL.isEmpty, let firstServer = AnisetteServer.currentServers.first {
            UserDefaults.standard.menuAnisetteURL = firstServer.url
            isCustomSelected = false
        }
        
        var actions: [UIMenuElement] = AnisetteServer.currentServers.map { server in
            let isSelected = (server.url == UserDefaults.standard.menuAnisetteURL)
            return UIAction(title: server.name, subtitle: server.url, state: isSelected ? .on : .off) { _ in
                UserDefaults.standard.menuAnisetteURL = server.url
                UserDefaults.standard.isCustomAnisetteServer = false
                self.prepareAnisetteServerMenu()
            }
        }
        
        let customSubtitle = isCustomSelected ? UserDefaults.standard.customAnisetteURL : AppStrings.Settings.Server.enterCustomURL
        let customAction = UIAction(title: AppStrings.Settings.Server.custom, subtitle: customSubtitle, state: isCustomSelected ? .on : .off) { [weak self] _ in
            self?.promptForCustomAnisetteURL()
        }
        actions.append(customAction)
        
        self.anisetteServerButton.menu = UIMenu(title: AppStrings.Settings.Server.selectAnisetteServer, children: actions)
    }
    
    func promptForCustomAnisetteURL()
    {
        let alertController = UIAlertController(title: AppStrings.Settings.Server.customAnisetteServerTitle, message: AppStrings.Settings.Server.customAnisetteServerMessage, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "https://anisette.example.com"
            textField.text = UserDefaults.standard.customAnisetteURL
            textField.keyboardType = .URL
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
        }
        
        let cancelAction = UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel) { [weak self] _ in
            self?.prepareAnisetteServerMenu()
        }
        alertController.addAction(cancelAction)
        
        let saveAction = UIAlertAction(title: AppStrings.Common.save, style: .default) { [weak self] _ in
            guard let text = alertController.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty,
                  let url = URL(string: text),
                  url.scheme != nil, url.host != nil else {
                self?.presentAlert(title: AppStrings.Error.invalidURLTitle, message: AppStrings.Error.invalidURLMessage)
                self?.prepareAnisetteServerMenu()
                return
            }
            
            UserDefaults.standard.customAnisetteURL = text
            UserDefaults.standard.menuAnisetteURL = text
            UserDefaults.standard.isCustomAnisetteServer = true
            self?.prepareAnisetteServerMenu()
        }
        alertController.addAction(saveAction)
        
        self.present(alertController, animated: true)
    }
    
    func presentAlert(title: String, message: String)
    {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: systemLocalizedString("OK"), style: .default))
        self.present(alert, animated: true)
    }
    
    @objc func dismissKeyboard()
    {
        self.view.endEditing(true)
    }
}

private extension SettingsViewController
{
    @IBAction func authenticate(_ sender: UIButton)
    {
        if let team = DatabaseManager.shared.activeTeam()
        {
            let alertController = UIAlertController(title: AppStrings.Settings.signOutConfirmTitle, message: AppStrings.Settings.signOutConfirmMessage, preferredStyle: .actionSheet)
            alertController.popoverPresentationController?.sourceView = sender
            alertController.popoverPresentationController?.sourceRect = sender.bounds
            alertController.addAction(UIAlertAction(title: AppStrings.Settings.signOut, style: .destructive) { (action) in
                DatabaseManager.shared.signOut { (error) in
                    DispatchQueue.main.async {
                        if let error = error
                        {
                            let toastView = ToastView(error: error)
                            toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                        }
                        
                        self.update()
                    }
                }
            })
            alertController.addAction(.cancel)
            self.present(alertController, animated: true, completion: nil)
        }
        else
        {
            AuthenticationViewController.authenticate { (result) in
                switch result
                {
                case .failure(OperationError.cancelled): break // Ignore
                case .failure(let error):
                    DispatchQueue.main.async {
                        let toastView = ToastView(error: error)
                        toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                    }
                    
                case .success((let account, let team, _)):
                    let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
                    context.performAndWait {
                        let account = context.object(with: account.objectID) as! Account
                        account.isActiveAccount = true
                        
                        let team = context.object(with: team.objectID) as! Team
                        team.isActiveTeam = true
                        
                        do
                        {
                            try context.save()
                        }
                        catch
                        {
                            print("Failed to save active account and team.", error)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.update()
                }
            }
        }
    }
    
    @IBAction func linkPatreonAccount(_ sender: UIButton)
    {
        guard !PatreonAPI.shared.isAuthenticated else {
            let alertController = UIAlertController(title: AppStrings.Settings.unlinkPatreonConfirmTitle, message: AppStrings.Settings.unlinkPatreonConfirmMessage, preferredStyle: .actionSheet)
            alertController.popoverPresentationController?.sourceView = sender
            alertController.popoverPresentationController?.sourceRect = sender.bounds
            alertController.addAction(UIAlertAction(title: AppStrings.Settings.unlinkPatreon, style: .destructive) { (action) in
                PatreonAPI.shared.signOut { (result) in
                    DispatchQueue.main.async {
                        do
                        {
                            try result.get()
                        }
                        catch
                        {
                            let toastView = ToastView(error: error)
                            toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                        }
                        
                        self.update()
                    }
                }
            })
            alertController.addAction(.cancel)
            self.present(alertController, animated: true, completion: nil)
            
            return
        }
        
        PatreonAPI.shared.authenticate(presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                do
                {
                    let account = try result.get()
                    try account.managedObjectContext?.save()
                }
                catch OperationError.cancelled
                {
                    // Ignore
                }
                catch
                {
                    let toastView = ToastView(error: error)
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                }
                
                self.update()
            }
        }
    }
    
    @IBAction func toggleBackgroundRefresh(_ sender: UISwitch)
    {
        UserDefaults.standard.isBackgroundRefreshEnabled = sender.isOn
    }
    
    @IBAction func clearAppCache(_ sender: UIButton)
    {
        let alertController = UIAlertController(title: AppStrings.Settings.clearCacheConfirmTitle, message: nil, preferredStyle: .actionSheet)
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.bounds
        alertController.addAction(UIAlertAction(title: AppStrings.Settings.clearCache, style: .destructive) { (action) in
            AppManager.shared.clearAppCache { (result) in
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                        
                    case .success:
                        let toastView = ToastView(text: AppStrings.Settings.clearedAppCache, detailText: nil)
                        toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                    }
                }
            }
        })
        alertController.addAction(.cancel)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func toggleAppGrouping(_ sender: UISwitch)
    {
        UserDefaults.standard.isAppGroupingDisabled = !sender.isOn
    }
    
    @IBAction func toggleEnforceThreeAppLimit(_ sender: UISwitch)
    {
        UserDefaults.shared.enforceThreeAppLimit = sender.isOn
    }
    
    @IBAction func toggleSyncTrustedSources(_ sender: UISwitch)
    {
        UserDefaults.standard.syncTrustedSources = sender.isOn
    }
    
    @IBAction func resetPairingFile(_ sender: UIButton)
    {
        let alertController = UIAlertController(
            title: AppStrings.Settings.PairingFile.resetConfirmTitle,
            message: AppStrings.Settings.PairingFile.resetConfirmMessage,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.bounds
        alertController.addAction(UIAlertAction(title: AppStrings.Settings.PairingFile.reset, style: .destructive) { _ in
            MinimizeManager.shared.removePairingFile()
            
            MinimizeManager.shared.PromptForPairingFile(presentingViewController: self) { success in
                if success {
                    DispatchQueue.main.async {
                        self.presentAlert(
                            title: AppStrings.Settings.PairingFile.importSuccessTitle,
                            message: AppStrings.Settings.PairingFile.importSuccessMessage
                        )
                    }
                }
            }
        })
        alertController.addAction(.cancel)
        self.present(alertController, animated: true)
    }
    
    @IBAction func exportPairingFile(_ sender: UIButton)
    {
        guard let pairingFileURL = MinimizeManager.shared.pairingFileURL,
              FileManager.default.fileExists(atPath: pairingFileURL.path) else {
            self.presentAlert(
                title: AppStrings.Settings.PairingFile.notFoundTitle,
                message: AppStrings.Settings.PairingFile.notFoundMessage
            )
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [pairingFileURL], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = sender
        activityViewController.popoverPresentationController?.sourceRect = sender.bounds
        self.present(activityViewController, animated: true)
    }
    
    @IBAction func testPairingFile(_ sender: UIButton)
    {
        do {
            try MinimizeManager.shared.testPairingFile()
            self.presentAlert(
                title: AppStrings.Settings.PairingFile.testSuccessTitle,
                message: AppStrings.Settings.PairingFile.testSuccessMessage
            )
        } catch {
            self.presentAlert(
                title: AppStrings.Settings.PairingFile.testFailedTitle,
                message: error.localizedDescription
            )
        }
    }
    
    @IBAction func resetAllSettings(_ sender: UIButton)
    {
        let alertController = UIAlertController(
            title: AppStrings.Settings.resetAllConfirmTitle,
            message: AppStrings.Settings.resetAllConfirmMessage,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.bounds
        alertController.addAction(UIAlertAction(title: AppStrings.Settings.resetAll, style: .destructive) { _ in
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            UserDefaults.shared.removePersistentDomain(forName: Bundle.main.altstoreAppGroup)
            self.update()
            self.prepareAnisetteServerMenu()
        })
        alertController.addAction(.cancel)
        self.present(alertController, animated: true)
    }
    
    @objc func openPatreonSettings(_ sender: UIBarButtonItem)
    {
        let patreonSettingsURL = URL(string: "https://www.patreon.com/RileyTestut")!
        UIApplication.shared.open(patreonSettingsURL, options: [:], completionHandler: nil)
    }
    
    @objc func didUpdatePatrons(_ notification: Notification)
    {
        self.fetchPatrons()
    }
}

extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        var sections = Section.allCases.count
        if !Bundle.main.isMainAltStore
        {
            // Hide debug section
            sections -= 1
        }
        
        return sections
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        switch section
        {
        case .appleID:
            if DatabaseManager.shared.activeTeam() == nil
            {
                // Hide active profile cell when not signed in.
                return super.tableView(tableView, numberOfRowsInSection: section.rawValue) - 1
            }
            else
            {
                return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            }
            
        case .patreon:
            return 2 + self.patrons.count
            
        case .refreshAttempts:
            let refreshAttempts = DatabaseManager.shared.refreshAttempts()
            return refreshAttempts.isEmpty ? 0 : 1
            
        case .errorLog:
            let loggedErrors = DatabaseManager.shared.loggedErrors()
            return loggedErrors.isEmpty ? 0 : 1
            
        case .app:
            var count = super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            if !UIApplication.shared.supportsAlternateIcons
            {
                count -= 1
            }
            
            return count
            
        default:
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        switch Section.allCases[indexPath.section]
        {
        case .appleID:
            if DatabaseManager.shared.activeTeam() == nil && indexPath.row >= AppleIDRow.activeProfile.rawValue
            {
                // Shift rows up to account for hidden activeProfile cell
                let shiftedIndexPath = IndexPath(row: indexPath.row + 1, section: indexPath.section)
                return super.tableView(tableView, cellForRowAt: shiftedIndexPath)
            }
            else
            {
                return super.tableView(tableView, cellForRowAt: indexPath)
            }
            
        case .patreon where indexPath.row == PatreonRow.about.rawValue:
            let cell = tableView.dequeueReusableCell(withIdentifier: "AboutPatreonCell", for: indexPath) as! AboutPatreonTableViewCell
            cell.supportButton.addTarget(self, action: #selector(SettingsViewController.openPatreonSettings(_:)), for: .touchUpInside)
            return cell
            
        case .patreon where indexPath.row > PatreonRow.about.rawValue:
            let patronIndex = indexPath.row - 2
            let patron = self.patrons[patronIndex]
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "PatronCell") ?? UITableViewCell(style: .default, reuseIdentifier: "PatronCell")
            cell.selectionStyle = .none
            cell.backgroundColor = .altCellBackground
            
            cell.textLabel?.text = patron.name
            cell.textLabel?.textColor = .white
            
            return cell
            
        default:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        switch Section.allCases[indexPath.section]
        {
        case .appleID:
            if DatabaseManager.shared.activeTeam() == nil && indexPath.row >= AppleIDRow.activeProfile.rawValue
            {
                let shiftedIndexPath = IndexPath(row: indexPath.row + 1, section: indexPath.section)
                return super.tableView(tableView, heightForRowAt: shiftedIndexPath)
            }
            return UITableView.automaticDimension
            
        case .patreon:
            if indexPath.row == PatreonRow.about.rawValue
            {
                return UITableView.automaticDimension
            }
            else if indexPath.row > PatreonRow.about.rawValue
            {
                return 44
            }
            else
            {
                return super.tableView(tableView, heightForRowAt: indexPath)
            }
            
        default: return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        switch Section.allCases[indexPath.section]
        {
        case .patreon where indexPath.row == PatreonRow.about.rawValue: return 300
        case .patreon where indexPath.row > PatreonRow.about.rawValue: return 44
        default: return 44
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let sectionType = Section.allCases[section]
        switch sectionType
        {
        case .refreshAttempts:
            if self.tableView(tableView, numberOfRowsInSection: section) == 0 { return nil }
            return super.tableView(tableView, titleForHeaderInSection: section)
            
        case .errorLog:
            if self.tableView(tableView, numberOfRowsInSection: section) == 0 { return nil }
            return super.tableView(tableView, titleForHeaderInSection: section)
            
        default:
            return super.tableView(tableView, titleForHeaderInSection: section)
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        let lastSection = self.numberOfSections(in: tableView) - 1
        guard section == lastSection else { return nil }
        
        let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "FooterView") as! SettingsFooterView
        
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        footerView.versionLabel.text = "SideStore \(version) (\(build))"
        
        return footerView
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let lastSection = self.numberOfSections(in: tableView) - 1
        guard section == lastSection else { return super.tableView(tableView, heightForFooterInSection: section) }
        
        return 100
    }
    
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int
    {
        switch Section.allCases[indexPath.section]
        {
        case .patreon where indexPath.row >= PatreonRow.about.rawValue: return 0
        default: return super.tableView(tableView, indentationLevelForRowAt: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section.allCases[indexPath.section]
        {
        case .userCustomizations:
            let customizationsView = UserCustomizationsView()
            let hostingController = UIHostingController(rootView: customizationsView)
            hostingController.title = AppStrings.UserCustomizations.title
            self.navigationController?.pushViewController(hostingController, animated: true)
            
        default: break
        }
    }
}

extension SettingsViewController: UITextFieldDelegate
{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField)
    {
        if textField == self.jitURLTextField
        {
            let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.textFieldJITURL = (text?.isEmpty == false) ? text : nil
        }
    }
}
