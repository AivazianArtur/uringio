# Tested on Fedora 43

LIBURING_DIR := vendor/liburing
LIBURING_LIB := $(LIBURING_DIR)/src/liburing.a
STUBS_DIR := uringio_stubs
STUBTEST_ALLOWLIST := stubtest_allowlist.txt

PYTHON := python3
VENV := .venv
PIP := $(VENV)/bin/pip
PY := $(VENV)/bin/python
VENV_STAMP := $(VENV)/.stamp
CIBUILDWHEEL := $(PY) -m cibuildwheel
WHEELHOUSE := wheelhouse

EXAMPLES_DIR := docs/examples
TESTS_DIR := tests
# --- C-level tests (tests/c_tests) ---
CTESTS_DIR := tests/c_tests
CTESTS_FILES_BIN := $(CTESTS_DIR)/test_files_bin
CTESTS_SOCKETS_BIN := $(CTESTS_DIR)/test_sockets_bin
CTESTS_BUFFERS_BIN := $(CTESTS_DIR)/test_buffer_controllers_bin
CTESTS_REGISTRY_BIN := $(CTESTS_DIR)/test_registry_bin

SRC := src

CTESTS_DEPS := \
    $(SRC)/ops/files/files.c \
    $(SRC)/ops/files/buffer_select.c \
    $(SRC)/ops/files/fixed.c \
    $(SRC)/ops/files/multishot.c \
    $(SRC)/ring/ring.c \
    $(SRC)/ring/sqe_helper.c \
    $(SRC)/timer/timer.c

CTESTS_SOCKETS_DEPS := \
    $(SRC)/ops/sockets/sockets.c \
    $(SRC)/ops/sockets/buffer_select.c \
    $(SRC)/ops/sockets/fixed.c \
    $(SRC)/ops/sockets/multishot.c \
    $(SRC)/ops/sockets/zerocopy.c \
    $(SRC)/ring/ring.c \
    $(SRC)/ring/sqe_helper.c \
    $(SRC)/timer/timer.c

CTESTS_BUFFERS_DEPS := \
    $(SRC)/buffer_controllers/buffer_index.c \
    $(SRC)/buffer_controllers/buffer_modes.c \
    $(SRC)/ring/ring.c \
    $(SRC)/ring/sqe_helper.c \
    $(SRC)/timer/timer.c

CTESTS_REGISTRY_DEPS := \
    $(SRC)/registry/registry.c \
    $(SRC)/python_api/buffers/buffers.c \
    $(SRC)/buffer_controllers/buffer_index.c \
    $(SRC)/buffer_controllers/buffer_modes.c \
    $(SRC)/ring/ring.c \
    $(SRC)/ring/sqe_helper.c \
    $(SRC)/timer/timer.c

CTESTS_INCLUDES := \
    -D_GNU_SOURCE \
    -I $(SRC) \
    -I $(SRC)/python_api \
    -I $(SRC)/python_api/buffers \
    -I $(SRC)/python_api/execution_context \
    -I $(SRC)/registry \
    -I $(SRC)/buffer_controllers \
    -I $(SRC)/ring \
    -I $(SRC)/timer \
    -isystem vendor/liburing/include \
    -isystem vendor/liburing/src/include \
    -isystem vendor/liburing/src \
    -isystem vendor/liburing

ASAN_LIB := $(shell \
    if command -v ldconfig >/dev/null 2>&1; then \
        ldconfig -p | awk '/libasan\.so/ {print $$NF; exit}'; \
    else \
        echo /lib64/libasan.so.8; \
    fi)

ASAN_CFLAGS := -O0 -g3 -DURINGIO_DEBUG -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=all
ASAN_LDFLAGS := -fsanitize=address,undefined

ASAN_OPTIONS := detect_leaks=0:abort_on_error=1:halt_on_error=1:strict_string_checks=1
UBSAN_OPTIONS := print_stacktrace=1:halt_on_error=1

PKG_MANAGER := $(shell command -v dnf 2>/dev/null | xargs basename || command -v apt 2>/dev/null | xargs basename)


all: build


check-submodule:
	@if [ ! -f "$(LIBURING_DIR)/Makefile" ]; then \
		echo "Liburing submodule not found. Initializing..."; \
		git submodule update --init --recursive; \
	fi
	@if [ ! -f "$(LIBURING_DIR)/Makefile" ]; then \
		echo "Error: Failed to initialize submodule."; \
		exit 1; \
	fi
	@if [ ! -f "$(LIBURING_DIR)/src/include/liburing/compat.h" ]; then \
		echo "liburing not configured. Running configure..."; \
		cd $(LIBURING_DIR) && ./configure; \
	fi


$(VENV_STAMP): Makefile
	@echo "Creating/updating virtualenv..."
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip setuptools wheel cibuildwheel pytest mypy librt build
	touch $(VENV_STAMP)


venv: install-python-venv $(VENV_STAMP)

stage: venv clean-artifacts
	@echo "Building Linux wheels with cibuildwheel..."
	mkdir -p $(WHEELHOUSE)
	$(CIBUILDWHEEL) --platform linux --output-dir $(WHEELHOUSE)
	@echo ""
	@echo "Wheels:"
	@ls -lh $(WHEELHOUSE)

ifeq ($(PKG_MANAGER),apt)
install-python-venv:
	@dpkg -s python3-venv >/dev/null 2>&1 || { \
		echo "Installing python3-venv via apt..."; \
		sudo apt update && sudo apt install -y python3-venv; \
	}

install-python-dev:
	@find /usr/include -name Python.h 2>/dev/null | grep -q . || \
		sudo apt update && sudo apt install -y python3-dev

install-dev-tools:
	@echo "Installing dev tools via apt..."
	sudo apt update && sudo apt install -y \
		clang \
		llvm \
		lldb \
		gcc \
		gawk \
		g++ \
		cppcheck \
		clang-tools \
		libclang-dev \
		clang-format \
		python3-dev

install-twine:
	@command -v twine >/dev/null 2>&1 || { \
		echo "Installing twine via apt..."; \
		sudo apt update && sudo apt install -y twine; \
	}

else ifeq ($(PKG_MANAGER),dnf)
install-python-venv:
	@echo "Python venv is included with python3 on dnf-based systems, skipping."

install-python-dev:
	@find /usr/include -name Python.h 2>/dev/null | grep -q . || \
		sudo dnf install -y python3-devel --refresh --setopt=minrate=0 --setopt=timeout=300

install-dev-tools:
	@echo "Installing dev tools via dnf..."
	sudo dnf install -y \
		clang \
		llvm \
		lldb \
		gcc \
		gawk \
		gcc-c++ \
		cppcheck \
		clang-tools-extra \
		clang-analyzer \
		clang-devel \
		clang-format \
		python3-devel

install-twine:
	@command -v twine >/dev/null 2>&1 || { \
		echo "Installing twine via dnf..."; \
		sudo dnf install -y twine; \
	}

else
install-python-venv:
	@echo "Unknown package manager '$(PKG_MANAGER)'. Please install python3-venv manually."
	@exit 1

install-python-dev:
	@echo "Unknown package manager '$(PKG_MANAGER)'. Please install python3-dev/devel manually."
	@exit 1

install-dev-tools:
	@echo "Unknown package manager '$(PKG_MANAGER)'. Please install dev tools manually."
	@exit 1

install-twine:
	@echo "Unknown package manager '$(PKG_MANAGER)'. Please install twine manually."
	@exit 1
endif

$(LIBURING_LIB): check-submodule
	@echo "Building liburing..."
	CFLAGS= LDFLAGS= $(MAKE) -C $(LIBURING_DIR) library


deps: install-python-dev venv $(LIBURING_LIB)

dev-deps: deps install-dev-tools

build: deps
	$(PY) -m build --wheel

install: deps
	$(PIP) install -e .

sanitize: dev-deps run-examples test-python-asan test-c-files-asan test-c-sockets-asan test-c-buffers-asan test-c-registry-asan

run-examples: dev-deps
	@echo "START RUNNING EXAMPLES[ASan]"
	@echo "--------"

	CFLAGS="$(ASAN_CFLAGS)" \
	LDFLAGS="$(ASAN_LDFLAGS)" \
	$(PY) setup.py build_ext --inplace

	@fail=0; \
	for f in $$(find $(EXAMPLES_DIR) -type f -name '*.py' | sort); do \
		base=$$(basename $$f); \
		case $$base in \
			_*) echo ">>> Skipping $$f (private)"; continue ;; \
		esac; \
		echo ">>> Running $$f"; \
		LD_PRELOAD=$(ASAN_LIB):$$LD_PRELOAD \
		PYTHONMALLOC=malloc \
		ASAN_OPTIONS="$(ASAN_OPTIONS)" \
		UBSAN_OPTIONS="$(UBSAN_OPTIONS)" \
		$(PY) -X faulthandler $$f; \
		status=$$?; \
		if [ $$status -ne 0 ]; then \
			echo "!!! FAILED: $$f (exit $$status)"; \
			fail=1; \
		fi; \
	done; \
	echo "--------"; \
	if [ $$fail -ne 0 ]; then \
		echo "One or more examples FAILED"; \
		exit 1; \
	else \
		echo "All examples passed"; \
	fi
	@echo "========"


test-python: install
	@echo "START TESTING[plain]"
	@echo "--------"
	$(PY) -m pytest $(TESTS_DIR) -vv
	@echo "========"

test-python-asan: dev-deps
	@echo "START TESTING[ASan-UBSan]"
	@echo "--------"

	CFLAGS="$(ASAN_CFLAGS)" \
	LDFLAGS="$(ASAN_LDFLAGS)" \
	$(PY) setup.py build_ext --inplace

	ASAN_OPTIONS="$(ASAN_OPTIONS)" \
	UBSAN_OPTIONS="$(UBSAN_OPTIONS)" \
	LD_PRELOAD=$(ASAN_LIB):$$LD_PRELOAD \
	PYTHONMALLOC=malloc \
	$(PY) -X faulthandler -m pytest $(TESTS_DIR) -vv

	@echo "========"

test-python-asan-one: dev-deps
	@if [ -z "$(TEST)" ]; then \
		echo "Usage: make test-asan-one TEST=tests/...::test_name"; \
		exit 1; \
	fi

	@echo "START TESTING ONE [ASan-UBSan]"
	@echo ">>> $(TEST)"
	@echo "--------"

	CFLAGS="$(ASAN_CFLAGS)" \
	LDFLAGS="$(ASAN_LDFLAGS)" \
	$(PY) setup.py build_ext --inplace

	ASAN_OPTIONS="$(ASAN_OPTIONS)" \
	UBSAN_OPTIONS="$(UBSAN_OPTIONS)" \
	LD_PRELOAD=$(ASAN_LIB):$$LD_PRELOAD \
	PYTHONMALLOC=malloc \
	$(PY) -X faulthandler -m pytest "$(TEST)" -vv -s

	@echo "========"

build-c-tests-files: $(LIBURING_LIB)
	@echo "Building C-level file ops tests..."
	$(CC) -std=c11 -O0 -g3 $(CTESTS_INCLUDES) \
		$(CTESTS_DIR)/test_files.c $(CTESTS_DEPS) $(LIBURING_LIB) \
		-o $(CTESTS_FILES_BIN)

build-c-tests-sockets: $(LIBURING_LIB)
	@echo "Building C-level socket ops tests..."
	$(CC) -std=c11 -O0 -g3 $(CTESTS_INCLUDES) \
		$(CTESTS_DIR)/test_sockets.c $(CTESTS_SOCKETS_DEPS) $(LIBURING_LIB) \
		-o $(CTESTS_SOCKETS_BIN)

build-c-tests-buffers: $(LIBURING_LIB)
	@echo "Building C-level buffer controller tests..."
	$(CC) -std=c11 -O0 -g3 $(CTESTS_INCLUDES) \
		$(CTESTS_DIR)/test_buffer_controllers.c $(CTESTS_BUFFERS_DEPS) $(LIBURING_LIB) \
		-o $(CTESTS_BUFFERS_BIN)

build-c-tests-registry: $(LIBURING_LIB)
	@echo "Building C-level registry tests..."
	$(CC) -std=c11 -O0 -g3 -ffunction-sections -fdata-sections \
		$(CTESTS_INCLUDES) $(PYTHON_CFLAGS) \
		$(CTESTS_DIR)/test_registry.c $(CTESTS_REGISTRY_DEPS) $(LIBURING_LIB) \
		-Wl,--gc-sections \
		$(PYTHON_LDFLAGS) \
		-o $(CTESTS_REGISTRY_BIN)

test-c-files: build-c-tests-files
	@echo "START TESTING[C, files.c]"
	@echo "--------"
	@./$(CTESTS_FILES_BIN); status=$$?; rm -f $(CTESTS_FILES_BIN); exit $$status
	@echo "========"

test-c-files-asan: $(LIBURING_LIB)
	@echo "START TESTING[C, files.c, ASan-UBSan]"
	@echo "--------"
	$(CC) -std=c11 $(ASAN_CFLAGS) $(CTESTS_INCLUDES) \
		$(CTESTS_DIR)/test_files.c $(CTESTS_DEPS) $(LIBURING_LIB) \
		$(ASAN_LDFLAGS) -o $(CTESTS_FILES_BIN)_asan

	@ASAN_OPTIONS="$(ASAN_OPTIONS)" \
	UBSAN_OPTIONS="$(UBSAN_OPTIONS)" \
	LD_PRELOAD=$(ASAN_LIB):$$LD_PRELOAD \
	./$(CTESTS_FILES_BIN)_asan; status=$$?; rm -f $(CTESTS_FILES_BIN)_asan; exit $$status
	@echo "========"

test-c-sockets: build-c-tests-sockets
	@echo "START TESTING[C, sockets.c]"
	@echo "--------"
	@./$(CTESTS_SOCKETS_BIN); status=$$?; rm -f $(CTESTS_SOCKETS_BIN); exit $$status
	@echo "========"

test-c-sockets-asan: $(LIBURING_LIB)
	@echo "START TESTING[C, sockets.c, ASan-UBSan]"
	@echo "--------"
	$(CC) -std=c11 $(ASAN_CFLAGS) $(CTESTS_INCLUDES) \
		$(CTESTS_DIR)/test_sockets.c $(CTESTS_SOCKETS_DEPS) $(LIBURING_LIB) \
		$(ASAN_LDFLAGS) -o $(CTESTS_SOCKETS_BIN)_asan

	@ASAN_OPTIONS="$(ASAN_OPTIONS)" \
	UBSAN_OPTIONS="$(UBSAN_OPTIONS)" \
	LD_PRELOAD=$(ASAN_LIB):$$LD_PRELOAD \
	./$(CTESTS_SOCKETS_BIN)_asan; status=$$?; rm -f $(CTESTS_SOCKETS_BIN)_asan; exit $$status
	@echo "========"

test-c-buffers: build-c-tests-buffers
	@echo "START TESTING[C, buffer_controllers.c]"
	@echo "--------"
	@./$(CTESTS_BUFFERS_BIN); status=$$?; rm -f $(CTESTS_BUFFERS_BIN); exit $$status
	@echo "========"

test-c-buffers-asan: $(LIBURING_LIB)
	@echo "START TESTING[C, buffer_controllers.c, ASan-UBSan]"
	@echo "--------"
	$(CC) -std=c11 $(ASAN_CFLAGS) $(CTESTS_INCLUDES) \
		$(CTESTS_DIR)/test_buffer_controllers.c $(CTESTS_BUFFERS_DEPS) $(LIBURING_LIB) \
		$(ASAN_LDFLAGS) -o $(CTESTS_BUFFERS_BIN)_asan

	@ASAN_OPTIONS="$(ASAN_OPTIONS)" \
	UBSAN_OPTIONS="$(UBSAN_OPTIONS)" \
	LD_PRELOAD=$(ASAN_LIB):$$LD_PRELOAD \
	./$(CTESTS_BUFFERS_BIN)_asan; status=$$?; rm -f $(CTESTS_BUFFERS_BIN)_asan; exit $$status
	@echo "========"

PYTHON_CFLAGS := $(shell $(PY)-config --cflags 2>/dev/null || python3-config --cflags)
PYTHON_LDFLAGS := $(shell $(PY)-config --ldflags --embed 2>/dev/null || python3-config --ldflags --embed)
test-c-registry: build-c-tests-registry
	@echo "START TESTING[C, registry.c]"
	@echo "--------"
	@./$(CTESTS_REGISTRY_BIN); status=$$?; rm -f $(CTESTS_REGISTRY_BIN); exit $$status
	@echo "========"

test-c-registry-asan: $(LIBURING_LIB)
	@echo "START TESTING[C, registry.c, ASan-UBSan]"
	@echo "--------"
	$(CC) -std=c11 $(ASAN_CFLAGS) -ffunction-sections -fdata-sections \
		$(CTESTS_INCLUDES) $(PYTHON_CFLAGS) \
		$(CTESTS_DIR)/test_registry.c $(CTESTS_REGISTRY_DEPS) $(LIBURING_LIB) \
		$(ASAN_LDFLAGS) -Wl,--gc-sections $(PYTHON_LDFLAGS) \
		-o $(CTESTS_REGISTRY_BIN)_asan

	@ASAN_OPTIONS="$(ASAN_OPTIONS)" \
	UBSAN_OPTIONS="$(UBSAN_OPTIONS)" \
	LD_PRELOAD=$(ASAN_LIB):$$LD_PRELOAD \
	./$(CTESTS_REGISTRY_BIN)_asan; status=$$?; rm -f $(CTESTS_REGISTRY_BIN)_asan; exit $$status
	@echo "========"

test-all: test-python test-c-files test-c-sockets test-c-buffers test-c-registry stubs-check
	@echo "========"
	@echo "All tests (Python + C + stubs) passed"
	@echo "========"

test-all-asan: test-python-asan test-c-files-asan test-c-sockets-asan test-c-buffers-asan test-c-registry-asan
	@echo "========"
	@echo "All tests (Python + C) passed under ASan/UBSan"
	@echo "========"

lint: dev-deps lint-formatter lint-aggressive lint-cppcheck

lint-formatter: dev-deps
	@echo "START LINTING[formatter]"
	@echo "--------"
	cd src && find . \( -name "*.c" -o -name "*.h" \) -exec clang-format -i {} \;
	@echo "========"

lint-aggressive: dev-deps
	@echo "START LINTING[Aggressive compilation flags]"
	@echo "--------"

	CC=clang CFLAGS="-O0 -g3 \
	-Wall \
	-Wextra \
	-Werror \
	-Wshadow \
	-Wconversion \
	-Wcast-align \
	-Wstrict-prototypes \
	-Wmissing-prototypes \
	-Wpointer-arith \
	-Wformat=2 \
	-Wundef \
	-Wwrite-strings \
	-Wswitch-enum \
	-Wunreachable-code \
	-Wdouble-promotion \
	-Wfloat-equal \
	-fstack-protector-strong \
	-fno-omit-frame-pointer \
	-isystem vendor/liburing/include \
	-isystem vendor/liburing/src/include \
	-isystem vendor/liburing/src \
	-isystem vendor/liburing" \
	$(PY) setup.py build_ext --inplace

	@echo "========"


lint-cppcheck: dev-deps
	@echo "START LINTING[cppcheck]"
	@echo "--------"
	mkdir -p cpp-check-results

	cppcheck \
	--cppcheck-build-dir=cpp-check-results \
	--enable=all \
	--inconclusive \
	--force \
	--inline-suppr \
	--check-level=exhaustive \
	--suppress=missingIncludeSystem \
	--suppress=missingInclude \
	-D"Py_RETURN_FALSE=return Py_False;" \
	-D"Py_RETURN_TRUE=return Py_True;" \
	-D"Py_RETURN_NONE=return Py_None;" \
	-I ./src ./src

	@echo "========"

DOCS_STAMP := $(VENV)/.docs-stamp

$(DOCS_STAMP): $(VENV_STAMP)
	@echo "Installing mkdocs-material..."
	$(PIP) install mkdocs-material
	touch $(DOCS_STAMP)

docs-deps: venv $(DOCS_STAMP)

docs-serve: docs-deps
	bash setup_symlinks.sh
	$(PY) -m mkdocs serve

stubtest: install
	@echo "START STUBTEST[.pyi vs runtime API]"
	@echo "--------"
	@touch $(STUBTEST_ALLOWLIST)
	MYPYPATH=$(STUBS_DIR) $(PY) -m mypy.stubtest uringio \
		--allowlist $(STUBTEST_ALLOWLIST) \
		--concise
	@echo "========"

check-stubs: install
	@echo "START MYPY[examples against stubs]"
	@echo "--------"
	MYPYPATH=$(STUBS_DIR) $(PY) -m mypy $(EXAMPLES_DIR)
	@echo "========"

stubs-check: stubtest check-stubs


sdist: venv
	$(PY) -m build --sdist

dist-check: stage sdist install-twine
	@echo "START TWINE CHECK"
	@echo "--------"
	twine check $(WHEELHOUSE)/*.whl dist/*.tar.gz
	@echo "========"

publish-test: dist-check
	twine upload --repository testpypi $(WHEELHOUSE)/*.whl dist/*.tar.gz

publish: dist-check
	twine upload $(WHEELHOUSE)/*.whl dist/*.tar.gz

clean-artifacts:
	@echo "Cleaning build artifacts and compiled objects..."
	rm -rf build dist *.egg-info $(WHEELHOUSE) cpp-check-results
	find . -type f \( -name '*.so' -o -name '*.o' \) -delete
	-@$(MAKE) -C $(LIBURING_DIR) clean

clean: clean-artifacts
	@echo "Cleaning virtual environment..."
	rm -rf $(VENV)

help:
	@echo "Detected package manager: $(PKG_MANAGER)"
	@echo ""
	@echo "── Build ──────────────────────────────────────────"
	@echo "  make install              - build and install uringio (venv)"
	@echo "  make build                - build wheel"
	@echo "  make clean                - clean everything including venv"
	@echo "  make clean-artifacts      - clean build artifacts only (.so, .o, build/)"
	@echo ""
	@echo "── Lint ────────────────────────────────────────"
	@echo "  make lint                 - check code with linter and formatter."
	@echo ""
	@echo "── Examples ────────────────────────────────────────"
	@echo "  make run-examples         - run all docs/examples/*.py under ASan"
	@echo ""
	@echo "── Docs ────────────────────────────────────────────"
	@echo "  make docs-serve           - serve mkdocs site locally at 127.0.0.1:8000"
	@echo ""
	@echo "── Tests ───────────────────────────────────────────"
	@echo "  make test-python                 - run pytest (Python only)"
	@echo "  make test-python-asan            - ASan + UBSan pytest suite (Python only)"
	@echo "  make test-python-asan-one TEST=path::name - run a single pytest test under ASan"
	@echo "  make test-c-files                - run C-level tests on ops/files/files.c (plain)"
	@echo "  make test-c-files-asan           - run C-level tests on ops/files/files.c under ASan + UBSan"
	@echo "  make test-c-sockets              - run C-level tests on ops/sockets/sockets.c (plain)"
	@echo "  make test-c-sockets-asan         - run C-level tests on ops/sockets/sockets.c under ASan + UBSan"
	@echo "  make test-c-buffers              - run C-level tests on buffer_controllers/*.c (plain)"
	@echo "  make test-c-buffers-asan         - run C-level tests on buffer_controllers/*.c under ASan + UBSan"
	@echo "  make test-c-registry             - run C-level tests on registry/registry.c (plain)"
	@echo "  make test-c-registry-asan        - run C-level tests on registry/registry.c under ASan + UBSan"
	@echo "  make test-all                    - run Python + C tests together (plain)"
	@echo "  make test-all-asan               - run Python + C tests together under ASan + UBSan"
	@echo ""
	@echo "── Publish ─────────────────────────────────────────"
	@echo "  make publish              - upload wheels and sdist to PyPI"
	@echo "  make publish-test         - upload wheels and sdist to TestPyPI"
	@echo ""
	@echo "── Sanitizers ─────────────────────────────────────"
	@echo "  ASAN_LIB=$(ASAN_LIB)"

.PHONY: all deps dev-deps build stage install clean clean-artifacts help check-submodule venv \
        install-python-venv install-python-dev install-dev-tools install-twine \
        run-examples sanitize test-python test-python-asan test-python-asan-one \
        build-c-tests-files build-c-tests-sockets build-c-tests-buffers build-c-tests-registry \
        test-c-files test-c-files-asan test-c-sockets test-c-sockets-asan \
        test-c-buffers test-c-buffers-asan test-c-registry test-c-registry-asan \
        test-all test-all-asan \
        lint lint-formatter lint-aggressive lint-cppcheck \
        stubtest check-stubs stubs-check sdist dist-check publish publish-test \
        docs-deps docs-serve
