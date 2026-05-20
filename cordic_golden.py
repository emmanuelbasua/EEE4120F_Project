"""
CORDIC golden model for CRU verification.
Generates reference (sin, cos) values in Q1.15 for arbitrary angles
so the Verilog testbench can compare against them.
"""
import math

Q15 = 1 << 15            # 32768
Q15_MAX = (1 << 15) - 1  # 0x7FFF

def to_q15(x):
    """Float -> signed 16-bit Q1.15 (two's complement). Saturates."""
    v = int(round(x * Q15))
    if v > Q15_MAX:  v = Q15_MAX
    if v < -Q15:     v = -Q15
    return v & 0xFFFF

def from_q15(h):
    """16-bit Q1.15 (two's complement) -> float."""
    if h & 0x8000:
        h -= 0x10000
    return h / Q15

# CORDIC gain (the converged product over all i of sqrt(1 + 2^-2i))
def cordic_gain(n=16):
    K = 1.0
    for i in range(n):
        K *= math.sqrt(1 + 2.0**(-2*i))
    return K

K = cordic_gain(16)
K_INV = 1.0 / K          # ~= 0.6072529

# Verilog uses K_INV = 0x4DB9 (1 LSB below ideal) to avoid 16-bit signed
# overflow at angle=0. Mirror that exact value here so the Python model
# bit-matches the hardware.
K_INV_Q15 = 0x4DB7

def sat16(v):
    """Wrap to 16-bit signed (two's complement) - matches Verilog overflow."""
    v = v & 0xFFFF
    return v - 0x10000 if v & 0x8000 else v

def cordic_sin_cos(theta_rad, n=16):
    """Software CORDIC mirroring the Verilog hardware EXACTLY, including
    16-bit signed overflow behaviour on the >>> arithmetic shift."""
    x = K_INV_Q15
    if x & 0x8000: x -= 0x10000   # interpret as signed
    y = 0
    z = to_q15(theta_rad)
    if z & 0x8000: z -= 0x10000

    # arctan(2^-i) in Q1.15 radians (must match atan_rom in CRU.v)
    atan_rom = [to_q15(math.atan(2.0**(-i))) for i in range(n)]

    for i in range(n):
        d = +1 if z >= 0 else -1
        # Match Verilog signed >>> (arithmetic shift right, rounds to -inf).
        # Python's >> on signed ints already rounds to -inf, so it matches.
        x_sh = x >> i
        y_sh = y >> i
        new_x = sat16(x - d * y_sh)
        new_y = sat16(y + d * x_sh)
        new_z = sat16(z - d * atan_rom[i])
        x, y, z = new_x, new_y, new_z

    # x ~= cos(theta), y ~= sin(theta)
    return (x & 0xFFFF), (y & 0xFFFF)

if __name__ == "__main__":
    angles = [
        ("0",       0.0),
        ("pi/8",    math.pi/8),
        ("pi/6",    math.pi/6),
        ("pi/4",    math.pi/4),
        ("pi/3",    math.pi/3),
        ("-pi/6",  -math.pi/6),
    ]
    print(f"{'angle':>8s} {'cos_hw':>8s} {'cos_ref':>8s} {'sin_hw':>8s} {'sin_ref':>8s}"
          f"  cos_err  sin_err")
    print("-"*80)
    for name, t in angles:
        cos_hw, sin_hw = cordic_sin_cos(t)
        cos_ref = to_q15(math.cos(t))
        sin_ref = to_q15(math.sin(t))
        cos_err = (cos_hw - cos_ref) if cos_hw < 0x8000 else (cos_hw - 0x10000 - (cos_ref if cos_ref < 0x8000 else cos_ref - 0x10000))
        sin_err = (sin_hw - sin_ref) if sin_hw < 0x8000 else (sin_hw - 0x10000 - (sin_ref if sin_ref < 0x8000 else sin_ref - 0x10000))
        print(f"{name:>8s}  0x{cos_hw:04X}   0x{cos_ref:04X}   0x{sin_hw:04X}   0x{sin_ref:04X}"
              f"   {from_q15(cos_hw)-math.cos(t):+.5f}   {from_q15(sin_hw)-math.sin(t):+.5f}")
