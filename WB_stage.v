`include "cpuhead.h"
module WB_stage(
    input wire         clk,
    input wire         resetn,
    
    //allowin
    output wire        ws_allowin,
    
    //from ms
    input wire         ms_to_ws_valid,
    input wire [31:0]  ms_pc,
    input wire [31:0]  ms_rf_wdata,
    input wire [ 4:0]  ms_rf_waddr,
    input wire         ms_rf_we,
    
    //to id: for write back
    output wire        ws_rf_we,
    output reg  [ 4:0] ws_rf_waddr,
    output wire [31:0] ws_rf_wdata,

    //trace debug
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    
    //exception from ms
    input wire  [86:0] ms_ex_zip,//{ms_csr_we, ms_csr_wmask, ms_csr_wvalue, ms_csr_num, ms_ertn, ms_has_int, ms_adef_ex, ms_sys_ex, ms_brk_ex, ms_ine_ex, ms_ale_ex， ms_adem_ex}
    input wire         ms_csr_re,
    input wire  [31:0] ms_result,
    
    // wb and csr interface
    output reg         csr_re,
    output      [13:0] csr_num,
    input       [31:0] csr_rvalue,
    output             csr_we,
    output      [31:0] csr_wmask,
    output      [31:0] csr_wvalue,
    output             ertn_flush,
    output             wb_ex,
    output reg  [31:0] wb_pc,
    output      [ 5:0] wb_ecode,
    output      [ 8:0] wb_esubcode,
    
    output wire        ipi_int_in,
    output wire [ 7:0] hw_int_in,
    output wire [31:0] coreid_in,
    output reg  [31:0] wb_vaddr,

    //TLB
    output wire        inst_wb_tlbfill,
    output wire        inst_wb_tlbsrch,
    output wire        tlb_we,
    output wire        inst_wb_tlbrd,
    output wire        wb_tlbsrch_found,
    output wire [ 3:0] wb_tlbsrch_idxgot,
    output wire        wb_refetch_flush,
    input  wire [ 9:0] ms2ws_tlb_zip,

    input  wire [ 7:0] ms2ws_tlb_exc,

    output wire        current_exc_fetch
);

reg [9:0] ms2ws_tlb_zip_reg;
always @(posedge clk) begin
    if(!resetn)
        ms2ws_tlb_zip_reg <= 10'b0;
    else if (ms_to_ws_valid && ws_allowin)
        ms2ws_tlb_zip_reg <= ms2ws_tlb_zip;
end//21 debug

wire ws_ready_go;
reg  ws_valid;

reg [31:0] ws_from_ms_wdata;


reg [86:0] ws_ex_zip;

wire [ 7:0] ws_tlb_exc;


wire        wb_has_int;
wire        wb_adef_ex;
wire        wb_sys_ex;
wire        wb_brk_ex;
wire        wb_ine_ex;
wire        wb_ale_ex;

reg         ws_rf_we_reg;

wire        ertn_flush_tmp;

wire        ws_adem_ex;

//TLB
wire        inst_wb_tlbwr;
wire        wb_refetch_flag;
reg  [ 7:0] ws_tlb_exc_r;

assign ws_ready_go    = 1'b1;
assign ws_allowin     = (!ws_valid || ws_ready_go) & (~wb_ex);
always @(posedge clk) begin
    if (!resetn)
        ws_valid <= 1'b0;
    else if(wb_ex | ertn_flush | wb_refetch_flush) //21
        ws_valid <= 1'b0;
    else if (ws_allowin)
        ws_valid <= ms_to_ws_valid;
end

always @(posedge clk) begin
    if (!resetn) begin
        wb_pc            <= 32'b0;
        ws_from_ms_wdata <= 32'b0;
        ws_rf_waddr      <= 5'b0 ;
        ws_rf_we_reg     <= 1'b0 ;
        
        csr_re           <= 1'b0 ;
        ws_ex_zip        <= 87'b0;
        wb_vaddr         <= 32'b0;
        ws_tlb_exc_r     <= 8'd0 ;
    end
    else if (ms_to_ws_valid && ws_allowin) begin
        wb_pc            <= ms_pc;
        ws_from_ms_wdata <= ms_rf_wdata;
        ws_rf_waddr      <= ms_rf_waddr;
        ws_rf_we_reg     <= ms_rf_we;
        
        // accept csr read request and exception zip from MS when transfer occurs
        csr_re           <= ms_csr_re;
        ws_ex_zip        <= ms_ex_zip;
        wb_vaddr         <= ms_result;
        
        ws_tlb_exc_r     <= ms2ws_tlb_exc;
    end
    else if(ws_allowin) begin
        ws_rf_we_reg     <= 1'b0;
    end
end

assign ws_rf_we = ws_rf_we_reg & ws_valid & ~wb_ex;

assign ws_rf_wdata = csr_re ? csr_rvalue : ws_from_ms_wdata;

//exception
assign {csr_we, csr_wmask, csr_wvalue, csr_num, ertn_flush_tmp, wb_has_int, wb_adef_ex, wb_sys_ex, wb_brk_ex, wb_ine_ex, wb_ale_ex, ws_adem_ex} = ws_ex_zip;
assign wb_ex = (wb_adef_ex | wb_sys_ex | wb_brk_ex | wb_ine_ex | wb_ale_ex | wb_has_int | ws_adem_ex | (|ws_tlb_exc)) & ws_valid;
assign ertn_flush = ertn_flush_tmp & ws_valid;

assign wb_esubcode = ws_adem_ex ? `ESUBCODE_ADEM : `ESUBCODE_ADEF;

assign wb_ecode = wb_has_int ? `ECODE_INT :
                  wb_adef_ex ? `ECODE_ADE :
                  ws_tlb_exc[`EARRAY_TLBR_FETCH] ? `ECODE_TLBR :
                  ws_tlb_exc[`EARRAY_PIF] ? `ECODE_PIF :
                  ws_tlb_exc[`EARRAY_PPI_FETCH] ? `ECODE_PPI :
                  ws_tlb_exc[`EARRAY_TLBR_MEM] ? `ECODE_TLBR :
                  ws_tlb_exc[`EARRAY_PIL] ? `ECODE_PIL :
                  ws_tlb_exc[`EARRAY_PIS] ? `ECODE_PIS :
                  ws_tlb_exc[`EARRAY_PME] ? `ECODE_PME :
                  ws_tlb_exc[`EARRAY_PPI_MEM] ? `ECODE_PPI :
                  wb_sys_ex  ? `ECODE_SYS :
                  wb_brk_ex  ? `ECODE_BRK :
                  wb_ine_ex  ? `ECODE_INE :
                  wb_ale_ex  ? `ECODE_ALE :
                  ws_adem_ex ? `ECODE_ADE :
                  6'b0;

assign ipi_int_in   = 1'b0;
assign hw_int_in    = 8'b0;
assign coreid_in    = 32'b0;

assign debug_wb_pc       = wb_pc;
assign debug_wb_rf_we    = {4{ws_rf_we_reg & ws_valid & ~wb_ex}};
assign debug_wb_rf_wnum  = ws_rf_waddr;
assign debug_wb_rf_wdata = ws_rf_wdata;

//TLB
assign {wb_refetch_flag, inst_wb_tlbsrch, inst_wb_tlbrd, inst_wb_tlbwr, inst_wb_tlbfill, wb_tlbsrch_found, wb_tlbsrch_idxgot} = ms2ws_tlb_zip_reg;//21debug
assign tlb_we = (inst_wb_tlbwr || inst_wb_tlbfill) && ws_valid;
assign wb_refetch_flush = wb_refetch_flag && ws_valid;

assign ws_tlb_exc = ws_tlb_exc_r;

assign current_exc_fetch = wb_adef_ex | ws_tlb_exc[`EARRAY_TLBR_FETCH] | ws_tlb_exc[`EARRAY_PIF] | ws_tlb_exc[`EARRAY_PPI_FETCH];

endmodule