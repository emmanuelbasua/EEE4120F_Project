`timescale 1ns/1ps

module sim_tb;

localparam CLK_PERIOD = 10;
localparam N          = 16;
localparam ERR_THRESH = 20;

reg        clk, rst_n, start;
reg [11:0] theta;
wire [15:0] cos_out, sin_out;
wire        busy, valid;

integer pass_count = 0;
integer fail_count = 0;
integer cycle_count, k;

reg [11:0] test_theta [0:N-1];
reg [15:0] gold_cos   [0:N-1];
reg [15:0] gold_sin   [0:N-1];

cordic_engine #(.N_ITER(16)) DUT (
    .clk(clk), .rst_n(rst_n), .start(start), .theta(theta),
    .cos_result(cos_out), .sin_result(sin_out), .busy(busy), .valid(valid)
);

initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    // Gold values from fixed-point Python model (bit-exact match expected)
    //          theta      cos(Q1.15)  sin(Q1.15)
    test_theta[ 0]=12'h000; gold_cos[ 0]=16'h7FFD; gold_sin[ 0]=16'h0002; //   0deg
    test_theta[ 1]=12'h0E4; gold_cos[ 1]=16'h7E08; gold_sin[ 1]=16'h1648; //  10deg
    test_theta[ 2]=12'h155; gold_cos[ 2]=16'h7BA3; gold_sin[ 2]=16'h211C; //  15deg
    test_theta[ 3]=12'h200; gold_cos[ 3]=16'h7647; gold_sin[ 3]=16'h30FC; //  22.5deg
    test_theta[ 4]=12'h2AB; gold_cos[ 4]=16'h6ED4; gold_sin[ 4]=16'h4005; //  30deg
    test_theta[ 5]=12'h400; gold_cos[ 5]=16'h5A7E; gold_sin[ 5]=16'h5A81; //  45deg
    test_theta[ 6]=12'h555; gold_cos[ 6]=16'h4005; gold_sin[ 6]=16'h6ED4; //  60deg
    test_theta[ 7]=12'h6AB; gold_cos[ 7]=16'h2114; gold_sin[ 7]=16'h7BA5; //  75deg
    test_theta[ 8]=12'h7E9; gold_cos[ 8]=16'h023E; gold_sin[ 8]=16'h7FF5; //  89deg
    test_theta[ 9]=12'hF1C; gold_cos[ 9]=16'h7E09; gold_sin[ 9]=16'hE9B5; // -10deg
    test_theta[10]=12'hEAB; gold_cos[10]=16'h7B9F; gold_sin[10]=16'hDEEC; // -15deg
    test_theta[11]=12'hD55; gold_cos[11]=16'h6ED5; gold_sin[11]=16'hBFFB; // -30deg
    test_theta[12]=12'hC00; gold_cos[12]=16'h5A84; gold_sin[12]=16'hA582; // -45deg
    test_theta[13]=12'hAAB; gold_cos[13]=16'h4006; gold_sin[13]=16'h912C; // -60deg
    test_theta[14]=12'h955; gold_cos[14]=16'h211F; gold_sin[14]=16'h845D; // -75deg
    test_theta[15]=12'h000; gold_cos[15]=16'h7FFD; gold_sin[15]=16'h0002; //   0deg regression
end

task run_test;
    input integer tid;
    integer ec, es;
begin
    theta = test_theta[tid];
    @(posedge clk); #1; start = 1;
    @(posedge clk); #1; start = 0;
    cycle_count = 0;
    while (!valid && cycle_count < 30) begin
        @(posedge clk); #1;
        cycle_count = cycle_count + 1;
    end
    if (!valid) begin
        $display("[TIMEOUT] Test %2d theta=0x%03h", tid, test_theta[tid]);
        fail_count = fail_count + 1;
    end else begin
        ec = abs_diff(cos_out, gold_cos[tid]);
        es = abs_diff(sin_out, gold_sin[tid]);
        if (ec <= ERR_THRESH && es <= ERR_THRESH) begin
            $display("[PASS] Test %2d | theta=0x%03h | cos=0x%04h(err=%0d) sin=0x%04h(err=%0d) | cyc=%0d",
                tid, test_theta[tid], cos_out, ec, sin_out, es, cycle_count);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %2d | theta=0x%03h | cos=0x%04h(exp=0x%04h err=%0d) sin=0x%04h(exp=0x%04h err=%0d)",
                tid, test_theta[tid], cos_out, gold_cos[tid], ec, sin_out, gold_sin[tid], es);
            fail_count = fail_count + 1;
        end
    end
    repeat(3) @(posedge clk);
end
endtask

function integer abs_diff;
    input [15:0] a, b;
    integer d;
begin
    d = $signed(a) - $signed(b);
    abs_diff = (d < 0) ? -d : d;
end
endfunction

initial begin
    $dumpfile("cru_tb.vcd");
    $dumpvars(0, sim_tb);
    $display("==============================================");
    $display("  CRU Simulation  cordic_engine.v");
    $display("==============================================");
    rst_n = 0; start = 0; theta = 0;
    repeat(4) @(posedge clk);
    rst_n = 1;
    repeat(2) @(posedge clk);
    for (k = 0; k < N; k = k + 1) run_test(k);
    $display("==============================================");
    $display("  PASS: %0d  FAIL: %0d  TOTAL: %0d", pass_count, fail_count, N);
    if (fail_count == 0) $display("  *** ALL TESTS PASSED ***");
    $display("==============================================");
    $finish;
end

endmodule
