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

  home.sessionVariables = {
    DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";
  };

  systemd.user.services.docker = {
    Unit = {
      Description = "Docker Application Container Engine (Rootless)";
    };
    Service = {
      Environment = [ "PATH=${pkgs.docker}/bin:/bin:/usr/bin:/sbin:/usr/sbin" ];
      ExecStart = "${pkgs.docker}/bin/dockerd-rootless.sh --experimental";
      ExecReload = "/bin/kill -s HUP $MAINPID";
      LimitNOFILE = 1048576;
      LimitNPROC = "infinity";
      LimitCORE = "infinity";
      Delegate = "yes";
      KillMode = "mixed";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}