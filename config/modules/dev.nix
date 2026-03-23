{ pkgs, ... }: {
  home.packages = with pkgs; [
    git
    go
    air
    nodejs
    docker
    docker-compose
    opencode
    nil
  ];

  home.sessionPath = [
    "$HOME/.npm-global/bin"
    "$HOME/go/bin"
  ];
}