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
    
    //to ws
    output wire         ms_to_ws_valid,
    output reg  [31:0] ms_pc,
    
    //to id: for load-use
    output reg         ms_rf_we,
    output reg  [ 4:0] ms_rf_waddr,
    output wire [31:0] ms_rf_wdata,

    input  wire [ 4:0] es_ld_inst,//

    //data sram interface
    input wire [31:0] data_sram_rdata,
    
    output wire        ms_ex,
    input  wire        wb_ex,
    
    input wire [80:0] es_ex_zip,
    output reg [80:0] ms_ex_zip,
    
    input wire es_csr_re,
    output reg ms_csr_re
);

wire ms_ready_go;
reg  ms_valid;
reg  [31:0] ms_alu_result;
reg         ms_res_from_mem;
wire  [31:0] ms_mem_result;

wire [31:0] shift_rdata;//

assign ms_ex = ms_ex_zip[1];

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
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
        
        ms_csr_re        <= 1'b0;
        ms_ex_zip        <= 80'b0;
    end
    else if (es_to_ms_valid && ms_allowin) begin
        ms_pc           <= es_pc;
        ms_alu_result   <= es_alu_result;
        ms_res_from_mem <= es_res_from_mem;
        ms_rf_waddr     <= es_rf_waddr;
        ms_rf_we        <= es_rf_we;
        ms_ld_inst      <= es_ld_inst;
        
        ms_csr_re        <= es_csr_re & ms_valid;
        ms_ex_zip        <= es_ex_zip;
    end
    else if(ms_allowin) begin
        ms_rf_we        <= 1'b0;
        ms_res_from_mem <= 1'b0;
    end
end
assign {op_ld_b, op_ld_bu,op_ld_h, op_ld_hu, op_ld_w} = ms_ld_inst;
assign shift_rdata = {24'b0,data_sram_rdata} >> {ms_alu_result[1:0],3'b0};//
assign ms_mem_result[7:0] = shift_rdata[7:0];
assign ms_mem_result[15:8]= {8{op_ld_b}} & {8{shift_rdata[7]}}|
                            {8{op_ld_bu}} & 8'b0|
                            {8{~op_ld_bu & ~op_ld_b}} & shift_rdata[15:8];
assign ms_mem_result[31:16]={16{op_ld_b}} & {16{shift_rdata[7]}} |
                            {16{op_ld_h}} & {16{shift_rdata[15]}}|
                            {16{op_ld_bu | op_ld_hu}} & 16'b0    |
                            {16{op_ld_w}} & shift_rdata[31:16];

assign ms_rf_wdata = ms_res_from_mem ? ms_mem_result : ms_alu_result;


endmodule

