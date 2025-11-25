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
    input  wire        br_stall,
    input  wire        br_taken,
    input  wire [31:0] br_target,
    
    //inst sram interface
    output wire        inst_sram_req,     //en
    output wire        inst_sram_wr,      //1 for write, 0 for read
    output wire [ 3:0] inst_sram_wstrb,   //byte enable
    output wire [ 1:0] inst_sram_size,    //00: byte, 01: half, 10: word
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    
    // exception
    input  wire         wb_ex,
    input  wire         ertn_flush,
    input  wire [31:0]  ex_entry,
    input  wire [31:0]  ertn_entry,
    
    output wire         fs_adef_ex,

    input wire  [ 3:0]  axi_arid //for bridge

);

wire pf_ready_go;
wire to_fs_valid;
wire fs_ready_go;
wire fs_allowin;
reg  fs_valid;

// for inst discard
wire fs_cancel;
wire pf_cancel;
reg  inst_discard;

reg  pf_block;

reg         wb_ex_reg;
reg         ertn_flush_reg;
reg         br_taken_reg;
reg  [31:0] br_target_reg;
reg  [31:0] ex_entry_reg;
reg  [31:0] ertn_entry_reg;

wire [31:0] seq_pc;
wire [31:0] nextpc;

reg  [31:0] fs_inst_buf;
reg         fs_inst_buf_valid;


//cancel logic
assign fs_cancel = br_taken | wb_ex | ertn_flush;
assign pf_cancel = fs_cancel;//
always @(posedge clk) begin
    if (!resetn) begin
        inst_discard <= 1'b0;
    end
    else if (pf_cancel & inst_sram_req | fs_cancel & !fs_allowin & !fs_ready_go) begin//
        inst_discard <= 1'b1;
    end
    else if (inst_discard & inst_sram_data_ok)begin
        inst_discard <= 1'b0;
    end
end

assign fs_ready_go  = (inst_sram_data_ok | fs_inst_buf_valid) & !inst_discard;//有指�?
assign fs_allowin   = (!fs_valid) | (fs_ready_go & ds_allowin);
assign fs_to_ds_valid = fs_valid & fs_ready_go;
assign pf_ready_go = inst_sram_req & inst_sram_addr_ok;//握手成功
assign to_fs_valid = pf_ready_go & ~pf_block &~pf_cancel;

always @(posedge clk) begin
    if (!resetn)
        fs_valid <= 1'b0;
    else if (fs_allowin)
        fs_valid <= to_fs_valid;
    else if (fs_cancel)
        fs_valid <= 1'b0;
end

//临时缓存
always @(posedge clk) begin
    if (!resetn) begin
        fs_inst_buf_valid <= 1'b0;
        fs_inst_buf <= 32'b0;
    end
    else if (fs_to_ds_valid & ds_allowin) begin
        fs_inst_buf_valid <= 1'b0;
    end
    else if (fs_cancel) begin
        fs_inst_buf_valid <= 1'b0;
    end
    else if (!fs_inst_buf_valid & inst_sram_data_ok & !inst_discard) begin
        fs_inst_buf_valid <= 1'b1;
        fs_inst_buf <= inst_sram_rdata;
    end
end

always @(posedge clk)begin
    if(!resetn)begin
        pf_block <= 1'b0;
    end
    else if(pf_cancel & ~pf_block & ~axi_arid[0])begin
        pf_block <= 1'b1;
    end
    else if(inst_sram_data_ok)begin
        pf_block <= 1'b0;
    end
end


always @(posedge clk) begin
    if (!resetn) begin
        br_taken_reg <= 1'b0;
        wb_ex_reg <= 1'b0;
        ertn_flush_reg <= 1'b0;
        br_target_reg <= 32'b0;
        ex_entry_reg <= 32'b0;
        ertn_entry_reg <= 32'b0;
    end
    else if (wb_ex )begin
        wb_ex_reg <= wb_ex;
        ex_entry_reg <= ex_entry;
    end
    else if(ertn_flush ) begin
        ertn_flush_reg <= ertn_flush;
        ertn_entry_reg <= ertn_entry;
    end
    else if (br_taken ) begin
        br_taken_reg <= br_taken;
        br_target_reg <= br_target;
    end
    else if (pf_ready_go) begin
        br_taken_reg <= 1'b0;
        wb_ex_reg <= 1'b0;
        ertn_flush_reg <= 1'b0;
        br_target_reg <= 32'b0;
        ex_entry_reg <= 32'b0;
        ertn_entry_reg <= 32'b0;
    end
end

//pre_IF 生成nextPC
//遇到cancel信号而未等到ready_go时，将cancel相关信号存在寄存器中，等到ready_go时再使用
assign seq_pc = fs_pc + 32'h4;
assign nextpc = wb_ex_reg ? ex_entry_reg:
                wb_ex ? ex_entry:
                ertn_flush_reg ? ertn_entry_reg:
                ertn_flush ? ertn_entry:
                br_taken_reg ? br_target_reg:
                br_taken ? br_target : seq_pc;//异常 or 返回 or 跳转 or 顺序

assign fs_inst = fs_inst_buf_valid ? fs_inst_buf : inst_sram_rdata; 


assign inst_sram_req   = resetn & fs_allowin & !br_stall & !pf_block;//只有IF阶段发出请求
assign inst_sram_wr    = (|inst_sram_wstrb);
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;
assign inst_sram_size  = 2'b10;

always @(posedge clk) begin
    if (!resetn)
        fs_pc <= 32'h1bfffffc;
    else if (to_fs_valid & fs_allowin)
        fs_pc <= nextpc;
end


assign fs_adef_ex = (nextpc[1:0] != 2'b00) & fs_valid;

endmodule

