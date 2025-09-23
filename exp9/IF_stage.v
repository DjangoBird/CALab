module IF_stage(
    input wire    clk,
    input wire    resetn,
    
    //allowin
    input wire    ds_allowin,
    
    //to ds
    output wire        fs_to_ds_valid,
    output wire [31:0] fs_inst,
    output reg  [31:0] fs_pc,
    
    //br
    input  wire       br_taken,
    input  wire [31:0] br_target,
    
    //inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata
);

wire to_fs_valid;
wire fs_ready_go;
wire fs_allowin;
reg  fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

assign seq_pc = fs_pc + 32'h4;
assign nextpc = br_taken ? br_target : seq_pc;

assign fs_ready_go  = 1'b1;
assign fs_allowin   = !fs_valid | (fs_ready_go && ds_allowin);
assign fs_to_ds_valid = fs_valid && fs_ready_go;
assign to_fs_valid = resetn;

always @(posedge clk) begin
    if (!resetn)
        fs_valid <= 1'b0;
    else if (fs_allowin)
        fs_valid <= to_fs_valid;
end

assign inst_sram_en    = resetn & fs_allowin;
assign inst_sram_we   = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

always @(posedge clk) begin
    if (!resetn)
        fs_pc <= 32'h1bfffffc;
    else if (fs_allowin)
        fs_pc <= nextpc;
end

assign fs_inst = inst_sram_rdata;


endmodule

