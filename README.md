<p align="center">
  <img src="Resources/Dia%20Router.icon/Assets/dia.svg" width="96" height="96" alt="Dia Router icon">
</p>

# Dia Router

Dia Router is a small macOS menu-bar app that sends links to the right [Dia](https://www.diabrowser.com/) profile. It owns the routing rules, Dia profile mapping, default-browser handling, and an optional Chromium extension for explicitly sending a link to another profile.

No signing identity, certificate, credentials, or machine-specific configuration is committed to the repository.

## Requirements

- macOS 14 or later
- Dia installed with at least one profile
- Xcode Command Line Tools, or Xcode, for building the app
- ImageMagick only if you want to regenerate the checked-in Chrome extension PNG icons

## How routing works

1. Dia Router receives an `http` or `https` URL as the macOS default web handler.
2. The first matching rule selects a Dia profile. Unmatched URLs use the chosen default profile.
3. Dia Router activates Dia and invokes the shortcut assigned to that profile.
4. It opens the original URL explicitly in Dia, avoiding a default-browser loop.

Dia Router reads profile names and order from Dia's local Chromium profile state. It does not read Dia's keyboard-shortcut settings, so the shortcut numbers must be aligned in both apps.

The built-in rules initially send Slack, Linear, Notion, and Google Meet to the first profile. You can edit the rules and default profile in Settings.

## Build and install

```sh
./scripts/build-app.sh
./scripts/install-app.sh
```

The install script places the app at `~/Applications/Dia Router.app` and launches it. The app registers its embedded login item through `SMAppService`, so macOS attributes background activity to Dia Router rather than to a shell or system helper.

To launch the currently installed app and let it register its login item without rebuilding, run:

```sh
./scripts/install-login-item.sh
```

## Align Dia profile shortcuts

Dia Router detects Dia profiles automatically when the app starts and whenever Settings opens. Add, remove, or rename profiles in Dia, then reopen Dia Router Settings to sync them. There is no separate **Add Profile** action in Router.

The default mapping follows Dia's detected profile order:

| Dia profile order | Expected Dia shortcut | Router setting |
| --- | --- | --- |
| First profile | `⌘⌥1` | `⌘⌥1` |
| Second profile | `⌘⌥2` | `⌘⌥2` |
| Third profile | `⌘⌥3` | `⌘⌥3` |
| Fourth through ninth | `⌘⌥4` through `⌘⌥9` | Matching number |

In Dia, open **Settings → Shortcuts** and assign each profile-switching action to `Command-Option-1` through `Command-Option-9` in the same order shown in Dia Router. If you later use a different number for a profile, change that profile's shortcut picker in Router to match. Dia Router supports up to nine shortcut-mapped profiles.

`profile=Other` selects the profile after the currently active Dia profile. With two profiles it toggles between them; with three or more it advances through the detected order.

## First-run setup

1. Open Dia Router Settings from its menu-bar icon.
2. Confirm that the detected profile names and shortcut numbers match Dia.
3. Click **Request Permission**, then allow Dia Router in **System Settings → Privacy & Security → Accessibility**.
4. Click **Set Dia Router as Default**.
5. Use **Test Routing** to preview and open a URL before relying on the rules day to day.

## Install the Chrome extension

The standalone Manifest V3 extension in [`chrome-extension`](chrome-extension) provides a dedicated gesture for links that should go to another Dia profile. Chromium Cleanup intentionally does not include this routing code, so the behavior remains isolated and optional.

1. Build and install the Dia Router macOS app first.
2. In Dia, open `chrome://extensions`.
3. Turn on **Developer mode**.
4. Click **Load unpacked** and select this repository's `chrome-extension` folder.
5. Repeat **Load unpacked** in every Dia profile or container that does not share data/extensions and where you want to use the gesture. Each non-sharing profile has its own extension installation; you can select the same `chrome-extension` folder each time.
6. On the first routed link, approve Dia's prompt to open `Dia Router.app`. You can select **Always allow** for subsequent links.

Use either of these commands on an `http` or `https` link:

- `Command-Shift-click` sends the link to the next Dia profile.
- Right-click and choose **Open link in other Dia profile**.

The exact `Command-Shift-click` modifier avoids conflicting with Dia's `Option-click` split-tab behavior. The extension has no settings, analytics, external requests, or profile-specific names. It only passes the clicked URL to the locally installed app using the `dia-router://` protocol. Browser-internal pages do not allow content scripts, so the gesture is available on ordinary web pages only.

The app also accepts a named profile from other Chromium extensions:

```text
dia-router://open?url=https%3A%2F%2Fexample.com&profile=Personal
```

Profile names are matched case-insensitively. Use `profile=Other` for the next profile without hard-coding a name.

## Extension icons

The checked-in PNG extension icons are generated from [`Resources/Dia Router.icon/Assets/dia.svg`](Resources/Dia%20Router.icon/Assets/dia.svg), which remains the single SVG source of truth:

```sh
brew install imagemagick
./scripts/generate-extension-icons.sh
```

The script produces transparent 16, 32, 48, and 128 px PNGs in `chrome-extension/icons`.

## Signing

The repository does not contain a personal signing identity. By default, `build-app.sh` uses an ad-hoc signature so anyone can build the app without an Apple Developer account.

For a stable local signature, first list the identities available in your keychain:

```sh
security find-identity -v -p codesigning
```

Then either provide the identity for one build:

```sh
DIA_ROUTER_SIGNING_IDENTITY='Apple Development: YOUR NAME (TEAMID)' ./scripts/build-app.sh
```

Or create an ignored local file at `scripts/signing.local.zsh`:

```sh
export DIA_ROUTER_SIGNING_IDENTITY='Apple Development: YOUR NAME (TEAMID)'
```

The local file is excluded by `.gitignore`. A stable signature helps macOS preserve Accessibility permission across rebuilds. After changing the signing identity, or replacing an older build that used a different bundle identifier, remove any stale Dia Router entry from Accessibility if necessary, install the rebuilt app, and grant it once more.

The unpacked Chrome extension does not require signing, a private key, or a Chrome Web Store account.

## License

Dia Router's source code and documentation are available under the [MIT License](LICENSE). The Dia name, logo, and derived icon assets are excluded from that license and remain the property of their respective owners. This is an independent project and is not affiliated with or endorsed by Dia.

## Development

```sh
swift test
swift build
```
