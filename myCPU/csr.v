`define CSR_CRMD   14'h00
`define CSR_PRMD   14'h01
`define CSR_EUEN   14'h02
`define CSR_ECFG   14'h04
`define CSR_ESTAT  14'h05
`define CSR_ERA    14'h06
`define CSR_BADV   14'h07
`define CSR_EENTRY 14'h0c
`define CSR_SAVE0  14'h30
`define CSR_SAVE1  14'h31
`define CSR_SAVE2  14'h32
`define CSR_SAVE3  14'h33
`define CSR_TID    14'h40
`define CSR_TCFG   14'h41
`define CSR_TVAL   14'h42
`define CSR_TICLR  14'h44
    
`define CSR_CRMD_PLV    1 :0
`define CSR_CRMD_IE     2
`define CSR_PRMD_PPLV   1 :0
`define CSR_PRMD_PIE    2
`define CSR_ECFG_LIE    12:0
`define CSR_ESTAT_IS10  1 :0
`define CSR_ERA_PC      31:0
`define CSR_EENTRY_VA   31:6
`define CSR_SAVE_DATA   31:0
`define CSR_TID_TID     31:0

module csr(
    input  wire          clock       ,
    input  wire          reset     ,
    
    // 指令访问接口
    input  wire          csr_re    ,
    input  wire [13:0]   csr_num   ,
    output wire [31:0]   csr_rvalue,
    
    input  wire          csr_we    ,
    input  wire [31:0]   csr_wmask ,
    input  wire [31:0]   csr_wvalue,
    
    // 硬件电路交互接口
    output wire [31:0]   ex_entry  , //送往pre-IF的异常处理入口地址
    output wire [31:0]   ertn_entry, //送往pre-IF的返回入口地址
    output wire          has_int   , //送往ID流水级的中断有效信号
    input  wire          ertn_flush, //来自WB流水级的ertn指令执行有效信号
    input  wire          wb_ex     , //来自WB流水级的异常处理触发信号
    input  wire [ 5:0]   wb_ecode  , //异常类型
    input  wire [ 8:0]   wb_esubcode,//异常类型
    input  wire [31:0]   wb_pc       //写回的返回地址
    );
    
    //CRMD
    wire [31:0] csr_crmd_value;
    reg [1:0] csr_crmd_plv;
    reg       csr_crmd_ie;
    wire       csr_crmd_da;
    wire       csr_crmd_pg;
    wire [1:0] csr_crmd_datf;
    wire [1:0] csr_crmd_datm;
    
    //PRMD
    wire [31:0] csr_prmd_value;
    reg       csr_prmd_pie;
    reg [1:0] csr_prmd_pplv;
    
    //ECFG
    wire [31:0] csr_ecfg_value;
    reg [12:0]csr_ecfg_lie;
    
    //ESTAT
    wire [31:0] csr_estat_value;
    reg [1:0] csr_estat_is;
    reg [31:0] csr_estat_pc;
    reg [5:0] csr_estat_ecode;
    reg [8:0] csr_estat_esubcode;
    
    //ERA
    reg [31:0] csr_era_pc;
    
    //EENTRY
    wire [31: 0] csr_eentry_value;  
    reg  [25: 0] csr_eentry_va;   
    
    //SAVE0~3
    reg  [31: 0] csr_save0_data;
    reg  [31: 0] csr_save1_data;
    reg  [31: 0] csr_save2_data;
    reg  [31: 0] csr_save3_data;
    
    //TICLR
    wire [31: 0] csr_ticlr_value;
    
    assign has_int = (~|(csr_estat_is[11:0] & csr_ecfg_lie[11:0])) & csr_crmd_ie;
    assign ex_entry = csr_eentry_value;
    assign ertn_entry = csr_era_pc;
    
    //PLV,IE in CRMD    
    always @(posedge clock) begin
        if (reset) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
        end
        else if (wb_ex) begin
            csr_crmd_plv <= 2'b0;
            csr_crmd_ie <= 1'b0;
        end
        else if (ertn_flush) begin
            csr_crmd_plv <= csr_prmd_pplv;
            csr_crmd_ie <= csr_prmd_pie;
        end
        else if (csr_we && csr_num==`CSR_CRMD) begin
            csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV]&csr_wvalue[`CSR_CRMD_PLV]
            | ~csr_wmask[`CSR_CRMD_PLV]&csr_crmd_plv;
            csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE]&csr_wvalue[`CSR_CRMD_IE]
            | ~csr_wmask[`CSR_CRMD_IE]&csr_crmd_ie;
        end
    end
    
    //DA,PG,DAFT,DATM in CRMD
    assign csr_crmd_da = 1'b1; 
    assign csr_crmd_pg = 1'b0; 
    assign csr_crmd_datf = 2'b00; 
    assign csr_crmd_datm = 2'b00;
    
    //PPLV,PIE in PRMD
    always @(posedge clock) begin
        if (wb_ex) begin
            csr_prmd_pplv <= csr_crmd_plv;
            csr_prmd_pie <= csr_crmd_ie;
        end
        else if (csr_we && csr_num==`CSR_PRMD) begin
            csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV]&csr_wvalue[`CSR_PRMD_PPLV]
            | ~csr_wmask[`CSR_PRMD_PPLV]&csr_prmd_pplv;
            csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE]&csr_wvalue[`CSR_PRMD_PIE]
            | ~csr_wmask[`CSR_PRMD_PIE]&csr_prmd_pie;
        end
    end
    
    //LIE in ECFG
//    always @(posedge clock) begin
//        if (reset)
//            csr_ecfg_lie <= 13'b0;
//        else if (csr_we && csr_num==`CSR_ECFG)
//            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_wvalue[`CSR_ECFG_LIE]
//            | ~csr_wmask[`CSR_ECFG_LIE]&13'h1bff&csr_ecfg_lie;
//    end
    
    //IS in ESTATE
    always @(posedge clock) begin
        if (reset)
            csr_estat_is[1:0] <= 2'b0;
        else if (csr_we && csr_num==`CSR_ESTAT)
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10]&csr_wvalue[`CSR_ESTAT_IS10]
            | ~csr_wmask[`CSR_ESTAT_IS10]&csr_estat_is[1:0];
            
        //csr_estat_is[9:2] <= hw_int_in[7:0];
        csr_estat_is[9:2] <= 8'b0;
        csr_estat_is[10] <= 1'b0;
        csr_estat_is[ 11] <= 1'b0;
        //if (timer_cnt[31:0]==32'b0)
        //    csr_estat_is[11] <= 1'b1;
        //else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR]
        //&& csr_wvalue[`CSR_TICLR_CLR])
        //    csr_estat_is[11] <= 1'b0;
        
        //csr_estat_is[12] <= ipi_int_in;
    end
    
    //Ecode,Esubcode in ESTATE
    always @(posedge clock) begin
        if (wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end
        
    //PC in ERA
    always @(posedge clock)begin
        if (wb_ex)
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_num == `CSR_ERA)
            csr_era_pc <= csr_wmask[`CSR_ERA_PC]&csr_wvalue[`CSR_ERA_PC]
                        | ~csr_wmask[`CSR_ERA_PC]&csr_era_pc;
    end
    
    //Vaddr in BADV
//    assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
//    always @(posedge clock) begin
//        if (wb_ex && wb_ex_addr_err)
//            csr_badv_vaddr <= (wb_ecode==`ECODE_ADE &&
//            wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
//    end

    //VA in EENTRY
    always @(posedge clock) begin
    if (csr_we && csr_num==`CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA]&csr_wvalue[`CSR_EENTRY_VA]
        | ~csr_wmask[`CSR_EENTRY_VA]&csr_eentry_va;
    end
    
    // SAVE0~3
    always @(posedge clock) begin
        if (csr_we && csr_num == `CSR_SAVE0) 
            csr_save0_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
        if (csr_we && (csr_num == `CSR_SAVE1)) 
            csr_save1_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
        if (csr_we && (csr_num == `CSR_SAVE2)) 
            csr_save2_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
        if (csr_we && (csr_num == `CSR_SAVE3)) 
            csr_save3_data <=  csr_wmask[`CSR_SAVE_DATA] & csr_wvalue[`CSR_SAVE_DATA]
                            | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
    end
    
    assign csr_crmd_value  = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, 
                            csr_crmd_da, csr_crmd_ie, csr_crmd_plv};
    assign csr_prmd_value  = {29'b0, csr_prmd_pie, csr_prmd_pplv};
    assign csr_ecfg_value  = {19'b0, csr_ecfg_lie};
    assign csr_estat_value = { 1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};
    assign csr_eentry_value= {csr_eentry_va, 6'b0};
    
    assign csr_rvalue = {32{csr_num == `CSR_CRMD  }} & csr_crmd_value
                      | {32{csr_num == `CSR_PRMD  }} & csr_prmd_value
                      | {32{csr_num == `CSR_ECFG  }} & csr_ecfg_value
                      | {32{csr_num == `CSR_ESTAT }} & csr_estat_value
                      | {32{csr_num == `CSR_ERA   }} & csr_era_pc
                      | {32{csr_num == `CSR_EENTRY}} & csr_eentry_value
                      | {32{csr_num == `CSR_SAVE0 }} & csr_save0_data
                      | {32{csr_num == `CSR_SAVE1 }} & csr_save1_data
                      | {32{csr_num == `CSR_SAVE2 }} & csr_save2_data
                      | {32{csr_num == `CSR_SAVE3 }} & csr_save3_data
                      | {32{csr_num == `CSR_TICLR }} & csr_ticlr_value;
endmodule

