module Adder (
    input   [63:0] in1,
    input   [63:0] in2,
    input   [63:0] in3,
    output  [63:0] C,
    output  [63:0] S
);
    assign S  = in1 ^ in2 ^ in3;
    assign C = {(in1 & in2 | in1 & in3 | in2 & in3), 1'b0} ;
endmodule

// 流程: 
//       1. (布斯编码) 根据乘数B的位，生成部分积的选择信号。该算法将32个部分积减少到17个。
//       2. (部分积生成) 根据选择信号，生成17个未对齐的部分积。
//       3. (华莱士树) 通过多级并行的3-to-2压缩器(CSA)，将17个对齐后的部分积快速压缩成2个操作数。
//       4. (最终加法) 使用一个常规的进位传播加法器(CPA)，将最后2个操作数相加，得到最终结果。
//
module mul (
    input          mul_clk,
    input          resetn,
    input          mul_signed,
    input   [31:0] A,
    input   [31:0] B,
    output  [63:0] result
);

    wire [63:0] A_add;      // +A (符号扩展到64位)
    wire [63:0] A_sub;      // -A (A的补码)
    wire [63:0] A2_add;     // +2A (A左移一位)
    wire [63:0] A2_sub;     // -2A (2A的补码)

    assign A_add  = {{32{A[31] & mul_signed}}, A};
    assign A_sub  = ~A_add + 1'b1;
    assign A2_add = A_add << 1;
    assign A2_sub = ~A2_add + 1'b1; 


    wire [33:0] B_m;
    wire [33:0] B_l;    // i + 1
    wire [33:0] B_r;    // i - 1

    // 将B扩展到34位。对于有符号数，高位补符号位；对于无符号数，高位补0。

    assign B_m  = {{2{B[31] & mul_signed}}, B}; 
    assign B_l  = {1'b0, B_m[33:1]};
    assign B_r  = {B_m[32:0], 1'b0};

    // B[i+1, i, i-1] | 操作 | 含义
    //    000, 111    |  +0  | 0
    //    001, 010    |  +A  | +x
    //       011      |  +2A | +x左移
    //       100      |  -2A | -x左移
    //    101, 110    |  -A  | -x
    wire [34:0] sel_neg_x;   // -A
    wire [34:0] sel_x;       // +A
    wire [34:0] sel_neg_2x;  // -2A
    wire [34:0] sel_2x;      // +2A
    wire [34:0] sel_0;       // 0

    assign sel_neg_x   = ( B_l &  B_m & ~B_r) | (B_l & ~B_m & B_r);    // 编码 110, 101
    assign sel_x       = (~B_l &  B_m & ~B_r) | (~B_l & ~B_m& B_r);    // 编码 010, 001
    assign sel_neg_2x  = ( B_l & ~B_m & ~B_r) ;                      // 编码 100
    assign sel_2x      = (~B_l & B_m & B_r);                         // 编码 011
    assign sel_0       = (B_l & B_m & B_r) | (~B_l & ~B_m & ~B_r);     // 编码 111, 000

    // 将选择信号压缩到17位
    wire [16:0] sel_x_val;
    wire [16:0] sel_neg_x_val;
    wire [16:0] sel_2x_val;
    wire [16:0] sel_neg_2x_val;
    wire [16:0] sel_0_val;

    assign sel_x_val      = { sel_x[32], sel_x[30], sel_x[28], sel_x[26], sel_x[24], sel_x[22], sel_x[20], sel_x[18], sel_x[16], sel_x[14], sel_x[12], sel_x[10], sel_x[8], sel_x[6], sel_x[4], sel_x[2], sel_x[0] };
    assign sel_neg_x_val  = { sel_neg_x[32], sel_neg_x[30], sel_neg_x[28], sel_neg_x[26], sel_neg_x[24], sel_neg_x[22], sel_neg_x[20], sel_neg_x[18], sel_neg_x[16], sel_neg_x[14], sel_neg_x[12], sel_neg_x[10], sel_neg_x[8], sel_neg_x[6], sel_neg_x[4], sel_neg_x[2], sel_neg_x[0] };
    assign sel_2x_val     = { sel_2x[32], sel_2x[30], sel_2x[28], sel_2x[26], sel_2x[24], sel_2x[22], sel_2x[20], sel_2x[18], sel_2x[16], sel_2x[14], sel_2x[12], sel_2x[10], sel_2x[8], sel_2x[6], sel_2x[4], sel_2x[2], sel_2x[0] };
    assign sel_neg_2x_val = { sel_neg_2x[32], sel_neg_2x[30], sel_neg_2x[28], sel_neg_2x[26], sel_neg_2x[24], sel_neg_2x[22], sel_neg_2x[20], sel_neg_2x[18], sel_neg_x[16], sel_neg_x[14], sel_neg_x[12], sel_neg_x[10], sel_neg_x[8], sel_neg_x[6], sel_neg_x[4], sel_neg_x[2], sel_neg_x[0] };
    assign sel_0_val      = { sel_0[32], sel_0[30], sel_0[28], sel_0[26], sel_0[24], sel_0[22], sel_0[20], sel_0[18], sel_0[16], sel_0[14], sel_0[12], sel_0[10], sel_0[8], sel_0[6], sel_0[4], sel_0[2], sel_0[0] };


    wire [18:0] debug;
    assign debug = sel_x_val + sel_neg_2x_val + sel_neg_x_val + sel_2x_val + sel_0_val;


    wire [63:0] P [16:0]; // 17个未对齐的部分积

    genvar i;
    generate
        for (i = 0; i < 17; i = i + 1) begin : gen_partial_products
            assign P[i] = (sel_x_val[i]      ? A_add  : 64'b0) |
                          (sel_neg_x_val[i]  ? A_sub  : 64'b0) |
                          (sel_2x_val[i]     ? A2_add : 64'b0) |
                          (sel_neg_2x_val[i] ? A2_sub : 64'b0);
        end
    endgenerate


    // 17 -> 12
    wire [63:0] level_1 [11:0];
    Adder adder1_1 (.in1(P[15] << 30), .in2(P[14] << 28), .in3(P[13] << 26), .C(level_1[0]), .S(level_1[1]));
    Adder adder1_2 (.in1(P[12] << 24), .in2(P[11] << 22), .in3(P[10] << 20), .C(level_1[2]), .S(level_1[3]));
    Adder adder1_3 (.in1(P[9]  << 18), .in2(P[8]  << 16), .in3(P[7]  << 14), .C(level_1[4]), .S(level_1[5]));
    Adder adder1_4 (.in1(P[6]  << 12), .in2(P[5]  << 10), .in3(P[4]  << 8),  .C(level_1[6]), .S(level_1[7]));
    Adder adder1_5 (.in1(P[3]  << 6),  .in2(P[2]  << 4),  .in3(P[1]  << 2),  .C(level_1[8]), .S(level_1[9]));
    assign level_1[10] = P[0];
    assign level_1[11] = P[16] << 32;

    // 12 -> 8
    wire [63:0] level_2 [7:0];
    Adder adder2_1 (.in1(level_1[0]), .in2(level_1[1]), .in3(level_1[2]), .C(level_2[0]), .S(level_2[1]));
    Adder adder2_2 (.in1(level_1[3]), .in2(level_1[4]), .in3(level_1[5]), .C(level_2[2]), .S(level_2[3]));
    Adder adder2_3 (.in1(level_1[6]), .in2(level_1[7]), .in3(level_1[8]), .C(level_2[4]), .S(level_2[5]));
    Adder adder2_4 (.in1(level_1[9]), .in2(level_1[10]),.in3(level_1[11]),.C(level_2[6]), .S(level_2[7]));

    // 8 -> 6
    wire [63:0] level_3 [5:0];
    Adder adder3_1 (.in1(level_2[0]), .in2(level_2[1]), .in3(level_2[2]), .C(level_3[0]), .S(level_3[1]));
    Adder adder3_2 (.in1(level_2[3]), .in2(level_2[4]), .in3(level_2[5]), .C(level_3[2]), .S(level_3[3]));
    assign level_3[4] = level_2[6];
    assign level_3[5] = level_2[7];

    // 6 -> 4
    wire [63:0] level_4 [3:0];
    Adder adder4_1 (.in1(level_3[0]), .in2(level_3[1]), .in3(level_3[2]), .C(level_4[0]), .S(level_4[1]));
    Adder adder4_2 (.in1(level_3[3]), .in2(level_3[4]), .in3(level_3[5]), .C(level_4[2]), .S(level_4[3]));

    // 4 -> 3
    wire [63:0] level_5 [2:0];
    Adder adder5_1 (.in1(level_4[0]), .in2(level_4[1]), .in3(level_4[2]), .C(level_5[0]), .S(level_5[1]));
    assign level_5[2] = level_4[3];

    // 3 -> 2
    wire [63:0] level_6 [1:0];
    Adder adder6_1 (.in1(level_5[0]), .in2(level_5[1]), .in3(level_5[2]), .C(level_6[0]), .S(level_6[1]));

    assign result = (level_6[0] + level_6[1]) & {64{resetn}};

endmodule