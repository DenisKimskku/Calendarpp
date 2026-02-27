# typed: false
# frozen_string_literal: true

cask "calendar-plus-plus" do
  version "1.1.0"
  sha256 "d70a432ca3c1564274fa993e0a85c1a8fc3bb6974abb50934a10883d8fef252f"

  url "https://deniskim1.com/releases/calendar++-v#{version}.zip"
  name "calendar++"
  desc "Smart calendar and event management for menu bar"
  homepage "https://deniskim1.com/"

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

    This build is distributed without Apple Developer ID notarization.
    If macOS blocks launch, run:
      xattr -dr com.apple.quarantine "/Applications/calendar++.app"
      open -a "calendar++"
    (or right-click calendar++.app in Applications and choose Open once)

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
      https://deniskim1.com/
  EOS
end
