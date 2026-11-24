# MCA Project 11 — Four-Lane 16-bit SIMD Vector Processing Unit
# Run from the project root: ~/mca-project
# Quick: make viva       | Individual tests: make test-alu, make test-random, ...
# Keeps original RTL and earlier Phase 3/4 reports unchanged.

.DEFAULT_GOAL := help

IVERILOG ?= iverilog
VVP      ?= vvp
YOSYS    ?= yosys
NEXTPNR  ?= nextpnr-ice40
PYTHON   ?= python3

BUILD      := build/viva
SYNTH_DIR  := results/synthesis/viva
TIMING_DIR := results/synthesis/viva_timing
RTL        := $(wildcard rtl/*.v)

TESTBENCHES := tb_alu16 tb_simd4 tb_vector_regfile tb_vector_control \
               tb_simd_core tb_simd_random tb_simd_core_advanced tb_scalar_core
TEST_TARGETS := $(addprefix run-,$(TESTBENCHES))

.PHONY: help doctor test tests $(TEST_TARGETS) \
        benchmark graphs synth timing summary viva all \
        test-alu test-simd test-regfile test-control test-core \
        test-random test-core-advanced test-scalar \
        wave waves clean

help:
	@printf '\nMCA Project 11 — SIMD Viva Commands\n'
	@printf '  make viva                Full viva run: tests + benchmark + graphs + synthesis + FPGA timing\n'
	@printf '  make test                Run all 8 functional verification testbenches\n'
	@printf '  make test-alu            Test one 16-bit ALU\n'
	@printf '  make test-simd           Test four parallel ALU lanes\n'
	@printf '  make test-regfile        Test 8 x 64-bit vector register file\n'
	@printf '  make test-control        Exhaustive vector-control tests (2048 cases)\n'
	@printf '  make test-core           Test integrated SIMD processor\n'
	@printf '  make test-random         Randomized four-lane verification (10012 vectors)\n'
	@printf '  make test-core-advanced  Advanced integrated load/execute/writeback tests\n'
	@printf '  make test-scalar         Scalar core verification\n'
	@printf '  make benchmark           Scalar vs SIMD verification and cycle-count CSV\n'
	@printf '  make graphs              Recreate three graphs from benchmark CSV\n'
	@printf '  make synth               Map both ORIGINAL cores to iCE40 FPGA resources\n'
	@printf '  make timing              Match storage, place/route both TIMING wrappers\n'
	@printf '  make summary             Show resource and Fmax summary after timing\n'
	@printf '  make waves               List available VCD waveforms\n'
	@printf '  make wave                Open the advanced-core VCD in Surfer\n'
	@printf '  make doctor              Check tools and project files\n'
	@printf '  make clean               Remove only compiled .vvp viva files\n\n'

all: viva

# The testbench's named module is selected with -s. Additional RTL modules are
# compiled as dependencies but are not instantiated unless used by the test.
$(BUILD)/%.vvp: tb/%.v $(RTL)
	@mkdir -p $(BUILD)
	@echo '[compile] $*'
	@$(IVERILOG) -g2012 -s $* -o $@ $(RTL) $<

# A static pattern rule gives each test its own always-runnable command.
$(TEST_TARGETS): run-%: $(BUILD)/%.vvp
	@echo '\n========== $* =========='
	@$(VVP) $<

# Short human-friendly aliases for viva demonstrations.
test-alu:           run-tb_alu16
test-simd:          run-tb_simd4
test-regfile:       run-tb_vector_regfile
test-control:       run-tb_vector_control
test-core:          run-tb_simd_core
test-random:        run-tb_simd_random
test-core-advanced: run-tb_simd_core_advanced
test-scalar:        run-tb_scalar_core

test tests: $(TEST_TARGETS)
	@echo '\n[DONE] All 8 testbenches executed. Confirm their PASS counts above.'

# Includes 16/64/256/1024 elements and all 5 operations.
benchmark: $(BUILD)/tb_scalar_vs_simd.vvp
	@mkdir -p results
	@echo '\n========== SCALAR vs SIMD BENCHMARK =========='
	@$(VVP) $<
	@test -s results/benchmark_results.csv || { echo 'ERROR: CSV was not created'; exit 1; }
	@echo '[saved] results/benchmark_results.csv'

graphs: benchmark
	@test -f plot_benchmarks.py || { echo 'ERROR: Missing plot_benchmarks.py in project root'; exit 1; }
	@mkdir -p results/graphs
	@$(PYTHON) plot_benchmarks.py results/benchmark_results.csv results/graphs
	@echo '[saved] results/graphs/'

# These direct-core synthesis outputs can be compared to the original Phase 4
# measurements. Synthesis does not require a physical FPGA.
synth:
	@mkdir -p $(SYNTH_DIR)
	@echo '\n========== ORIGINAL SCALAR CORE SYNTHESIS =========='
	@$(YOSYS) -Q -T -l $(SYNTH_DIR)/scalar.log -p 'read_verilog rtl/alu16.v rtl/scalar_regfile.v rtl/scalar_core.v; synth_ice40 -top scalar_core -json $(SYNTH_DIR)/scalar.json; stat' > /dev/null
	@echo '[saved] $(SYNTH_DIR)/scalar.json'
	@echo '========== ORIGINAL SIMD CORE SYNTHESIS =========='
	@$(YOSYS) -Q -T -l $(SYNTH_DIR)/simd.log -p 'read_verilog rtl/alu16.v rtl/simd4.v rtl/vector_regfile.v rtl/vector_control.v rtl/simd_core.v; synth_ice40 -top simd_core -json $(SYNTH_DIR)/simd.json; stat' > /dev/null
	@echo '[saved] $(SYNTH_DIR)/simd.json'

# Uses the previously generated Phase 4 v2 timing wrapper RTL. Does not edit it.
# The two clock-speed estimates are wrapper-inclusive, not isolated ALU Fmax.
timing:
	@mkdir -p $(TIMING_DIR)
	@for f in rtl/fpga_timing_stimulus.v rtl/scalar_timing_top.v rtl/simd_timing_top.v; do \
	  test -f "$$f" || { echo "ERROR: Missing $$f. Run your existing phase4_timing_v2.sh once to generate it."; exit 1; }; \
	done
	@echo '\n========== SCALAR FPGA TIMING =========='
	@$(YOSYS) -Q -T -l $(TIMING_DIR)/scalar.log -p 'read_verilog rtl/alu16.v rtl/scalar_regfile.v rtl/scalar_core.v rtl/fpga_timing_stimulus.v rtl/scalar_timing_top.v; synth_ice40 -nobram -top scalar_timing_top -json $(TIMING_DIR)/scalar.json; stat' > /dev/null
	@$(NEXTPNR) --hx8k --package ct256 --json $(TIMING_DIR)/scalar.json --asc $(TIMING_DIR)/scalar.asc --freq 50 --seed 1 --timing-allow-fail --pcf-allow-unconstrained --log $(TIMING_DIR)/scalar_pnr.log > /dev/null 2>&1
	@grep 'Max frequency' $(TIMING_DIR)/scalar_pnr.log | tail -n 1
	@echo '========== SIMD FPGA TIMING =========='
	@$(YOSYS) -Q -T -l $(TIMING_DIR)/simd.log -p 'read_verilog rtl/alu16.v rtl/simd4.v rtl/vector_regfile.v rtl/vector_control.v rtl/simd_core.v rtl/fpga_timing_stimulus.v rtl/simd_timing_top.v; synth_ice40 -nobram -top simd_timing_top -json $(TIMING_DIR)/simd.json; stat' > /dev/null
	@$(NEXTPNR) --hx8k --package ct256 --json $(TIMING_DIR)/simd.json --asc $(TIMING_DIR)/simd.asc --freq 50 --seed 1 --timing-allow-fail --pcf-allow-unconstrained --log $(TIMING_DIR)/simd_pnr.log > /dev/null 2>&1
	@grep 'Max frequency' $(TIMING_DIR)/simd_pnr.log | tail -n 1
	@echo '[saved] $(TIMING_DIR)/'

# A compact, automated readout of mapped FPGA cells.
summary:
	@echo '\n========== FPGA HARDWARE SUMMARY =========='
	@for design in scalar simd; do \
	  json='$(TIMING_DIR)/'$$design'.json'; log='$(TIMING_DIR)/'$$design'_pnr.log'; \
	  test -f "$$json" && test -f "$$log" || { echo 'Run make timing first'; exit 1; }; \
	  $(PYTHON) -c 'import json,sys,collections; d=json.load(open(sys.argv[1])); top=sys.argv[2]; c=collections.Counter(x["type"] for x in d["modules"][top]["cells"].values()); ff=sum(v for k,v in c.items() if k.startswith("SB_DFF")); ram=sum(v for k,v in c.items() if k.startswith("SB_RAM")); print("%-6s LUT4=%-5d CARRY=%-4d FF=%-4d BRAM=%d"%(sys.argv[3],c["SB_LUT4"],c["SB_CARRY"],ff,ram))' "$$json" "$${design}_timing_top" "$$design"; \
	  grep 'Max frequency' "$$log" | tail -n 1; \
	done
	@echo 'Note: timing is for wrapper-inclusive FPGA implementations.'

# One-command full demonstration. To avoid FPGA steps during a short viva,
# run `make test` followed by `make benchmark` instead.
viva: doctor test graphs synth timing summary
	@echo '\n====================================================='
	@echo 'VIVA DEMO COMPLETE — check the PASS lines and logs above'
	@echo '====================================================='
	@echo 'Waveforms: make waves  |  View: make wave'

doctor:
	@echo '\n========== TOOL CHECK =========='
	@for tool in $(IVERILOG) $(VVP) $(YOSYS) $(NEXTPNR) $(PYTHON); do \
	  command -v "$$tool" >/dev/null || { echo "ERROR: Missing $$tool"; exit 1; }; \
	  echo "[OK] $$tool"; \
	done
	@test -f rtl/alu16.v && test -f rtl/simd_core.v && test -f tb/tb_scalar_vs_simd.v || { echo 'ERROR: Run from ~/mca-project with all RTL/testbench files'; exit 1; }
	@echo '[OK] Project structure found'

waves:
	@echo 'Available VCD files:'
	@find . -name '*.vcd' -print

wave: test-core-advanced
	@file=$$(find . -name 'simd_core_advanced.vcd' -print | head -n 1); \
	  test -n "$$file" || { echo 'ERROR: simd_core_advanced.vcd not found. Run make waves to inspect filenames.'; exit 1; }; \
	  if command -v surfer >/dev/null; then surfer "$$file"; \
	  else open -a Surfer "$$file"; fi

# Safely removes only the ephemeral compiled simulation executables.
clean:
	@rm -rf $(BUILD)
	@echo 'Removed $(BUILD); RTL, CSV, waveforms, images, and FPGA logs are untouched.'
