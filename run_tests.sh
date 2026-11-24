
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "=========================================="
echo " PROJECT 11 - SIMD VECTOR PROCESSING UNIT"
echo " COMPLETE REGRESSION TESTING"
echo "=========================================="

run_test() {
    local name="$1"
    local top="$2"
    local output="$3"
    shift 3

    echo ""
    echo "=========================================="
    echo " TEST: $name"
    echo "=========================================="

    iverilog -g2012 -Wall -s "$top" -o "$output" "$@"
    vvp "$output"

    echo "COMPLETED: $name"
}

# TEST 1 - 16-bit ALU
run_test "16-bit ALU" tb_alu16 alu_tb.out \
    rtl/alu16.v \
    tb/tb_alu16.v

# TEST 2 - Four-lane SIMD
run_test "Four-Lane SIMD" tb_simd4 simd_tb.out \
    rtl/alu16.v \
    rtl/simd4.v \
    tb/tb_simd4.v

# TEST 3 - Vector Register File
run_test "Vector Register File" tb_vector_regfile regfile_tb.out \
    rtl/vector_regfile.v \
    tb/tb_vector_regfile.v

# TEST 4 - Vector Control Unit
run_test "Vector Control Unit" tb_vector_control vector_control_tb.out \
    rtl/vector_control.v \
    tb/tb_vector_control.v

# TEST 5 - Integrated SIMD Core
run_test "Integrated SIMD Core" tb_simd_core simd_core_tb.out \
    rtl/alu16.v \
    rtl/simd4.v \
    rtl/vector_regfile.v \
    rtl/vector_control.v \
    rtl/simd_core.v \
    tb/tb_simd_core.v

# TEST 6 - Randomized SIMD Verification
run_test "Randomized SIMD Verification" tb_simd_random simd_random_tb.out \
    rtl/alu16.v \
    rtl/simd4.v \
    tb/tb_simd_random.v

# TEST 7 - Advanced Integrated Core
run_test "Advanced Integrated Core" tb_simd_core_advanced simd_core_advanced_tb.out \
    rtl/alu16.v \
    rtl/simd4.v \
    rtl/vector_regfile.v \
    rtl/vector_control.v \
    rtl/simd_core.v \
    tb/tb_simd_core_advanced.v

echo ""
echo "=========================================="
echo " ALL 7 REGRESSION TEST SUITES COMPLETED"
echo "=========================================="
