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
  ];
}