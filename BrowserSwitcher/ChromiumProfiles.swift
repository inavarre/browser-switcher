import AppKit

/// Reads Chromium-family browser profiles so the prompt can offer one entry per profile.
enum ChromiumProfiles {
    /// Where each browser keeps its data (and its `Local State` file), under ~/Library/Application Support.
    static let dataFolders: [String: String] = [
        "com.google.Chrome": "Google/Chrome",
        "com.brave.Browser": "BraveSoftware/Brave-Browser",
        "com.microsoft.edgemac": "Microsoft Edge",
    ]

    static func profiles(forBundleID bundleID: String) -> [BrowserProfile] {
        guard let folder = dataFolders[bundleID],
              let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return [] }
        return profiles(inDataDirectory: support.appendingPathComponent(folder))
    }

    /// Profiles listed in `<dataDirectory>/Local State`, in the browser's own order.
    static func profiles(inDataDirectory dataDirectory: URL) -> [BrowserProfile] {
        guard let data = try? Data(contentsOf: dataDirectory.appendingPathComponent("Local State")),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: [String: Any]]
        else { return [] }

        let ordered = (profile["profiles_order"] as? [String] ?? []).filter { cache[$0] != nil }
        let unordered = cache.keys.filter { !ordered.contains($0) }.sorted()
        return (ordered + unordered).map { directory in
            let name = (cache[directory]?["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? directory
            let picture = dataDirectory
                .appendingPathComponent(directory)
                .appendingPathComponent("Google Profile Picture.png")
            return BrowserProfile(directory: directory, name: name, picture: NSImage(contentsOf: picture))
        }
    }
}
