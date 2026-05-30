{ pkgs, ... }: 

let
  myTerminalTools = with pkgs; [
    watch
    eza
    btop
    lazygit
    curlie
    fzf
    neofetch
  ];
in
{
  home.packages = myTerminalTools;

  programs.micro = {
    enable = true;
    settings = {
      colorscheme = "solarized-dark";
      autoclose = true;      # Enables IDE-style bracket and quote completion
      syntax = true;         # Enables syntax highlighting
      tabsize = 4;
      tabstospaces = true;
      softwrap = true;
      ruler = true;          # Shows line and column numbers at the bottom
    };
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellAliases = { 
      "cd" = "z"; 
      "ls" = "eza --icons --group-directories-first";
      "top" = "btop";
      "lgit" = "lazygit";
      "curl" = "curlie";
    };
  };
  
  home.sessionVariables = {
    LANG = "C.UTF-8";
    LC_ALL = "C.UTF-8";
    EDITOR = "emacs";
  };

  programs.neovim = {
    enable = true;
    defaultEditor = false;
    viAlias = true;
    vimAlias = true;
    
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      which-key-nvim
      vim-colors-solarized
    ];

    initLua = ''
      -- 1. Core Keymaps (Leader must be set first)
      vim.g.mapleader = " "
      vim.keymap.set('i', 'jk', '<Esc>', { noremap = true, silent = true })

      -- 2. Aesthetics & UI
      vim.o.background = "dark"
      vim.cmd("colorscheme solarized")
      vim.opt.termguicolors = true
      vim.opt.number = true
      vim.opt.relativenumber = true

      -- 3. Indentation
      vim.opt.tabstop = 4
      vim.opt.shiftwidth = 4
      vim.opt.expandtab = true

      -- 4. Plugin Initialization
      require("which-key").setup {
        delay = 500,
      }
    '';
  };
  
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "[╭─ ](dimmed white)$os$username$hostname$directory$git_branch$git_status$fill$cmd_duration$time$line_break[│](dimmed white)\n[╰─](dimmed white)$character";
      right_format = "\${custom.charging_status}$battery"; 

      custom.charging_status = {
        description = "Check if laptop is charging via sysfs";
        command = ''
          if [ -f /sys/class/power_supply/ADP1/online ]; then
            [ "$(cat /sys/class/power_supply/ADP1/online)" -eq 1 ] && echo "⚡"
          fi
        '';
        when = "test -d /sys/class/power_supply/ADP1"; 
        shell = ["sh"];
        style = "bold yellow";
        format = "[$output]($style) "; 
      };

      fill = {
        symbol = "·";
        style = "dimmed white";
      };
      os = {
        disabled = false;
        format = "[$symbol ]($style)";
        style = "bold #268bd2";
        symbols = {
          Macos = ""; 
          Ubuntu = "";
          Windows = "󰍲";
        };
      };
      git_branch = {
        format = "[ $symbol$branch ]($style)";
        symbol = ""; 
        style = "bold #6c71c4";
      };
      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        style = "bold #dc322f";
        conflicted = "~";
        up_to_date = "";
        untracked = "?";   
        stashed = "≡";     
        modified = "!";    
        staged = "+";      
        renamed = "»";     
        deleted = "x";     
      };
      directory = {
        format = "[󰉋 $path]($style) ";
        style = "bold #2aa198";
        truncation_length = 3;
        truncate_to_repo = false;
      };
      username = {
        show_always = true;
        format = "[ $user]($style)";
        style_user = "bold #2aa198";
      };
      hostname = {
        ssh_only = false;
        format = "[@$hostname ]($style) ";
        style = "bold #b28d1e";
      };
      cmd_duration = {
        format = "[⏳ $duration]($style) ";
        style = "dimmed #586e75";
      };
      time = {
        disabled = false;
        format = "[🦉 $time]($style)";
        time_format = "%H:%M:%S";
        style = "bold #586e75";
      };
      character = {
        success_symbol = " [ϟ](bold #859900)";
        error_symbol = " [ϟ](bold #dc322f)";
      };
      battery = {
        disabled = false;
        format = "[$symbol$percentage]($style)";
        display = [
          { threshold = 20; style = "bold red"; }
          { threshold = 100; style = "bold green"; }
        ];
      };
    };
  };
}
