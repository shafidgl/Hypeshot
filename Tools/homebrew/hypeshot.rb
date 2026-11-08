# Homebrew cask for the direct-download build. Lives in the tap repo shafidgl/homebrew-tap as Casks/hypeshot.rb.
# After each GitHub release: update version and sha256 (printed by Tools/release-direct.sh), then
#   brew install --cask shafidgl/tap/hypeshot
cask "hypeshot" do
  version "1.0"
  sha256 "REPLACE_WITH_SHA256_OF_NOTARIZED_DMG"

  url "https://github.com/shafidgl/Hypeshot/releases/download/v#{version}/Hypeshot-#{version}.dmg"
  name "Hypeshot"
  desc "Menu bar screenshot tool for macOS"
  homepage "https://github.com/shafidgl/Hypeshot"

  depends_on macos: ">= :tahoe"

  app "Hypeshot.app"

  zap trash: [
    "~/Library/Preferences/com.shafi.hypeshot.plist",
    "~/Library/Application Support/Hypeshot",
  ]
end
