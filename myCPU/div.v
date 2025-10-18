module div(
    input   wire    div_clk,
    input   wire    resetn,
    input   wire    div,
    input   wire    div_signed,
    input   wire [31:0] x,
    input   wire [31:0] y,
    output  wire [31:0] q,
    output  wire [31:0] r,
    output  wire    complete
);

    // count: 0 - 32。0为初始化周期，1-32为32次迭代周期。
    reg     [5:0]     count; 
    reg     [64:0]    Q_R_Reg; 

    wire    [31:0]    abs_x;
    wire    [31:0]    abs_y;
    wire              sign_q; 
    wire              sign_r;

    wire    [32:0]    y_extended; 
    
    wire    [64:0]    shifted_Q_R;
    wire    [32:0]    shifted_R;
    wire    [64:0]    initial_Q_R;

    wire    [32:0]    try_r_sub;
    wire              sub_borrow;
    wire    [32:0]    next_r_val;
    
    assign abs_x = div_signed ? (x[31] ? ~x + 1'b1 : x) : x;
    assign abs_y = div_signed ? (y[31] ? ~y + 1'b1 : y) : y;
    assign sign_q = x[31] ^ y[31];  
    assign sign_r = x[31];
    
    assign y_extended = {1'b0, abs_y}; 
    
    assign initial_Q_R = {33'b0, abs_x};

    assign shifted_Q_R = Q_R_Reg << 1;
    assign shifted_R   = shifted_Q_R[64:32];

    assign try_r_sub = shifted_R - y_extended; 
    
    assign sub_borrow = try_r_sub[32]; 
    
    assign next_r_val = sub_borrow ? shifted_R : try_r_sub;

    assign complete = ~div || count == 6'b100001;

    always@(posedge div_clk) begin
        if (~resetn) begin
            count <= 6'b0;
        end
        else if (div) begin
            if (complete)
                count <= 6'b0; // 完成后复位计数器
            else
                count <= count + 1'b1;
        end
        else begin
            count <= 6'b0;
        end
    end

    always@(posedge div_clk) begin
        if (~resetn) begin
            Q_R_Reg <= 65'b0;
        end
        else if (div) begin
            if (count == 6'b0) begin 
                Q_R_Reg <= initial_Q_R;
            end
            else if (count >= 1 && count <= 32) begin 
                Q_R_Reg <= { 
                    next_r_val,
                    shifted_Q_R[31:1],      //左移
                    ~sub_borrow         //上商
                };
            end
        end
    end

    assign q = div_signed ? (sign_q ? ~Q_R_Reg[31:0] + 1'b1 : Q_R_Reg[31:0]) : Q_R_Reg[31:0];3
    assign r = div_signed ? (sign_r ? ~Q_R_Reg[63:32] + 1'b1 : Q_R_Reg[63:32]) : Q_R_Reg[63:32];
    
endmodule