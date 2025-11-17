.PHONY: help install dry-run server db lowlatency desktop verify rollback rollback-all clean
.PHONY: server-parallel db-parallel lowlatency-parallel desktop-parallel
.PHONY: server-validated db-validated lowlatency-validated desktop-validated
.PHONY: benchmark benchmark-compare list-profiles list-modules status

help:
	@echo "========================================"
	@echo "Ubuntu Ultra Optimizer - Makefile"
	@echo "Version 1.0.0 - 30 Modules Complete"
	@echo "========================================"
	@echo ""
	@echo "📦 Setup:"
	@echo "  install           - Install dependencies and setup directories"
	@echo ""
	@echo "🚀 Quick Apply:"
	@echo "  server            - Apply server profile"
	@echo "  db                - Apply database profile"
	@echo "  lowlatency        - Apply low-latency profile"
	@echo "  desktop           - Apply desktop profile"
	@echo ""
	@echo "⚡ Advanced Apply (Parallel + Validated):"
	@echo "  server-parallel   - Server with parallel execution"
	@echo "  server-validated  - Server with validation & auto-rollback"
	@echo "  db-parallel       - Database with parallel execution"
	@echo "  db-validated      - Database with validation & auto-rollback"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  dry-run           - Preview changes (no apply)"
	@echo "  benchmark         - Run full benchmark suite"
	@echo "  benchmark-compare - Compare before/after benchmarks"
	@echo ""
	@echo "🔍 Information:"
	@echo "  verify            - Verify applied optimizations"
	@echo "  status            - Show current optimization status"
	@echo "  list-profiles     - List available profiles"
	@echo "  list-modules      - List all modules"
	@echo ""
	@echo "🔄 Rollback:"
	@echo "  rollback          - Rollback latest run (interactive)"
	@echo "  rollback-all      - Rollback all runs"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "  clean             - Clean temporary files"
	@echo ""
	@echo "Examples:"
	@echo "  sudo make server              # Standard apply"
	@echo "  sudo make server-parallel     # Faster with parallel execution"
	@echo "  sudo make server-validated    # Safest with auto-rollback"
	@echo "  sudo make dry-run             # Preview changes"
	@echo "  sudo make benchmark           # Performance testing"
	@echo "  sudo make verify              # Check current status"
	@echo "  sudo make rollback            # Undo changes"
	@echo ""

install:
	@echo "Installing dependencies..."
	@apt-get update
	@apt-get install -y cpufrequtils sysstat ethtool jq numactl 2>/dev/null || true
	@mkdir -p /var/lib/ubuntu-ultra-opt/state
	@mkdir -p /var/lib/ubuntu-ultra-opt/backups
	@mkdir -p /var/log/ubuntu-ultra-opt
	@chmod +x orchestrator/cli.sh
	@chmod +x orchestrator/rollback.sh
	@chmod +x quick-start.sh
	@chmod +x verify.sh
	@echo "✅ Installation complete"

dry-run:
	@./orchestrator/cli.sh --profile server --dry-run --verbose

server:
	@./orchestrator/cli.sh --profile server

db:
	@./orchestrator/cli.sh --profile db

lowlatency:
	@./orchestrator/cli.sh --profile lowlatency --max-risk high

desktop:
	@./orchestrator/cli.sh --profile desktop

# Parallel execution variants
server-parallel:
	@./orchestrator/cli.sh --profile server --parallel

db-parallel:
	@./orchestrator/cli.sh --profile db --parallel

lowlatency-parallel:
	@./orchestrator/cli.sh --profile lowlatency --parallel --max-risk high

desktop-parallel:
	@./orchestrator/cli.sh --profile desktop --parallel

# Validated execution with auto-rollback
server-validated:
	@./orchestrator/cli.sh --profile server --validate --auto-rollback

db-validated:
	@./orchestrator/cli.sh --profile db --validate --auto-rollback

lowlatency-validated:
	@./orchestrator/cli.sh --profile lowlatency --validate --auto-rollback --max-risk high

desktop-validated:
	@./orchestrator/cli.sh --profile desktop --validate --auto-rollback

# Verification and status
verify:
	@./verify.sh

status:
	@echo "📊 Ubuntu Ultra Optimizer Status"
	@echo ""
	@if [ -d /var/lib/ubuntu-ultra-opt/state ] && [ -n "$$(ls -A /var/lib/ubuntu-ultra-opt/state 2>/dev/null)" ]; then \
		echo "Latest Run: $$(ls -t /var/lib/ubuntu-ultra-opt/state | head -1)"; \
		echo "Total Runs: $$(ls /var/lib/ubuntu-ultra-opt/state | wc -l)"; \
		echo ""; \
	else \
		echo "No optimization runs found"; \
	fi

rollback:
	@echo "Available runs:"
	@ls -lt /var/lib/ubuntu-ultra-opt/state/ | head -10
	@echo ""
	@echo "To rollback, run:"
	@echo "  sudo ./orchestrator/rollback.sh <RUN_ID>"

clean:
	@echo "Cleaning temporary files..."
	@find /tmp -name "ultra-opt-*" -type f -delete 2>/dev/null || true
	@echo "✅ Clean complete"

# Quick targets for common operations
quick:
	@./quick-start.sh

status: verify

list-runs:
	@echo "Recent optimization runs:"
	@ls -lt /var/lib/ubuntu-ultra-opt/state/ | head -10
