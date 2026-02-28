.PHONY: help update switch test build boot prune

# NixOS flake lives in ./nixos
NIXOS_DIR ?= nixos
HOST ?= bloomware
FLAKE ?= ./$(NIXOS_DIR)#$(HOST)
KEEP_GENERATIONS ?= 10

help:
	@echo "Targets:"
	@echo "  make update   - nix flake update (in $(NIXOS_DIR))"
	@echo "  make switch   - sudo nixos-rebuild switch --flake $(FLAKE) --show-trace"
	@echo "  make test     - sudo nixos-rebuild test   --flake $(FLAKE) --show-trace"
	@echo "  make build    - sudo nixos-rebuild build  --flake $(FLAKE) --show-trace"
	@echo "  make boot     - sudo nixos-rebuild boot   --flake $(FLAKE) --show-trace"
	@echo "  make prune    - delete old generations (keep last $(KEEP_GENERATIONS)) and garbage collect"

update:
	cd $(NIXOS_DIR) && nix flake update

switch:
	sudo nixos-rebuild switch --flake $(FLAKE) --show-trace

test:
	sudo nixos-rebuild test --flake $(FLAKE) --show-trace

build:
	sudo nixos-rebuild build --flake $(FLAKE) --show-trace

boot:
	sudo nixos-rebuild boot --flake $(FLAKE) --show-trace

prune:
	@echo "Pruning system generations (keeping last $(KEEP_GENERATIONS))..."
	sudo nix-env --delete-generations +$(KEEP_GENERATIONS) -p /nix/var/nix/profiles/system
	@echo "Pruning user generations (keeping last $(KEEP_GENERATIONS))..."
	nix-env --delete-generations +$(KEEP_GENERATIONS)
	@echo "Running garbage collection..."
	sudo nix-collect-garbage
