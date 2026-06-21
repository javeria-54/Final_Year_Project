#include "Vpipeline_top.h"
#include "Vpipeline_top___024root.h"
#include "verilated.h"
#include <stdio.h>

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    Vpipeline_top* top = new Vpipeline_top;
    FILE* log = fopen("sim_log.txt", "w");
    
    top->rst_n = 0;
    top->clk   = 0;
    
    int cycle = 0;
    int sim_time = 0;
    
    for (int i = 0; i < 2000; i++) {
        top->clk = !top->clk;
        sim_time += 10;
        
        if (sim_time == 50) top->rst_n = 1;
        
        top->eval();
        
        if (top->clk == 1 && top->rst_n == 1) {
            cycle++;
            fprintf(log, "[%5dns | cycle %4d] "
                "PC=0x%08x | "
                "PC_next=0x%08x | "
                "instr=0x%08x | "
                "stall_fetch=%d | "
                "exc_req=%d | exc_code=%d\n",
                sim_time, cycle,
                (unsigned int)top->rootp->pipeline_top__DOT__fetch_module__DOT__pc_ff,
                (unsigned int)top->rootp->pipeline_top__DOT__fetch_module__DOT__pc_next,
                (unsigned int)top->rootp->pipeline_top__DOT__fetch_module__DOT__instr_word,
                (int)top->rootp->pipeline_top__DOT__rob__DOT__stall_fetch_o,
                (int)top->rootp->pipeline_top__DOT__fetch_module__DOT__exc_req_ff,
                (int)top->rootp->pipeline_top__DOT__fetch_module__DOT__exc_code_ff
            );
        }
    }
    
    fclose(log);
    top->final();
    delete top;
    printf("Done. %d cycles, %dns. Check sim_log.txt\n", cycle, sim_time);
    return 0;
}
