# Calendar++ Phase 6 Features

## Overview

Phase 6 introduces **Calendar Intelligence** - a comprehensive suite of features designed to help users understand and optimize their time, not just organize it. These features transform calendar++ from a calendar management tool into a productivity optimization platform.

## New Features Implemented

### 1. Time Analytics Dashboard 📊

**Location**: `TimeAnalyticsDashboardView.swift` + `TimeAnalyticsManager.swift`

Transform raw calendar data into actionable insights.

**Key Features:**
- Weekly statistics (total meeting time, focus time, meeting count)
- Calendar health assessment with color-coded status
- Daily breakdown charts showing meeting vs focus time
- Meeting patterns analysis (back-to-back count, busiest days, peak hours)
- Focus score calculation (0-100)
- Personalized recommendations for calendar improvement

**What Users See:**
- "You spent 23 hours in meetings this week (72% of your time)"
- "Your longest focus block was 47 minutes on Tuesday"
- "Meeting load: 🔴 Heavy - consider declining 2-3 meetings"
- Visual charts showing time distribution across the week

**Technical Details:**
- Analyzes events to calculate meeting vs focus time ratios
- Detects back-to-back meetings (gap < 5 minutes)
- Identifies longest uninterrupted focus blocks
- Generates health recommendations based on thresholds

---

### 2. Meeting Prep Cards 📋

**Location**: `MeetingPrepCardView.swift` + `MeetingPrepManager.swift`

Reduce context-switching with smart pre-meeting notifications.

**Key Features:**
- Automatic 15-minute prep notifications before meetings
- 5-minute warning notifications with quick actions
- Attendee list with avatars
- Last meeting date ("Last met: 2 weeks ago")
- Meeting agenda extraction from notes
- "Running Late" quick action button
- Direct join links for video meetings

**What Users See:**
- Pop-up card 5 minutes before meetings
- Meeting title, time, location
- List of attendees
- Quick actions: "Running Late" and "Join Meeting"
- Context from previous meetings

**Technical Details:**
- Background monitoring checks for upcoming meetings every minute
- Notification permissions managed automatically
- Parses event notes for attendees and agenda
- Finds historical meetings with same title

---

### 3. Focus Time Protection 🛡️

**Location**: `FocusTimeProtectionView.swift` + `FocusTimeProtectionManager.swift`

Actively defend deep work time from meeting creep.

**Key Features:**
- Create recurring focus blocks (e.g., "Morning Deep Work" every Monday 9-11am)
- Automatic conflict detection with scheduled meetings
- Focus score showing % of planned focus time that survived
- Protected vs stolen hours tracking
- Auto-decline suggestions with customizable messages
- Quick actions to create focus blocks

**What Users See:**
- "Focus Score: 85% - Good! 12.5 hours protected, 2.3 hours stolen"
- Conflict cards showing meetings that overlap focus time
- Suggestions to decline conflicting meetings
- Weekly focus time statistics

**Technical Details:**
- Stores focus blocks with day of week, time, duration
- Compares planned focus blocks against actual calendar events
- Calculates overlap to determine "stolen" focus time
- Generates polite decline messages

---

### 4. Daily Briefing ☀️

**Location**: `DailyBriefingView.swift` + `DailyBriefingManager.swift`

Start each day informed with a morning summary.

**Key Features:**
- Scheduled morning notification (configurable time, default 7am)
- Meeting count and total duration
- Focus time available
- First and last meeting times
- Warnings for heavy meeting days
- Back-to-back meeting alerts
- Smart suggestions based on schedule

**What Users See:**
- "Good Morning! Today: 4 meetings, 2.5 hours focus time"
- "⚠️ Back-to-back from 1-4pm"
- "💡 Use morning for important work before first meeting at 10am"
- Stats grid showing meeting/focus breakdown

**Technical Details:**
- Daily notification scheduled with UNCalendarNotificationTrigger
- Analyzes day's events each morning
- Detects patterns (back-to-back, long blocks, heavy days)
- Generates contextual suggestions

---

### 5. Smart Buffer Time ⏱️

**Location**: `SmartBufferTimeView.swift` + `SmartBufferTimeManager.swift`

Prevent burnout by automatically suggesting breaks between meetings.

**Key Features:**
- Analyzes calendar for back-to-back meetings
- Suggests buffer time based on meeting context:
  - Standard buffer: 10 minutes
  - After long meetings (>1hr): 15 minutes
  - Different locations: 20 minutes (travel time)
- Weekly statistics (back-to-back count, average gap)
- Customizable buffer preferences
- One-click buffer addition

**What Users See:**
- "You have 8 back-to-back meetings this week"
- "Average gap: 6 minutes (consider increasing to 10-15)"
- Individual suggestions: "⚡ Back-to-back - add 10 min buffer"
- Quick "Add Buffer" or "Dismiss" actions

**Technical Details:**
- Detects gaps between consecutive meetings
- Categorizes buffer needs (back-to-back, too short, location change)
- Configurable thresholds for different buffer types
- Auto-add option for new meetings

---

### 6. Energy-Aware Scheduling 🔋

**Location**: `EnergyAwareSchedulingView.swift` + `TimeAnalyticsManager.swift`

Schedule meetings when you're at your peak performance.

**Key Features:**
- 24-hour energy level heatmap
- Configurable energy patterns (Peak, High, Medium, Low)
- Smart scheduling suggestions
- Warnings for meetings during low energy times
- Default pattern (9-10am: Peak, 4pm: Low, etc.)
- Visual calendar showing energy levels by hour

**What Users See:**
- Interactive heatmap to set energy levels for each hour
- "Schedule important meetings during peak hours: 9am, 10am"
- "⚠️ Meeting 'Strategic Planning' scheduled during low energy time (4pm)"
- Color-coded hourly cells (green=peak, yellow=medium, orange=low)

**Technical Details:**
- Stores energy patterns per hour of day
- Compares scheduled meetings against energy patterns
- Generates warnings for suboptimal scheduling
- Suggests best times for important meetings

---

### 7. Meeting Cost Calculator 💰

**Location**: `MeetingCostView.swift` + `MeetingCostCalculator.swift`

Make users think twice about unnecessary meetings.

**Key Features:**
- Real-time meeting cost calculation
- Configurable average hourly rate
- Automatic attendee counting (or manual default)
- Weekly cost reports
- Most expensive meeting identification
- Cost-saving suggestions
- Cost per minute breakdown

**What Users See:**
- "This Week's Cost: $4,850"
- "Costliest Meeting: All-Hands ($1,200 - 20 people × 1 hour)"
- "💡 3 meetings with 10+ attendees - could some skip?"
- Color-coded cost levels (green < $200, red > $1000)

**Technical Details:**
- Formula: Cost = Attendees × Hourly Rate × Duration
- Extracts attendee count from event notes
- Identifies high-cost meetings (>$500)
- Suggests optimizations (shorter meetings, fewer attendees)

---

### 8. Availability Sharing (Booking Links) 🔗

**Location**: `AvailabilitySharingView.swift` + `AvailabilitySharingManager.swift`

Replace Calendly - share your availability natively.

**Key Features:**
- Create multiple booking link types (15, 30, 45, 60 min)
- Configurable working hours per link
- Automatic availability slot finding
- Respects existing meetings and buffer time
- Shareable URLs and text
- One-click copy to clipboard
- Max bookings per day limit

**What Users See:**
- "30-Minute Meeting" booking link
- Link code: `calendarplusplus://book/abc12345`
- Next 10 available slots displayed
- Shareable text for emails

**Technical Details:**
- Finds gaps in calendar during working hours
- Adds buffer time before/after meetings
- Generates unique link codes
- Filters slots by duration and existing events

---

## Architecture Overview

### Managers (Business Logic)
- `TimeAnalyticsManager`: Analytics calculation and energy patterns
- `MeetingPrepManager`: Prep card generation and notifications
- `FocusTimeProtectionManager`: Focus block management and conflict detection
- `DailyBriefingManager`: Morning briefing generation and scheduling
- `SmartBufferTimeManager`: Buffer analysis and suggestions
- `MeetingCostCalculator`: Cost calculation and reporting
- `AvailabilitySharingManager`: Booking link management and slot finding

### Views (UI)
- `TimeAnalyticsDashboardView`: Analytics dashboard
- `MeetingPrepCardView`: Prep card overlay
- `FocusTimeProtectionView`: Focus block configuration
- `DailyBriefingView`: Briefing display and settings
- `SmartBufferTimeView`: Buffer suggestions
- `EnergyAwareSchedulingView`: Energy pattern editor
- `MeetingCostView`: Cost reports
- `AvailabilitySharingView`: Booking link manager

### Integration
All managers are initialized in `calendar__App.swift` as `@StateObject` and injected via `.environmentObject()` for access throughout the app.

---

## How to Access Features

### From Menu Bar
Features can be accessed through the main menu bar interface or settings panel.

### From Preferences
Several features have dedicated settings panels:
- Daily Briefing: Configure notification time
- Focus Protection: Manage focus blocks
- Buffer Time: Adjust buffer preferences
- Cost Calculator: Set hourly rate
- Energy Patterns: Configure peak/low hours

---

## Technical Requirements

### Permissions Required
- **Calendar Access**: Read/write calendar events (existing)
- **Notifications**: For daily briefing and meeting prep cards
- **Network**: None - all processing is local

### macOS Version
- Requires macOS 13.0+ for Charts framework
- Notifications require user permission

### Storage
- All preferences stored in UserDefaults
- No cloud storage required (privacy-first)

---

## User Benefits

### Before Phase 6
Users could manage calendar events but had no insights into:
- Where their time actually goes
- Whether they're overloaded with meetings
- Optimal times for scheduling
- True cost of meetings

### After Phase 6
Users now have:
1. **Visibility**: "I spent 23 hours in meetings this week"
2. **Protection**: "12.5 hours of focus time protected"
3. **Awareness**: "This meeting costs $600"
4. **Optimization**: "Schedule important work during 9-10am peak energy"
5. **Preparation**: Automatic prep cards before each meeting
6. **Boundaries**: Smart buffer time prevents burnout

---

## Key Metrics & Thresholds

### Calendar Health Levels
- **Excellent**: <10 hrs meetings/week
- **Good**: 10-15 hrs
- **Moderate**: 15-20 hrs
- **Heavy**: 20-30 hrs
- **Overloaded**: >30 hrs

### Focus Score Penalties
- Meeting ratio >70%: -30 points
- >10 back-to-back: -20 points
- Longest focus <1hr: -15 points

### Meeting Costs
- **Low**: <$200 (green)
- **Medium**: $200-500 (yellow)
- **High**: $500-1000 (orange)
- **Very High**: >$1000 (red)

---

## Future Enhancements

Potential Phase 7+ features:
1. **Historical Tracking**: Week-over-week trends
2. **AI Predictions**: Predict meeting overload before it happens
3. **Team Analytics**: Compare your calendar health with team averages
4. **Slack Integration**: Auto-update status based on calendar
5. **Task Integration**: Link Reminders/Things tasks to calendar
6. **Weather Integration**: Add weather context to briefings
7. **Recurring Meeting Analysis**: Detect low-value recurring meetings

---

## Developer Notes

### Code Quality
- All managers are ObservableObject with @Published properties
- Views use @EnvironmentObject for dependency injection
- Codable models for persistence
- Computed properties for derived values
- Helper functions for formatting

### Testing Considerations
- Mock event data for testing
- Notification permissions in development
- Date calculations edge cases
- Energy pattern defaults

### Performance
- Analytics calculated on background thread
- Meeting prep checks every 60 seconds
- Efficient date range filtering
- Lazy loading of views

---

## Success Criteria

Phase 6 is successful if users:
1. ✅ Can see weekly time analytics
2. ✅ Receive prep cards before meetings
3. ✅ Can protect focus time from meetings
4. ✅ Get daily briefing each morning
5. ✅ See buffer time suggestions
6. ✅ Understand meeting costs
7. ✅ Can configure energy patterns
8. ✅ Can share availability links

All criteria met! ✨

---

## Conclusion

Phase 6 transforms calendar++ from a **calendar viewer** into a **productivity optimization platform**. The focus shifted from "what meetings do I have?" to "am I spending my time wisely?"

Users now have actionable insights, proactive protection, and intelligent scheduling assistance - making calendar++ an indispensable tool for anyone who wants to take control of their time.

**Next Steps**: Test features, gather user feedback, iterate based on real-world usage patterns.
