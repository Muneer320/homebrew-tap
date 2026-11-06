class Klicky < Formula
  desc "Mechanical keyboard sounds for desktop sessions"
  homepage "https://klicky.muneer320.tech/"
  url "https://github.com/Muneer320/klicky/releases/download/v0.5.0/klicky-0.5.0-source.tar.gz"
  sha256 "cbf9714596e0966c5fbaa150545681e1361d2b36773f172bc892941eba61354b"
  license "MIT"

  depends_on "rust" => :build
  depends_on :macos

  # Fixed package launcher and menu resource paths; upstream PR #94.
  patch :DATA

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    ENV["KLICKY_MACOS_INSTALL_BINARY"] = (opt_bin/"klicky").to_s
    system "cargo", "install", *std_cargo_args(root: libexec), "--bin", "klicky"
    system "swiftc", "packaging/macos/KlickyMenu.swift", "-o", "klicky-menu"
    (libexec/"bin").install "klicky-menu"
    (share/"klicky").install "sounds"
    (share/"klicky/branding").install "assets/branding/klicky-menu-template.png",
                                   "assets/branding/klicky-menu-template@2x.png"
    (bin/"klicky").write_env_script opt_libexec/"bin/klicky",
                                  KLICKY_SYSTEM_SOUNDS_DIR: opt_share/"klicky/sounds"
    (bin/"klicky-menu").write_env_script opt_libexec/"bin/klicky-menu",
                                       KLICKY_MENU_CLI:  opt_bin/"klicky",
                                       KLICKY_MENU_ICON: opt_share/"klicky/branding/klicky-menu-template.png"
    doc.install "ACKNOWLEDGEMENTS.md", "LICENSE", "sounds/LICENSE.md" => "SOUNDS-LICENSE.md"
  end

  def caveats
    <<~EOS
      Open the menu and enable keyboard sounds:
        brew services start muneer320/tap/klicky
        klicky service enable

      macOS requires Accessibility permission for:
        #{opt_libexec}/bin/klicky
      Allow it in System Settings > Privacy & Security > Accessibility,
      then run: klicky service start

      Before upgrading, stop the daemon with: klicky service stop
      After upgrading, run: klicky service start

      Before uninstalling, remove both user login services:
        klicky service disable && brew services stop muneer320/tap/klicky
      Then run: brew uninstall muneer320/tap/klicky
      Settings and custom packs stay in ~/Library/Application Support/klicky.
      Use one installation method; remove a source install before switching.
    EOS
  end

  service do
    run opt_bin/"klicky-menu"
    keep_alive false
    require_root false
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/klicky --version")
    assert_match "eg-oreo", shell_output("#{bin}/klicky list")
    system bin/"klicky", "volume", "0.2"
    assert_path_exists testpath/"Library/Application Support/klicky/config.toml"
  end
end

__END__
diff --git a/packaging/macos/KlickyMenu.swift b/packaging/macos/KlickyMenu.swift
index 131c98c..553657c 100644
--- a/packaging/macos/KlickyMenu.swift
+++ b/packaging/macos/KlickyMenu.swift
@@ -5,14 +5,14 @@ final class KlickyMenu: NSObject, NSApplicationDelegate {
     private var item: NSStatusItem!
     private let toggle = NSMenuItem(title: "Turn Klicky On", action: #selector(toggleKlicky), keyEquivalent: "")
     private let status = NSMenuItem(title: "Checking status…", action: nil, keyEquivalent: "")
-    private let binary = FileManager.default.homeDirectoryForCurrentUser
+    private let binary = ProcessInfo.processInfo.environment["KLICKY_MENU_CLI"] ?? FileManager.default.homeDirectoryForCurrentUser
         .appendingPathComponent(".local/bin/klicky").path
     private var running = false
     private var enabled = false
 
     func applicationDidFinishLaunching(_ notification: Notification) {
         item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
-        let iconPath = FileManager.default.homeDirectoryForCurrentUser
+        let iconPath = ProcessInfo.processInfo.environment["KLICKY_MENU_ICON"] ?? FileManager.default.homeDirectoryForCurrentUser
             .appendingPathComponent("Library/Application Support/klicky/branding/klicky-menu-template.png").path
         if let data = try? Data(contentsOf: URL(fileURLWithPath: iconPath)),
            let standard = NSBitmapImageRep(data: data) {
diff --git a/src/service.rs b/src/service.rs
index 5ef3310..8ba3279 100644
--- a/src/service.rs
+++ b/src/service.rs
@@ -348,7 +348,12 @@ fn stop_launch_agent(
 
 #[cfg(any(target_os = "macos", test))]
 fn installed_binary(home: &std::path::Path) -> Result<std::path::PathBuf> {
-    let binary = std::fs::canonicalize(home)?.join(".local/bin/klicky");
+    // A package build may pin a stable launcher inside its managed prefix.
+    // This is a build-time setting, never an override from the running user's environment.
+    let binary = match option_env!("KLICKY_MACOS_INSTALL_BINARY") {
+        Some(path) => std::path::PathBuf::from(path),
+        None => std::fs::canonicalize(home)?.join(".local/bin/klicky"),
+    };
     validate_installed_binary(&binary)?;
     Ok(binary)
 }
@@ -357,19 +362,26 @@ fn installed_binary(home: &std::path::Path) -> Result<std::path::PathBuf> {
 fn validate_installed_binary(binary: &std::path::Path) -> Result<()> {
     use std::os::unix::fs::PermissionsExt;
     let validate = || -> Result<()> {
-        if !binary.is_absolute() || !binary.ends_with(".local/bin/klicky") {
-            bail!("expected the installed ~/.local/bin/klicky executable");
+        let package_binary = option_env!("KLICKY_MACOS_INSTALL_BINARY");
+        let expected = match package_binary {
+            Some(path) => binary == std::path::Path::new(path),
+            None => binary.ends_with(".local/bin/klicky"),
+        };
+        if !binary.is_absolute() || !expected {
+            bail!("expected the installed Klicky executable");
         }
         let metadata = std::fs::symlink_metadata(binary)?;
         if !metadata.is_file() || metadata.permissions().mode() & 0o111 == 0 {
             bail!("installed path must be a regular executable file, not a symlink");
         }
-        if std::fs::canonicalize(binary)? != binary {
+        // Homebrew's opt directory is a managed symlink to the current keg.
+        // Source installs retain the stricter no-redirection rule.
+        if package_binary.is_none() && std::fs::canonicalize(binary)? != binary {
             bail!("installed path must not redirect through symlinks or parent traversal");
         }
         Ok(())
     };
-    validate().with_context(|| format!("Invalid installed Klicky binary at {}. Run ./scripts/install-macos.sh from the repository to install a regular executable at ~/.local/bin/klicky", binary.display()))
+    validate().with_context(|| format!("Invalid installed Klicky binary at {}. Repair it using the installation method that owns this path", binary.display()))
 }
 
 #[cfg(any(target_os = "macos", test))]
