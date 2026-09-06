cask "thaw@1" do
  version "1.2.0"
  sha256 "d67f4d31ef9fa057849a98540b810cfa42e0bc66019d3605abd08e45c69aa06f"

  url "https://github.com/thaw-app/Thaw/releases/download/#{version}/Thaw_#{version}.zip"
  name "Thaw"
  desc "Menu bar manager for macOS Sonoma and Sequoia"
  homepage "https://github.com/thaw-app/Thaw/"

  livecheck do
    skip "Compatibility release pinned to macOS 14 and 15"
  end

  auto_updates true
  depends_on macos: :sonoma
  conflicts_with cask: "thaw"

  app "Thaw.app"

  uninstall quit: ["com.stonerl.Thaw", "com.stonerl.Thaw.MenuBarItemService"]

  zap trash: [
    "~/Library/Caches/com.stonerl.Thaw",
    "~/Library/HTTPStorages/com.stonerl.Thaw",
    "~/Library/Preferences/com.stonerl.Thaw.plist",
    "~/Library/WebKit/com.stonerl.Thaw",
  ]
end
