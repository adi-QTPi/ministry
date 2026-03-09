{ pkgs, ... }: {

  home.sessionPath = [ 
    "$HOME/.nix-profile/bin"
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellAliases = { "cd" = "z"; };
  };
  programs.zoxide.enable = true;
  programs.fzf.enable = true;
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "[╭─ ](dimmed white)$os$directory$git_branch$git_status$fill$username$hostname$cmd_duration$time$line_break[╰─](dimmed white)$character";
      right_format = "$battery";
      fill = {
        symbol = "·";
        style = "dimmed white";
      };
      os = {
        disabled = false;
        format = "[$symbol ]($style)";
        style = "bold blue";
        symbols = {
          Macos = ""; # Apple logo
          Ubuntu = "";
          Windows = "󰍲";
        };
      };
      git_branch = {
        format = "[ $symbol$branch ]($style)";
        symbol = ""; 
        style = "bold purple";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "bold red";
        conflicted = "~";
        up_to_date = "";
        untracked = "?";   # Simple question mark
        stashed = "≡";     # Subtle math symbol for stack
        modified = "!";    # Exclamation for changed
        staged = "+";      # Plus for added to index
        renamed = "»";     # Double arrows for moved
        deleted = "x";     # Simple x for removed
      };
      directory = {
        format = "[󰋜 $path]($style) ";
        style = "bold blue";
        truncation_length = 3;
        truncate_to_repo = false;
      };
      username = {
        show_always = true;
        format = "[$user]($style)";
        style_user = "bold yellow";
      };
      hostname = {
        ssh_only = false;
        format = "[@$hostname]($style) ";
        style = "bold yellow";
      };
      cmd_duration = {
        format = "[󱦟$duration]($style) ";
        style = "dimmed cyan";
      };
      time = {
        disabled = false;
        format = "[󱑎 $time]($style)";
        time_format = "%H:%M:%S";
        style = "dimmed cyan";
      };
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
      battery = {
        disabled = false;
        format = "[$symbol$percentage]($style)";
        display = [
          { threshold = 100; style = "bold green"; }
        ];
      };
    };
  };
  programs.tmux = {
    enable = true;
    shortcut = "a";
    baseIndex = 0; 
    mouse = true; 
    extraConfig = ''
      bind | split-window -h
      bind - split-window -v

      unbind '"'
      unbind %

      bind r source-file ~/.tmux.conf \; display "Reloaded!"
    '';
  };
}