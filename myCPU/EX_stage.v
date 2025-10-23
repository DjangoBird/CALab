module EX_stage(
    input wire         clk,
    input wire         resetn,
    
    //allowin
    input  wire        ms_allowin,
    output wire        es_allowin,
    
    //from ds
    input wire         ds_to_es_valid,
    input wire [18:0]  ds_alu_op,//add width for mul,div and mod
    input wire         ds_res_from_mem,
    input wire [31:0]  ds_alu_src1,
    input wire [31:0]  ds_alu_src2,
    input wire [31:0]  ds_rkd_value,
    input wire         ds_mem_we,
    input wire         ds_rf_we,
    input wire [ 4:0]  ds_rf_waddr,
    input wire [31:0]  ds_pc,
    
    //to ms
    output wire        es_to_ms_valid,
    output reg  [31:0] es_pc,

    //to id: for load-use
    output reg         es_rf_we,
    output reg  [ 4:0] es_rf_waddr,
    output wire [31:0] es_alu_result,
    output reg         es_res_from_mem,

    //data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata

);

wire es_ready_go;
reg  es_valid;

reg  [18:0] es_alu_op;//add width for mul,div and mod
reg  [31:0] es_alu_src1;
reg  [31:0] es_alu_src2;
reg  [31:0] es_rkd_value;
reg         es_mem_we;
reg  [31:0] es_mem_result;
reg         es_rf_we_wire;

wire        alu_complete;

assign es_ready_go = alu_complete;
assign es_allowin  = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid = es_valid && es_ready_go;

always @(posedge clk) begin
    if (!resetn)
        es_valid <= 1'b0;
    else if (es_allowin)
        es_valid <= ds_to_es_valid;
end

always @(posedge clk) begin
    if (!resetn) begin
        es_alu_op       <= 18'b0;
        es_res_from_mem <= 1'b0;
        es_alu_src1     <= 32'b0;
        es_alu_src2     <= 32'b0;
        es_rkd_value    <= 32'b0;
        es_mem_we       <= 1'b0;
        es_rf_we_wire   <= 1'b0;
        es_rf_waddr     <= 5'b0;
        es_pc           <= 32'b0;
    end
    else if (ds_to_es_valid && es_allowin) begin
        es_alu_op       <= ds_alu_op;
        es_res_from_mem <= ds_res_from_mem;
        es_alu_src1     <= ds_alu_src1;
        es_alu_src2     <= ds_alu_src2;
        es_rkd_value    <= ds_rkd_value;
        es_mem_we       <= ds_mem_we;
        es_rf_we        <= ds_rf_we;
        es_rf_waddr     <= ds_rf_waddr;
        es_pc           <= ds_pc;
    end
    else if(es_allowin) begin
        es_rf_we        <= 1'b0;
        es_res_from_mem <= 1'b0;
        es_mem_we       <= 1'b0;
    end
end

alu u_alu(
    .clk       (clk),
    .resetn    (resetn),
    .alu_op    (es_alu_op),
    .alu_src1  (es_alu_src1),
    .alu_src2  (es_alu_src2),
    .alu_result(es_alu_result),
    .complete  (alu_complete)
);

assign data_sram_en    = es_valid && (es_mem_we || es_res_from_mem);
assign data_sram_we   = es_mem_we ? 4'b1111 : 4'b0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rkd_value;

endmodule