module EX_stage(
    input wire         clk,
    input wire         resetn,
    
    input wire [7:0]   mem_inst,//

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
    output reg  [ 4:0] es_ld_inst, //

    //data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    
    input  wire        ms_ex,
    input  wire        wb_ex,
    
    input wire ds_csr_re,
    output reg es_csr_re,
    
    input wire [80:0] ds_ex_zip,//{ds_csr_we, ds_csr_wmask, ds_csr_wvalue, ds_csr_num, inst_syscall, inst_ertn},
    output reg [80:0] es_ex_zip//{es_csr_we, es_csr_wmask, es_csr_wvalue, es_csr_num, inst_syscall, inst_ertn}

);

wire es_ready_go;
reg  es_valid;

reg  [18:0] es_alu_op;//add width for mul,div and mod
reg  [31:0] es_alu_src1;
reg  [31:0] es_alu_src2;
reg  [31:0] es_rkd_value;

reg  [31:0] es_mem_result;

  
wire        alu_complete;
reg [2:0] es_st_inst;//

assign es_ex       = es_ex_zip[1];//inst_syscall

assign es_ready_go = alu_complete;
assign es_allowin  = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid = es_valid && es_ready_go;

always @(posedge clk) begin
    if (!resetn)
        es_valid <= 1'b0;
    else if(wb_ex)
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

        es_rf_we        <= 1'b0;
        es_rf_waddr     <= 5'b0;
        es_pc           <= 32'b0;
        es_ld_inst      <= 5'b0;
        es_st_inst      <= 3'b0;
        
        es_ex_zip       <= 82'b0;
        es_csr_re       <= 1'b0;
    end
    else if (ds_to_es_valid && es_allowin) begin
        es_alu_op       <= ds_alu_op;
        es_res_from_mem <= ds_res_from_mem;
        es_alu_src1     <= ds_alu_src1;
        es_alu_src2     <= ds_alu_src2;
        es_rkd_value    <= ds_rkd_value;

        es_rf_we        <= ds_rf_we;
        es_rf_waddr     <= ds_rf_waddr;
        es_pc           <= ds_pc;
        es_ld_inst      <= mem_inst[4:0];
        es_st_inst      <= mem_inst[7:5];
        
        es_ex_zip       <= ds_ex_zip;
        es_csr_re       <= ds_csr_re & es_valid;
    end
    else if(es_allowin) begin
        es_rf_we        <= 1'b0;
        es_res_from_mem <= 1'b0;

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

wire [3:0] es_mem_we;
assign es_mem_we[0]     = op_st_w | op_st_h & ~es_alu_result[1] | op_st_b & ~es_alu_result[0] & ~es_alu_result[1];   
assign es_mem_we[1]     = op_st_w | op_st_h & ~es_alu_result[1] | op_st_b &  es_alu_result[0] & ~es_alu_result[1];   
assign es_mem_we[2]     = op_st_w | op_st_h &  es_alu_result[1] | op_st_b & ~es_alu_result[0] &  es_alu_result[1];   
assign es_mem_we[3]     = op_st_w | op_st_h &  es_alu_result[1] | op_st_b &  es_alu_result[0] &  es_alu_result[1];  

assign {op_st_b,op_st_h,op_st_w} = es_st_inst;
assign data_sram_en    = es_valid && (es_mem_we || es_res_from_mem);
assign data_sram_we     = {4{es_valid & ~es_ex & ~ms_ex & ~wb_ex}} & es_mem_we;//发生异常时不可访存
                        
assign data_sram_addr  = es_alu_result;
//assign data_sram_wdata = es_rkd_value;
assign data_sram_wdata[ 7: 0]   = es_rkd_value[ 7: 0];
assign data_sram_wdata[15: 8]   = op_st_b ? es_rkd_value[ 7: 0] : es_rkd_value[15: 8];
assign data_sram_wdata[23:16]   = op_st_w ? es_rkd_value[23:16] : es_rkd_value[ 7: 0];
assign data_sram_wdata[31:24]   = op_st_w ? es_rkd_value[31:24] : 
                                  op_st_h ? es_rkd_value[15: 8] : es_rkd_value[ 7: 0];

endmodule