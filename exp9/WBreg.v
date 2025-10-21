module WBreg(
    input  wire        clk,
    input  wire        resetn,
    
    //mem & wb
    output wire        wb_allowin,
    input  wire [37:0] mem_rf_zip, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    input  wire        mem_to_wb_valid,
    input  wire [31:0] mem_pc,    
    
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    // id & wb 
    output wire [37:0] wb_rf_zip  // {rf_we, rf_waddr, rf_wdata}
);
    
    wire        wb_ready_go;
    reg         wb_valid;
    reg  [31:0] wb_pc;
    reg  [31:0] rf_wdata;
    reg  [4 :0] rf_waddr;
    reg         rf_we;

    assign wb_ready_go      = 1'b1;
    assign wb_allowin       = ~wb_valid | wb_ready_go ;     
    
    always @(posedge clk) begin
        if(~resetn)
            wb_valid <= 1'b0;
        else if(wb_allowin)
            wb_valid <= mem_to_wb_valid;
    end

    always @(posedge clk) begin
        if(~resetn) begin
            {wb_pc, rf_we, rf_waddr, rf_wdata} <=70'b0;
        end
        else if(mem_to_wb_valid & wb_allowin) begin
            wb_pc <= mem_pc;
            {rf_we, rf_waddr, rf_wdata} <= mem_rf_zip;
        end
    end

    assign wb_rf_zip = {rf_we & wb_valid, rf_waddr, rf_wdata};

    assign debug_wb_pc = wb_pc;
    assign debug_wb_rf_wdata = rf_wdata;
    assign debug_wb_rf_we = {4{rf_we & wb_valid}};
    assign debug_wb_rf_wnum = rf_waddr;
endmodule