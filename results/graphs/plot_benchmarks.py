#!/usr/bin/env python3
"""Reproduce Phase 3 charts from results/benchmark_results.csv.
Run: python3 plot_benchmarks.py PATH_TO_CSV OUTPUT_DIR
"""
import csv
import sys
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np

DEFAULT = [
    {'operation':'ADD','elements':str(n),
     'scalar_execute_cycles':str(n), 'simd_execute_cycles':str(n//4),
     'scalar_total_cycles':str(n*3), 'simd_total_cycles':str(n*3//4),
     'scalar_throughput_elem_per_cycle':'1', 'simd_throughput_elem_per_cycle':'4',
     'execution_speedup':'4', 'total_speedup':'4'}
    for n in (16,64,256,1024)
]

def main():
    path = Path(sys.argv[1]) if len(sys.argv)>1 else None
    output = Path(sys.argv[2]) if len(sys.argv)>2 else Path(__file__).resolve().parent
    output.mkdir(parents=True,exist_ok=True)
    if path and path.is_file():
        with path.open(newline='') as f: rows=list(csv.DictReader(f))
    elif path:
        raise SystemExit(f'CSV file missing: {path}')
    else:
        rows=DEFAULT
    rows = sorted((r for r in rows if r['operation'].strip().upper()=='ADD'),key=lambda r:int(r['elements']))
    if len(rows)!=4:
        raise SystemExit('Expected four ADD records for 16,64,256,1024 elements')
    els=[int(r['elements']) for r in rows]
    x=np.arange(len(els))
    w=0.34
    def chart(a,b,title,ylabel,filename,fmt=lambda n:f'{n:,}',ylim=None):
        fig,ax=plt.subplots(figsize=(8.5,5.1),layout='constrained')
        bars1=ax.bar(x-w/2,a,width=w,label='Scalar',edgecolor='black',linewidth=0.35)
        bars2=ax.bar(x+w/2,b,width=w,label='4-lane SIMD',edgecolor='black',linewidth=0.35)
        ax.set_xticks(x,[f'{n:,}' for n in els])
        ax.set_xlabel('Workload size (16-bit elements)')
        ax.set_ylabel(ylabel)
        ax.set_title(title,fontsize=14,pad=16)
        ax.legend(frameon=False)
        ax.grid(axis='y',alpha=.2)
        ax.set_axisbelow(True)
        for bars in (bars1,bars2):
            for bar in bars:
                ax.annotate(fmt(bar.get_height()), (bar.get_x()+bar.get_width()/2,bar.get_height()),
                            xytext=(0,3),textcoords='offset points',ha='center',va='bottom',fontsize=9)
        ax.set_ylim(0,max(a+b)*1.17 if ylim is None else ylim)
        fig.savefig(output/filename,dpi=220)
        plt.close(fig)
    chart([int(r['scalar_execute_cycles']) for r in rows],
          [int(r['simd_execute_cycles']) for r in rows],
          'Execution-only cycles: Scalar vs 4-lane SIMD','Clock cycles', 'execution_cycles.png')
    chart([int(r['scalar_total_cycles']) for r in rows],
          [int(r['simd_total_cycles']) for r in rows],
          'Loading + execution cycles: Scalar vs 4-lane SIMD','Clock cycles','total_cycles.png')
    chart([float(r['scalar_throughput_elem_per_cycle']) for r in rows],
          [float(r['simd_throughput_elem_per_cycle']) for r in rows],
          'Execution throughput: Scalar vs 4-lane SIMD','16-bit elements per simulated cycle',
          'execution_throughput.png',fmt=lambda n:f'{n:g}',ylim=5)
    for name in ('execution_cycles.png','total_cycles.png','execution_throughput.png'):
        print(output/name)

if __name__=='__main__': main()
