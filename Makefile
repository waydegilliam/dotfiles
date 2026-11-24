OXFMT_ARGS := --config prettier/.prettierrc.json . '!**/*.toml'
TAPLO_ARGS = --package=@taplo/cli --call \
	'git ls-files -z --cached --others --exclude-standard -- "*.toml" | xargs -0 taplo format --option column_width=120 $(1)'
STYLUA_CONFIG := stylua/.config/stylua/stylua.toml
NVIM_PLUGINS_DIR := nvim/.config/nvim/pack/local/opt
NVIM_PLUGINS := $(patsubst tests/%/minimal_init.lua,%,$(wildcard tests/*/minimal_init.lua))
LUARC_FOR = $(CURDIR)/$(if $(wildcard tests/$(1)/.luarc.json),tests/$(1)/.luarc.json,tests/.luarc.json)

.PHONY: lint format test typecheck format-nvim check-nvim \
	$(addprefix test-,$(NVIM_PLUGINS)) \
	$(addprefix typecheck-,$(NVIM_PLUGINS)) \
	$(addprefix format-,$(NVIM_PLUGINS)) \
	$(addprefix check-,$(NVIM_PLUGINS))

lint:
	npx --yes oxfmt $(OXFMT_ARGS) --check >/dev/null 2>&1
	npx --yes $(call TAPLO_ARGS,--check) >/dev/null 2>&1

format:
	npx --yes oxfmt $(OXFMT_ARGS) --write >/dev/null 2>&1
	npx --yes $(call TAPLO_ARGS) >/dev/null 2>&1

test: $(addprefix test-,$(NVIM_PLUGINS))
typecheck: $(addprefix typecheck-,$(NVIM_PLUGINS))
format-nvim: $(addprefix format-,$(NVIM_PLUGINS))
check-nvim: $(addprefix check-,$(NVIM_PLUGINS))

$(addprefix test-,$(NVIM_PLUGINS)): test-%:
	nvim --headless --noplugin -u tests/$*/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/$* { minimal_init = 'tests/$*/minimal_init.lua' }"

$(addprefix typecheck-,$(NVIM_PLUGINS)): typecheck-%:
	@VIMRUNTIME="$$(nvim --headless -u NONE -c 'lua io.write(vim.env.VIMRUNTIME)' -c 'qa')" \
		PLUGIN_LUA_DIR="$(CURDIR)/$(NVIM_PLUGINS_DIR)/$*/lua" \
		sh -c '\
			lua-language-server --check "$(CURDIR)/$(NVIM_PLUGINS_DIR)/$*" --configpath="$(call LUARC_FOR,$*)" --checklevel=Warning && \
			lua-language-server --check "$(CURDIR)/tests/$*" --configpath="$(call LUARC_FOR,$*)" --checklevel=Warning \
		'

$(addprefix format-,$(NVIM_PLUGINS)): format-%:
	stylua --config-path $(STYLUA_CONFIG) $(NVIM_PLUGINS_DIR)/$* tests/$*

$(addprefix check-,$(NVIM_PLUGINS)): check-%:
	stylua --config-path $(STYLUA_CONFIG) --check $(NVIM_PLUGINS_DIR)/$* tests/$*
	$(MAKE) typecheck-$*
	$(MAKE) test-$*
