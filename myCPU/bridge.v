module bridge(
    input  wire        aclk,
    input  wire        aresetn,

    output reg  [ 3:0] arid,
    output reg  [31:0] araddr,
    output reg  [ 7:0] arlen,//记得改成reg
    output reg  [ 2:0] arsize,
    output reg  [ 1:0] arburst,
    output reg  [ 1:0] arlock,
    output reg  [ 3:0] arcache,
    output reg  [ 2:0] arprot,
    output wire        arvalid,
    input  wire        arready,
    input  wire [ 3:0] rid,
    input  wire [31:0] rdata,
    input  wire [ 1:0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    output reg  [ 3:0] awid,
    output reg  [31:0] awaddr,
    output reg  [ 7:0] awlen,
    output reg  [ 2:0] awsize,
    output reg  [ 1:0] awburst,
    output reg  [ 1:0] awlock,
    output reg  [ 3:0] awcache,
    output reg  [ 2:0] awprot,
    output wire        awvalid,
    input  wire        awready,
    output reg  [ 3:0] wid,
    output reg  [31:0] wdata,
    output reg  [ 3:0] wstrb,    
    output reg         wlast,
    output wire        wvalid,
    input  wire        wready,  
    input  wire [ 3:0] bid,
    input  wire [ 1:0] bresp,
    input  wire        bvalid,
    output wire        bready,

    // // inst sram interface
    // input  wire        inst_sram_req,
    // input  wire        inst_sram_wr,
    // input  wire [ 3:0] inst_sram_wstrb,
    // input  wire [ 1:0] inst_sram_size,
    // input  wire [31:0] inst_sram_addr,
    // input  wire [31:0] inst_sram_wdata,
    // output wire        inst_sram_addr_ok,
    // output wire        inst_sram_data_ok,
    // output wire [31:0] inst_sram_rdata,

        // icache rd interface
    input               	icache_rd_req,
    input   	[ 2:0]      icache_rd_type,
    input   	[31:0]      icache_rd_addr,
    output              	icache_rd_rdy,		// icache_addr_ok
    output              	icache_ret_valid,	// icache_data_ok
	output					icache_ret_last,
    output  	[31:0]      icache_ret_data,//21

    // data sram interface
    input  wire        data_sram_req,
    input  wire        data_sram_wr,
    input  wire [ 3:0] data_sram_wstrb,
    input  wire [ 1:0] data_sram_size,
    input  wire [31:0] data_sram_addr,
    input  wire [31:0] data_sram_wdata,
    output wire        data_sram_addr_ok,
    output wire        data_sram_data_ok,
    output wire [31:0] data_sram_rdata
);

reg [4:0] ar_current_state;//读请求状态机
reg [4:0] ar_next_state;
reg [4:0] r_current_state;//读数据状态机
reg [4:0] r_next_state;
reg [4:0] w_current_state;//写请求和写数据状态机
reg [4:0] w_next_state;
reg [4:0] b_current_state;//写相应状态机
reg [4:0] b_next_state;

reg [1:0] ar_resp_count;
reg [1:0] aw_resp_count;
reg [1:0] wd_resp_count;

reg [31:0] buf_rdata [1:0];//数据寄存器，0表示指令SRAM寄存器，1表示数据SRAM寄存器

wire read_block;//当检测到读后写相关时，阻塞读请求，防止读到旧数据

reg [3:0] rid_r;

localparam IDLE = 5'b1; //通道没有正在进行的事务，正在等待启动新事务的条件

localparam AR_REQ_START = 3'b010, //状态1：开始发送读地址
           AR_REQ_END   = 3'b100; //状态2：读地址发送完成

always @(posedge aclk) begin
    if (!aresetn) begin
        ar_current_state <= IDLE;
    end
    else begin
        ar_current_state <= ar_next_state;
    end
end

always @(*) begin
    case (ar_current_state)
        IDLE:begin
				if(~aresetn | read_block)begin
					ar_next_state = IDLE;
				end
				else if(data_sram_req & ~data_sram_wr | icache_rd_req)begin//21
					ar_next_state = AR_REQ_START;
				end
				else begin
					ar_next_state = IDLE;
				end
			end
        AR_REQ_START: begin
            if (arready & arvalid) begin
                ar_next_state = AR_REQ_END;
            end
            else begin
                ar_next_state = AR_REQ_START;
            end
        end
        AR_REQ_END: begin
            ar_next_state = IDLE;
        end
        default: begin
            ar_next_state = IDLE;
        end
    endcase
end

    localparam  R_DATA_START   	= 4'b0010,
				R_DATA_MID      = 4'b0100,
				R_DATA_END		= 4'b1000;//21

always @(posedge aclk) begin
    if(~aresetn) begin
        r_current_state <= IDLE;
    end
    else begin
        r_current_state <= r_next_state;
    end
end

always @(*) begin
    case(r_current_state)
        IDLE:begin
            if(aresetn & arvalid & arready | (|ar_resp_count))begin
                r_next_state = R_DATA_START;
            end
            else begin
                r_next_state =IDLE;
            end
        end
        R_DATA_START:begin
				if(rvalid & rready & rlast) 	// 传输完毕
					r_next_state = R_DATA_END;
				else if(rvalid & rready)		// 传输中
					r_next_state = R_DATA_MID;
				else
					r_next_state = R_DATA_START;
		end
		R_DATA_MID:begin
				if(rvalid & rready & rlast) 	// 传输完毕
					r_next_state = R_DATA_END;
				else if(rvalid & rready)		// 传输中
					r_next_state = R_DATA_MID;
				else
					r_next_state = R_DATA_START;
		end//21
        R_DATA_END:begin
            r_next_state =IDLE;
        end
            default:begin
                r_next_state =IDLE;
        end
    endcase
end

localparam W_REQ_START = 5'b00010, //状态1：开始发送地址和数据
           W_ADDR_RESP = 5'b00100, //状态2：地址已发送，等待数据
           W_DATA_RESP = 5'b01000, //状态3：数据已发送，等待地址
           W_REQ_END   = 5'b10000; //状态4：地址和数据都发送完成

always @(posedge aclk)begin
    if(~aresetn)begin
        w_current_state <= IDLE;
    end
    else begin
        w_current_state <= w_next_state;
    end
end

always @(*)begin
    case(w_current_state)
        IDLE:begin
            if(~aresetn)begin
                w_next_state = IDLE;
            end
            else if(data_sram_wr)begin
                w_next_state = W_REQ_START;
            end
            else begin
                w_next_state = IDLE;
            end
        end
        W_REQ_START:begin
            if(awvalid & awready & wvalid &wready | (|aw_resp_count) & (|wd_resp_count))begin
                w_next_state = W_REQ_END;
            end
            else if(awvalid & awready | (|aw_resp_count))begin
                w_next_state = W_ADDR_RESP;
            end
            else if(wvalid & wready | (|wd_resp_count))begin
                w_next_state = W_DATA_RESP;
            end
            else begin
                w_next_state = W_REQ_START;
            end
        end
        W_ADDR_RESP:begin
            if(wvalid & wready)begin
                w_next_state = W_REQ_END;
            end
            else begin
                w_next_state = W_ADDR_RESP;
            end
        end
        W_DATA_RESP:begin
            if(awvalid & awready)begin
                w_next_state = W_REQ_END;
            end
            else begin
                w_next_state = W_DATA_RESP;
            end
        end
        W_REQ_END:begin
            if(bvalid & bready)begin
                w_next_state = IDLE;
            end
            else begin
                w_next_state = W_REQ_END;
            end
        end
        default:begin
            w_next_state = IDLE;
        end
    endcase
end

localparam B_START = 3'b010, //状态1：等待写响应
           B_END   = 3'b100; //状态2：响应接收完成

always @(posedge aclk) begin
    if(~aresetn)
        b_current_state <= IDLE;  
    else 
        b_current_state <= b_next_state; 
end

always @(*)begin
    case(b_current_state)
        IDLE:begin
            if(aresetn & bready)begin
                b_next_state = B_START;
            end
            else begin
                b_next_state = IDLE;
            end
        end
        B_START:begin
            if(bready & bvalid)begin
                b_next_state = B_END;
            end
            else begin
                b_next_state = B_START;
            end
        end
        B_END:begin
            b_next_state = IDLE;
        end
        default:begin
            b_next_state = IDLE;
        end
    endcase
end

assign arvalid = (ar_current_state == AR_REQ_START) ? 1'b1 : 1'b0;
always @(posedge aclk)begin
    if(~aresetn)begin
        arid <= 4'b0;
        araddr <= 32'b0;
        arlen <= 8'b0;
        arsize <= 3'b010;
        arburst <= 2'b01;
        arlock <= 2'b0;
        arcache <=4'b0;
        arprot <= 3'b0;
    end
    else if(ar_current_state[0])begin
        arid <= {3'b0, data_sram_req & !data_sram_wr};//0表示指令sram，1表示数据sram
        araddr <= data_sram_req & !data_sram_wr ? data_sram_addr : icache_rd_addr;//21
        arsize <= data_sram_req & !data_sram_wr ? {1'b0,data_sram_size} : 3'b010;//21
        arlen  <= data_sram_req & ~data_sram_wr? 8'b0 : 8'b11;//21
        arburst <= 2'b01;
        arlock <= 2'b0;
        arcache <=4'b0;
        arprot <= 3'b0;
    end
end

always @(posedge aclk) begin
    if(~aresetn)begin
        ar_resp_count <= 2'b0;
    end
    else if(arvalid & arready & rvalid & rready & rlast)begin//21
        ar_resp_count <= ar_resp_count;//发生在同一周期的处理
    end
    else if(arvalid & arready)begin
        ar_resp_count <= ar_resp_count + 1'b1;
    end
    else if(rvalid & rready & rlast)begin//21
        ar_resp_count <= ar_resp_count - 1'b1;
    end
end
assign rready = r_current_state[1] || r_current_state[2];	// R_DATA_START | R_DATA_MID //21

assign read_block = (araddr == awaddr) & (|w_current_state[4:1]) & ~b_current_state[2];
always @(posedge aclk)begin
    if(~aresetn)begin
        buf_rdata[0] <= 32'b0;
        buf_rdata[1] <= 32'b0;
    end
    else if(rvalid & rready)begin
        buf_rdata[rid] <= rdata;
    end
end
always @(posedge aclk)begin
    if(~aresetn)begin
        rid_r <= 4'b0;
    end
    else if(rvalid & rready)begin
        rid_r <= rid;
    end
end
assign data_sram_rdata = buf_rdata[1];
assign data_sram_addr_ok = arid[0] & arvalid & arready | wid[0] &awvalid &awready;
assign data_sram_data_ok = rid_r[0] & r_current_state[3] | bid[0] & bvalid &bready;//21
// assign inst_sram_rdata = buf_rdata[0];
// assign inst_sram_addr_ok = ~arid[0] & arvalid & arready;
// assign inst_sram_data_ok = ~rid_r[0] & r_current_state[2] | ~bid[0] & bvalid & bready;

assign icache_ret_data = buf_rdata[0];
assign icache_ret_valid = ~rid_r[0] & (|r_current_state[3:2]); // rvalid & rready的下一拍
assign icache_rd_rdy = ~arid[0] & arvalid & arready;
assign icache_ret_last = ~rid_r[0] & r_current_state[3];//21

assign awvalid = w_current_state == W_REQ_START | w_current_state == W_DATA_RESP ;
always @(posedge aclk)begin
    if(~aresetn)begin
        awid <= 4'b1;
        awaddr <=32'b0;
        awlen <=8'b0;
        awsize <= 3'b0;
        awburst <= 2'b01;
        awlock <=2'b0;
        awcache <= 4'b0;
        awprot <= 3'b0;
    end
    else if(w_current_state[0])begin
        awaddr <= data_sram_wr ? data_sram_addr : icache_rd_addr;//21
        awsize <= data_sram_wr ? {1'b0,data_sram_size} : 3'b010;//21
        awid <= 4'b1;
        awlen <=8'b0;
        awburst <= 2'b01;
        awlock <=2'b0;
        awcache <= 4'b0;
        awprot <= 3'b0;
    end
end

assign wvalid = w_current_state[1] | w_current_state[2];
always @(posedge aclk)begin
    if(~aresetn)begin
        wid <= 4'b1;
        wdata <= 32'b0;
        wstrb <= 4'b0;
        wlast <= 1'b1;
    end
    else if(w_current_state[0])begin
        wstrb <= data_sram_wstrb;
        wdata <= data_sram_wdata;
        wid <= 4'b1;
        wlast <= 1'b1;
    end
end

assign bready = w_current_state[4];
always @(posedge aclk)begin
    if(~aresetn)begin
        aw_resp_count <= 2'b0;
    end
    else if(awvalid & awready & bvalid & bready)begin
        aw_resp_count <= aw_resp_count;
    end
    else if(awvalid & awready)begin
        aw_resp_count <= aw_resp_count + 1'b1;
    end
    else if(bvalid & bready)begin
        aw_resp_count <= aw_resp_count -1'b1;
    end
end//
always @(posedge aclk)begin
    if(~aresetn)begin
        wd_resp_count <= 2'b0;
    end
    else if(wvalid & wready & bvalid & bready)begin
        wd_resp_count <= wd_resp_count;
    end
    else if(wvalid & wready)begin
        wd_resp_count <= wd_resp_count + 1'b1;
    end
    else if(bvalid & bready)begin
        wd_resp_count <= wd_resp_count - 1'b1;
    end
end//
endmodule

