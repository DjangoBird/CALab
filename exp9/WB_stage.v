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
    output wire  [31:0] ws_rf_wdata,

    //trace debug
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    
    //exception from ms
    input wire [80:0] ms_ex_zip,
    input wire ms_csr_re,
    
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
    output      [ 8:0] wb_esubcode
);

wire ws_ready_go;
reg  ws_valid;

reg [80:0] ws_ex_zip;
reg [31:0] ws_from_ms_wdata;

assign ws_ready_go    = 1'b1;
assign ws_allowin     = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (!resetn)
        ws_valid <= 1'b0;
    else if(wb_ex | ertn_flush)
        ws_valid <= 1'b0;
    else if (ws_allowin)
        ws_valid <= ms_to_ws_valid;
end

always @(posedge clk) begin
    if (!resetn) begin
        wb_pc        <= 32'b0;
        ws_from_ms_wdata  <= 32'b0;
        ws_rf_waddr  <= 5'b0;
        ws_rf_we     <= 1'b0;
        
        csr_re    <= 1'b0;
        ws_ex_zip <= 80'b0;
    end
    else if (ms_to_ws_valid && ws_allowin) begin
        wb_pc       <= ms_pc;
        ws_from_ms_wdata <= ms_rf_wdata;
        ws_rf_waddr <= ms_rf_waddr;
        ws_rf_we    <= ms_rf_we;
        
        csr_re    <= ms_csr_re;
        ws_ex_zip <= ms_ex_zip;
        
    end
    else if(ws_allowin) begin
        ws_rf_we <= 1'b0;
    end
end

assign ws_rf_wdata = csr_re ? csr_rvalue : ws_from_ms_wdata;
//exception
assign {csr_we, csr_wmask, csr_wvalue, csr_num ,wb_ex, ertn_flush} = ws_ex_zip;
assign wb_ecode = {6{wb_ex}} & 6'hb;
assign wb_esubcode = 9'b0;

assign debug_wb_pc       = wb_pc;
assign debug_wb_rf_we    = {4{ws_rf_we & ws_valid}};
assign debug_wb_rf_wnum  = ws_rf_waddr;
assign debug_wb_rf_wdata = ws_rf_wdata;

endmodule