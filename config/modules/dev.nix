{ pkgs, ... }: {
  home.packages = with pkgs; [
    go
    docker
    docker-compose
    opencode
    nil
  ];
}