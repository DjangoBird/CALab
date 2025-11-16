module MEM_stage(
    input wire         clk,
    input wire         resetn,
    
    //allowin
    input  wire        ws_allowin,
    output wire        ms_allowin,
    
    //from es
    input wire         es_to_ms_valid,
    input wire [31:0]  es_pc,
    input wire         es_res_from_mem,
    input wire [31:0]  es_alu_result,
    input wire [ 4:0]  es_rf_waddr,
    input wire         es_rf_we,
    input wire         es_mem_req,
    
    input wire [31:0] es_result,
    output reg [31:0] ms_result,
    
    //to ws
    output wire         ms_to_ws_valid,
    output reg  [31:0] ms_pc,
    
    //to id: for load-use
    output reg         ms_rf_we,
    output reg  [ 4:0] ms_rf_waddr,
    output wire [31:0] ms_rf_wdata,

    input  wire [ 4:0] es_ld_inst,//

    //data sram interface
    input wire        data_sram_data_ok,
    input wire [31:0] data_sram_rdata,
    
    output wire        ms_ex,
    input  wire        wb_ex,
    
    input wire [85:0] es_ex_zip,//{es_csr_we, es_csr_wmask, es_csr_wvalue, es_csr_num, es_ertn, es_has_int, es_adef_ex, es_sys_ex, es_brk_ex, es_ine_ex, es_ale_ex}
    output reg [85:0] ms_ex_zip,//{ms_csr_we, ms_csr_wmask, ms_csr_wvalue, ms_csr_num, ms_ertn, ms_has_int, ms_adef_ex, ms_sys_ex, ms_brk_ex, ms_ine_ex, ms_ale_ex}
    
    input wire es_csr_re,
    output reg ms_csr_re
);

wire ms_ready_go;
reg  ms_valid;
reg  [31:0] ms_alu_result;
reg         ms_res_from_mem;
wire  [31:0] ms_mem_result;

wire [31:0] shift_rdata;

wire        ms_csr_we;
wire [31:0] ms_csr_wmask;
wire [31:0] ms_csr_wvalue;
wire [13:0] ms_csr_num;

wire        ms_has_int;
wire        ms_adef_ex;
wire        ms_sys_ex;
wire        ms_brk_ex;
wire        ms_ine_ex;
wire        ms_ertn;
wire        ms_ale_ex;


//类SRAM
wire ms_wait_data_ok;
reg  ms_wait_data_ok_reg;

assign ms_wait_data_ok = ms_wait_data_ok_reg & ms_valid & !wb_ex;


assign ms_ex = (|ms_ex_zip[6:0]);

//指令接收数据要等待数据返回握手完成（data_ok正在或者已经为1）
assign ms_ready_go    = !ms_wait_data_ok | ms_wait_data_ok & data_sram_data_ok;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin | wb_ex;
assign ms_to_ws_valid = ms_valid && ms_ready_go & ~wb_ex;
always @(posedge clk) begin
    if (!resetn)
        ms_valid <= 1'b0;
    else if (wb_ex)
        ms_valid <= 1'b0;
    else if (ms_allowin)
        ms_valid <= es_to_ms_valid;
end
reg [4:0] ms_ld_inst;
always @(posedge clk) begin
    if (!resetn) begin
        ms_pc            <= 32'b0;
        ms_alu_result    <= 32'b0;
        ms_res_from_mem  <= 1'b0;
        ms_rf_waddr      <= 5'b0;
        ms_rf_we         <= 1'b0;
        ms_ld_inst       <= 5'b0;
        ms_wait_data_ok_reg <= 1'b0;
        ms_csr_re        <= 1'b0;
        ms_ex_zip        <= 86'b0;
        ms_result        <=32'b0;
    end
    else if (es_to_ms_valid && ms_allowin) begin
        ms_pc           <= es_pc;
        ms_alu_result   <= es_alu_result;
        ms_res_from_mem <= es_res_from_mem;
        ms_rf_waddr     <= es_rf_waddr;
        ms_rf_we        <= es_rf_we;
        ms_ld_inst      <= es_ld_inst;
        ms_wait_data_ok_reg <= es_mem_req;
        // pass through csr read request and exception zip when transfer occurs
        ms_csr_re        <= es_csr_re;
        ms_ex_zip        <= es_ex_zip;
        ms_result       <=es_result;
    end
    else if(ms_allowin) begin
        ms_rf_we        <= 1'b0;
        ms_res_from_mem <= 1'b0;
        ms_wait_data_ok_reg <= 1'b0;
    end
end


assign {op_ld_b, op_ld_bu,op_ld_h, op_ld_hu, op_ld_w} = ms_ld_inst;
assign shift_rdata = {24'b0,data_sram_rdata} >> {ms_result[1:0],3'b0};//
assign ms_mem_result[7:0] = shift_rdata[7:0];
assign ms_mem_result[15:8]= {8{op_ld_b}} & {8{shift_rdata[7]}}|
                            {8{op_ld_bu}} & 8'b0|
                            {8{~op_ld_bu & ~op_ld_b}} & shift_rdata[15:8];
assign ms_mem_result[31:16]={16{op_ld_b}} & {16{shift_rdata[7]}} |
                            {16{op_ld_h}} & {16{shift_rdata[15]}}|
                            {16{op_ld_bu | op_ld_hu}} & 16'b0    |
                            {16{op_ld_w}} & shift_rdata[31:16];

assign ms_rf_wdata = ms_res_from_mem ? ms_mem_result : ms_result;

endmodule

