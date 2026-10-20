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

import Foundation

protocol SharedStorageUrlsProtocol {
    /// Base path to the shared container directory.
    var sharedContainerUrl: URL { get }

    /// Path to the app's database file.
    var dbFolderUrl: URL { get }

    /// Path to the directory where filters' files are stored.
    var filtersFolderUrl: URL { get }

    /// Path to the directory where DNS filters' files are stored.
    var dnsFiltersFolderUrl: URL { get }

    /// Path to the directory where content blockers' JSONs are stored.
    var cbJsonsFolderUrl: URL { get }

    /// Path to the directory where WebExtension's files are stored.
    var webExtFolderUrl: URL { get }

    /// URL of the file where plain text advanced rules were stored before v4.5.11.
    /// In the current version we only make sure that this file is removed when advanced rules are saved.
    @available(*, deprecated, message: "Remove in v5.0")
    var advancedRulesFileUrl: URL { get }

    /// Path to the directory where statistics data is stored.
    var statisticsFolderUrl: URL { get }
}

/// This object contains all shared folders URLs
struct SharedStorageUrls: SharedStorageUrlsProtocol {
    let sharedContainerUrl: URL
    let dbFolderUrl: URL
    let filtersFolderUrl: URL
    let dnsFiltersFolderUrl: URL
    let cbJsonsFolderUrl: URL
    let webExtFolderUrl: URL
    let advancedRulesFileUrl: URL
    let statisticsFolderUrl: URL

}

extension SharedStorageUrls {
    init() {
        // Use the same resolved container as logs and shared preferences. A
        // re-signing profile may authorize different groups from Info.plist.
        self.sharedContainerUrl = AESharedResources().sharedResuorcesURL()
        self.dbFolderUrl = sharedContainerUrl.appendingPathComponent("db_files", isDirectory: true)
        self.filtersFolderUrl = sharedContainerUrl.appendingPathComponent("filters", isDirectory: true)
        self.dnsFiltersFolderUrl = sharedContainerUrl.appendingPathComponent("dns_filters", isDirectory: true)
        self.cbJsonsFolderUrl = sharedContainerUrl.appendingPathComponent("cb_jsons", isDirectory: true)
        self.webExtFolderUrl = sharedContainerUrl.appendingPathComponent("webext", isDirectory: true)
        self.advancedRulesFileUrl = cbJsonsFolderUrl.appendingPathComponent("advanced_rules.txt")
        self.statisticsFolderUrl = sharedContainerUrl.appendingPathComponent("dns_statistics", isDirectory: true)
    }
}
