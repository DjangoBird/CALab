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

    //data sram interface
    input wire [31:0] data_sram_rdata
);

wire ms_ready_go;
reg  ms_valid;
reg  [31:0] ms_alu_result;
reg         ms_res_from_mem;
wire  [31:0] ms_mem_result;


assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (!resetn)
        ms_valid <= 1'b0;
    else if (ms_allowin)
        ms_valid <= es_to_ms_valid;
end

always @(posedge clk) begin
    if (!resetn) begin
        ms_pc            <= 32'b0;
        ms_alu_result    <= 32'b0;
        ms_res_from_mem  <= 1'b0;
        ms_rf_waddr      <= 5'b0;
        ms_rf_we         <= 1'b0;
    end
    else if (es_to_ms_valid && ms_allowin) begin
        ms_pc           <= es_pc;
        ms_alu_result   <= es_alu_result;
        ms_res_from_mem <= es_res_from_mem;
        ms_rf_waddr     <= es_rf_waddr;
        ms_rf_we        <= es_rf_we;
    end
end

assign ms_mem_result = data_sram_rdata;
assign ms_rf_wdata = ms_res_from_mem ? ms_mem_result : ms_alu_result;


endmodule

