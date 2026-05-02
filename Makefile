.PHONY: format setup-git-hooks

format:
	swift format --recursive --in-place Package.swift Sources Tests

setup-git-hooks:
	mkdir -p .git/hooks
	for hook in githooks/*; do \
		[ -f "$$hook" ] || continue; \
		cp "$$hook" ".git/hooks/$$(basename "$$hook")"; \
		chmod +x ".git/hooks/$$(basename "$$hook")"; \
	done
