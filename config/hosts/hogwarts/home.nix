{ config, pkgs, ... }: {
  imports = [ ../../modules/shell.nix ../../modules/dev.nix ../../modules/desktop.nix ];

  home.username = "aditya";
  home.homeDirectory = "/Users/aditya";
  home.stateVersion = "24.11";

  programs.zsh.shellAliases = {
    hm = "home-manager switch --flake ~/03-TechEd/01-homelab/rubie-homelab/config#aditya@hogwarts";
  };

  # GPG configuration
  programs.gpg = {
    enable = true;
    package = pkgs.gnupg;
  };

  # GPG Agent configuration
  services.gpg-agent = {
    enable = true;
    enableZshIntegration = true;
    pinentry.package = pkgs.pinentry_mac;
  };

  home.file."Library/Fonts/home-manager".source = 
    config.lib.file.mkOutOfStoreSymlink "${config.home.path}/share/fonts";

  programs.home-manager.enable = true;
}