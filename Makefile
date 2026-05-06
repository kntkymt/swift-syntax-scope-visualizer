.PHONY: format setup-git-hooks license build-web

WASM_SDK ?= swift-6.3.1-RELEASE_wasm
CONFIG ?= release

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

build-web:
	swift package --swift-sdk $(WASM_SDK) js -c $(CONFIG) --use-cdn
	rm -rf dist
	mkdir -p dist
	cp -r .build/plugins/PackageToJS/outputs/Package dist/Package
	sed 's|\./\.build/plugins/PackageToJS/outputs/Package/index\.js|./Package/index.js|' index.html > dist/index.html
	touch dist/.nojekyll
