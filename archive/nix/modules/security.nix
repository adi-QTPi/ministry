{ pkgs, ... }: {
  home.packages = with pkgs; [
    # --- Network Recon & Mapping (CLI) ---
    nmap                 # The gold standard port scanner
    masscan              # Asynchronous, extremely fast port scanner for massive networks
    arp-scan             # Local network ARP discovery (perfect for finding headless devices)
    bind                 # Provides 'dig' and 'nslookup' for DNS recon
    whois                # Domain and IP registration info
    socat                # The modern, vastly more powerful netcat
    
    # --- Packet Capture & Traffic Analysis (CLI/TUI) ---
    tshark               # Terminal-based Wireshark (headless captures and filtering)
    tcpdump              # Classic command-line packet sniffer (essential for your OpenWrt SSH pipe)
    termshark            # TUI for Wireshark (graphical packet analysis directly in the terminal)
    aircrack-ng          # Wireless security suite (CLI tools for offline cracking and analysis)
    
    # --- Web Interception & Fuzzing (CLI/TUI) ---
    mitmproxy            # Interactive TUI intercepting HTTP/TLS proxy (the ultimate terminal alternative to Burp)
    ffuf                 # Blazing fast web fuzzer (directory/endpoint discovery)
    gobuster             # Alternative tool for URI and DNS fuzzing
    nuclei               # Template-based vulnerability scanner
    nikto                # Classic web server misconfiguration scanner
    
    # --- Exploitation & Payloads (CLI) ---
    sqlmap               # Automatic SQL injection detection and exploitation
    metasploit           # The standard exploitation framework (runs entirely via msfconsole)
    (python3.withPackages (ps: with ps; [ 
      scapy              # Interactive packet manipulation (forge and decode raw frames byte-by-byte)
      requests 
    ]))
    
    # --- Utilities & Cryptography (CLI) ---
    jq                   # Essential for parsing JSON output from security tools
    yq-go                # Like jq, but for YAML/XML (great for declarative config auditing)
    hexyl                # A command-line hex viewer (good for inspecting binaries/payloads)
    jwt-cli              # Decode and inspect JSON Web Tokens instantly
    hashcat              # Advanced password recovery (for cracking the WPA handshakes you capture)
  ];

  # Optional: If you download wordlists (like SecLists), map them here for easy CLI access
  # home.sessionVariables = {
  #   WORDLISTS = "$HOME/SecLists";
  # };
}