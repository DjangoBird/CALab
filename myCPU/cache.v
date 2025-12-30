// op
`define READ  1'b0
`define WRITE 1'b1

// rd_type
`define READ_BYTE     3'b000 //1字节
`define READ_HALFWORD 3'b001 //2字节
`define READ_WORD     3'b010 //4字节
`define READ_BLOCK    3'b100 //16字节，Cache块大小

// wr_type
`define WRITE_BYTE     3'b000 //1字节
`define WRITE_HALFWORD 3'b001 //2字节
`define WRITE_WORD     3'b010 //4字节
`define WRITE_BLOCK    3'b100 //16字节，Cache块大小

// 主状态机
`define IDLE    5'b00001
`define LOOKUP  5'b00010
`define MISS    5'b00100
`define REPLACE 5'b01000
`define REFILL  5'b10000

// Write Buffer 状态机
`define WRITEBUF_IDLE  2'b01
`define WRITEBUF_WRITE 2'b10

module cache(
    input wire        clk,
    input wire        resetn,

    /* with CPU, Page 246 */
    input wire        valid,  
    input wire        op,     // write or read
    input wire [ 7:0] index,  // vaddr[11:4]
    input wire [19:0] tag,    // paddr[31:12]
    input wire [ 3:0] offset, // vaddr[3:0]
    input wire [ 3:0] wstrb,  
    input wire [31:0] wdata, 
    
    output wire        addr_ok, 
    output wire        data_ok, 
    output wire [31:0] rdata,   
    input  wire [ 1:0] datm,  //cache可缓存类型

    /* with AXI, Page 248 */
    // read ports
    output wire        rd_req,   
    output wire [ 2:0] rd_type,  // 读Cache块，3'b100
    output wire [31:0] rd_addr,  
    input  wire        rd_rdy,  
    input  wire        ret_valid,
    input  wire        ret_last,
    input  wire [31:0] ret_data, 

    // write ports
    output wire         wr_req,   
    output wire [ 2:0]  wr_type,  // 写Cache块，3'b100
    output wire [31:0]  wr_addr,  
    output wire [ 3:0]  wr_wstrb, 
    output wire [127:0] wr_data, 
    input  wire         wr_rdy    
);

// P243~P244: Cache 表的组织管理
// 例化tagv RAM，共2路
wire [ 7:0] tagv_addr;
wire [20:0] tagv_wdata;
wire [20:0] tagv_w0_rdata, tagv_w1_rdata;
wire        tagv_w0_en, tagv_w1_en;
wire        tagv_w0_we, tagv_w1_we;

wire uncache_flag;
reg [ 1:0] datm_r;

tagv_ram tagv_way0(
    .addra(tagv_addr),
    .clka(clk),
    .dina(tagv_wdata),
    .douta(tagv_w0_rdata),
    .ena(tagv_w0_en),
    .wea(tagv_w0_we & !uncache_flag)
);
tagv_ram tagv_way1(
    .addra(tagv_addr),
    .clka(clk),
    .dina(tagv_wdata),
    .douta(tagv_w1_rdata),
    .ena(tagv_w1_en),
    .wea(tagv_w1_we & !uncache_flag)
);

// 例化data bank RAM，共2路，每路4个bank
wire [ 7:0] data_addr;
wire [31:0] data_wdata;
wire [31:0] data_w0_b0_rdata, data_w0_b1_rdata, 
            data_w0_b2_rdata, data_w0_b3_rdata, 
            data_w1_b0_rdata, data_w1_b1_rdata, 
            data_w1_b2_rdata, data_w1_b3_rdata;
wire        data_w0_b0_en, data_w0_b1_en, 
            data_w0_b2_en, data_w0_b3_en, 
            data_w1_b0_en, data_w1_b1_en, 
            data_w1_b2_en, data_w1_b3_en;
wire [ 3:0] data_w0_b0_we, data_w0_b1_we, 
            data_w0_b2_we, data_w0_b3_we, 
            data_w1_b0_we, data_w1_b1_we, 
            data_w1_b2_we, data_w1_b3_we;

data_bank_ram data_way0_bank0(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w0_b0_rdata),
    .ena(data_w0_b0_en),
    .wea(data_w0_b0_we & {4{~uncache_flag}})
);
data_bank_ram data_way0_bank1(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w0_b1_rdata),
    .ena(data_w0_b1_en),
    .wea(data_w0_b1_we & {4{~uncache_flag}})
);
data_bank_ram data_way0_bank2(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w0_b2_rdata),
    .ena(data_w0_b2_en),
    .wea(data_w0_b2_we & {4{~uncache_flag}})
);
data_bank_ram data_way0_bank3(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w0_b3_rdata),
    .ena(data_w0_b3_en),
    .wea(data_w0_b3_we & {4{~uncache_flag}})
);
data_bank_ram data_way1_bank0(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w1_b0_rdata),
    .ena(data_w1_b0_en),
    .wea(data_w1_b0_we & {4{~uncache_flag}})
);
data_bank_ram data_way1_bank1(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w1_b1_rdata),
    .ena(data_w1_b1_en),
    .wea(data_w1_b1_we & {4{~uncache_flag}})
);
data_bank_ram data_way1_bank2(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w1_b2_rdata),
    .ena(data_w1_b2_en),
    .wea(data_w1_b2_we & {4{~uncache_flag}})
);
data_bank_ram data_way1_bank3(
    .addra(data_addr),
    .clka(clk),
    .dina(data_wdata),
    .douta(data_w1_b3_rdata),
    .ena(data_w1_b3_en),
    .wea(data_w1_b3_we & {4{~uncache_flag}})
);

// D表
reg [255:0] dirty_way0;
reg [255:0] dirty_way1;

/* ---------------------------------------------------------- */

// P243: 对Cache模块的四种访问
wire lookup;  //判断是否命中
wire hitwrite;//命中的写操作会进入 Write Buffer，随后将数据写入命中 Cache 行的对应位置。
wire replace; //给refill数据空出位置而读取一个Cache行
wire refill;  //从内存读取数据到Cache

// 主状态机
reg [4:0] current_state;
reg [4:0] next_state;

// Write Buffer 状态机
reg [1:0] writebuf_current_state;
reg [1:0] writebuf_next_state;

/* ---------------------------------------------------------- */

// P248~P250：Cache模块内其他数据通路
// request buffer
reg        reg_op;
reg [ 7:0] reg_index;
reg [19:0] reg_tag;
reg [ 3:0] reg_offset;
reg [ 3:0] reg_wstrb;
reg [31:0] reg_wdata;

// 锁存输入
always @(posedge clk)begin
    if(~resetn)begin
        reg_op <= 1'b0;
        reg_index <= 8'b0;
        reg_tag <= 20'b0;
        reg_offset <= 4'b0;
        reg_wstrb <= 4'b0;
        reg_wdata <= 32'b0;
    end
    else if(lookup)begin
        reg_op <= op;
        reg_index <= index;
        reg_tag <= tag;
        reg_offset <= offset;
        reg_wstrb <= wstrb;
        reg_wdata <= wdata;
    end
end

// tag compare
wire        way0_v, way1_v;
wire [19:0] way0_tag, way1_tag;
wire        way0_hit, way1_hit;
wire        cache_hit;
// P249
assign {way0_tag, way0_v} = tagv_w0_rdata;
assign {way1_tag, way1_v} = tagv_w1_rdata;
assign way0_hit = way0_v && (way0_tag == reg_tag);
assign way1_hit = way1_v && (way1_tag == reg_tag);// valid 且 tag 匹配
assign cache_hit = (way0_hit || way1_hit) && (datm_r == 2'b01);

// data select
wire [127:0] way0_data, way1_data;// 整个Cache块Data
wire [ 31:0] way0_load_word, way1_load_word;// 具体访问的bank
wire [ 31:0] load_res;// 给到CPU的rdata
// P249
assign way0_data = {data_w0_b3_rdata, data_w0_b2_rdata, data_w0_b1_rdata, data_w0_b0_rdata};
assign way1_data = {data_w1_b3_rdata, data_w1_b2_rdata, data_w1_b1_rdata, data_w1_b0_rdata};
assign way0_load_word = way0_data[reg_offset[3:2]*32 +: 32];
assign way1_load_word = way1_data[reg_offset[3:2]*32 +: 32];
// signal[start +: width]   // 从 start 位开始，向上取 width 位（递增方向）
// signal[start -: width]   // 从 start 位开始，向下取 width 位（递减方向）
assign load_res = {32{way0_hit}} & way0_load_word |// way0命中
                  {32{way1_hit}} & way1_load_word |// way1命中
                  {32{refill}} & ret_data;// 访存返回

// miss buffer
reg [ 1:0] refill_word_counter;// 记录从AXI总线返回了几个32位数据，判断是否是refill的bank

always @(posedge clk)begin
    if(~resetn)
        refill_word_counter <= 2'b0;
    else if(refill && ret_valid && !uncache_flag)
        refill_word_counter <= refill_word_counter + 1'b1;
end

// LSFR伪随机数算法
reg [2:0] lfsr;
always @(posedge clk)begin
    if(~resetn)begin
        lfsr <= 3'b111;
    end
    else if(ret_valid == 1 & ret_last == 1)begin// 最后一个32位数据从AXI返回 
        lfsr <= {lfsr[0], lfsr[2]^lfsr[0], lfsr[1]};
    end
end
/*步骤	lfsr 值	replace_way = lfsr[0]
0（初始）	          111 1
1	{1, 1⊕1=0, 1} → 101	1
2	{1, 1⊕1=0, 0} → 100	0
3	{0, 1⊕0=1, 0} → 010	0
4	{0, 0⊕0=0, 1} → 001	1
5	{1, 0⊕1=1, 0} → 110	0
6	{0, 1⊕0=1, 1} → 011	1
7	{1, 0⊕1=1, 1} → 111	1 ← 回到初始值，周期=7*/

// replace Cache
wire         replace_way;
wire [127:0] replace_data;

assign replace_way = lfsr[0];
assign replace_data = replace_way ? way1_data : way0_data;

// write buffer
reg        write_way; 
reg [ 1:0] write_bank;
reg [ 7:0] write_index; 
reg [ 3:0] write_strb; 
reg [31:0] write_data;

// get from request buffer
always @(posedge clk)begin
    if(~resetn)begin
        write_way <= 1'b0;
        write_bank <= 2'b0;
        write_index <= 8'b0;
        write_strb <= 4'b0;
        write_data <= 32'b0;
    end
    else if((current_state == `LOOKUP) && (reg_op == `WRITE) && cache_hit)begin // write hit
        write_way <= way1_hit;
        write_bank <= reg_offset[3:2];
        write_index <= reg_index;
        write_strb <= reg_wstrb;
        write_data <= reg_wdata;
    end
end

// 判断替换Cache是否为脏数据，决定是否拉高wr_req写回内存
wire   replace_dirty;
assign replace_dirty = (replace_way == 1'b0) && dirty_way0[reg_index] && way0_v 
                    || (replace_way == 1'b1) && dirty_way1[reg_index] && way1_v;
                          
// dirty 表
always @(posedge clk)begin
    if(~resetn)begin
        dirty_way0 <= 256'b0;
        dirty_way1 <= 256'b0;
    end
    // 写命中时拉高dirty位，Cache和内存数据不同
    else if(hitwrite && !uncache_flag)begin
        if(way0_hit)
            dirty_way0[write_index] <= 1'b1;
        else if(way1_hit)
            dirty_way1[write_index] <= 1'b1;
    end
    // refill时取消dirty位，Cache和内存数据相同
    else if(refill && !uncache_flag)begin
        if(replace_way == 1'b0)
            dirty_way0[reg_index] <= 1'b0;
        else if(replace_way == 1'b1)
            dirty_way1[reg_index] <= 1'b0;
    end
end

// conflicts
wire conflict_case1 = (current_state == `LOOKUP)            // 主状态机处于 LOOKUP 状态
                   && (reg_op == `WRITE) && hitwrite        // 当前是 store 操作
                   && valid && (op == `READ)                // 一个新的读 cache 请求
                   && {tag, index, offset[3:2]} == {reg_tag, reg_index, offset[3:2]}; // 地址相等

wire conflict_case2 = (writebuf_current_state == `WRITEBUF_WRITE)  // writebuff 状态机处于 WRITE 状态
                   && valid && (op == `READ)                       // 一个新的读Load类 cache 请求
                   && (offset[3:2] == write_bank);                 // 读写同一个 bank



// 主状态机
//1.
always @(posedge clk)begin
    if(~resetn)
        current_state <= `IDLE;
    else 
        current_state <= next_state;
end


always @(posedge clk)begin
    if(!resetn)
        datm_r <= 2'b01;
    else if(valid)
        datm_r <= datm;
    else if(data_ok)
        datm_r <= 2'b01;
end

assign uncache_flag = (datm_r == 2'b00);

//2.
always @(*)begin
    case(current_state)
    `IDLE:begin
        if(valid && (~conflict_case1) && (~conflict_case2))
            next_state = `LOOKUP;
        else
            next_state = `IDLE;
    end
    `LOOKUP:begin
        if(~cache_hit || uncache_flag || ((datm == 2'b00) && valid))
            next_state = `MISS;
        else if(valid && (~conflict_case1) && (~conflict_case2))
            next_state = `LOOKUP;
        else
            next_state = `IDLE;
    end
    `MISS:begin
        if(uncache_flag && reg_op == `WRITE && wr_rdy)
            next_state = `IDLE;
        else if(!uncache_flag && replace_dirty && wr_rdy)
            next_state = `REPLACE;
        else if(!uncache_flag && !replace_dirty || uncache_flag && reg_op == `READ)
            next_state = `REPLACE;
        else
            next_state = `MISS;
    end
    `REPLACE:begin
        if(rd_rdy == 1)
            next_state = `REFILL;
        else
            next_state = `REPLACE;
    end
    `REFILL:begin
        if(ret_valid == 1 && ret_last == 1)
            next_state = `IDLE;
        else
            next_state = `REFILL;
    end
    endcase
end

// Write Buffer 状态机
//1.
always @(posedge clk)begin
    if(~resetn)
        writebuf_current_state <= `WRITEBUF_IDLE;
    else
        writebuf_current_state <= writebuf_next_state;
end

//2.
always @(*) begin
    case(writebuf_current_state)
    `WRITEBUF_IDLE:begin
        if((current_state == `LOOKUP) && (reg_op == `WRITE) && cache_hit)// write hit
            writebuf_next_state = `WRITEBUF_WRITE;
        else
            writebuf_next_state = `WRITEBUF_IDLE;
    end
    `WRITEBUF_WRITE:begin
        if((current_state == `LOOKUP) && (reg_op == `WRITE) && cache_hit)
            writebuf_next_state = `WRITEBUF_WRITE;
        else
            writebuf_next_state = `WRITEBUF_IDLE;
    end
    endcase
end

assign lookup = (current_state == `IDLE) && valid && (~conflict_case1) && (~conflict_case2) ||
                (current_state == `LOOKUP) && valid && cache_hit && (~conflict_case1) && (~conflict_case2);
assign hitwrite = (writebuf_current_state == `WRITEBUF_WRITE);
assign replace = (current_state == `MISS) || (current_state == `REPLACE);
assign refill = (current_state == `REFILL);


// refill 数据的赋值
wire [31:0] refill_word;
wire [31:0] mixed_word;
// 合并输入的wdata和访存返回的ret_data
assign mixed_word = {{reg_wstrb[3]? reg_wdata[31:24] : ret_data[31:24]},
                     {reg_wstrb[2]? reg_wdata[23:16] : ret_data[23:16]},
                     {reg_wstrb[1]? reg_wdata[15: 8] : ret_data[15: 8]},
                     {reg_wstrb[0]? reg_wdata[ 7: 0] : ret_data[ 7: 0]}};
assign refill_word = ((refill_word_counter == reg_offset[3:2]) && (reg_op == `WRITE))? mixed_word : //读缺失时，refill是原有数据与访存数据的mix
                                                                                       ret_data;    //写缺失时，refill是访存数据

// tagv ram input
// P250
assign tagv_wdata = {reg_tag, 1'b1}; // refill 的 tag 阶段来自 request buffer
assign tagv_addr  = {8{lookup}} & index |              // lookup 的 addr 时来自模块输入端口 
                    {8{replace || refill}} & reg_index;// replace 和 refill 的 addr 来自 request buffer

// P253
assign tagv_w0_en = lookup || ((replace || refill) && (replace_way == 1'b0));
assign tagv_w1_en = lookup || ((replace || refill) && (replace_way == 1'b1));// lookup时片选2路，replace和refill时片选替换那一路
assign tagv_w0_we = refill && (replace_way == 1'b0) && ret_valid && (refill_word_counter == reg_offset[3:2]);
assign tagv_w1_we = refill && (replace_way == 1'b1) && ret_valid && (refill_word_counter == reg_offset[3:2]);// refill时写使能替换的那一路

// bank ram input
// P250
assign data_wdata = refill   ? refill_word :
                    hitwrite ? write_data  : 32'b0;
// 缺失后refill或store命中时写入data_bank

assign data_addr  = (replace || refill) ? reg_index   :        // replace的addr来自request buffer
                    (hitwrite           ? write_index :        // writehit的addr来自write buffer
                    (lookup             ? index       : 8'b0));// lookup的addr来自CPU
// P253
assign data_w0_b0_en = lookup && (offset[3:2] == 2'b00) || //lookup片选2路，请求所在bank
                       hitwrite && (write_way == 1'b0)  || //write buffer记录那路
                       (replace || refill) && (replace_way == 1'b0); //replace和refill片选替换那一路所有bank
assign data_w0_b1_en = lookup && (offset[3:2] == 2'b01) ||
                       hitwrite && (write_way == 1'b0)  ||
                       (replace || refill) && (replace_way == 1'b0);
assign data_w0_b2_en = lookup && (offset[3:2] == 2'b10) ||
                       hitwrite && (write_way == 1'b0)  ||
                       (replace || refill) && (replace_way == 1'b0);
assign data_w0_b3_en = lookup && (offset[3:2] == 2'b11) ||
                       hitwrite && (write_way == 1'b0)  ||
                       (replace || refill) && (replace_way == 1'b0);
assign data_w1_b0_en = lookup && (offset[3:2] == 2'b00) ||
                       hitwrite && (write_way == 1'b1)  ||
                       (replace || refill) && (replace_way == 1'b1);
assign data_w1_b1_en = lookup && (offset[3:2] == 2'b01) ||
                       hitwrite && (write_way == 1'b1)  ||
                       (replace || refill) && (replace_way == 1'b1);
assign data_w1_b2_en = lookup && (offset[3:2] == 2'b10) ||
                       hitwrite && (write_way == 1'b1)  ||
                       (replace || refill) && (replace_way == 1'b1);
assign data_w1_b3_en = lookup && (offset[3:2] == 2'b11) ||
                       hitwrite && (write_way == 1'b1)  ||
                       (replace || refill) && (replace_way == 1'b1);

// data_bank_ram要开字节写使能
assign data_w0_b0_we = {4{hitwrite && (write_way == 1'b0) && (write_bank == 2'b00)}} & write_strb |//write命中按strb写入
                       {4{refill && (replace_way == 1'b0) && (refill_word_counter == 2'b00) && ret_valid}} & {4'b1111};//refill写入整个Cache块
assign data_w0_b1_we = {4{hitwrite && (write_way == 1'b0) && (write_bank == 2'b01)}} & write_strb |
                       {4{refill && (replace_way == 1'b0) && (refill_word_counter == 2'b01) && ret_valid}} & {4'b1111};
assign data_w0_b2_we = {4{hitwrite && (write_way == 1'b0) && (write_bank == 2'b10)}} & write_strb |
                       {4{refill && (replace_way == 1'b0) && (refill_word_counter == 2'b10) && ret_valid}} & {4'b1111};
assign data_w0_b3_we = {4{hitwrite && (write_way == 1'b0) && (write_bank == 2'b11)}} & write_strb |
                       {4{refill && (replace_way == 1'b0) && (refill_word_counter == 2'b11) && ret_valid}} & {4'b1111};
assign data_w1_b0_we = {4{hitwrite && (write_way == 1'b1) && (write_bank == 2'b00)}} & write_strb |
                       {4{refill && (replace_way == 1'b1) && (refill_word_counter == 2'b00) && ret_valid}} & {4'b1111};
assign data_w1_b1_we = {4{hitwrite && (write_way == 1'b1) && (write_bank == 2'b01)}} & write_strb |
                       {4{refill && (replace_way == 1'b1) && (refill_word_counter == 2'b01) && ret_valid}} & {4'b1111};
assign data_w1_b2_we = {4{hitwrite && (write_way == 1'b1) && (write_bank == 2'b10)}} & write_strb |
                       {4{refill && (replace_way == 1'b1) && (refill_word_counter == 2'b10) && ret_valid}} & {4'b1111};
assign data_w1_b3_we = {4{hitwrite && (write_way == 1'b1) && (write_bank == 2'b11)}} & write_strb |
                       {4{refill && (replace_way == 1'b1) && (refill_word_counter == 2'b11) && ret_valid}} & {4'b1111};

// P254
/* with CPU */
assign addr_ok = (current_state == `IDLE) ||
                 (current_state == `LOOKUP) && (cache_hit || datm == 2'b0) &&
                 valid && (~conflict_case1) && (~conflict_case2);
assign data_ok = (current_state == `LOOKUP) && cache_hit     && !uncache_flag || 
                 (current_state == `MISS)   && uncache_flag  && wr_rdy    && (reg_op == `WRITE) || 
                 (current_state == `REFILL) && uncache_flag  && ret_valid && ret_last ||
                 (current_state == `REFILL) && !uncache_flag && ret_valid && (refill_word_counter == reg_offset[3:2]);
assign rdata   = load_res;

/* with AXI */
assign rd_req = (current_state == `REPLACE);
assign rd_type = {3{!uncache_flag}} & `READ_BLOCK |
                 {3{ uncache_flag}} & `READ_WORD   ; // 后续考虑 ucached 
assign rd_addr = {32{!uncache_flag}} & {reg_tag, reg_index, 4'b0000} |
                 {32{ uncache_flag}} & {reg_tag, reg_index, reg_offset};


assign wr_req = (current_state == `MISS) && replace_dirty && !uncache_flag ||
                (current_state == `MISS) && (reg_op == `WRITE) && uncache_flag;
assign wr_type = {3{!uncache_flag && reg_op}} & `WRITE_BLOCK | 
                 {3{ uncache_flag}} & `WRITE_WORD; // 后续考虑 ucached
assign wr_addr = {32{ uncache_flag}} & {reg_tag, reg_index, reg_offset} |
                 {32{!uncache_flag}} & (
                 {32{replace_way == 1'b0}} & {way0_tag, reg_index, 4'b0000} |
                 {32{replace_way == 1'b1}} & {way1_tag, reg_index, 4'b0000}
                 );
assign wr_wstrb = {4{ uncache_flag}} & reg_wstrb |
                  {4{!uncache_flag}} & 4'b1111; // 后续考虑 ucached
assign wr_data = {128{ uncache_flag}} & reg_wdata |
                 {128{!uncache_flag}} & replace_data;

endmodule