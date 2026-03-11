{ pkgs, ... }: {

  home.sessionPath = [ 
    "$HOME/.nix-profile/bin"
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    shellAliases = { 
      "cd" = "z"; 
      "ls" = "eza --icons --group-directories-first";
      "cat" = "bat";
      "top" = "btm";
      "lgit" = "lazygit";
      "curl" = "curlie";

      "vi" = "nvim";
      "vim" = "nvim";
    };
  };
  
  home.sessionVariables = {
    LANG = "C.UTF-8";
    LC_ALL = "C.UTF-8";
    EDITOR = "nvim";
  };

  # Modern Vim Setup (Neovim)
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      which-key-nvim
      vim-colors-solarized
    ];

    extraConfig = ''
      " Enable Solarized Dark
      syntax enable
      set background=dark
      colorscheme solarized
      
      " Basic quality of life settings
      set number           " Show line numbers
      set relativenumber   " Show relative line numbers for easy jumping
      set tabstop=2        " 2 spaces for tabs (standard for YAML/Nix)
      set shiftwidth=2
      set expandtab
      set termguicolors    " Enable true color support

      " Initialize the Which-Key popup menu
      lua << EOF
        -- Map the leader key to Space (standard modern convention)
        vim.g.mapleader = " "
        
        -- Start Which-Key
        require("which-key").setup {
          delay = 500, -- Delay in milliseconds before the popup shows
        }
      EOF
    '';
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
          Macos = ""; 
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
        untracked = "?";   
        stashed = "≡";     
        modified = "!";    
        staged = "+";      
        renamed = "»";     
        deleted = "x";     
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
}