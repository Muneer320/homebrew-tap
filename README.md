# Klicky for Homebrew

[Klicky](https://klicky.muneer320.tech/) adds mechanical keyboard sounds to your desktop. This project-owned tap builds the Rust app and native Swift menu helper for macOS, with all ten sound packs. Requires [Homebrew](https://brew.sh/) and Apple's Command Line Tools (`xcode-select --install`). Apple Silicon and Intel macOS packages are checked in CI.

## Install and start

```bash
brew install muneer320/tap/klicky && brew services start muneer320/tap/klicky && klicky service enable
```

The initial installation compiles from source, so allow a few minutes. **macOS must ask you for Accessibility permission.** Allow the binary shown by `brew info klicky` under System Settings → Privacy & Security → Accessibility, then run `klicky service start`. A terminal command cannot approve this permission for you.

Homebrew manages the menu helper; Klicky's menu and `service` commands manage its separate sound daemon. To omit the menu, leave out `brew services start muneer320/tap/klicky`. Use the menu's power control to stop/start sounds without losing the menu itself. Quitting the menu leaves sounds running.

Use one installation method. Before switching from the source installer, run its [uninstall command](https://klicky.muneer320.tech/guide.html) without purge. Your saved preferences and custom packs will carry over. Do not run a source-installed menu helper alongside this one.

## Update

```bash
klicky service stop && brew update && brew upgrade muneer320/tap/klicky && brew services restart muneer320/tap/klicky && klicky service start
```

If you opted out of the menu, omit `brew services restart muneer320/tap/klicky` from that line. The launchers and resource paths remain stable through Homebrew's `opt` directory. macOS may require Accessibility approval again after rebuilding the executable. Settings remain in `~/Library/Application Support/klicky`.

## Remove completely

```bash
klicky service disable && brew services stop muneer320/tap/klicky && brew uninstall muneer320/tap/klicky
```

Run the complete line **before** removing the formula. Plain `brew uninstall` removes package files, but cannot clean Klicky's independently managed daemon registration. The line above removes both login registrations, stops the app and menu, and preserves your configuration and custom packs.

To erase those preferences and custom packs too, delete `~/Library/Application Support/klicky` after uninstalling. Do not delete it while another Klicky installation still uses it.

## Package maintenance

The formula verifies the versioned v0.5.0 source archive by SHA-256 and applies the small [managed-path adaptation](https://github.com/Muneer320/klicky/pull/94) as an inline patch. Released assets are unchanged. It installs only into Homebrew's managed prefix; it does not modify your home directory or start monitoring during the build.

CI covers Apple Silicon and Intel source builds, formula style/audit, sound discovery, configuration persistence, stable launch paths, menu startup, reinstall and removal. Hosted runners do not provide an interactive Accessibility grant or physical latency measurements. Bottles and Homebrew/core admission are separate future work; this tap is directly installable without core acceptance.

[Source and issues](https://github.com/Muneer320/klicky) · [User guide](https://klicky.muneer320.tech/guide.html) · [Package issue tracker](https://github.com/Muneer320/homebrew-tap/issues)
