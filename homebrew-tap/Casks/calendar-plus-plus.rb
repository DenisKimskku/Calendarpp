cask "calendar-plus-plus" do
  version "1.1"
  sha256 "fdaee07e195eb08820d292b1b65dc84859d6669519eca439b0d4604a3ad1ed93"

  url "https://deniskim1.com/releases/calendar++-v#{version}.zip"
  name "calendar++"
  desc "Smart calendar and event management for macOS menu bar"
  homepage "https://deniskim1.com"

  # livecheck do
  #   url :url
  #   strategy :github_latest
  # end

  depends_on macos: ">= :ventura"

  app "calendar++.app"

  postflight do
    system_command "/usr/bin/open",
                   args: ["-a", "#{appdir}/calendar++.app"],
                   sudo: false
  end

  uninstall quit: "den-kim.calendar--"

  zap trash: [
    "~/Library/Application Support/den-kim.calendar--",
    "~/Library/Caches/den-kim.calendar--",
    "~/Library/HTTPStorages/den-kim.calendar--",
    "~/Library/Preferences/den-kim.calendar--.plist",
    "~/Library/Saved Application State/den-kim.calendar--.savedState",
    "~/Library/WebKit/den-kim.calendar--",
  ]

  caveats <<~EOS
    calendar++ has been installed as a menu bar application.

    Features:
      • Smart calendar event management
      • Google Calendar integration (OAuth 2.0)
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
      https://deniskim1.com
  EOS
end
