
//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI
import CoreData
import Minimuxer
import SafariServices

#if canImport(AltStoreCore)
import AltStoreCore
#endif
import Roxas

import AltSign
import UniformTypeIdentifiers

extension SettingsViewController
{
    private enum Section: Int, CaseIterable
    {
        case signIn
        case appleID
        case patreon
        case anisette
        case pairingFile
        case refreshAttempts
        case errorLog
        case debug
        case appData
        case credits
    }
    
    private enum AppleIDRow: Int, CaseIterable
    {
        case account = 0
        case activeAppLimit
    }
    
    private enum PatreonRow: Int, CaseIterable
    {
        case account = 0
        case about
    }
}

class SettingsViewController: UITableViewController, UIDocumentPickerDelegate
{
    private lazy var refreshAttemptsDataSource = self.makeRefreshAttemptsDataSource()
    
    private var account: Account?
    private var team: Team?
    
    private var patreonAccount: PatreonAccount?
    
    private var activeAppsLimit: Int? {
        guard let team = self.team else { return nil }
        let limit = (team.type == .free) ? 3 : nil
        return limit
    }
    
    private var remainingAvailableAppIDs: Int?
    
    @IBOutlet private var accountCell: UITableViewCell!
    @IBOutlet private var patreonAccountCell: UITableViewCell!
    @IBOutlet private var anisetteServerPickerCell: UITableViewCell!
    @IBOutlet private var serverTextField: UITextField!
    @IBOutlet private var refreshAttemptsCell: UITableViewCell!
    @IBOutlet private var resetAnisetteCell: UITableViewCell!
    @IBOutlet private var activeAppLimitCell: UITableViewCell!
    @IBOutlet private var errorLogCell: UITableViewCell!
    @IBOutlet private var verboseLogCell: UITableViewCell!
    @IBOutlet private var shareLogCell: UITableViewCell!
    @IBOutlet private var resetPairingCell: UITableViewCell!
    @IBOutlet private var udidCell: UITableViewCell!
    @IBOutlet private var profileCell: UITableViewCell!
    @IBOutlet private var connectionCell: UITableViewCell!
    
    private var prototypeConstraint: NSLayoutConstraint!
    private var _updatingView: Bool = false
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.prototypeConstraint = self.refreshAttemptsCell.contentView.heightAnchor.constraint(equalToConstant: 44)
        
        self.tableView.register(CollapsibleTableSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: "HeaderView")
        self.tableView.register(ServerURLTableViewCell.self, forCellReuseIdentifier: "ServerURLCell")
        
        if #unavailable(iOS 15)
        {
            // Keep pre-iOS 15 behavior of removing separator above section headers.
            self.tableView.sectionHeaderHeight = .leastNormalMagnitude
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.didFetchLatestRefreshAttempts(_:)), name: DatabaseManager.didFetchLatestRefreshAttemptsNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.update), name: PatreonAPI.didUpdateAccountNotification, object: nil)
        
        self.initializeAnisetteSettings()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.refreshAttemptsDataSource.performFetch()
        
        self.update()
        
        PatreonAPI.shared.updateAccount()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        guard !self._updatingView else { return }
        self._updatingView = true
        
        // Wait until self.tableView's Safe Area Insets have been assigned, then reload data to adjust bottom contentInset cleanly.
        self.reload()
    }
}

private extension SettingsViewController
{
    func makeRefreshAttemptsDataSource() -> RSTFetchedResultsTableViewDataSource<RefreshAttempt>
    {
        let fetchRequest: NSFetchRequest<RefreshAttempt> = RefreshAttempt.fetchRequest()
        fetchRequest.fetchLimit = 3
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RefreshAttempt.date, ascending: false)]
        
        let dataSource = RSTFetchedResultsTableViewDataSource(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.cellConfigurationHandler = { (cell, refreshAttempt, indexPath) in
            let cell = cell as! RefreshAttemptTableViewCell
            
            let formatString: String
            
            if Calendar.current.isDateInToday(refreshAttempt.date)
            {
                formatString = NSLocalizedString("Today at %@", comment: "")
            }
            else if Calendar.current.isDateInYesterday(refreshAttempt.date)
            {
                formatString = NSLocalizedString("Yesterday at %@", comment: "")
            }
            else
            {
                formatString = "%@ at %@"
            }
            
            if refreshAttempt.isSuccess
            {
                cell.statusImageView.image = UIImage(systemName: "checkmark.circle")
                cell.statusImageView.tintColor = .refreshSuccess
                
                cell.errorDescriptionLabel.isHidden = true
            }
            else
            {
                cell.statusImageView.image = UIImage(systemName: "exclamationmark.circle")
                cell.statusImageView.tintColor = .refreshFailure
                
                cell.errorDescriptionLabel.text = refreshAttempt.errorDescription
                cell.errorDescriptionLabel.isHidden = false
            }
            
            if formatString.components(separatedBy: "%@").count == 2
            {
                cell.dateLabel.text = String(format: formatString, DateFormatter.shortTime.string(from: refreshAttempt.date))
            }
            else
            {
                cell.dateLabel.text = String(format: formatString, DateFormatter.mediumDate.string(from: refreshAttempt.date), DateFormatter.shortTime.string(from: refreshAttempt.date))
            }
        }
        
        return dataSource
    }
    
    @objc func update()
    {
        let context = DatabaseManager.shared.viewContext
        context.performAndWait {
            self.account = DatabaseManager.shared.activeAccount(in: context)
            self.team = DatabaseManager.shared.activeTeam(in: context)
            self.patreonAccount = DatabaseManager.shared.patreonAccount(in: context)
            
            let fetchRequest = AppID.fetchRequest() as NSFetchRequest<AppID>
            fetchRequest.predicate = NSPredicate(format: "%K >= %@", #keyPath(AppID.expirationDate), NSDate())
            
            let appIDs = try? context.fetch(fetchRequest)
            self.remainingAvailableAppIDs = appIDs.map { max(10 - $0.count, 0) }
        }
        
        self.reload()
    }
    
    func reload()
    {
        if let account = self.account
        {
            self.accountCell.detailTextLabel?.text = account.appleID
        }
        
        if let patreonAccount = self.patreonAccount
        {
            self.patreonAccountCell.detailTextLabel?.text = patreonAccount.name
        }
        else
        {
            self.patreonAccountCell.detailTextLabel?.text = NSLocalizedString("Link Patreon Account", comment: "")
        }
        
        if let limit = self.activeAppsLimit
        {
            let format: String
            if limit == 1
            {
                format = NSLocalizedString("%@ App", comment: "")
            }
            else
            {
                format = NSLocalizedString("%@ Apps", comment: "")
            }
            
            self.activeAppLimitCell.detailTextLabel?.text = String(format: format, NSNumber(value: limit))
            self.activeAppLimitCell.accessoryType = .disclosureIndicator
            self.activeAppLimitCell.selectionStyle = .default
        }
        else
        {
            self.activeAppLimitCell.detailTextLabel?.text = NSLocalizedString("None", comment: "")
            self.activeAppLimitCell.accessoryType = .none
            self.activeAppLimitCell.selectionStyle = .none
        }
        
        let bottomInset = self.tableView.safeAreaInsets.bottom
        self.tableView.contentInset.bottom = bottomInset + 20
        
        self.tableView.reloadData()
        self.reloadUDIDLabel()
        self.reloadProfileStatusLabel()
        self.reloadConnectionStatusLabel()
    }
    
    @objc func didFetchLatestRefreshAttempts(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.tableView.reloadSections(IndexSet(integer: Section.refreshAttempts.rawValue), with: .Automatic)
        }
    }
}

private extension SettingsViewController
{
    @IBAction func signIn(_ sender: UIButton)
    {
        AppManager.shared.authenticate(presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(OperationError.cancelled): break
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                    
                case .success:
                    self.update()
                }
            }
        }
    }
    
    func signOutButtonTapped()
    {
        let alertController = UIAlertController(title: NSLocalizedString("Are you sure you want to sign out?", comment: ""),
                                                message: NSLocalizedString("You will no longer be able to install or refresh apps once you sign out.", comment: ""),
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Sign Out", comment: ""), style: .destructive) { (action) in
            self.signOut()
        })
        alertController.addAction(.cancel)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func signOut()
    {
        DatabaseManager.shared.signOut { (error) in
            DispatchQueue.main.async {
                if let error = error
                {
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                }
                
                self.update()
            }
        }
    }
    
    func patreonButtonTapped()
    {
        if let account = self.patreonAccount
        {
            let message = String(format: NSLocalizedString("SideStore is currently linked with the Patreon account %@.", comment: ""), account.name)
            
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Unlink Patreon Account", comment: ""), style: .destructive, handler: { (action) in
                self.signOutPatreon()
            }))
            alertController.addAction(.cancel)
            
            self.present(alertController, animated: true, completion: nil)
        }
        else
        {
            self.signInPatreon()
        }
    }
    
    func signInPatreon()
    {
        PatreonAPI.shared.authenticate(presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(URLError.cancelled), .failure(OperationError.cancelled): break
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                    
                case .success:
                    self.update()
                }
            }
        }
    }
    
    func signOutPatreon()
    {
        PatreonAPI.shared.signOut { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                    
                case .success:
                    self.update()
                }
            }
        }
    }
    
    func toggleActiveAppLimit()
    {
        guard self.activeAppsLimit != nil else { return }
        
        if UserDefaults.standard.isAppLimitDisabled
        {
            UserDefaults.standard.isAppLimitDisabled = false
            
            self.reload()
        }
        else
        {
            let title = NSLocalizedString("Remove 3-App Limit?", comment: "")
            let message = NSLocalizedString("""
            SideStore allows you to install up to 10 apps at a time when using the MacDirtyCow exploit or on iOS 16.1.2 and below.
            
            After disabling this limit, you can deactivate and activate apps freely from the My Apps tab.
            """, comment: "")
            
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.addAction(.cancel)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Remove Limit", comment: ""), style: .default) { (action) in
                UserDefaults.standard.isAppLimitDisabled = true
                self.reload()
            })
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func clearAppCache()
    {
        let title = NSLocalizedString("Clear App Cache?", comment: "")
        let message = NSLocalizedString("Are you sure you want to clear SideStore's app cache? This will delete any cached data for downloaded apps.", comment: "")
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alertController.addAction(.cancel)
        alertController.addAction(UIAlertAction(title: title, style: .destructive) { _ in
            do
            {
                let cacheDirectory = FileManager.default.AltStoreCachesDirectory
                if FileManager.default.fileExists(atPath: cacheDirectory.path)
                {
                    try FileManager.default.removeItem(at: cacheDirectory)
                }
                
                try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true, attributes: nil)
                
                let toastView = ToastView(text: NSLocalizedString("Cleared App Cache", comment: ""), detailText: nil)
                toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
            }
            catch
            {
                let toastView = ToastView(error: error)
                toastView.show(in: self.navigationController?.view ?? self.view)
            }
        })
        
        self.present(alertController, animated: true)
    }
}

extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        var sections = Section.allCases.count
        if !UserDefaults.standard.isDebugModeEnabled
        {
            // Hide App Data section unless Debug Mode is enabled.
            sections -= 1
        }
        
        return sections
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn:
            guard self.account == nil else { return 0 }
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            
        case .appleID:
            guard self.account != nil else { return 0 }
            
            var rows = super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            if self.activeAppsLimit == nil
            {
                // No active app limit, so hide the cell.
                rows -= 1
            }
            
            return rows
            
        case .patreon:
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            
        case .anisette:
            if UserDefaults.standard.textInputAnisetteURL
            {
                return 3 // Text field, Toggle, Reset
            }
            else
            {
                return 3 // Picker, Toggle, Reset
            }
            
        case .pairingFile:
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            
        case .refreshAttempts:
            guard self.refreshAttemptsDataSource.itemCount > 0 else { return 0 }
            guard UserDefaults.standard.isBackgroundRefreshEnabled else { return 0 }
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            
        case .errorLog:
            let count = super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            return count
            
        case .debug:
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            
        case .appData:
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
            
        case .credits:
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .anisette:
            return self.tableView(tableView, anisetteCellForRowAt: indexPath)
            
        case .refreshAttempts:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            
            for subview in cell.contentView.subviews
            {
                subview.removeFromSuperview()
            }
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(stackView)
            
            for (index, refreshAttempt) in (self.refreshAttemptsDataSource.fetchedResultsController.fetchedObjects ?? []).enumerated()
            {
                let indexPath = IndexPath(row: index, section: 0)
                
                let attemptCell = self.refreshAttemptsCell.instantiateView() as! RefreshAttemptTableViewCell
                attemptCell.contentView.translatesAutoresizingMaskIntoConstraints = false
                self.refreshAttemptsDataSource.cellConfigurationHandler(attemptCell, refreshAttempt, indexPath)
                
                if index == self.refreshAttemptsDataSource.itemCount - 1
                {
                    attemptCell.separatorView.isHidden = true
                }
                
                stackView.addArrangedSubview(attemptCell.contentView)
            }
            
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                stackView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            ])
            
            return cell
            
        case .appleID:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            
            let row = AppleIDRow.allCases[indexPath.row]
            switch row
            {
            case .account: break
            case .activeAppLimit:
                if UserDefaults.standard.isAppLimitDisabled
                {
                    cell.detailTextLabel?.text = NSLocalizedString("Disabled", comment: "")
                }
            }
            
            return cell
            
        case .debug:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            if indexPath.row == DebugRow.verboseLog.rawValue
            {
                let switchControl = UISwitch()
                switchControl.isOn = UserDefaults.standard.isVerboseLoggingEnabled
                switchControl.addTarget(self, action: #selector(SettingsViewController.toggleVerboseLogging(_:)), for: .valueChanged)
                cell.accessoryView = switchControl
            }
            return cell
            
        default:
            let cell = super.tableView(tableView, cellForRowAt: indexPath)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .refreshAttempts: return UITableView.automaticDimension
        case .anisette:
            if indexPath.row == 0 && UserDefaults.standard.textInputAnisetteURL
            {
                return 44.0
            }
            return super.tableView(tableView, heightForRowAt: indexPath)
            
        default: return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .refreshAttempts: return 132
        default: return UITableView.automaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.account != nil: return nil
        case .appleID where self.account == nil: return nil
        case .refreshAttempts where self.refreshAttemptsDataSource.itemCount == 0 || !UserDefaults.standard.isBackgroundRefreshEnabled: return nil
        default: return super.tableView(tableView, titleForHeaderInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.account != nil: return .leastNormalMagnitude
        case .appleID where self.account == nil: return .leastNormalMagnitude
        case .refreshAttempts where self.refreshAttemptsDataSource.itemCount == 0 || !UserDefaults.standard.isBackgroundRefreshEnabled: return .leastNormalMagnitude
        default: return super.tableView(tableView, heightForHeaderInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.account != nil: return nil
        case .appleID:
            guard self.account != nil else { return nil }
            
            var footerText: String?
            
            if self.activeAppsLimit != nil
            {
                footerText = NSLocalizedString("Free Developer accounts are limited to 3 active apps by default.", comment: "")
            }
            
            if let remainingAppIDs = self.remainingAvailableAppIDs, self.team?.type == .free
            {
                let remainingFormat: String
                if remainingAppIDs == 1
                {
                    remainingFormat = NSLocalizedString("You can register %@ more App ID with this account this week.", comment: "")
                }
                else
                {
                    remainingFormat = NSLocalizedString("You can register %@ more App IDs with this account this week.", comment: "")
                }
                
                let remainingText = String(format: remainingFormat, NSNumber(value: remainingAppIDs))
                
                if let existingText = footerText
                {
                    footerText = existingText + "\n\n" + remainingText
                }
                else
                {
                    footerText = remainingText
                }
            }
            
            return footerText
            
        case .refreshAttempts where self.refreshAttemptsDataSource.itemCount == 0 || !UserDefaults.standard.isBackgroundRefreshEnabled: return nil
        default: return super.tableView(tableView, titleForFooterInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.account != nil: return .leastNormalMagnitude
        case .appleID where self.account == nil: return .leastNormalMagnitude
        case .refreshAttempts where self.refreshAttemptsDataSource.itemCount == 0 || !UserDefaults.standard.isBackgroundRefreshEnabled: return .leastNormalMagnitude
        default: return super.tableView(tableView, heightForFooterInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .appleID:
            switch AppleIDRow.allCases[indexPath.row]
            {
            case .account: self.signOutButtonTapped()
            case .activeAppLimit: self.toggleActiveAppLimit()
            }
            
        case .patreon:
            switch PatreonRow.allCases[indexPath.row]
            {
            case .account: self.patreonButtonTapped()
            case .about: break
            }
            
        case .anisette:
            self.tableView(tableView, didSelectAnisetteRowAt: indexPath)
            
        case .pairingFile:
            self.selectPairingFile()
            
        case .debug:
            self.tableView(tableView, didSelectDebugRowAt: indexPath)
            
        default: break
        }
    }
}

// MARK: - Anisette -
private extension SettingsViewController
{
    enum AnisetteRow: Int, CaseIterable
    {
        case server = 0
        case toggleInput = 1
        case reset = 2
    }
    
    func initializeAnisetteSettings()
    {
        self.serverTextField?.delegate = self
    }
    
    func tableView(_ tableView: UITableView, anisetteCellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        guard let row = AnisetteRow(rawValue: indexPath.row) else {
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
        
        switch row
        {
        case .server:
            if UserDefaults.standard.textInputAnisetteURL
            {
                let cell = tableView.dequeueReusableCell(withIdentifier: "ServerURLCell", for: indexPath) as! ServerURLTableViewCell
                cell.textField.text = UserDefaults.standard.anisetteServer
                cell.textField.placeholder = "https://..."
                cell.textField.delegate = self
                cell.textField.keyboardType = .URL
                cell.textField.autocorrectionType = .no
                cell.textField.autocapitalizationType = .none
                cell.textField.returnKeyType = .done
                return cell
            }
            else
            {
                let cell = self.anisetteServerPickerCell!
                cell.detailTextLabel?.text = AnisetteServer.currentServerName()
                return cell
            }
            
        case .toggleInput:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "ToggleAnisetteInputCell")
            cell.textLabel?.text = NSLocalizedString("Custom Anisette URL", comment: "")
            
            let switchControl = UISwitch()
            switchControl.isOn = UserDefaults.standard.textInputAnisetteURL
            switchControl.addTarget(self, action: #selector(SettingsViewController.toggleAnisetteURLInput(_:)), for: .valueChanged)
            cell.accessoryView = switchControl
            cell.selectionStyle = .none
            
            return cell
            
        case .reset:
            return self.resetAnisetteCell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectAnisetteRowAt indexPath: IndexPath)
    {
        guard let row = AnisetteRow(rawValue: indexPath.row) else { return }
        
        switch row
        {
        case .server:
            if !UserDefaults.standard.textInputAnisetteURL
            {
                self.presentAnisetteServerPicker()
            }
            
        case .toggleInput:
            break
            
        case .reset:
            self.resetAnisetteData()
        }
    }
    
    @objc func toggleAnisetteURLInput(_ sender: UISwitch)
    {
        UserDefaults.standard.textInputAnisetteURL = sender.isOn
        self.tableView.reloadSections(IndexSet(integer: Section.anisette.rawValue), with: .automatic)
    }
    
    func presentAnisetteServerPicker()
    {
        let alertController = UIAlertController(title: NSLocalizedString("Select Anisette Server", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        for server in AnisetteServer.allCases
        {
            let action = UIAlertAction(title: server.name, style: .default) { _ in
                UserDefaults.standard.anisetteServer = server.rawValue
                self.tableView.reloadSections(IndexSet(integer: Section.anisette.rawValue), with: .automatic)
            }
            
            if UserDefaults.standard.anisetteServer == server.rawValue
            {
                action.setValue(true, forKey: "checked")
            }
            
            alertController.addAction(action)
        }
        
        alertController.addAction(.cancel)
        
        if let popover = alertController.popoverPresentationController
        {
            popover.sourceView = self.anisetteServerPickerCell
            popover.sourceRect = self.anisetteServerPickerCell.bounds
        }
        
        self.present(alertController, animated: true)
    }
    
    func resetAnisetteData()
    {
        let alertController = UIAlertController(title: NSLocalizedString("Reset Anisette Data?", comment: ""),
                                                message: NSLocalizedString("This will clear your current Anisette data and generate new data on the next sign in or refresh.", comment: ""),
                                                preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Reset Anisette Data", comment: ""), style: .destructive) { _ in
            Keychain.shared.anisetteData = nil
            
            let toastView = ToastView(text: NSLocalizedString("Anisette Data Reset", comment: ""), detailText: nil)
            toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
        })
        
        alertController.addAction(.cancel)
        self.present(alertController, animated: true)
    }
}

// MARK: - Pairing File -
private extension SettingsViewController
{
    func selectPairingFile()
    {
        let alertController = UIAlertController(title: NSLocalizedString("Reset Pairing File?", comment: ""),
                                                message: NSLocalizedString("Are you sure you want to choose a new pairing file?", comment: ""),
                                                preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Choose Pairing File", comment: ""), style: .destructive) { _ in
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            self.present(documentPicker, animated: true)
        })
        
        alertController.addAction(.cancel)
        self.present(alertController, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        
        DatabaseManager.shared.start( matches: url) { error in
            DispatchQueue.main.async {
                if let error = error
                {
                    let toastView = ToastView(error: error)
                    toastView.show(in: self.navigationController?.view ?? self.view)
                }
                else
                {
                    let toastView = ToastView(text: NSLocalizedString("Pairing File Imported", comment: ""), detailText: nil)
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                    
                    self.reload()
                }
            }
        }
    }
}

// MARK: - Debug -
private extension SettingsViewController
{
    enum DebugRow: Int, CaseIterable
    {
        case errorLog = 0
        case verboseLog
        case shareLog
        case jitRow
        case udid
        case profileRow
        case connectionRow
        case cacheRow
    }
    
    func tableView(_ tableView: UITableView, didSelectDebugRowAt indexPath: IndexPath)
    {
        guard let row = DebugRow(rawValue: indexPath.row) else { return }
        
        switch row
        {
        case .errorLog:
            break
            
        case .verboseLog:
            break
            
        case .shareLog:
            self.shareLogs()
            
        case .jitRow:
            break
            
        case .udid:
            if let udid = self.udidCell.detailTextLabel?.text
            {
                UIPasteboard.general.string = udid
                let toastView = ToastView(text: NSLocalizedString("Copied UDID to Clipboard", comment: ""), detailText: nil)
                toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
            }
            
        case .profileRow:
            self.reloadProfileStatusLabel()
            
        case .connectionRow:
            self.reloadConnectionStatusLabel()
            
        case .cacheRow:
            self.clearAppCache()
        }
    }
    
    @objc func toggleVerboseLogging(_ sender: UISwitch)
    {
        UserDefaults.standard.isVerboseLoggingEnabled = sender.isOn
    }
    
    func shareLogs()
    {
        let logURL = FileManager.default.logFileURL
        guard FileManager.default.fileExists(atPath: logURL.path) else {
            let toastView = ToastView(text: NSLocalizedString("No Log File Found", comment: ""), detailText: nil)
            toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [logURL], applicationActivities: nil)
        if let popover = activityViewController.popoverPresentationController
        {
            popover.sourceView = self.shareLogCell
            popover.sourceRect = self.shareLogCell.bounds
        }
        
        self.present(activityViewController, animated: true)
    }
}

// MARK: - UITextFieldDelegate -
extension SettingsViewController: UITextFieldDelegate
{
    func textFieldShouldReturn(_ textField: UITextField) -> Bool
    {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField)
    {
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            textField.text = UserDefaults.standard.anisetteServer
            return
        }
        
        if let url = URL(string: text), url.scheme != nil, url.host != nil
        {
            UserDefaults.standard.anisetteServer = text
        }
        else
        {
            textField.text = UserDefaults.standard.anisetteServer
            let toastView = ToastView(text: "Invalid URL the previous value will be restored", detailText: nil)
            toastView.layer.backgroundColor = UIColor.systemRed.cgColor
            toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.5)
        }
    }
    
    private func reloadUDIDLabel()
    {
        Task { [weak self] in
            do
            {
                let udid = try await fetchUDID()
                await MainActor.run {
                    self?.udidCell.detailTextLabel?.text = udid
                }
            }
            catch
            {
                await MainActor.run {
                    self?.udidCell.detailTextLabel?.text = NSLocalizedString("Error", comment: "")
                }
            }
        }
    }
    
    private func reloadProfileStatusLabel()
    {
        let hasProfile = Minimuxer.hasPairingFile()
        self.profileCell.detailTextLabel?.text = hasProfile ? NSLocalizedString("Installed", comment: "") : NSLocalizedString("Not Installed", comment: "")
    }
    
    private func reloadConnectionStatusLabel()
    {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let isConnected = Minimuxer.testDeviceConnection()
            DispatchQueue.main.async {
                self?.connectionCell.detailTextLabel?.text = isConnected ? NSLocalizedString("Connected", comment: "") : NSLocalizedString("Disconnected", comment: "")
            }
        }
    }
}

// MARK: - ServerURLTableViewCell -
private class ServerURLTableViewCell: UITableViewCell
{
    let textField: UITextField
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?)
    {
        self.textField = UITextField()
        self.textField.translatesAutoresizingMaskIntoConstraints = false
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        self.contentView.addSubview(self.textField)
        
        NSLayoutConstraint.activate([
            self.textField.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
            self.textField.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
            self.textField.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            self.textField.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - AnisetteServer Helper -
private enum AnisetteServer: String, CaseIterable
{
    case sideStore = "https://ani.sidestore.io"
    case macley = "https://ani.macley.me"
    
    var name: String
    {
        switch self
        {
        case .sideStore: return "SideStore (Official)"
        case .macley: return "Macley"
        }
    }
    
    static func currentServerName() -> String
    {
        let current = UserDefaults.standard.anisetteServer
        if let server = AnisetteServer(rawValue: current)
        {
            return server.name
        }
        return current
    }
}
