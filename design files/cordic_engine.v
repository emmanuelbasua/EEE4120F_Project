// =============================================================================
// Coordinate Rotation Unit (CRU) for StarCore-1
// EEE4120F HPES Project 2026  |  OrbitEdge-1 Mission
// =============================================================================
//
// ARCHITECTURE: Iterative (folded) CORDIC, rotation mode.
//   Computes cos(theta) and sin(theta) using only shift-and-add arithmetic.
//   No hardware multipliers required.
//
// FIXED-POINT FORMATS
//   theta input : 12-bit signed Q0.11 normalised
//                 Encodes angle as a fraction of 90 degrees:
//                   theta = round( angle_degrees / 90 * 2^11 )
//                 Range: -2048..+2047 -> -90..+90 degrees
//                 Examples:   0 deg -> 0x000
//                            45 deg -> 0x400
//                           -45 deg -> 0xC00
//
//   z register  : 16-bit signed Q0.14 (same normalised units, finer LSB)
//                 Loaded by left-shifting theta 3 bits (Q0.11 -> Q0.14):
//                   z = { theta[11], theta[11:0], 3'b000 }
//
//   atan_rom    : 16-entry x 16-bit, Q0.14 normalised arctangent.
//                 Entry i = round( atan(2^-i) / (pi/2) * 2^14 )
//                 Same unit as z so z +/- atan_rom[i] is valid.
//                 File: atan_rom.mem
//
//   x, y regs   : 16-bit signed Q1.15 (range approx +/-1)
//                 Initialised to K_INV.  After 16 iterations:
//                   x -> cos(theta),  y -> sin(theta)
//
// FSM (Moore, 3 states):
//   IDLE -> ITER : on START; loads x0=K_INV, y0=0, z0=theta_extended
//   ITER         : 16 micro-rotations.  BUSY=1, VALID=0.
//   DONE -> IDLE : latches results, pulses VALID for 1 cycle.  BUSY=0.
//   Total latency: 18 clock cycles from START to VALID.
//
// =============================================================================

module cordic_engine #(
    parameter N_ITER = 16
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [11:0] theta,
    output reg  [15:0] cos_result,
    output reg  [15:0] sin_result,
    output reg         busy,
    output reg         valid
);

// ---------------------------------------------------------------------------
// FSM states
// ---------------------------------------------------------------------------
localparam [1:0] IDLE = 2'd0, ITER = 2'd1, DONE = 2'd2;
reg [1:0] state;

// ---------------------------------------------------------------------------
// Iteration counter
// ---------------------------------------------------------------------------
reg [3:0] i;

// ---------------------------------------------------------------------------
// K_INV: CORDIC gain pre-compensation constant
//
// Exact value: K_INV = 1 / prod_{i=0}^{15} sqrt(1 + 2^{-2i})
//            = 0.607253...
//            -> Q1.15 -> round(0.607253 * 32768) = 19898 = 0x4DBA
//
// ---------------------------------------------------------------------------
localparam signed [15:0] K_INV = 16'sh4DB8;

// ---------------------------------------------------------------------------
// Datapath registers
// ---------------------------------------------------------------------------
reg signed [15:0] x;   // cos accumulator, Q1.15
reg signed [15:0] y;   // sin accumulator, Q1.15
reg signed [15:0] z;   // angle accumulator, Q0.14 normalised

// ---------------------------------------------------------------------------
// Arctangent ROM
// Entry i = round( atan(2^-i) / (pi/2) * 2^14 )
// i=0: 0x2000  i=1: 0x12E4  i=2: 0x09FB  i=3: 0x0511  ...
// ---------------------------------------------------------------------------
reg [15:0] atan_rom [0 : N_ITER-1];
initial $readmemh("atan_rom.mem", atan_rom);

// ---------------------------------------------------------------------------
// Arithmetic right-shift combinational helpers
// ---------------------------------------------------------------------------
wire signed [15:0] x_shr = $signed(x) >>> i;
wire signed [15:0] y_shr = $signed(y) >>> i;
wire               d_pos = ~z[15];   // 1 when z >= 0

// ---------------------------------------------------------------------------
// FSM + Datapath
// ---------------------------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state      <= IDLE;
        x          <= 16'sd0;
        y          <= 16'sd0;
        z          <= 16'sd0;
        i          <= 4'd0;
        cos_result <= 16'd0;
        sin_result <= 16'd0;
        busy       <= 1'b0;
        valid      <= 1'b0;
    end else begin
        case (state)

            // ----------------------------------------------------------------
            // IDLE: wait for start pulse, keep outputs idle
            // ----------------------------------------------------------------
            IDLE: begin
                busy  <= 1'b0;
                valid <= 1'b0;
                if (start) begin
                    x     <= K_INV;
                    y     <= 16'sd0;
                    // BUG FIX #1: shift theta left 3 to convert Q0.11 -> Q0.14
                    // {theta[11], theta[11:0], 3'b000} = 1+12+3 = 16 bits
                    z     <= $signed({theta[11], theta[11:0], 3'b000});
                    i     <= 4'd0;
                    busy  <= 1'b1;
                    state <= ITER;
                end
            end

            // ----------------------------------------------------------------
            // ITER: perform CORDIC micro-rotation for step i
            // ----------------------------------------------------------------
            ITER: begin
                if (d_pos) begin
                    x <= x - y_shr;
                    y <= y + x_shr;
                    z <= z - $signed({1'b0, atan_rom[i]});
                end else begin
                    x <= x + y_shr;
                    y <= y - x_shr;
                    z <= z + $signed({1'b0, atan_rom[i]});
                end

                i <= i + 4'd1;
                if (i == N_ITER - 1) begin
                    busy  <= 1'b0;
                    state <= DONE;
                end
            end

            // ----------------------------------------------------------------
            // DONE: latch results, pulse VALID, return to IDLE
            // ----------------------------------------------------------------
            DONE: begin
                cos_result <= x;
                sin_result <= y;
                valid      <= 1'b1;
                state      <= IDLE;
            end

            default: state <= IDLE;

        endcase
    end
end

endmodule
