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
    output reg         ws_rf_we,
    output reg  [ 4:0] ws_rf_waddr,
    output reg  [31:0] ws_rf_wdata,

    //trace debug
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

wire ws_ready_go;
reg  ws_valid;
reg  [31:0] ws_pc;


assign ws_ready_go    = 1'b1;
assign ws_allowin     = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (!resetn)
        ws_valid <= 1'b0;
    else if (ws_allowin)
        ws_valid <= ms_to_ws_valid;
end

always @(posedge clk) begin
    if (!resetn) begin
        ws_pc        <= 32'b0;
        ws_rf_wdata  <= 32'b0;
        ws_rf_waddr  <= 5'b0;
        ws_rf_we     <= 1'b0;
    end
    else if (ms_to_ws_valid && ws_allowin) begin
        ws_pc       <= ms_pc;
        ws_rf_wdata <= ms_rf_wdata;
        ws_rf_waddr <= ms_rf_waddr;
        ws_rf_we    <= ms_rf_we;
    end
    else if(ws_allowin) begin
        ws_rf_we <= 1'b0;
    end
end

assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_we    = {4{ws_rf_we & ws_valid}};
assign debug_wb_rf_wnum  = ws_rf_waddr;
assign debug_wb_rf_wdata = ws_rf_wdata;

endmodule