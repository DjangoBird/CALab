module mycpu_top(
    input  wire        aclk,
    input  wire        aresetn,

    output wire [ 3:0] arid,
    output wire [31:0] araddr,
    output wire [ 7:0] arlen,
    output wire [ 2:0] arsize,
    output wire [ 1:0] arburst,
    output wire [ 1:0] arlock,
    output wire [ 3:0] arcache,
    output wire [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    output wire [ 3:0] awid,
    output wire [31:0] awaddr,
    output wire [ 7:0] awlen,
    output wire [ 2:0] awsize,
    output wire [ 1:0] awburst,
    output wire [ 1:0] awlock,
    output wire [ 3:0] awcache,
    output wire [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,
    output wire [ 3:0] wid,
    output wire [31:0] wdata,
    output wire [ 3:0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,  
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

wire        inst_sram_req;
wire        inst_sram_wr;
wire [ 3:0] inst_sram_wstrb;
wire [ 1:0] inst_sram_size;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire        inst_sram_addr_ok;
wire        inst_sram_data_ok;
wire [31:0] inst_sram_rdata;

wire        data_sram_req;
wire        data_sram_wr;
wire [ 3:0] data_sram_wstrb;
wire [ 1:0] data_sram_size;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire        data_sram_addr_ok;
wire        data_sram_data_ok;
wire [31:0] data_sram_rdata;

//icache read channel
wire [31:0] inst_addr_vrtl;
wire        icache_addr_ok;
wire        icache_data_ok;
wire [31:0] icache_rdata;
wire        icache_rd_req;
wire [ 2:0] icache_rd_type;
wire [31:0] icache_rd_addr;
wire        icache_rd_rdy;
wire        icache_ret_valid; 
wire        icache_ret_last;
wire [31:0] icache_ret_data;

    //icache write channel=meaning less ,all is 0        
wire        icache_wr_req;
wire [ 2:0] icache_wr_type;
wire [31:0] icache_wr_addr;
wire [ 3:0] icache_wr_strb;
wire [127:0]icache_wr_data;
wire        icache_wr_rdy=1'b0;

     //dcache read channel
wire [31:0] data_addr_vrtl;
wire        dcache_addr_ok;
wire        dcache_data_ok;
wire [31:0] dcache_rdata;
wire        dcache_rd_req;
wire [ 2:0] dcache_rd_type;
wire [31:0] dcache_rd_addr;
wire        dcache_rd_rdy;
wire        dcache_ret_valid;
wire        dcache_ret_last;
wire [31:0] dcache_ret_data;

    //dcache write channel
wire        dcache_wr_req;
wire [ 2:0] dcache_wr_type;
wire [31:0] dcache_wr_addr;
wire [ 3:0] dcache_wr_wstrb;
wire[127:0] dcache_wr_data;
wire        dcache_wr_rdy;
wire [ 1:0] datm;


cache icache(
    .clk (aclk),
    .resetn (aresetn),

    .valid (inst_sram_req),
    .op (inst_sram_wr),
    .index (inst_addr_vrtl[11:4]),
    .tag (inst_sram_addr[31:12]),
    .offset (inst_addr_vrtl[3:0]),
    .wstrb (inst_sram_wstrb),
    .wdata (inst_sram_wdata),
    .addr_ok (icache_addr_ok),
    .data_ok (icache_data_ok),
    .rdata(icache_rdata),

    .rd_req (icache_rd_req),
    .rd_type (icache_rd_type),
    .rd_addr (icache_rd_addr),
    .rd_rdy (icache_rd_rdy),
    .ret_valid (icache_ret_valid),
    .ret_last (icache_ret_last),
    .ret_data (icache_ret_data),
    .datm     (2'b01), //icache永远可以缓存

    .wr_req (icache_wr_req),
    .wr_type (icache_wr_type),
    .wr_addr (icache_wr_addr),
    .wr_wstrb (icache_wr_strb),
    .wr_data (icache_wr_data),
    .wr_rdy (icache_wr_rdy)
);

cache dcache(
        //----------cpu interface------
        .clk    (aclk),
        .resetn (aresetn),
        .valid  (data_sram_req),
        .op     (data_sram_wr),
        .index  (data_addr_vrtl[11:4]),
        .tag    (data_sram_addr[31:12]),
        .offset (data_addr_vrtl[3:0]),
        .wstrb  (data_sram_wstrb),
        .wdata  (data_sram_wdata),
        .addr_ok(dcache_addr_ok),
        .data_ok(dcache_data_ok),
        .rdata  (dcache_rdata),
        //--------AXI read interface-------
        .rd_req (dcache_rd_req),
        .rd_type(dcache_rd_type),
        .rd_addr(dcache_rd_addr),

        .rd_rdy   (dcache_rd_rdy),
        .ret_valid(dcache_ret_valid),
        .ret_last (dcache_ret_last),
        .ret_data (dcache_ret_data),
        .datm     (datm),

        //--------AXI write interface------
        .wr_req (dcache_wr_req),
        .wr_type(dcache_wr_type),
        .wr_addr(dcache_wr_addr),
        .wr_wstrb(dcache_wr_wstrb),
        .wr_data(dcache_wr_data),
        .wr_rdy (dcache_wr_rdy)
);

mycpu_core u_mycpu_core(
    .clk            (aclk            ),
    .resetn         (aresetn         ),
    // inst sram interface
    .inst_sram_req  (inst_sram_req  ),
    .inst_sram_wr   (inst_sram_wr   ),
    .inst_sram_wstrb(inst_sram_wstrb),
    .inst_sram_size (inst_sram_size ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .inst_sram_addr_ok(icache_addr_ok),
    .inst_sram_data_ok(icache_data_ok),
    .inst_sram_rdata(icache_rdata),
    // data sram interface
    .data_sram_req  (data_sram_req  ),
    .data_sram_wr   (data_sram_wr   ),
    .data_sram_wstrb(data_sram_wstrb),
    .data_sram_size (data_sram_size ),
    .data_sram_addr (data_sram_addr ),
    .data_sram_wdata(data_sram_wdata),
    .data_sram_addr_ok(dcache_addr_ok),
    .data_sram_data_ok(dcache_data_ok),
    .data_sram_rdata(dcache_rdata),
    // trace debug interface
    .debug_wb_pc      (debug_wb_pc       ),
    .debug_wb_rf_we   (debug_wb_rf_we   ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),

    .inst_addr_vrtl (inst_addr_vrtl),//icache

    .data_addr_vrtl (data_addr_vrtl ),//dcache
    .datm(datm)
);

bridge u_bridge(
    .aclk           (aclk           ),
    .aresetn        (aresetn        ),
    
    // axi interface
    .arid           (arid           ),
    .araddr         (araddr         ),
    .arlen          (arlen          ),
    .arsize         (arsize         ),
    .arburst        (arburst        ),
    .arlock         (arlock         ),
    .arcache        (arcache        ),
    .arprot         (arprot         ),
    .arvalid        (arvalid        ),
    .arready        (arready        ),
    .rid            (rid            ),
    .rdata          (rdata          ),
    .rresp          (rresp          ),
    .rlast          (rlast          ),
    .rvalid         (rvalid         ),
    .rready         (rready         ),
    .awid           (awid           ),
    .awaddr         (awaddr         ),
    .awlen          (awlen          ),
    .awsize         (awsize         ),
    .awburst        (awburst        ),
    .awlock         (awlock         ),
    .awcache        (awcache        ),
    .awprot         (awprot         ),
    .awvalid        (awvalid        ),
    .awready        (awready        ),
    .wid            (wid            ),
    .wdata          (wdata          ),
    .wstrb          (wstrb          ),
    .wlast          (wlast          ),
    .wvalid         (wvalid         ),
    .wready         (wready         ),
    .bid            (bid            ),
    .bresp          (bresp          ),
    .bvalid         (bvalid         ),
    .bready         (bready         ),

    // // inst sram interface
    // .inst_sram_req  (inst_sram_req  ),
    // .inst_sram_wr   (inst_sram_wr   ),
    // .inst_sram_wstrb(inst_sram_wstrb),
    // .inst_sram_size (inst_sram_size ),
    // .inst_sram_addr (inst_sram_addr ),
    // .inst_sram_wdata(inst_sram_wdata),
    // .inst_sram_addr_ok(inst_sram_addr_ok),
    // .inst_sram_data_ok(inst_sram_data_ok),
    // .inst_sram_rdata(inst_sram_rdata),

    .icache_rd_req      (icache_rd_req      ),
    .icache_rd_type     (icache_rd_type     ),
    .icache_rd_addr     (icache_rd_addr     ),
    .icache_rd_rdy      (icache_rd_rdy      ),
    .icache_ret_valid   (icache_ret_valid   ),
    .icache_ret_last    (icache_ret_last    ),
    .icache_ret_data    (icache_ret_data    ),//21
    
    // dcache interface
    .dcache_rd_req      (dcache_rd_req      ),
    .dcache_rd_type     (dcache_rd_type     ),
    .dcache_rd_addr     (dcache_rd_addr     ),
    .dcache_rd_rdy      (dcache_rd_rdy      ),
    .dcache_ret_valid   (dcache_ret_valid   ),
    .dcache_ret_last    (dcache_ret_last    ),
    .dcache_ret_data    (dcache_ret_data    ),

    .dcache_wr_req      (dcache_wr_req      ),
    .dcache_wr_type     (dcache_wr_type     ),
    .dcache_wr_addr     (dcache_wr_addr     ),
    .dcache_wr_wstrb    (dcache_wr_wstrb    ),
    .dcache_wr_data     (dcache_wr_data     ),
    .dcache_wr_rdy      (dcache_wr_rdy      )

);



endmodule
