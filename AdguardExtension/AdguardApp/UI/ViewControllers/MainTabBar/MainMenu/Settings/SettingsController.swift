//
// This file is part of Adguard for iOS (https://github.com/AdguardTeam/AdguardForiOS).
// Copyright © Adguard Software Limited. All rights reserved.
//
// Adguard for iOS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Adguard for iOS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Adguard for iOS. If not, see <http://www.gnu.org/licenses/>.
//

import SafariAdGuardSDK

class SettingsController: UITableViewController {

    private let configuration: ConfigurationServiceProtocol = ServiceLocator.shared.getService()!
    private let theme: ThemeServiceProtocol = ServiceLocator.shared.getService()!
    private let resources: AESharedResourcesProtocol = ServiceLocator.shared.getService()!
    private let safariProtection: SafariProtectionProtocol = ServiceLocator.shared.getService()!
    private let settingsReset: SettingsResetServiceProtocol = ServiceLocator.shared.getService()!

    @IBOutlet weak var wifiUpdateSwitch: UISwitch!
    @IBOutlet weak var invertedSwitch: UISwitch!
    @IBOutlet weak var advancedModeSwitch: UISwitch!
    @IBOutlet weak var showStatusBarSwitch: UISwitch!

    @IBOutlet var themableLabels: [ThemableLabel]!

    @IBOutlet var themeButtons: [UIButton]!

    // Sections
    private let titleSection = 0
    private let themeSection = 1
    private let otherSection = 2

    // Raws
    private let systemDefault = 0
    private let dark = 1
    private let light = 2

    private let wifiOnlyRow = 0
    private let invertWhitelistRow = 1
    private let advancedModeRow = 2
    private let showStatusBarRow = 3
    private let advancedSettingsRow = 4
    private let resetStatisticsRow = 5
    private let resetSettingsRow = 6

    private var isBigScreen: Bool { traitCollection.verticalSizeClass == .regular && traitCollection.horizontalSizeClass == .regular }

    private var headersTitles: [String] = []

    // MARK: - ViewController life cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Appearance", style: .plain, target: self, action: #selector(openInternalAppearance))
        fillHeaderTitles()
        tableView.sectionHeaderHeight = 40
        tableView.rowHeight = UITableView.automaticDimension

        let wifiOnlyObject = resources.sharedDefaults().object(forKey: AEDefaultsWifiOnlyUpdates) as? NSNumber
        let wifiOnly = wifiOnlyObject?.boolValue ?? true
        wifiUpdateSwitch.isOn = wifiOnly

        advancedModeSwitch.isOn = configuration.advancedMode

        showStatusBarSwitch.isOn = configuration.showStatusBar

        let inverted = resources.sharedDefaults().bool(forKey: AEDefaultsInvertedWhitelist)
        invertedSwitch.isOn = inverted

        setupBackButton()

        updateUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTheme()
        title = InternalAppearance.name
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        switch (indexPath.section, indexPath.row) {
        // Theme section
        case (themeSection, _):
            setTheme(withButtonTag: indexPath.row)

        // Other section
        case (otherSection, wifiOnlyRow):
            wifiUpdateSwitch.setOn(!wifiUpdateSwitch!.isOn, animated: true)
            toggleWifiOnly(wifiUpdateSwitch)
        case (otherSection, invertWhitelistRow):
            invertedSwitch.setOn(!invertedSwitch.isOn, animated: true)
            toggleInverted(invertedSwitch)
        case (otherSection, advancedModeRow):
            advancedModeSwitch.setOn(!advancedModeSwitch!.isOn, animated: true)
            advancedModeAction(advancedModeSwitch)
        case (otherSection, showStatusBarRow):
            showStatusBarSwitch.setOn(!showStatusBarSwitch.isOn, animated: true)
            toggleShowStatusBar(showStatusBarSwitch)
        case (otherSection, resetStatisticsRow):
            resetStatistics(indexPath)
        case (otherSection, resetSettingsRow):
            resetSettings(indexPath)
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    // MARK: - Actions

    @IBAction func toggleWifiOnly(_ sender: UISwitch) {
        resources.sharedDefaults().set(sender.isOn, forKey: AEDefaultsWifiOnlyUpdates)
    }

    @IBAction func toggleInverted(_ sender: UISwitch) {
        invertWhitelist()
    }

    @IBAction func advancedModeAction(_ sender: UISwitch) {
        configuration.advancedMode = sender.isOn
        tableView.reloadData()
    }

    @IBAction func toggleShowStatusBar(_ sender: UISwitch) {
        configuration.showStatusBar = sender.isOn
    }

    @IBAction func systemDefaultTheme(_ sender: UIButton) {
        setTheme(withButtonTag: sender.tag)
    }

    @IBAction func darkTheme(_ sender: UIButton) {
        setTheme(withButtonTag: sender.tag)
    }

    @IBAction func lightTheme(_ sender: UIButton) {
        setTheme(withButtonTag: sender.tag)
    }

    private func resetStatistics(_ indexPath: IndexPath){
        let alert = UIAlertController(title: String.localizedString("reset_stat_title"), message: String.localizedString("reset_stat_descr"), preferredStyle: .deviceAlertStyle)

        let yesAction = UIAlertAction(title: String.localizedString("reset_title").capitalized, style: .destructive) { [weak self] _ in
            alert.dismiss(animated: true, completion: nil)
            self?.settingsReset.resetAllStatistics()
        }

        alert.addAction(yesAction)

        let cancelAction = UIAlertAction(title: String.localizedString("common_action_cancel"), style: .cancel) { _ in
            alert.dismiss(animated: true, completion: nil)
        }

        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    private func resetSettings(_ indexPath: IndexPath) {
        let alert = UIAlertController(title: nil, message: String.localizedString("confirm_reset_text"), preferredStyle: .deviceAlertStyle)

        let yesAction = UIAlertAction(title: String.localizedString("common_action_yes"), style: .destructive) { [weak self] _ in
            alert.dismiss(animated: true, completion: nil)
            self?.settingsReset.resetAllSettings(sync: false, fromUI: true, resetLicense: true)
        }

        alert.addAction(yesAction)

        let cancelAction = UIAlertAction(title: String.localizedString("common_action_cancel"), style: .cancel) { _ in
            alert.dismiss(animated: true, completion: nil)
        }

        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    // MARK: - table view cells

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        theme.setupTableCell(cell)
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == titleSection { return UIView() }

        let padding: CGFloat = isBigScreen ? 24.0 : 16.0
        let font = UIFont.systemFont(ofSize: isBigScreen ? 30.0 : 20.0, weight: .medium)
        let labelHeight: CGFloat = isBigScreen ? 30.0 : 20.0

        let height = calculateHeaderHeight(section: section)

        let view = UIView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.frame.width, height: height))
        view.backgroundColor = theme.backgroundColor

        let label = ThemableLabel(frame: CGRect(x: padding, y: height - 32, width: self.view.frame.width - padding, height: labelHeight))
        label.greyText = true
        label.font = font
        label.text = headersTitles[section]
        label.textAlignment = .left
        theme.setupLabel(label)

        view.addSubview(label)
        return view
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return calculateHeaderHeight(section: section)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        if indexPath.section == themeSection && indexPath.row == systemDefault {
            if #available(iOS 13.0, *){ } else {
                tableView.cellForRow(at: indexPath)?.isHidden = true
                return 0.0
            }
        }

        if !configuration.advancedMode && indexPath.section == otherSection && indexPath.row == advancedSettingsRow {
            tableView.cellForRow(at: indexPath)?.isHidden = true
            return 0.0
        }

        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    // MARK: - private methods

    private func updateUI() {
        themeButtons.forEach({ $0.isSelected = false })
        switch configuration.userThemeMode {
        case .systemDefault: themeButtons[systemDefault].isSelected = true
        case .light: themeButtons[light].isSelected = true
        case .dark: themeButtons[dark].isSelected = true
        }
    }

    private func fillHeaderTitles(){
        headersTitles.append("")
        headersTitles.append(String.localizedString("theme_header_title"))
        headersTitles.append(String.localizedString("other_header_title"))
    }

    private func calculateHeaderHeight(section: Int) -> CGFloat{
        switch section {
        case titleSection:
            return 0.01
        case themeSection:
            return 48.0
        case otherSection:
            return isBigScreen ? 96.0 : 64.0
        default:
            return 0.0
        }
    }

    private func setTheme(withButtonTag tag: Int){
        guard let button = themeButtons?.first(where: {$0.tag == tag}) else { return }
        themeButtons.forEach({$0.isSelected = false})
        button.isSelected = true
        switch tag {
        case systemDefault: configuration.userThemeMode = .systemDefault
        case dark: configuration.userThemeMode = .dark
        case light: configuration.userThemeMode = .light
        default: configuration.userThemeMode = .light
        }
        updateTheme()
    }

    private func invertWhitelist() {

        let oldValue = resources.sharedDefaults().bool(forKey: AEDefaultsInvertedWhitelist)
        let newValue = invertedSwitch.isOn

        if oldValue != newValue {
            resources.sharedDefaults().set(newValue, forKey: AEDefaultsInvertedWhitelist)

            safariProtection.update(allowlistIsInverted: newValue) { [weak self] error in
                if error != nil {
                    self?.resources.sharedDefaults().set(oldValue, forKey: AEDefaultsInvertedWhitelist)
                    DispatchQueue.main.async {
                        self?.invertedSwitch.setOn(oldValue, animated: true)
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let resetStatistics = Notification.Name("resetStatistics")
    static let resetSettings = Notification.Name("resetSettings")
}

@objc extension NSNotification {
    public static let resetStatistics = Notification.Name.resetStatistics
    public static let resetSettings = Notification.Name.resetSettings
}

extension SettingsController: ThemableProtocol {
    func updateTheme() {
        view.backgroundColor = theme.backgroundColor
        theme.setupLabels(themableLabels)
        theme.setupNavigationBar(navigationController?.navigationBar)
        theme.setupTable(tableView)
        theme.setupSwitch(wifiUpdateSwitch)
        theme.setupSwitch(invertedSwitch)
        tableView.reloadData()
        updateUI()
    }
}


// Internal appearance controls. Kept in this compilation unit so both app targets
// include them without altering the extension target source membership.
import UIKit
import ImageIO

final class InternalAppearance {
    static let nameKey = "internal.appearance.name"
    static let backgroundURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("internal-background.jpg")
    private static var cachedImage: UIImage?
    private static var loaded = false
    private static var cachedColor: UIColor?
    private static var cacheKey = ""

    static var name: String {
        get { UserDefaults.standard.string(forKey: nameKey) ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Ad Getr3kt") }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    static func background(dark: Bool) -> UIColor? {
        if !loaded { cachedImage = UIImage(contentsOfFile: backgroundURL.path); loaded = true }
        guard let image = cachedImage else { return nil }
        let size = UIScreen.main.bounds.size
        let key = "\(size.width):\(size.height):\(dark)"
        if key == cacheKey, let color = cachedColor { return color }
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { context in
            let scale = max(size.width / image.size.width, size.height / image.size.height)
            let scaled = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (size.width-scaled.width)/2, y: (size.height-scaled.height)/2, width: scaled.width, height: scaled.height))
            (dark ? UIColor.black : UIColor.white).withAlphaComponent(0.82).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        let color = UIColor(patternImage: rendered)
        cachedColor = color; cacheKey = key
        return color
    }

    static func saveBackground(_ url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size < 30_000_000,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048
              ] as CFDictionary),
              let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.85)
        else { throw NSError(domain: "Appearance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose an image smaller than 30 MB."]) }
        try FileManager.default.createDirectory(at: backgroundURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try data.write(to: backgroundURL, options: .atomic)
        invalidate()
    }

    static func resetBackground() throws {
        if FileManager.default.fileExists(atPath: backgroundURL.path) { try FileManager.default.removeItem(at: backgroundURL) }
        invalidate()
    }

    static func invalidate() {
        cachedImage = nil; cachedColor = nil; loaded = false; cacheKey = ""
        NotificationCenter.default.post(name: .themeChanged, object: nil)
    }
}

final class InternalAppearanceController: UITableViewController, UIDocumentPickerDelegate {
    private let rows = ["Choose background image", "Remove background image", "Change app icon", "Change in-app name", "Home Screen name"]
    private var iconChangeInProgress = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Appearance"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "appearance")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = rows[indexPath.row]
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        if indexPath.row == 3 { cell.detailTextLabel?.text = InternalAppearance.name }
        if indexPath.row == 4 { cell.detailTextLabel?.text = "Set app_name in the unsigned IPA workflow, then sign and reinstall that IPA." }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
            let picker = UIDocumentPickerViewController(documentTypes: ["public.image"], in: .import)
            picker.delegate = self
            present(picker, animated: true)
        case 1:
            do { try InternalAppearance.resetBackground() } catch { show(error.localizedDescription) }
        case 2: chooseIcon()
        case 3:
            let alert = UIAlertController(title: "In-app name", message: "This changes the name shown inside this build. Home Screen renaming requires rebuilding and reinstalling.", preferredStyle: .alert)
            alert.addTextField { $0.text = InternalAppearance.name; $0.autocapitalizationType = .words }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
                let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !value.isEmpty, value.count <= 80, value.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
                    self?.show("Use 1–80 printable characters."); return
                }
                InternalAppearance.name = value
                self?.tableView.reloadData()
            })
            present(alert, animated: true)
        default: show("Change the app_name input under GitHub Actions → Ad Getr3kt unsigned IPA → Run workflow. Sign and reinstall the resulting IPA.")
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do { try InternalAppearance.saveBackground(url) } catch { show(error.localizedDescription) }
    }

    private func chooseIcon() {
        guard UIApplication.shared.supportsAlternateIcons else { show("This installation does not support alternate icons."); return }
        guard !iconChangeInProgress else { return }
        let alert = UIAlertController(title: "App icon", message: "Choose an icon included with this build.", preferredStyle: .actionSheet)
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let alternatives = icons?["CFBundleAlternateIcons"] as? [String: Any] ?? [:]
        for name in ["Default"] + alternatives.keys.sorted() {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.iconChangeInProgress = true
                UIApplication.shared.setAlternateIconName(name == "Default" ? nil : name) { error in
                    DispatchQueue.main.async {
                        self?.iconChangeInProgress = false
                        if let error = error { self?.show(error.localizedDescription) }
                    }
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = view
        alert.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        present(alert, animated: true)
    }

    private func show(_ message: String) {
        let alert = UIAlertController(title: "Appearance", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension SettingsController {
    @objc func openInternalAppearance() {
        navigationController?.pushViewController(InternalAppearanceController(style: .grouped), animated: true)
    }
}
