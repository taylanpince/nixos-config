.PHONY: help update switch test build boot

# NixOS flake lives in ./nixos
NIXOS_DIR ?= nixos
HOST ?= bloomware
FLAKE ?= ./$(NIXOS_DIR)#$(HOST)

help:
	@echo "Targets:"
	@echo "  make update   - nix flake update (in $(NIXOS_DIR))"
	@echo "  make switch   - sudo nixos-rebuild switch --flake $(FLAKE) --show-trace"
	@echo "  make test     - sudo nixos-rebuild test   --flake $(FLAKE) --show-trace"
	@echo "  make build    - sudo nixos-rebuild build  --flake $(FLAKE) --show-trace"
	@echo "  make boot     - sudo nixos-rebuild boot   --flake $(FLAKE) --show-trace"

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
