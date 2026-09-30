OXFMT_ARGS := --config prettier/.prettierrc.json . '!**/*.toml'
TAPLO_ARGS = --package=@taplo/cli --call \
	'git ls-files -z --cached --others --exclude-standard -- "*.toml" | xargs -0 taplo format --option column_width=120 $(1)'

.PHONY: lint format

lint:
	npx --yes oxfmt $(OXFMT_ARGS) --check >/dev/null 2>&1
	npx --yes $(call TAPLO_ARGS,--check) >/dev/null 2>&1

format:
	npx --yes oxfmt $(OXFMT_ARGS) --write >/dev/null 2>&1
	npx --yes $(call TAPLO_ARGS) >/dev/null 2>&1
