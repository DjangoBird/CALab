module EXEreg(
    input  wire        clk,
    input  wire        resetn,
    
    output wire        exe_allowin,
    
    input  wire [5 :0] id_rf_zip, // {id_rf_we, id_rf_waddr}
    
    input  wire        id_to_exe_valid,
    input  wire [31:0] id_pc,    
    
    input  wire [82:0] id_alu_data_zip, // {exe_alu_op, exe_alu_src1, exe_alu_src2}
    
    input  wire        id_res_from_mem, 
    input  wire        id_mem_we,
    
    input  wire [31:0] id_rkd_value,
    
    input  wire        mem_allowin,
    
    output wire  [5 :0] exe_rf_zip, // {exe_rf_we, exe_rf_waddr}
       
    output wire        exe_to_mem_valid,
    output reg  [31:0] exe_pc,    
    output wire [31:0] exe_alu_result, 
    output reg         exe_res_from_mem, 
    output reg         exe_mem_we,
    output reg  [31:0] exe_rkd_value
);

    wire        exe_ready_go;
    reg         exe_valid;

    reg  [18:0] exe_alu_op;
    reg  [31:0] exe_alu_src1;
    reg  [31:0] exe_alu_src2;
    
    reg         exe_rf_we;
    reg   [4:0] exe_rf_waddr;
    
    wire        alu_complete;


    assign exe_ready_go      = alu_complete;
    assign exe_allowin       = ~exe_valid | exe_ready_go & mem_allowin;     
    assign exe_to_mem_valid  = exe_valid & exe_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            exe_valid <= 1'b0;
        else if(exe_allowin)
            exe_valid <= id_to_exe_valid; 
    end


    always @(posedge clk) begin
        if(~resetn) begin
            exe_pc           <= 32'b0;
            exe_alu_op       <= 12'b0;
            exe_alu_src1     <= 32'b0;
            exe_alu_src2     <= 32'b0;
            exe_res_from_mem <= 1'b0;
            exe_mem_we       <= 1'b0;
            exe_rkd_value    <= 32'b0;
            exe_rf_we        <= 1'b0;
            exe_rf_waddr     <= 5'b0;
        end
        else if(id_to_exe_valid & exe_allowin) begin
            exe_pc <= id_pc;
            {exe_alu_op, exe_alu_src1, exe_alu_src2} <= id_alu_data_zip;
            exe_res_from_mem                         <= id_res_from_mem;
            exe_mem_we                               <= id_mem_we;
            exe_rkd_value                            <= id_rkd_value;
            {exe_rf_we, exe_rf_waddr}                <= id_rf_zip; 
        end
        else if(exe_allowin) begin
            exe_res_from_mem <= 1'b0;
            exe_mem_we       <= 1'b0;
            exe_rf_we        <= 1'b0;
        end
    end
    assign exe_rf_zip = {exe_rf_we & exe_valid, exe_rf_waddr};
    
    alu u_alu(
        .clk       (clk),
        .resetn    (resetn),
        .alu_op     (exe_alu_op    ),
        .alu_src1   (exe_alu_src1  ),
        .alu_src2   (exe_alu_src2  ),
        .alu_result (exe_alu_result),
        .complete  (alu_complete)
    );
    

endmodule