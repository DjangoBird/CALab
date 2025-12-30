`include "cpuhead.h"
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

    //TLB
    output wire [18:0] s0_vppn,           //vpn2
    output wire        s0_va_bit12,       //va[12]  
    input  wire        s0_found,          //TLB hit
    input  wire [ 3:0] s0_index,          //TLB hit index
    input  wire [19:0] s0_ppn,            //ppn
    input  wire [ 5:0] s0_ps,             //page size
    input  wire [ 1:0] s0_plv,            //权限级
    input  wire        s0_v,              //valid

    //from CSR
    input  wire [ 1:0] crmd_plv_CSRoutput, //当前特权级
    //DMW0
    input  wire        csr_dmw0_plv0,
    input  wire        csr_dmw0_plv3,
    input  wire [ 2:0] csr_dmw0_pseg,
    input  wire [ 2:0] csr_dmw0_vseg,
    //DMW1
    input  wire        csr_dmw1_plv0,
    input  wire        csr_dmw1_plv3,
    input  wire [ 2:0] csr_dmw1_pseg,
    input  wire [ 2:0] csr_dmw1_vseg,

    input  wire        csr_direct_addr,

    output wire [ 7:0] fs_tlb_exc,
    //icache
    output wire [31:0] inst_addr_vrtl
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
// wire [31:0] nextpc;
wire [31:0] nextpc_v;
wire [31:0] nextpc_p;
assign inst_addr_vrtl = nextpc_v;

reg  [31:0] fs_inst_buf;
reg         fs_inst_buf_valid;

reg         inst_sram_addr_ack;

// wire        inst_sram_addr_ack_r;
// assign      inst_sram_addr_ack_r = inst_sram_addr_ack & !inst_sram_data_ok;//21

//TLB
//addr translation
wire        dmw0_hit;
wire        dmw1_hit;
wire [31:0] dmw0_paddr;
wire [31:0] dmw1_paddr;
wire [31:0] tlb_paddr;
wire        tlb_used;


//cancel logic
assign fs_cancel = br_taken | wb_ex | ertn_flush;
assign pf_cancel = fs_cancel;//
always @(posedge clk) begin
    if (!resetn) begin
        inst_discard <= 1'b0;
    end
    else if (pf_cancel & inst_sram_req & inst_sram_addr_ok| fs_cancel & !fs_allowin & !fs_ready_go) begin//21
        inst_discard <= 1'b1;
    end
    else if (inst_discard & inst_sram_data_ok)begin
        inst_discard <= 1'b0;
    end
end

assign fs_ready_go  = (inst_sram_data_ok | fs_inst_buf_valid) & !inst_discard;//有指令
assign fs_allowin   = (!fs_valid) | (fs_ready_go & ds_allowin);
assign fs_to_ds_valid = fs_valid & fs_ready_go ;
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

// 判断当前地址是否已经握手成功，若成功则拉低req，避免重复申请
always @(posedge clk) begin
    if(~resetn)
        inst_sram_addr_ack <= 1'b0;
    else if(pf_ready_go)
        inst_sram_addr_ack <= 1'b1;
    else if(inst_sram_data_ok)
        inst_sram_addr_ack <= 1'b0;
end//16

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
    // else if(pf_cancel & ~inst_sram_data_ok)begin
    //     pf_block <= 1'b1;
    // end     //21?
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
        wb_ex_reg <= 1'b1; //21 ? 
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
assign nextpc_v = wb_ex_reg ? ex_entry_reg:
                  wb_ex ? ex_entry:
                  ertn_flush_reg ? ertn_entry_reg:
                  ertn_flush ? ertn_entry:
                  br_taken_reg ? br_target_reg:
                  br_taken ? br_target : seq_pc;//异常 or 返回 or 跳转 or 顺序

assign fs_inst = fs_inst_buf_valid ? fs_inst_buf : inst_sram_rdata; 


assign inst_sram_req   = fs_allowin & resetn & (~br_stall | wb_ex | ertn_flush) & ~pf_block & ~inst_sram_addr_ack;//16 //21？
assign inst_sram_wr    = (|inst_sram_wstrb);
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = nextpc_p;
assign inst_sram_wdata = 32'b0;
assign inst_sram_size  = 3'b0;

always @(posedge clk) begin
    if (!resetn)
        fs_pc <= 32'h1bfffffc;
    else if (to_fs_valid & fs_allowin)
        fs_pc <= nextpc_v;
end


assign fs_adef_ex = (nextpc_v[1:0] != 2'b00) & fs_valid;


//TLB
assign {s0_vppn, s0_va_bit12} = nextpc_v[31:12];
assign dmw0_hit = (nextpc_v[31:29] == csr_dmw0_vseg) & (crmd_plv_CSRoutput == 2'd0 && csr_dmw0_plv0 || crmd_plv_CSRoutput == 2'd3 && csr_dmw0_plv3);
assign dmw1_hit = (nextpc_v[31:29] == csr_dmw1_vseg) & (crmd_plv_CSRoutput == 2'd0 && csr_dmw1_plv0 || crmd_plv_CSRoutput == 2'd3 && csr_dmw1_plv3);

assign dmw0_paddr = {csr_dmw0_pseg, nextpc_v[28:0]};
assign dmw1_paddr = {csr_dmw1_pseg, nextpc_v[28:0]};

assign tlb_paddr = (s0_ps == 6'd22) ? {s0_ppn[19:10], nextpc_v[21:0]} :
                                      {s0_ppn, nextpc_v[11:0]};
assign nextpc_p = csr_direct_addr ? nextpc_v   :
                  dmw0_hit ?        dmw0_paddr :
                  dmw1_hit ?        dmw1_paddr :
                                    tlb_paddr  ;

assign tlb_used = !csr_direct_addr && !dmw0_hit && !dmw1_hit;


assign {fs_tlb_exc[`EARRAY_PIL], fs_tlb_exc[`EARRAY_PIS], fs_tlb_exc[`EARRAY_PME], fs_tlb_exc[`EARRAY_TLBR_MEM], fs_tlb_exc[`EARRAY_PPI_MEM]} = 5'h0;
assign fs_tlb_exc[`EARRAY_TLBR_FETCH] = fs_valid & tlb_used & ~s0_found;
assign fs_tlb_exc[`EARRAY_PIF] = fs_valid & tlb_used & ~s0_v & ~fs_tlb_exc[`EARRAY_TLBR_FETCH];
assign fs_tlb_exc[`EARRAY_PPI_FETCH] = fs_valid & tlb_used & ~fs_tlb_exc[`EARRAY_PIF] & (crmd_plv_CSRoutput > s0_plv);//权限不足

endmodule

