#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/mca-project"
mkdir -p rtl results/synthesis/timing_v2

cat > rtl/fpga_timing_stimulus.v <<'VERILOG'
`timescale 1ns/1ps
// Shared, shallow-depth synchronous stimulus for timing-only experiments.
// A short LFSR avoids the long binary incrementer path in the earlier wrapper.
module fpga_timing_stimulus (
    input wire clk,
    input wire rst,
    input wire run,
    output reg [15:0] ctrl,
    output reg [63:0] data
);
    always @(posedge clk) begin
        if (rst) begin
            ctrl <= 16'hB4D3;
            data <= 64'hD3A59C7E1024B6F1;
        end else if (run) begin
            ctrl <= {ctrl[14:0], ctrl[15] ^ ctrl[13] ^ ctrl[12] ^ ctrl[10]};
            data <= {data[62:0], data[63] ^ data[62] ^ data[60] ^ data[59]};
        end
    end
endmodule
VERILOG

cat > rtl/scalar_timing_top.v <<'VERILOG'
`timescale 1ns/1ps
// Clocked stimulus and clocked output capture keep processor paths observable.
module scalar_timing_top (
    input wire clk,
    input wire rst,
    input wire run,
    output wire status
);
    wire [15:0] ctrl;
    wire [63:0] data;
    wire [15:0] read_a, read_b, result;
    reg [15:0] captured_result;

    fpga_timing_stimulus stimulus (
        .clk(clk), .rst(rst), .run(run), .ctrl(ctrl), .data(data)
    );

    scalar_core core (
        .clk(clk),
        .load_en(run && !ctrl[0]),
        .load_addr(ctrl[9:5]),
        .load_data(data[15:0]),
        .execute_en(run && ctrl[0]),
        .src_a_addr(ctrl[14:10]),
        .src_b_addr(ctrl[13:9]),
        .dst_addr(ctrl[8:4]),
        .opcode(ctrl[3:1]),
        .src_a_data(read_a),
        .src_b_data(read_b),
        .alu_result(result)
    );

    always @(posedge clk) begin
        if (rst) captured_result <= 16'b0;
        else if (run) captured_result <= result;
    end
    assign status = ^captured_result;
endmodule
VERILOG

cat > rtl/simd_timing_top.v <<'VERILOG'
`timescale 1ns/1ps
// Same input generator and clocked output observation as scalar_timing_top.
module simd_timing_top (
    input wire clk,
    input wire rst,
    input wire run,
    output wire status
);
    wire [15:0] ctrl;
    wire [63:0] data;
    wire [63:0] read_a, read_b, result;
    reg [63:0] captured_result;

    fpga_timing_stimulus stimulus (
        .clk(clk), .rst(rst), .run(run), .ctrl(ctrl), .data(data)
    );

    simd_core core (
        .clk(clk),
        .load_en(run && !ctrl[0]),
        .load_addr(ctrl[7:5]),
        .load_data(data),
        .execute_en(run && ctrl[0]),
        .src_a_addr(ctrl[10:8]),
        .src_b_addr(ctrl[13:11]),
        .dst_addr(ctrl[6:4]),
        .opcode(ctrl[3:1]),
        .src_a_data(read_a),
        .src_b_data(read_b),
        .alu_result(result)
    );

    always @(posedge clk) begin
        if (rst) captured_result <= 64'b0;
        else if (run) captured_result <= result;
    end
    assign status = ^captured_result;
endmodule
VERILOG

root=results/synthesis/timing_v2

echo 'Synthesis: scalar, matched flop-backed storage'
yosys -Q -T -l "$root/scalar.log" -p "read_verilog rtl/alu16.v rtl/scalar_regfile.v rtl/scalar_core.v rtl/fpga_timing_stimulus.v rtl/scalar_timing_top.v; synth_ice40 -nobram -top scalar_timing_top -json $root/scalar.json; stat" > /dev/null

echo 'Synthesis: SIMD, matched flop-backed storage'
yosys -Q -T -l "$root/simd.log" -p "read_verilog rtl/alu16.v rtl/simd4.v rtl/vector_regfile.v rtl/vector_control.v rtl/simd_core.v rtl/fpga_timing_stimulus.v rtl/simd_timing_top.v; synth_ice40 -nobram -top simd_timing_top -json $root/simd.json; stat" > /dev/null

for design in scalar simd; do
    echo "Place & route: $design"
    nextpnr-ice40 \
        --hx8k --package ct256 \
        --json "$root/$design.json" \
        --asc "$root/$design.asc" \
        --freq 50 --seed 1 \
        --timing-allow-fail --pcf-allow-unconstrained \
        --log "$root/${design}_pnr.log" > /dev/null 2>&1
    echo "Final routed $design Fmax:"
    grep 'Max frequency' "$root/${design}_pnr.log" | tail -n 1
    echo "Critical path synopsis ($design):"
    awk '
        /Critical path report for clock/ { active=1 }
        active && /clk-to-q/ && source == "" { source=$0 }
        active && /Sink / { last_sink=$0 }
        active && /ns logic/ {
            print source
            print last_sink
            print $0
            exit
        }
    ' "$root/${design}_pnr.log"
done

python3 - <<'PY'
import json
from collections import Counter
from pathlib import Path
folder = Path('results/synthesis/timing_v2')
for arch, top in [('scalar', 'scalar_timing_top'), ('simd', 'simd_timing_top')]:
    doc = json.loads((folder / f'{arch}.json').read_text())
    counts = Counter(cell['type'] for cell in doc['modules'][top]['cells'].values())
    flipflops = sum(n for name, n in counts.items() if name.startswith('SB_DFF'))
    print(f'{arch:6s} LUT4={counts["SB_LUT4"]:5d} carry={counts["SB_CARRY"]:4d} flipflops={flipflops:4d} blockram={sum(n for name, n in counts.items() if name.startswith("SB_RAM"))}')
PY

echo 'Results and logs saved under results/synthesis/timing_v2/'
