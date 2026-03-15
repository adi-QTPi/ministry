{ pkgs, ... }: {
  home.packages = with pkgs; [
    # --- Network Recon & Mapping ---
    nmap                 # The gold standard port scanner
    bind                 # Provides 'dig' and 'nslookup' for DNS recon
    whois                # Domain and IP registration info
    socat                # The modern, vastly more powerful netcat
    
    # --- Web Fuzzing & Scanning ---
    ffuf                 # Blazing fast web fuzzer (directory/endpoint discovery)
    gobuster             # Alternative tool for URI and DNS fuzzing
    nuclei               # Template-based vulnerability scanner (incredible tool)
    nikto                # Classic web server misconfiguration scanner
    
    # --- Traffic Analysis & Payloads ---
    termshark            # TUI for Wireshark (packet analysis in the terminal)
    sqlmap               # Automatic SQL injection detection and exploitation
    
    # --- Utilities ---
    jq                   # Essential for parsing JSON output from security tools
    yq-go                # Like jq, but for YAML/XML (great for config auditing)
    hexyl                # A command-line hex viewer (good for inspecting binaries/payloads)
    jwt-cli              # Decode and inspect JSON Web Tokens instantly
  ];

  # Optional: If you download wordlists (like SecLists), you might want to map them
  # home.sessionVariables = {
  #   WORDLISTS = "$HOME/SecLists";
  # };
}