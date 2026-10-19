# Swift App Automation

Read any Mac app's interface as values, and press, set and type into it —
through Accessibility, without screenshots.

```swift
import AppAutomation

let finder = try AppSession(matching: "Finder")

// The focused window, flat: one Element per control, each with a ref.
let snapshot = try finder.snapshot()

// Find one thing by what a person would call it, and press it.
let button = try finder.resolve(ElementQuery("New Folder", role: "button"))
try finder.press(button.ref)

// Fill a field and confirm it took.
let search = try finder.resolve(ElementQuery("Search", role: "text-field"))
try finder.setValue(search.ref, to: "invoice")

// Or choose from the menu bar by path.
try finder.chooseMenu(["File", "New Folder"])
```

Accessibility hands back the same tree VoiceOver reads: every button, field,
checkbox, menu item and row, with its name, its value and what can be done to
it. Reading Finder's whole tree — 351 elements — takes **0.06 s**. That is
computer use without a screenshot, without OCR, and without guessing where to
click.

## What it does

| Call | What it does |
|---|---|
| `Automation.apps()` | running apps |
| `Automation.app(matching:)` | one app, by name, bundle id or pid |
| `AppSession.snapshot(_:)` | a window — or every window, or the menu bar — as a flat list |
| `AppSession.find(_:)` / `resolve(_:)` | elements a query matches / the one it means |
| `AppSession.text(_:)` | a window as the words on it |
| `AppSession.focusedElement()` | whatever has keyboard focus |
| `AppSession.press(_:)` | buttons, checkboxes, links, rows, web content included |
| `AppSession.setValue(_:to:)` | fields, checkboxes, sliders — read back and checked |
| `AppSession.type(_:into:)` | real key events, to that app only |
| `AppSession.pick(_:in:)` | choose from a pop-up button |
| `AppSession.menuItems()` / `chooseMenu(_:)` | the menu bar as paths |
| `AppSession.focus(_:)` | bring the app forward — the one call that does |
| `AppSession.wait(until:options:)` | read until conditions hold, steadily — touches nothing |

## Refs

Every element carries a ref like `1.3.1#9f2c`: where it is, and a
fingerprint of what was there. Accessibility elements cannot outlive the
process that read them, so a ref is how a tool run twice — or an agent
between turns — finds the same element again.

A position alone is not enough. A list re-sorts, a row is inserted, and
`1.3.1` is now a different button. **The fingerprint is checked before
anything is done**, and a mismatch throws `AutomationError.stale` rather
than pressing whatever now sits there.

The first number picks the top level: `0` is the menu bar, `1` and up are the
windows. Not the app's `AXChildren`, for a reason below.

## Waiting

```swift
let send = ElementQuery("Send", role: "button")
let report = try mail.wait(until: [
    WaitCondition(.element(send, in: .focusedWindow), .enabled),
    WaitCondition(.window("New Message")),
], options: WaitOptions(timeout: 30))
if report.outcome == .satisfied { … }
```

A wait reads until every `WaitCondition` holds at the same reading —
`exists`, `gone`, `valueEquals`, `valueContains`, `enabled`, `disabled`,
`selected` — on an element by query or ref, or a window by title. It never
acts.

- **Steady.** A condition is met after `stable` identical readings in a row
  (2), each at least `interval` apart. An early reading can break a run but
  never extend it, so a burst of notifications cannot confirm a flicker.
- **Woken early, polling anyway.** An `AXObserver` on the app's own element
  brings the next reading forward when the app announces a change; polling
  every `interval` carries on, because not every change is announced.
- **Four answers, not two.** Each reading is present, absent, ambiguous
  (several matches — never "exists") or unreadable (hidden, another Space,
  not answering, a tree cut short). Unreadable is never "gone".
- **A report whatever happens.** A timeout is not thrown: the
  `WaitReport` carries each condition's last reading. A lost grant, a lock,
  the app quitting or a password field's value end it as `.stopped`.

Elements now carry `isSelected` (`AXSelected`), and `ElementQuery` takes an
`identifier`, matched whole.

## Safe by construction

- **Every action re-reads its element first** and refuses if it changed.
- **Every action that can be checked is checked.** A value is read back
  after it is set; a failure to take is `AutomationError.notApplied`, not a
  quiet success.
- **Password fields are refused**, for reading and for writing, by subrole —
  not by trusting the value to come back blank, which it did, but a guard
  that depends on another app's good behaviour is not a guard.
- **Disabled controls are refused.** Pressing one returns success and does
  nothing.
- **Two matches is an error, not a coin toss.** `resolve` throws
  `ambiguous` with every candidate's ref.
- **Typing goes to one process.** Key events are posted to the app's pid, so
  they work with it in the background and can never land in whatever the
  person is looking at.

## Things that cost an afternoon

Each was measured, on this machine, against real apps or the fixture in
`Tests/AutomationFixture` — and each is now a rule in the code with a test.

**Chrome's web buttons ignore `AXPress` and report success.** A button, a
link and a checkbox in a web page each list only `AXShowMenu` and
`AXScrollToVisible` as actions. Calling `AXPress` anyway returns
`kAXErrorSuccess` — the header promises `kAXErrorActionUnsupported` — and
the click handler never runs. So the action list decides, not the return
code: an element without `AXPress` is focused and sent Space (Return for a
link, since Space on a focused link scrolls the page). Both worked with
Chrome in the background.

**`AXFrontmost` lies too.** Setting it on an app returned success and the
app did not move. `NSRunningApplication.activate()` at least returns
`false` when refused. `focus` checks the frontmost app afterwards rather than
believing either.

**A locked screen hides every window.** With the screen locked, Mail,
Contacts, Music, System Settings and Sidewatch each reported 163 elements and
not one control, and nothing could be brought forward. Every read would have
come back "nothing matches". It is detected up front and thrown as
`AutomationError.screenLocked` — the answer an agent running overnight needs.

**An app can list itself as its own child.** Measured on every app while the
screen was locked: `AXChildren` held the application element first, and
`AXWindows` held it in place of the windows. A walk that follows children
reads the app forever — Finder came back as 30,000 copies of itself. Locked
reads are refused up front now; as a second line, walks never re-enter the
app, and refs are rooted in `AXWindows`, filtered, rather than in
`AXChildren`.

**Windows on another Space do not exist** as far as Accessibility knows.
Notes, with six real windows on another desktop, reported zero. The window
server still lists them off-screen, so the library asks it and throws
`windowsOnAnotherSpace` rather than reporting an empty app.

**…but off-screen is not "on another Space".** Measured on macOS 27 with one
Space and nineteen apps: 92 of their ordinary windows were off-screen, and
91 were on no Space at all — AppKit's own scaffolding (a screen-wide strip
39 pt tall per closed document window, an unplaced 500×500, cursor helpers)
and windows apps closed but kept alive, ordered out (Notes 1000×660, Mail
420×632). Counted, every app with no window open read as "windows on
another Space", and a wait for an app's last window to close could never
succeed. Now a window counts only if it is off-screen AND in AppKit's
all-Spaces window list, which ordered-out windows are not. Not measured: a
window on a second Space — this Mac has one, and making another means
moving somebody's windows; that such windows are in the list is AppKit's
documented meaning of `.allSpaces`. (The Notes figure above was measured
before this rule.)

**A set value can take 30 ms to appear.** In Chrome, a read straight after a
successful set came back `nil`; the value was there 30 ms later. Read-backs
poll for up to half a second.

**A press that opens a dialog times out — and worked.** Pressing a button
that runs a modal alert returned `kAXErrorCannotComplete` after the timeout,
with the alert on screen. The header says why: the app is busy inside the
action. It is reported as a press with a note, not as a failure.

**One round trip per element, not per attribute.** Thirteen attributes read
one at a time across Contacts took **2.76 s**; the same in one
`AXUIElementCopyMultipleAttributeValues` call took **0.43 s**. A failed
attribute in that batch arrives as an `AXValue` of type `.axError` or as
`CFNull`, in place, and has to be recognised and dropped.

**Apps do not announce everything.** One `AXObserver` registration on the
app's own element receives notifications from everything in it — measured
on TextEdit, a window opening (`AXCreated`, `AXWindowCreated`, about 60 ms
after `open`) and closing (fourteen `AXUIElementDestroyed` over 25 ms) both
arrived. But a button added to a background AppKit window sent nothing at
all, while its value changing and its removal were announced at once. So a
notification only ever means "look again", and waits poll as well.

**There is no 20-character limit on typed text.** A 500-unit string in one
key event arrived whole. Text rides on the event's Unicode string with
virtual key 0; the SDK warns that frameworks "may ignore the Unicode string"
and use the key code — which would type `aaaa` — but AppKit and Chrome both
honour it, emoji included.

**Names live in different places in every app.** The first non-empty source
for an actionable control, measured across sixteen running apps: Finder's
commonest was a separate label element (78 of 186), Mail's the description
(97 of 272). And **1,195 of about 4,400** identifiers were AppKit's generated
`_NS:<n>`, which name nothing and are never used as labels. `Labeling` has
the order and the table.

**System Settings' sidebar has no names.** Its rows are SwiftUI hosting
views that expose no text at all — 40 of its 140 controls. They are in the
tree and can be pressed by ref; they cannot be found by name.

## Requirements

macOS 14+, and **Accessibility** for whatever launches the process — System
Settings ▸ Privacy & Security ▸ Accessibility. The grant belongs to the
launching app, not the binary: run from Terminal, this works exactly when
Terminal is listed. `Automation.isTrusted` says which, and
`Automation.requestTrust()` shows the prompt.

The screen must be unlocked.

macOS only, and not by choice — no other platform lets one app read and
drive another's interface.

## Tests

`swift test` runs the rules — labels, refs, matching, press methods,
keystroke chunking, value coercion — on hand-built values, with no app.

`APPAUTOMATION_LIVE=1 swift test --filter WaitLiveTests` waits on the same
fixture in its timeline mode, which takes no focus and is never touched: it
stays in the background and adds, enables and removes a button on a
schedule.

`APPAUTOMATION_LIVE=1 swift test --filter LiveTests` drives
`AutomationFixture`, a window with known controls that prints its own state
as JSON on every change. The assertions are made against what the fixture
reports, never against what Accessibility claims — Accessibility's claims
are what is being tested. It needs an unlocked GUI session, and it takes
focus while it runs.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-app-automation.git", from: "0.1.0")
```

## Licence

MIT.
