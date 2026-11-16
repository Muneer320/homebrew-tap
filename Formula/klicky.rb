class Klicky < Formula
  desc "Mechanical keyboard sounds for desktop sessions"
  homepage "https://klicky.muneer320.tech/"
  url "https://github.com/Muneer320/klicky/releases/download/v0.6.1/klicky-0.6.1-source.tar.gz"
  sha256 "a65648c30d56a5177ff560606cd3a50535e5e6f02adf8822660bbcab2739df9c"
  license "MIT"

  depends_on "rust" => :build
  depends_on arch: :arm64
  depends_on :macos

  deny_network_access!

  def fetch
    system "cargo", "fetch", *std_cargo_fetch_args
  end

  def install
    ENV["KLICKY_MACOS_INSTALL_BINARY"] = (opt_bin/"klicky").to_s
    system "cargo", "install", *std_cargo_args(root: libexec), "--bin", "klicky"
    system "swiftc", "packaging/macos/KlickyMenu.swift", "-o", "klicky-menu"
    (libexec/"bin").install "klicky-menu"
    pkgshare.install "sounds"
    (pkgshare/"branding").install "assets/branding/klicky-menu-template.png",
                                 "assets/branding/klicky-menu-template@2x.png"
    (bin/"klicky").write_env_script opt_libexec/"bin/klicky",
                                  KLICKY_SYSTEM_SOUNDS_DIR: opt_pkgshare/"sounds"
    (bin/"klicky-menu").write_env_script opt_libexec/"bin/klicky-menu",
                                       KLICKY_MENU_CLI:  opt_bin/"klicky",
                                       KLICKY_MENU_ICON: opt_pkgshare/"branding/klicky-menu-template.png"
    doc.install "ACKNOWLEDGEMENTS.md", "LICENSE"
    doc.install pkgshare/"sounds/LICENSE.md" => "SOUNDS-LICENSE.md"
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
    name macos: "dev.klicky.homebrew-menu"
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
