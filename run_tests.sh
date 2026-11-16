
#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

echo "========================================"
echo " PROJECT 11: SIMD VECTOR PROCESSING UNIT"
echo "========================================"

echo ""
echo "[1/4] Testing 16-bit ALU..."
iverilog -g2012 -Wall -s tb_alu16 -o alu_tb.out \
    rtl/alu16.v \
    tb/tb_alu16.v

vvp alu_tb.out

echo ""
echo "[2/4] Testing Four-Lane SIMD..."
iverilog -g2012 -Wall -s tb_simd4 -o simd_tb.out \
    rtl/alu16.v \
    rtl/simd4.v \
    tb/tb_simd4.v

vvp simd_tb.out

echo ""
echo "[3/4] Testing Vector Register File..."
iverilog -g2012 -Wall -s tb_vector_regfile -o regfile_tb.out \
    rtl/vector_regfile.v \
    tb/tb_vector_regfile.v

vvp regfile_tb.out

echo ""
echo "[4/4] Testing Integrated SIMD Core..."
iverilog -g2012 -Wall -s tb_simd_core -o simd_core_tb.out \
    rtl/alu16.v \
    rtl/simd4.v \
    rtl/vector_regfile.v \
    rtl/simd_core.v \
    tb/tb_simd_core.v

vvp simd_core_tb.out

echo ""
echo "========================================"
echo " ALL FOUR TEST SUITES COMPLETED"
echo "========================================"
