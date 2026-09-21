# Host tools, applications and fonts owned by Homebrew.
# Only package-level trust is allowed.
# Each package chooses :latest (upgrade) or :installed (install only if missing).
# Bootstrap selects each group and delegates state checks to native Bundle.
# For a latest Cask, also set greedy: true to include auto-updating/unversioned apps.
# Example: cask "raycast", greedy: true if update_policy(:latest)
# Use install.sh apply/check; a direct brew bundle call does not apply group policies.

def update_policy(policy)
  unless [:latest, :installed].include?(policy)
    raise ArgumentError, "Invalid package update policy: #{policy}"
  end
  selected = ENV.fetch("DANSHAN_BREW_POLICY", "all")
  unless ["all", "latest", "installed"].include?(selected)
    raise ArgumentError, "Invalid Bundle policy selection: #{selected}"
  end
  selected == "all" || selected == policy.to_s
end

brew "wget" if update_policy(:latest)
brew "cloc" if update_policy(:latest)
brew "telnet" if update_policy(:latest)
brew "graphviz" if update_policy(:latest)
brew "lrzsz" if update_policy(:latest)
brew "neovim" if update_policy(:latest)
brew "fzf" if update_policy(:latest)
brew "thefuck" if update_policy(:latest)
brew "tig" if update_policy(:latest)
brew "httpie" if update_policy(:latest)
brew "autojump" if update_policy(:latest)
brew "tmux" if update_policy(:latest)
brew "ripgrep" if update_policy(:latest)
brew "diff-so-fancy" if update_policy(:latest)
brew "lazygit" if update_policy(:latest)
brew "tree" if update_policy(:latest)
brew "scrcpy" if update_policy(:latest)
brew "coreutils" if update_policy(:latest)
brew "daipeihust/tap/im-select", trusted: true if update_policy(:latest)
brew "gron" if update_policy(:latest)
brew "stow" if update_policy(:latest)
brew "mise" if update_policy(:latest)
brew "herdr" if update_policy(:latest)
brew "gh" if update_policy(:latest)
brew "glab" if update_policy(:latest)
brew "fastfetch" if update_policy(:latest)
brew "fish" if update_policy(:latest)
brew "zoxide" if update_policy(:latest)
brew "fd" if update_policy(:latest)
brew "bat" if update_policy(:latest)
brew "leaf-markdown-viewer" if update_policy(:latest)
brew "witr" if update_policy(:latest)
brew "zsh-autosuggestions" if update_policy(:latest)
brew "zsh-syntax-highlighting" if update_policy(:latest)
brew "starship" if update_policy(:latest)

cask "sublime-text" if update_policy(:installed)
cask "visual-studio-code" if update_policy(:installed)
cask "surge" if update_policy(:installed)
cask "wechat" if update_policy(:installed)
cask "feishu" if update_policy(:installed)
cask "intellij-idea" if update_policy(:installed)
cask "pycharm" if update_policy(:installed)
cask "webstorm" if update_policy(:installed)
cask "kap" if update_policy(:installed)
cask "appcleaner" if update_policy(:installed)
cask "keycastr" if update_policy(:installed)
cask "the-unarchiver" if update_policy(:installed)
cask "vlc" if update_policy(:installed)
cask "omnidisksweeper" if update_policy(:installed)
cask "qqmusic" if update_policy(:installed)
cask "android-platform-tools" if update_policy(:installed)
cask "bruno" if update_policy(:installed)
cask "zspace" if update_policy(:installed)
cask "shottr" if update_policy(:installed)
cask "raycast" if update_policy(:installed)
cask "google-chrome" if update_policy(:installed)
cask "microsoft-excel" if update_policy(:installed)
cask "microsoft-word" if update_policy(:installed)
cask "microsoft-powerpoint" if update_policy(:installed)
cask "microsoft-outlook" if update_policy(:installed)
cask "zed" if update_policy(:installed)
cask "font-hack-nerd-font" if update_policy(:installed)
cask "font-fira-code-nerd-font" if update_policy(:installed)
cask "font-jetbrains-mono-nerd-font" if update_policy(:installed)
cask "chatgpt" if update_policy(:latest)
cask "obsidian" if update_policy(:installed)
cask "1password" if update_policy(:installed)
cask "1password-cli" if update_policy(:installed)
cask "antigravity" if update_policy(:installed)
cask "ghostty" if update_policy(:installed)
cask "hammerspoon" if update_policy(:installed)
cask "detachhead/tap/rebased", trusted: true if update_policy(:installed)
cask "muxy-app/tap/muxy", trusted: true if update_policy(:latest)
# Skip Thaw on macOS 27 and later.
case MacOS.version.major.to_i
when 26
  cask "thaw" if update_policy(:installed)
when 14..25
  # The local tap reads committed Cask definitions from this repository.
  tap "danshan/env", File.expand_path(__dir__)
  cask "danshan/env/thaw@1", trusted: true if update_policy(:installed)
end
cask "localsend/localsend/localsend", trusted: true if update_policy(:installed)
