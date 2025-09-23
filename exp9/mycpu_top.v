module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
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

wire br_taken;
wire [31:0] br_target;

wire [11:0] ds_alu_op;
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

wire       ws_rf_we;
wire [ 4:0] ws_rf_waddr;
wire [31:0] ws_rf_wdata;


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
    .br_taken       (br_taken       ),
    .br_target      (br_target      ),
    //inst sram interface
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_we   (inst_sram_we   ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_rdata(inst_sram_rdata)
);

ID_stage u_ID_stage(
    .clk            (clk            ),
    .resetn         (resetn         ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //to fs
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
    //from ws
    .ws_rf_we       (ws_rf_we       ),
    .ws_rf_waddr    (ws_rf_waddr    ),
    .ws_rf_wdata    (ws_rf_wdata    ),
    //from es
    .es_rf_we       (es_rf_we       ),
    .es_rf_waddr    (es_rf_waddr    ),
    .es_alu_result  (es_alu_result  ),
    .es_res_from_mem(es_res_from_mem),
    //from mem
    .ms_rf_we       (ms_rf_we       ),
    .ms_rf_waddr    (ms_rf_waddr    ),
    .ms_rf_wdata    (ms_rf_wdata    )
);

EX_stage u_EX_stage(
    .clk            (clk            ),
    .resetn         (resetn         ),
    //allowin
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
    .es_rf_we       (es_rf_we       ),
    .es_rf_waddr    (es_rf_waddr    ),
    .es_res_from_mem(es_res_from_mem),
    //data sram interface
    .data_sram_en   (data_sram_en   ),
    .data_sram_we   (data_sram_we  ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata)
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
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_pc          (ms_pc          ),
    .ms_rf_we       (ms_rf_we       ),
    .ms_rf_waddr    (ms_rf_waddr    ),
    .ms_rf_wdata    (ms_rf_wdata    ),
    //from data sram
    .data_sram_rdata(data_sram_rdata)
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
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);

endmodule
