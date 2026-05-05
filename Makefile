.PHONY: format setup-git-hooks license

format:
	swift format --recursive --in-place Package.swift Sources Tests

generate-license-list:
	swift package --allow-writing-to-package-directory --allow-network-connections all generate-license-list

setup-git-hooks:
	mkdir -p .git/hooks
	for hook in githooks/*; do \
		[ -f "$$hook" ] || continue; \
		cp "$$hook" ".git/hooks/$$(basename "$$hook")"; \
		chmod +x ".git/hooks/$$(basename "$$hook")"; \
	done
