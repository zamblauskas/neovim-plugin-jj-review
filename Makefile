# Tools come from PATH, else from Mason.
MASON_BIN := $(HOME)/.local/share/nvim/mason/bin
tool = $(or $(shell command -v $(1) 2>/dev/null),$(MASON_BIN)/$(1))
STYLUA := $(call tool,stylua)
SELENE := $(call tool,selene)
LUALS := $(call tool,lua-language-server)

export VIMRUNTIME := $(shell nvim --clean --headless -c 'lua io.write(vim.env.VIMRUNTIME)' -c 'qa!')

.PHONY: check test lint format format-check typecheck

check: format-check lint typecheck test

test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', sequential = true }"

format:
	$(STYLUA) lua tests

format-check:
	$(STYLUA) --check lua tests

lint:
	$(SELENE) lua tests

typecheck:
	$(LUALS) --check=$(CURDIR) --configpath=$(CURDIR)/.luarc.check.json --checklevel=Warning
