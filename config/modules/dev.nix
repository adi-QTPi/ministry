{ pkgs, ... }: {
  home.packages = with pkgs; [
    git
    go
    air
    nodejs
    opencode
    nil
    rustup
  ];

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
    "/Applications/Antigravity.app/Contents/Resources/app/bin"
    "/Applications/Antigravity\ IDE.app/Contents/Resources/app/bin"
  ];
}