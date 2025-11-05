module ID_stage(
    input wire         clk,
    input wire         resetn,
    
    //allowin
    input  wire        es_allowin,
    output wire        ds_allowin,
    
    //to fs
    output wire        br_taken,
    output wire [31:0] br_target,

    //from fs
    input wire         fs_to_ds_valid,
    input wire [31:0]  fs_inst,
    input wire [31:0]  fs_pc,
    
    //to es
    output wire        ds_to_es_valid,
    output reg  [31:0] ds_pc,
    output wire [18:0] ds_alu_op,//add width for mul,div and mod
    output wire        ds_res_from_mem,
    output wire [31:0] ds_alu_src1,
    output wire [31:0] ds_alu_src2,
    output wire [31:0] ds_rkd_value,
    output wire        ds_mem_we,
    output wire        ds_rf_we,
    output wire [ 4:0] ds_rf_waddr,
    
    //from es
    input  wire        es_rf_we,
    input  wire [ 4:0] es_rf_waddr,
    input  wire [31:0] es_alu_result,
    input  wire        es_res_from_mem,
    input  wire        es_csr_re,
    
    //from mem
    input  wire        ms_rf_we,
    input  wire [ 4:0] ms_rf_waddr,
    input  wire [31:0] ms_rf_wdata,
    input  wire        ms_csr_re,
    
    //from wb
    input  wire        ws_rf_we,
    input  wire [ 4:0] ws_rf_waddr,
    input  wire [31:0] ws_rf_wdata,

    output wire [ 7:0] mem_inst,//
    
    input wire wb_ex,
    output wire ds_csr_re,
    input wire [80:0] ms_ex_zip,//{ms_csr_we, ms_csr_wmask, ms_csr_wvalue, ms_csr_num, inst_syscall, inst_ertn}
    input wire [80:0] es_ex_zip,//{es_csr_we, es_csr_wmask, es_csr_wvalue, es_csr_num, inst_syscall, inst_ertn}
    output wire [80:0] ds_ex_zip//{ds_csr_we, ds_csr_wmask, ds_csr_wvalue, ds_csr_num, inst_syscall, inst_ertn}
);

wire ds_ready_go;
reg  ds_valid;
wire ds_stop;
reg  [31:0] ds_inst;

wire        ds_src1_is_pc;
wire        ds_src2_is_imm;

wire        dst_is_r1; //for bl
wire        gr_we;     //general register write enable

wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;

wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

//独热�?
wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_slti;//
wire        inst_sltu;
wire        inst_sltui;//
wire        inst_nor;
wire        inst_and;
wire        inst_andi;//
wire        inst_or;
wire        inst_ori;//
wire        inst_xor;
wire        inst_xori;
wire        inst_sll_w;//
wire        inst_slli_w;
wire        inst_srl_w;//
wire        inst_srli_w;
wire        inst_sra_w;//
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;
wire        inst_pcaddul2i;//
wire        inst_mul_w;//
wire        inst_mulh_w;//
wire        inst_mulh_wu;//
wire        inst_div_w;//
wire        inst_div_wu;//
wire        inst_mod_w;//
wire        inst_mod_wu;//

wire        inst_blt;
wire        inst_bge;
wire        inst_bltu;
wire        inst_bgeu;

wire        inst_ld_b;
wire        inst_ld_h;
wire        inst_ld_bu;
wire        inst_ld_hu;

wire        inst_st_b;
wire        inst_st_h;

//添加寄存器操作，异常，系统调用指令
wire        inst_csrrd;
wire        inst_csrwr;
wire        inst_csrxchg;
wire        inst_ertn;
wire        inst_syscall;

wire        need_ui5;
wire        need_ui12;//
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;



wire conflict_rs1_wb;
wire conflict_rs2_wb;
wire conflict_rs1_mem;
wire conflict_rs2_mem;
wire conflict_rs1_ex;
wire conflict_rs2_ex;
wire need_r1;
wire need_r2;


wire rj_eq_rd;
wire rj_less_rd;
wire rj_less_rd_u;

//exception

wire [13:0] ds_csr_num;
wire        ds_csr_we;
wire [31:0] ds_csr_wmask;
wire [31:0] ds_csr_wvalue;

/////////////////////////////////////////////////////////
//handsake
/////////////////////////////////////////////////////////
assign ds_ready_go    = !ds_stop;
assign ds_allowin     = !ds_valid | ds_ready_go & es_allowin;
//load-risk
assign ds_stop        = ( ( (conflict_rs1_ex & need_r1) | (conflict_rs2_ex & need_r2) ) & (es_res_from_mem | es_csr_re) )|
                        ( (conflict_rs1_mem | conflict_rs2_mem) & ms_csr_re);
assign ds_to_es_valid =  ds_valid & ds_ready_go;

always @(posedge clk) begin
    if (!resetn)
        ds_valid <= 1'b0;
    else if(wb_ex)
        ds_valid <= 1'b0;
    else if (br_taken)
        ds_valid <= 1'b0;
    else if (ds_allowin)
        ds_valid <= fs_to_ds_valid;
end

/////////////////////////////////////////////////////////
//if_id
/////////////////////////////////////////////////////////
always @(posedge clk) begin
    if (!resetn) begin
        ds_inst <= 32'b0;
        ds_pc   <= 32'h1bffffff;
    end
    else if (ds_allowin && fs_to_ds_valid) begin
        ds_inst <= fs_inst;
        ds_pc   <= fs_pc;
    end
end

//////////////////////////////////////////////////////////
//branch
//////////////////////////////////////////////////////////

assign rj_eq_rd = (rj_value == rkd_value);
assign rj_less_rd = ($signed(rj_value) < $signed(rkd_value));
assign rj_less_rd_u = (rj_value < rkd_value);

assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_blt  &&  rj_less_rd
                   || inst_bge  && !rj_less_rd
                   || inst_bltu &&  rj_less_rd_u
                   || inst_bgeu && !rj_less_rd_u
                   || inst_jirl 
                   || inst_bl
                   || inst_b
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (ds_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);



///////////////////////////////////////////////////////////
//decode
///////////////////////////////////////////////////////////

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd   = ds_inst[ 4: 0];
assign rj   = ds_inst[ 9: 5];
assign rk   = ds_inst[14:10];

assign i12  = ds_inst[21:10];
assign i20  = ds_inst[24: 5];
assign i16  = ds_inst[25:10];
assign i26  = {ds_inst[ 9: 0], ds_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];

assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];

assign inst_mul_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu= op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];

assign inst_div_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

//add syscall
assign inst_syscall = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];

assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];

assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];

assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];

assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ds_inst[25];

assign inst_pcaddul2i = op_31_26_d[6'h07] & ~ds_inst[25];

assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];

assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];

assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];

//add csr inst
assign inst_csrrd   = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h00);
assign inst_csrwr   = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj == 5'h01);
assign inst_csrxchg = op_31_26_d[6'h01] & (op_25_22[3:2] == 2'b0) & (rj != 5'h00) && (rj != 5'h01);

//add ertn
assign inst_ertn    = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] 
                        & (rk == 5'h0e) & (rj == 5'h00) & (rd == 5'h00);
                        
assign mem_inst = {inst_st_b, inst_st_h, inst_st_w, inst_ld_b, inst_ld_bu,inst_ld_h, inst_ld_hu, inst_ld_w};

assign ds_alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl | inst_pcaddul2i |inst_ld_b|inst_ld_bu|inst_ld_h|inst_ld_hu |inst_st_h |inst_st_b;
assign ds_alu_op[ 1] = inst_sub_w;
assign ds_alu_op[ 2] = inst_slt | inst_slti;
assign ds_alu_op[ 3] = inst_sltu | inst_sltui;
assign ds_alu_op[ 4] = inst_and | inst_andi;
assign ds_alu_op[ 5] = inst_nor;
assign ds_alu_op[ 6] = inst_or | inst_ori; 
assign ds_alu_op[ 7] = inst_xor | inst_xori;
assign ds_alu_op[ 8] = inst_slli_w | inst_sll_w;
assign ds_alu_op[ 9] = inst_srli_w | inst_srl_w;
assign ds_alu_op[10] = inst_srai_w | inst_sra_w;
assign ds_alu_op[11] = inst_lu12i_w;
assign ds_alu_op[12] = inst_mul_w ;
assign ds_alu_op[13] = inst_mulh_w;
assign ds_alu_op[14] = inst_mulh_wu;
assign ds_alu_op[15] = inst_div_w;
assign ds_alu_op[16] = inst_div_wu;
assign ds_alu_op[17] = inst_mod_w;
assign ds_alu_op[18] = inst_mod_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_ui12  =  inst_andi   | inst_ori | inst_xori ;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w|inst_st_b|inst_st_h | inst_slti | inst_sltui |inst_ld_b|inst_ld_bu|inst_ld_h|inst_ld_hu;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt |inst_bge |inst_bltu |inst_bgeu;//
assign need_si20  =  inst_lu12i_w | inst_pcaddul2i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
             (need_ui5 || need_si12) ? {{20{i12[11]}}, i12[11:0]} :
             {20'b0, i12[11:0]};

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | 
                       inst_st_w | inst_st_b | inst_st_h | 
                       inst_csrwr | inst_csrxchg;

assign ds_src1_is_pc    = inst_jirl | inst_bl | inst_pcaddul2i;

assign ds_src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_ld_b   |
                       inst_ld_bu  |
                       inst_ld_h   |
                       inst_ld_hu  |
                       inst_st_w   |
                       inst_st_b   |
                       inst_st_h   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     |
                       inst_pcaddul2i|
                       inst_andi   |
                       inst_ori    |
                       inst_xori   |
                       inst_slti   |
                       inst_sltui;

assign ds_alu_src1 = ds_src1_is_pc  ? ds_pc[31:0] : rj_value;
assign ds_alu_src2 = ds_src2_is_imm ? imm : rkd_value;
assign ds_rkd_value= rkd_value;

assign ds_res_from_mem  = inst_ld_w | inst_ld_b |inst_ld_bu|inst_ld_h|inst_ld_hu;
assign dst_is_r1     = inst_bl;


assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bge & 
                       ~inst_bltu & ~inst_bgeu & ~inst_b & ~inst_st_b & ~inst_st_h & 
                       ~inst_syscall & ds_valid;
assign ds_mem_we        = (inst_st_w |inst_st_b|inst_st_h) & ds_valid;
assign dest          = dst_is_r1 ? 5'd1 : rd;



///////////////////////////////////////////////////////////
//regfile
///////////////////////////////////////////////////////////

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (ws_rf_we    ),
    .waddr  (ws_rf_waddr ),
    .wdata  (ws_rf_wdata )
);

assign ds_rf_we    = gr_we;
assign ds_rf_waddr = dest;

wire type_branch_cond = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;


assign conflict_rs1_wb = ws_rf_we && (rf_raddr1 != 5'b0) && (ws_rf_waddr == rf_raddr1);
assign conflict_rs2_wb = ws_rf_we && (rf_raddr2 != 5'b0) && (ws_rf_waddr == rf_raddr2);
assign conflict_rs1_ex = es_rf_we && (rf_raddr1 != 5'b0) && (es_rf_waddr == rf_raddr1);
assign conflict_rs2_ex = es_rf_we && (rf_raddr2 != 5'b0) && (es_rf_waddr == rf_raddr2);
assign conflict_rs1_mem= ms_rf_we && (rf_raddr1 != 5'b0) && (ms_rf_waddr == rf_raddr1);
assign conflict_rs2_mem= ms_rf_we && (rf_raddr2 != 5'b0) && (ms_rf_waddr == rf_raddr2);
assign need_r1         = ~ds_src1_is_pc & ((ds_alu_op != 18'b0) | type_branch_cond);
assign need_r2         = ~ds_src2_is_imm & ((ds_alu_op != 18'b0) | type_branch_cond);

//bypass

assign rj_value  = conflict_rs1_ex  ? es_alu_result :
                   conflict_rs1_mem ? ms_rf_wdata :
                   conflict_rs1_wb  ? ws_rf_wdata :
                                      rf_rdata1;
assign rkd_value = conflict_rs2_ex  ? es_alu_result :
                   conflict_rs2_mem ? ms_rf_wdata :
                   conflict_rs2_wb  ? ws_rf_wdata :
                                      rf_rdata2;
 //exception
 assign ds_csr_re     = inst_csrrd | inst_csrwr | inst_csrxchg;
 assign ds_csr_we     = inst_csrwr | inst_csrxchg;
 assign ds_csr_wmask  = {32{inst_csrxchg}} & rj_value | {32{inst_csrwr}};
 assign ds_csr_wvalue = rkd_value;
 assign ds_csr_num    = ds_inst[23:10];
 
 assign ds_ex_zip = {ds_csr_we, ds_csr_wmask, ds_csr_wvalue, ds_csr_num, inst_syscall, inst_ertn};

endmodule


