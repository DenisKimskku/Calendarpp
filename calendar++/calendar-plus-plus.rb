cask "calendar-plus-plus" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"

  url "https://github.com/den-kim/calendarplusplus/releases/download/v#{version}/calendar++-v#{version}.zip"
  name "calendar++"
  desc "Smart calendar and event management for macOS menu bar"
  homepage "https://github.com/den-kim/calendarplusplus"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "calendar++.app"

  postflight do
    system_command "/usr/bin/open",
                   args: ["-a", "#{appdir}/calendar++.app"],
                   sudo: false
  end

  uninstall quit: "com.den-kim.calendarplusplus"

  zap trash: [
    "~/Library/Application Support/com.den-kim.calendarplusplus",
    "~/Library/Caches/com.den-kim.calendarplusplus",
    "~/Library/HTTPStorages/com.den-kim.calendarplusplus",
    "~/Library/Preferences/com.den-kim.calendarplusplus.plist",
    "~/Library/Saved Application State/com.den-kim.calendarplusplus.savedState",
    "~/Library/WebKit/com.den-kim.calendarplusplus",
  ]

  caveats <<~EOS
    calendar++ has been installed as a menu bar application.
    
    Features:
      • Smart calendar event management
      • Unified timeline with reminders
      • Deep work focus sessions
      • URL scheme automation (calendarplusplus://)
      • Shortcuts integration
    
    To start calendar++:
      Open from Applications folder or use Spotlight
    
    URL Scheme Examples:
      open "calendarplusplus://show-date?timestamp=$(date +%s)"
      open "calendarplusplus://new-event?title=Meeting&start=1702080000&end=1702083600"
      open "calendarplusplus://set-focus?set=work"
    
    For more information:
      https://github.com/den-kim/calendarplusplus
  EOS
end
