cask "calendar-plus-plus" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256_AFTER_FIRST_BUILD"

  url "https://github.com/den-kim/calendarplusplus/releases/download/v#{version}/calendar++-v#{version}.zip"
  name "calendar++"
  desc "Smart calendar menu bar app for macOS with focus modes and deep work support"
  homepage "https://github.com/den-kim/calendarplusplus"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "calendar++.app"

  zap trash: [
    "~/Library/Application Support/com.den-kim.calendarplusplus",
    "~/Library/Caches/com.den-kim.calendarplusplus",
    "~/Library/Preferences/com.den-kim.calendarplusplus.plist",
    "~/Library/Saved Application State/com.den-kim.calendarplusplus.savedState",
  ]
end
