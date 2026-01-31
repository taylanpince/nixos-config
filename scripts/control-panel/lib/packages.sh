#!/usr/bin/env bash
# Package management

show_packages_menu() {
  clear
  show_header
  gum style --foreground="$SUBTEXT" "Packages"
  echo ""
  
  local choice
  choice=$(gum choose --cursor.foreground="$ACCENT" \
    "󰏗  Search Packages" \
    "󰦗  Rebuild NixOS" \
    "󰃢  Garbage Collect" \
    "󰈈  System Info" \
    "󰌍  Back")

  case "$choice" in
    *Search*)   search_packages ;;
    *Rebuild*)  rebuild_nixos ;;
    *Garbage*)  garbage_collect ;;
    *Info*)     system_info ;;
    *Back*)     back_to_main ;;
  esac
}

search_packages() {
  clear
  show_header
  
  local query
  query=$(gum input --placeholder="Search nixpkgs...")
  
  if [[ -n "$query" ]]; then
    spinner "Searching..." nix search nixpkgs "$query" 2>/dev/null > /tmp/nix-search-results.txt
    
    if [[ -s /tmp/nix-search-results.txt ]]; then
      gum pager < /tmp/nix-search-results.txt
    else
      notify "No packages found for '$query'" "warning"
      pause
    fi
    rm -f /tmp/nix-search-results.txt
  fi
  show_packages_menu
}

rebuild_nixos() {
  local action
  action=$(gum choose --cursor.foreground="$ACCENT" \
    "󰦗  switch (apply now)" \
    "󰃢  boot (apply on reboot)" \
    "󰈈  dry-run (preview)" \
    "󰌍  Back")

  case "$action" in
    *switch*)
      if confirm "Rebuild and switch NixOS configuration?"; then
        echo ""
        sudo nixos-rebuild switch 2>&1 | tee /tmp/nixos-rebuild.log
        notify "Rebuild complete" "success"
        pause
      fi
      ;;
    *boot*)
      if confirm "Rebuild for next boot?"; then
        echo ""
        sudo nixos-rebuild boot 2>&1 | tee /tmp/nixos-rebuild.log
        notify "Rebuild complete - changes apply on reboot" "success"
        pause
      fi
      ;;
    *dry-run*)
      echo ""
      spinner "Running dry-build..." sudo nixos-rebuild dry-build 2>&1 | tee /tmp/nixos-rebuild.log
      gum pager < /tmp/nixos-rebuild.log
      ;;
  esac
  show_packages_menu
}

garbage_collect() {
  clear
  show_header
  
  # Show current store size
  local store_size
  store_size=$(du -sh /nix/store 2>/dev/null | cut -f1)
  gum style --foreground="$SUBTEXT" "Nix store size: $store_size"
  echo ""
  
  local action
  action=$(gum choose --cursor.foreground="$ACCENT" \
    "󰃢  Delete old generations" \
    "󰃢  Delete generations older than 7 days" \
    "󰃢  Full garbage collect" \
    "󰌍  Back")

  case "$action" in
    *"old generations"*)
      if confirm "Delete all old generations?"; then
        spinner "Collecting garbage..." sudo nix-collect-garbage -d
        notify "Garbage collection complete" "success"
        pause
      fi
      ;;
    *"7 days"*)
      if confirm "Delete generations older than 7 days?"; then
        spinner "Collecting garbage..." sudo nix-collect-garbage --delete-older-than 7d
        notify "Garbage collection complete" "success"
        pause
      fi
      ;;
    *"Full"*)
      if confirm "Run full garbage collection? This may take a while."; then
        echo ""
        sudo nix-collect-garbage -d
        sudo nix-store --optimise
        notify "Full garbage collection complete" "success"
        pause
      fi
      ;;
  esac
  show_packages_menu
}

system_info() {
  clear
  show_header
  
  {
    echo "󱄅 NixOS $(nixos-version 2>/dev/null || echo 'unknown')"
    echo ""
    echo "󰌢 Kernel: $(uname -r)"
    echo "󰍛 Host: $(hostname)"
    echo "󰥔 Uptime: $(uptime -p | sed 's/up //')"
    echo ""
    echo "󰋊 Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
    echo "󰍛 Memory: $(free -h | awk '/Mem:/ {print $3 "/" $2}')"
    echo "󰻠 CPU: $(grep -c ^processor /proc/cpuinfo) cores"
    echo ""
    echo "󰏗 Nix store: $(du -sh /nix/store 2>/dev/null | cut -f1)"
  } | gum style --border="rounded" --border-foreground="$ACCENT" --padding="1"
  
  pause
  show_packages_menu
}
