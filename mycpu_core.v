`include "cpuhead.h"
module mycpu_core(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [ 1:0] inst_sram_size,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [ 3:0] data_sram_wstrb,
    output wire [ 1:0] data_sram_size,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata,
    //icache 
    output wire [31:0] inst_addr_vrtl,
    //dcache
    output wire [31:0] data_addr_vrtl
);

wire ds_allowin;
wire es_allowin;
wire ms_allowin;
wire ws_allowin;

wire fs_to_ds_valid;
wire [31:0] fs_inst;
wire [31:0] fs_pc;
wire ds_to_es_valid;
wire [31:0] ds_pc;
wire es_to_ms_valid;
wire [31:0] es_pc;
wire ms_to_ws_valid;
wire [31:0] ms_pc;

wire br_stall;
wire br_taken;
wire [31:0] br_target;

wire [18:0] ds_alu_op;
wire        ds_res_from_mem;
wire        ds_rf_we;
wire [ 4:0] ds_rf_waddr;
wire [31:0] ds_alu_src1;
wire [31:0] ds_alu_src2;
wire        ds_mem_we;
wire [31:0] ds_rkd_value;

wire        es_rf_we;
wire [ 4:0] es_rf_waddr;
wire [31:0] es_alu_result;
wire        es_res_from_mem;
wire        ms_rf_we;
wire [ 4:0] ms_rf_waddr;
wire [31:0] ms_rf_wdata;
wire        ms_res_from_mem;

wire       ws_rf_we;
wire [ 4:0] ws_rf_waddr;
wire [31:0] ws_rf_wdata;

wire [7:0] mem_inst;
wire [4:0] es_ld_inst;


//csr with other
wire [13:0] csr_num;
wire [31:0] csr_rvalue;
    
wire        csr_re;
wire        csr_we;
wire [31:0] csr_wmask;
wire [31:0] csr_wvalue;
wire [31:0] ex_entry; //送往pre-IF的异常处理入口地址
wire [31:0] ertn_entry; //送往pre-IF的返回入口地址
wire [31:0] ertn_entry_target;

wire        has_int; //送往ID流水级的中断有效信号
wire        ertn_flush; //来自WB流水级的ertn指令执行有效信号

wire         ms_ex;   
wire         wb_ex; //来自WB流水级的异常处理触发信号
wire [ 5:0]  wb_ecode; //异常类型
wire [ 8:0]  wb_esubcode; //异常类型
wire [31:0]  wb_pc; //写回的返回地址

//TLB_CSR
wire [ 7:0] fs_tlb_exc;
wire [ 7:0] ds_tlb_exc;
wire [ 7:0] es2ms_tlb_exc;
wire [ 7:0] ms2ws_tlb_exc;

//IF阶段产生adef异常
wire        fs_adef_ex;

//exception zip
wire [84:0] ds_ex_zip;
wire [86:0] es_ex_zip;
wire [86:0] ms_ex_zip;

wire        ds_csr_re;
wire        es_csr_re;
wire        ms_csr_re;

wire        inst_rdcntvh;
wire        inst_rdcntvl;

wire [31:0] es_result;
wire [31:0] ms_result;

wire        ipi_int_in;
wire [ 7:0] hw_int_in;
wire [31:0] coreid_in;
wire [31:0] wb_vaddr;

// TLB 
// search port 0 (for fetch)
wire [18:0] s0_vppn;
wire        s0_va_bit12;
wire [ 9:0] s0_asid;
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_ppn;
wire [ 5:0] s0_ps;
wire [ 1:0] s0_plv;
wire [ 1:0] s0_mat;
wire        s0_d;
wire        s0_v;
// search port 1 (for load/store)
wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [ 9:0] s1_asid;
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_ppn;
wire [ 5:0] s1_ps;
wire [ 1:0] s1_plv;
wire [ 1:0] s1_mat;
wire        s1_d;
wire        s1_v;
// invtlb opcode
wire [ 4:0] invtlb_op;
wire        invtlb_valid;
// write port
wire inst_wb_tlbfill;

wire        tlb_we;
wire [ 3:0] w_index;
wire        w_e;
wire [18:0] tlbehi_vppn_CSRoutput;
wire [ 5:0] w_ps;
wire [ 9:0] asid_CSRoutput;
wire        w_g;

wire [19:0] w_ppn0;
wire [ 1:0] w_plv0;
wire [ 1:0] w_mat0;
wire        w_d0;
wire        w_v0;

wire [19:0] w_ppn1;
wire [ 1:0] w_plv1;
wire [ 1:0] w_mat1;
wire        w_d1;
wire        w_v1;
// read port
wire [ 3:0] r_index;
wire        r_e;
wire [18:0] r_vppn;
wire [ 5:0] r_ps;
wire [ 9:0] r_asid;
wire        r_g;

wire [19:0] r_ppn0;
wire [ 1:0] r_plv0;
wire [ 1:0] r_mat0;
wire        r_d0;
wire        r_v0;

wire [19:0] r_ppn1;
wire [ 1:0] r_plv1;
wire [ 1:0] r_mat1;
wire        r_d1;
wire        r_v1;

//CSR-TLB
wire        inst_wb_tlbsrch;
wire        wb_tlbsrch_found;
wire [ 3:0] wb_tlbsrch_idxgot;
wire [ 3:0] csr_tlbidx_index;
wire        inst_wb_tlbrd;

/*tlb-zip in exp 18*/
wire [10:0] ds2es_tlb_zip;
wire [ 9:0] es2ms_tlb_zip;
wire [ 9:0] ms2ws_tlb_zip;

//TLB block
wire [15:0] es_tlb_blk_zip;
wire [15:0] ms_tlb_blk_zip;

wire        wb_refetch_flush;

/* ----- output csr in exp 19 ----- */
// wire [31:0] csr_crmd_rvalue;
// wire [31:0] csr_asid_rvalue;
// wire [31:0] csr_dmw0_rvalue;
// wire [31:0] csr_dmw1_rvalue; 
wire [2:0] csr_dmw0_pseg;
wire [2:0] csr_dmw0_vseg;
wire [2:0] csr_dmw1_pseg;
wire [2:0] csr_dmw1_vseg;
wire       csr_dmw0_plv0;
wire       csr_dmw0_plv3;
wire       csr_dmw1_plv0;
wire       csr_dmw1_plv3;
wire       csr_direct_addr;
wire [1:0] crmd_plv_CSRoutput;

wire       current_exc_fetch;


assign ertn_entry_target = ertn_flush ? ertn_entry :
                           debug_wb_pc + 32'd4;


IF_stage u_IF_stage(
    .clk            (clk            ),
    .resetn         (resetn         ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //to ds
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_inst        (fs_inst        ),
    .fs_pc          (fs_pc          ),
    //br
    .br_stall       (br_stall       ),
    .br_taken       (br_taken       ),
    .br_target      (br_target      ),
    //inst sram interface
    .inst_sram_req  (inst_sram_req  ),
    .inst_sram_wr   (inst_sram_wr   ),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(inst_sram_addr_ok),
    .inst_sram_data_ok(inst_sram_data_ok),
    .inst_sram_rdata(inst_sram_rdata),
    
    .wb_ex(wb_ex),
    .ertn_flush(ertn_flush | wb_refetch_flush),
    .ex_entry(ex_entry),
    .ertn_entry(ertn_entry_target),
    
    .fs_adef_ex(fs_adef_ex),

    .s0_vppn    (s0_vppn   ),
    .s0_va_bit12(s0_va_bit12),
    .s0_found   (s0_found  ),
    .s0_index   (s0_index  ),
    .s0_ppn     (s0_ppn    ),
    .s0_ps      (s0_ps     ),
    .s0_plv     (s0_plv    ),
    .s0_v       (s0_v      ),
    .crmd_plv_CSRoutput(crmd_plv_CSRoutput),
    .csr_dmw0_pseg(csr_dmw0_pseg),
    .csr_dmw0_vseg(csr_dmw0_vseg),
    .csr_dmw1_pseg(csr_dmw1_pseg),
    .csr_dmw1_vseg(csr_dmw1_vseg),
    .csr_dmw0_plv0(csr_dmw0_plv0),
    .csr_dmw0_plv3(csr_dmw0_plv3),
    .csr_dmw1_plv0(csr_dmw1_plv0),
    .csr_dmw1_plv3(csr_dmw1_plv3),
    .csr_direct_addr(csr_direct_addr),

    .fs_tlb_exc(fs_tlb_exc),
    //icache
    .inst_addr_vrtl(inst_addr_vrtl)
);

ID_stage u_ID_stage(
    .clk            (clk            ),
    .resetn         (resetn         ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //to fs
    .br_stall       (br_stall       ),
    .br_taken       (br_taken       ),
    .br_target      (br_target      ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_inst        (fs_inst        ),
    .fs_pc          (fs_pc          ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_pc          (ds_pc          ),
    .ds_alu_op      (ds_alu_op      ),
    .ds_res_from_mem(ds_res_from_mem),
    .ds_rf_we       (ds_rf_we       ),
    .ds_rf_waddr    (ds_rf_waddr    ),
    .ds_alu_src1    (ds_alu_src1    ),
    .ds_alu_src2    (ds_alu_src2    ),
    .ds_mem_we      (ds_mem_we      ),
    .ds_rkd_value   (ds_rkd_value   ),
    
    .inst_rdcntvh   (inst_rdcntvh),
    .inst_rdcntvl   (inst_rdcntvl),
    //from ws
    .ws_rf_we       (ws_rf_we       ),
    .ws_rf_waddr    (ws_rf_waddr    ),
    .ws_rf_wdata    (ws_rf_wdata    ),
    //from es
    .es_rf_we       (es_rf_we       ),
    .es_rf_waddr    (es_rf_waddr    ),
    .es_result      (es_result  ),
    .es_res_from_mem(es_res_from_mem),
    //from mem
    .ms_rf_we       (ms_rf_we       ),
    .ms_rf_waddr    (ms_rf_waddr    ),
    .ms_rf_wdata    (ms_rf_wdata    ),
    .ms_res_from_mem(ms_res_from_mem),

    .mem_inst       (mem_inst       ),
    
    .es_ex          (es_ex),
    .ms_ex          (ms_ex),
    .wb_ex          (wb_ex|ertn_flush|wb_refetch_flush),
    .ms_csr_re      (ms_csr_re),
    .es_csr_re      (es_csr_re),
    .ds_csr_re      (ds_csr_re),

    .ds_ex_zip      (ds_ex_zip),
    
    .fs_adef_ex     (fs_adef_ex),
    .has_int        (has_int),

    .es_tlb_blk_zip (es_tlb_blk_zip),
    .ms_tlb_blk_zip (ms_tlb_blk_zip),

    .ds2es_tlb_zip  (ds2es_tlb_zip),

    .fs_tlb_exc(fs_tlb_exc),
    .ds_tlb_exc(ds_tlb_exc)
);

EX_stage u_EX_stage(
    .clk            (clk            ),
    .resetn         (resetn         ),
    //allowin

    .mem_inst       (mem_inst       ),

    .es_ld_inst     (es_ld_inst     ),

    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_pc          (ds_pc          ),
    .ds_alu_op      (ds_alu_op      ),
    .ds_res_from_mem(ds_res_from_mem),
    
    .ds_rf_we       (ds_rf_we       ),
    .ds_rf_waddr    (ds_rf_waddr    ),
    .ds_alu_src1    (ds_alu_src1    ),
    .ds_alu_src2    (ds_alu_src2    ),
    .ds_mem_we      (ds_mem_we      ),
    .ds_rkd_value   (ds_rkd_value   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_pc          (es_pc          ),
    .es_alu_result  (es_alu_result  ),
    .es_mem_req     (es_mem_req     ),
    .es_result      (es_result      ),
    .es_rf_we       (es_rf_we       ),
    .es_rf_waddr    (es_rf_waddr    ),
    .es_res_from_mem(es_res_from_mem),
    //data sram interface
    .data_sram_req  (data_sram_req  ),
    .data_sram_wr   (data_sram_wr   ),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_size (data_sram_size ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(data_sram_addr_ok),
    
    .ms_ex(ms_ex),
    .wb_ex(wb_ex|ertn_flush),
    .es_ex(es_ex),
    
    .ds_csr_re(ds_csr_re),
    .es_csr_re(es_csr_re),
    
    .inst_rdcntvh   (inst_rdcntvh),
    .inst_rdcntvl   (inst_rdcntvl),
    
    .ds_ex_zip(ds_ex_zip),
    .es_ex_zip(es_ex_zip),

    //to id
    .es_tlb_blk_zip(es_tlb_blk_zip),
    
    //TLB
    .ds2es_tlb_zip(ds2es_tlb_zip),
    .es2ms_tlb_zip(es2ms_tlb_zip),

    .invtlb_op   (invtlb_op),
    .inst_invtlb (invtlb_valid),
    .s1_vppn     (s1_vppn),
    .s1_va_bit12 (s1_va_bit12),
    .s1_asid     (s1_asid),
    .s1_found    (s1_found  ),
    .s1_index    (s1_index  ),
    .s1_ppn      (s1_ppn    ),
    .s1_ps       (s1_ps     ),
    .s1_plv      (s1_plv    ),
    .s1_mat      (s1_mat    ),
    .s1_d        (s1_d      ),
    .s1_v        (s1_v      ),
    .tlbehi_vppn_CSRoutput(tlbehi_vppn_CSRoutput),
    .asid_CSRoutput(asid_CSRoutput),

    .crmd_plv_CSRoutput(crmd_plv_CSRoutput),
    .csr_dmw0_pseg(csr_dmw0_pseg),
    .csr_dmw0_vseg(csr_dmw0_vseg),
    .csr_dmw1_pseg(csr_dmw1_pseg),
    .csr_dmw1_vseg(csr_dmw1_vseg),
    .csr_dmw0_plv0(csr_dmw0_plv0),
    .csr_dmw0_plv3(csr_dmw0_plv3),
    .csr_dmw1_plv0(csr_dmw1_plv0),
    .csr_dmw1_plv3(csr_dmw1_plv3),
    .csr_direct_addr(csr_direct_addr),

    .ds_tlb_exc(ds_tlb_exc),
    .es2ms_tlb_exc(es2ms_tlb_exc),

    .vaddr(data_addr_vrtl)
);

MEM_stage u_MEM_stage(
    .clk            (clk            ),
    .resetn         (resetn         ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_pc          (es_pc          ),
    .es_alu_result  (es_alu_result  ),
    .es_rf_we       (es_rf_we       ),
    .es_rf_waddr    (es_rf_waddr    ),
    .es_res_from_mem(es_res_from_mem),
    .es_mem_req     (es_mem_req     ),
    .es_result(es_result),
    .ms_result(ms_result),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_pc          (ms_pc          ),
    .ms_rf_we       (ms_rf_we       ),
    .ms_rf_waddr    (ms_rf_waddr    ),
    .ms_rf_wdata    (ms_rf_wdata    ),
    .ms_res_from_mem(ms_res_from_mem),

    .es_ld_inst     (es_ld_inst     ),

    //from data sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),

    .ms_ex(ms_ex),
    .wb_ex(wb_ex|ertn_flush|wb_refetch_flush),
    
    .es_ex_zip(es_ex_zip),
    .ms_ex_zip(ms_ex_zip),
    
    //to id
    .ms_tlb_blk_zip(ms_tlb_blk_zip),
    
    //TLB
    .es2ms_tlb_zip(es2ms_tlb_zip),
    .ms2ws_tlb_zip(ms2ws_tlb_zip),
    
    .es_csr_re(es_csr_re),
    .ms_csr_re(ms_csr_re),

    .es2ms_tlb_exc(es2ms_tlb_exc),
    .ms2ws_tlb_exc(ms2ws_tlb_exc)
);

WB_stage u_WB_stage(
    .clk            (clk            ),
    .resetn         (resetn         ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_pc          (ms_pc          ),
    .ms_rf_we       (ms_rf_we       ),
    .ms_rf_waddr    (ms_rf_waddr    ),
    .ms_rf_wdata    (ms_rf_wdata    ),
    //to id
    .ws_rf_we       (ws_rf_we       ),
    .ws_rf_waddr    (ws_rf_waddr    ),
    .ws_rf_wdata    (ws_rf_wdata    ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc       ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    
    .ms_ex_zip(ms_ex_zip),
    .ms_csr_re(ms_csr_re),
    .ms_result(ms_result),
    
    .csr_re     (csr_re    ),
    .csr_num    (csr_num   ),
    .csr_rvalue (csr_rvalue),
    .csr_we     (csr_we    ),
    .csr_wmask  (csr_wmask ),
    .csr_wvalue (csr_wvalue),
    .ertn_flush (ertn_flush),
    .wb_ex      (wb_ex     ),
    .wb_pc      (wb_pc     ),
    .wb_ecode   (wb_ecode  ),
    .wb_esubcode(wb_esubcode),
    
    .ipi_int_in(ipi_int_in),
    .hw_int_in(hw_int_in),
    .coreid_in(coreid_in),
    .wb_vaddr(wb_vaddr),

    //TLB
    .inst_wb_tlbfill(inst_wb_tlbfill),
    .inst_wb_tlbsrch(inst_wb_tlbsrch),
    .tlb_we      (tlb_we),
    .inst_wb_tlbrd(inst_wb_tlbrd),
    .wb_tlbsrch_found(wb_tlbsrch_found),
    .wb_tlbsrch_idxgot(wb_tlbsrch_idxgot),
    .wb_refetch_flush(wb_refetch_flush),

    .ms2ws_tlb_zip(ms2ws_tlb_zip),

    .current_exc_fetch(current_exc_fetch),

    .ms2ws_tlb_exc(ms2ws_tlb_exc)
);

csr u_csr(
        .clk        (clk      ),
        .reset      (~resetn   ),
        
        .csr_re     (csr_re    ),
        .csr_num    (csr_num   ),
        .csr_rvalue (csr_rvalue),
        
        .csr_we     (csr_we    ),
        .csr_wmask  (csr_wmask ),
        .csr_wvalue (csr_wvalue),

        .ex_entry   (ex_entry  ),
        .ertn_entry (ertn_entry),
        .has_int    (has_int   ),
        .ertn_flush (ertn_flush),
        .wb_ex      (wb_ex     ),
        .wb_ecode   (wb_ecode  ),
        .wb_esubcode(wb_esubcode),
        .wb_pc      (wb_pc     ),
        
        .ipi_int_in(ipi_int_in),
        .hw_int_in(hw_int_in),
        .coreid_in(coreid_in),
        .wb_vaddr(wb_vaddr),
        
        /* input data from WB */
        .tlbsrch_we        (inst_wb_tlbsrch),
        .tlbsrch_hit       (wb_tlbsrch_found),
        .tlbsrch_idx       (wb_tlbsrch_idxgot),
        .tlbrd_we          (inst_wb_tlbrd),
        
        /* input data from TLB, TLBSRCH & TLBRD use these data to write CSR */
        .r_tlb_e         (r_e),
        .r_tlb_ps        (r_ps),
        .r_tlb_vppn      (r_vppn),
        .r_tlb_asid      (r_asid),
        .r_tlb_g         (r_g),
        .r_tlb_ppn0      (r_ppn0),
        .r_tlb_plv0      (r_plv0),
        .r_tlb_mat0      (r_mat0),
        .r_tlb_d0        (r_d0),
        .r_tlb_v0        (r_v0),
        .r_tlb_ppn1      (r_ppn1),
        .r_tlb_plv1      (r_plv1),
        .r_tlb_mat1      (r_mat1),
        .r_tlb_d1        (r_d1),
        .r_tlb_v1        (r_v1),
    
        /* output data to TLB, TLBWR & TLBFILL use these data to write TLB */
        .w_tlb_e         (w_e),
        .w_tlb_ps        (w_ps),
        .w_tlb_vppn      (w_vppn),
        .w_tlb_asid      (w_asid),
        .w_tlb_g         (w_g),
        .w_tlb_ppn0      (w_ppn0),
        .w_tlb_plv0      (w_plv0),
        .w_tlb_mat0      (w_mat0),
        .w_tlb_d0        (w_d0),
        .w_tlb_v0        (w_v0),
        .w_tlb_ppn1      (w_ppn1),
        .w_tlb_plv1      (w_plv1),
        .w_tlb_mat1      (w_mat1),
        .w_tlb_d1        (w_d1),
        .w_tlb_v1        (w_v1),
        
        /* ----- output csr in exp 18 ----- */
        .csr_asid_asid   (asid_CSRoutput),
        .csr_tlbehi_vppn (tlbehi_vppn_CSRoutput),
        .csr_tlbidx_index(csr_tlbidx_index),
        
        
        /* ----- output csr in exp 19 ----- */
        .csr_crmd_plv (crmd_plv_CSRoutput),
        .csr_dmw0_pseg(csr_dmw0_pseg),
        .csr_dmw0_vseg(csr_dmw0_vseg),
        .csr_dmw1_pseg(csr_dmw1_pseg),
        .csr_dmw1_vseg(csr_dmw1_vseg),
        .csr_dmw0_plv0(csr_dmw0_plv0),
        .csr_dmw0_plv3(csr_dmw0_plv3),
        .csr_dmw1_plv0(csr_dmw1_plv0),
        .csr_dmw1_plv3(csr_dmw1_plv3),
        .csr_direct_addr(csr_direct_addr),
        .current_exc_fetch(current_exc_fetch)
    
    );
    
tlb u_tlb(
        .clk        (clk),
        .resetn     (~resetn),
        
        .s0_vppn    (s0_vppn),
        .s0_va_bit12(s0_va_bit12),
        .s0_asid    (asid_CSRoutput),
        .s0_found   (s0_found),
        .s0_index   (s0_index),
        .s0_ppn     (s0_ppn),
        .s0_ps      (s0_ps),
        .s0_plv     (s0_plv),
        .s0_mat     (s0_mat),
        .s0_d       (s0_d),
        .s0_v       (s0_v),

        .s1_vppn    (s1_vppn),
        .s1_va_bit12(s1_va_bit12),
        .s1_asid    (s1_asid),
        .s1_found   (s1_found),
        .s1_index   (s1_index),
        .s1_ppn     (s1_ppn),
        .s1_ps      (s1_ps),
        .s1_plv     (s1_plv),
        .s1_mat     (s1_mat),
        .s1_d       (s1_d),
        .s1_v       (s1_v),

        .invtlb_op   (invtlb_op),
        .invtlb_valid(invtlb_valid),

        .inst_wb_tlbfill(inst_wb_tlbfill),
        
        .we         (tlb_we),
        .w_index    (csr_tlbidx_index),
        .w_e        (w_e),
        .w_vppn     (tlbehi_vppn_CSRoutput),
        .w_ps       (w_ps),
        .w_asid     (asid_CSRoutput),
        .w_g        (w_g),
        .w_ppn0     (w_ppn0),
        .w_plv0     (w_plv0),
        .w_mat0     (w_mat0),
        .w_d0       (w_d0),
        .w_v0       (w_v0),
        .w_ppn1     (w_ppn1),
        .w_plv1     (w_plv1),
        .w_mat1     (w_mat1),
        .w_d1       (w_d1),
        .w_v1       (w_v1),

        .r_index    (csr_tlbidx_index),
        .r_e        (r_e),
        .r_vppn     (r_vppn),
        .r_ps       (r_ps),
        .r_asid     (r_asid),
        .r_g        (r_g),

        .r_ppn0     (r_ppn0),
        .r_plv0     (r_plv0),
        .r_mat0     (r_mat0),
        .r_d0       (r_d0),
        .r_v0       (r_v0),

        .r_ppn1     (r_ppn1),
        .r_plv1     (r_plv1),
        .r_mat1     (r_mat1),
        .r_d1       (r_d1),
        .r_v1       (r_v1)
);

endmodule
