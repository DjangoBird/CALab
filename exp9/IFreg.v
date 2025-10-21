module IFreg(
    input  wire        clk,
    input  wire        resetn,
    
    output wire         inst_sram_en,
    output wire [ 3:0]  inst_sram_we,
    output wire [31:0]  inst_sram_addr,
    output wire [31:0]  inst_sram_wdata,
    input  wire [31:0]  inst_sram_rdata,
    
    input  wire         id_allowin,
    output wire         if_to_id_valid,
    
    input  wire         br_taken,
    input  wire [31:0]  br_target,

    output wire [31:0]  if_inst,
    output reg  [31:0]  if_pc
);
    
    wire if_allowin;
    wire if_ready_go;
    reg  if_valid;
    wire to_if_valid;
    wire [31:0]  seq_pc;
    wire [31:0]  nextpc;
    
    assign to_if_valid      =resetn;
    assign if_ready_go      = 1'b1;
    assign if_allowin       = ~if_valid | if_ready_go & id_allowin;     
    assign if_to_id_valid   = if_valid & if_ready_go;
    
    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 1'b0;
        else if(if_allowin)
            if_valid <= to_if_valid;
    end

    assign inst_sram_en     = if_allowin & resetn;
    assign inst_sram_we     = 4'b0;
    assign inst_sram_addr   = nextpc;
    assign inst_sram_wdata  = 32'b0;

    
    assign seq_pc           = if_pc + 3'h4;  
    assign nextpc           = br_taken ? br_target : seq_pc;
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1bfffffC;
        else if(if_allowin)
            if_pc <= nextpc;
    end
    
    assign if_inst          = inst_sram_rdata;
endmodule