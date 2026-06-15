--------------------------------------------------------------------------------
-- File    : fir_filter.vhd
-- Purpose : Small sequential FIR filter with coefficient ROM, delay line, and
--           multiply-accumulate logic. One multiplier processes all taps in
--           G_NUM_TAPS clock cycles per input sample.
--           Demonstrates USE_DSP, ROM_STYLE, and SHREG_EXTRACT attributes.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.synth_demo_pkg.all;

entity fir_filter is
  generic (
    G_SAMPLE_W : positive := 16;
    G_COEFF_W  : positive := 16;
    G_NUM_TAPS : positive := 8
  );
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;  -- synchronous active-high reset

    -- Input sample stream
    sample_valid_i : in  std_logic;
    sample_data_i  : in  signed(G_SAMPLE_W-1 downto 0);

    -- Filtered output stream (registered)
    result_valid_o : out std_logic;
    result_data_o  : out signed(G_SAMPLE_W+G_COEFF_W-1 downto 0)
  );
end entity;

architecture rtl of fir_filter is

  -- Accumulator with guard bits for the tap sum
  constant C_ACC_W : positive := G_SAMPLE_W + G_COEFF_W + clog2(G_NUM_TAPS);

  type delay_line_t is array (0 to G_NUM_TAPS-1) of signed(G_SAMPLE_W-1 downto 0);
  type coeff_rom_t  is array (0 to G_NUM_TAPS-1) of signed(G_COEFF_W-1 downto 0);

  -- Triangular (Bartlett-like) low-pass coefficients, generated so that the
  -- ROM contents scale with any G_NUM_TAPS value.
  function f_init_coeffs return coeff_rom_t is
    variable v : coeff_rom_t;
    variable w : integer;
  begin
    for i in 0 to G_NUM_TAPS-1 loop
      if i < (G_NUM_TAPS+1)/2 then
        w := i + 1;
      else
        w := G_NUM_TAPS - i;
      end if;
      v(i) := to_signed(w * 256, G_COEFF_W);
    end loop;
    return v;
  end function;

  -- Never written -> inferred as a ROM
  signal coeff_rom : coeff_rom_t := f_init_coeffs;

  attribute ROM_STYLE : string;
  attribute ROM_STYLE of coeff_rom : signal is "distributed";

  -- Sample delay line, shifted on each new input sample
  signal delay_line : delay_line_t := (others => (others => '0'));

  attribute SHREG_EXTRACT : string;
  attribute SHREG_EXTRACT of delay_line : signal is "yes";

  -- Multiply-accumulate result, mapped to DSP slices
  signal mac_result : signed(C_ACC_W-1 downto 0) := (others => '0');

  attribute USE_DSP : string;
  attribute USE_DSP of mac_result : signal is "yes";

  type fir_state_t is (S_IDLE, S_MAC, S_DONE);
  signal state : fir_state_t := S_IDLE;

  signal tap_idx  : natural range 0 to G_NUM_TAPS-1 := 0;
  signal valid_r  : std_logic := '0';
  signal result_r : signed(G_SAMPLE_W+G_COEFF_W-1 downto 0) := (others => '0');

begin

  p_fir : process (clk)
  begin
    if rising_edge(clk) then
      valid_r <= '0';

      if rst = '1' then
        state   <= S_IDLE;
        tap_idx <= 0;
      else
        case state is

          when S_IDLE =>
            if sample_valid_i = '1' then
              -- Shift the new sample into the delay line
              delay_line <= sample_data_i & delay_line(0 to G_NUM_TAPS-2);
              mac_result <= (others => '0');
              tap_idx    <= 0;
              state      <= S_MAC;
            end if;

          when S_MAC =>
            -- One multiply-accumulate per cycle: ROM read, SRL read, DSP MAC
            mac_result <= mac_result +
                          resize(delay_line(tap_idx) * coeff_rom(tap_idx), C_ACC_W);
            if tap_idx = G_NUM_TAPS-1 then
              state <= S_DONE;
            else
              tap_idx <= tap_idx + 1;
            end if;

          when S_DONE =>
            -- Saturate the C_ACC_W-bit accumulator into the 32-bit result.
            -- The triangle peaks genuinely exceed signed 32-bit range at these
            -- coefficients, so the guard bits matter. The value fits in signed
            -- 32-bit iff the upper bits [C_ACC_W-1 : 31] are all equal to the
            -- 32-bit sign bit (bit 31); otherwise clamp to the 32-bit min/max.
            if mac_result(C_ACC_W-1 downto G_SAMPLE_W+G_COEFF_W-1) =
                 (C_ACC_W-1 downto G_SAMPLE_W+G_COEFF_W-1 => '0') or
               mac_result(C_ACC_W-1 downto G_SAMPLE_W+G_COEFF_W-1) =
                 (C_ACC_W-1 downto G_SAMPLE_W+G_COEFF_W-1 => '1') then
              -- In range: low 32 bits are an exact representation.
              result_r <= mac_result(G_SAMPLE_W+G_COEFF_W-1 downto 0);
            elsif mac_result(C_ACC_W-1) = '0' then
              -- Positive overflow -> max positive 32-bit value (0x7FFF_FFFF)
              result_r <= (G_SAMPLE_W+G_COEFF_W-1 => '0', others => '1');
            else
              -- Negative overflow -> min negative 32-bit value (0x8000_0000)
              result_r <= (G_SAMPLE_W+G_COEFF_W-1 => '1', others => '0');
            end if;
            valid_r  <= '1';
            state    <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

  result_valid_o <= valid_r;
  result_data_o  <= result_r;

end architecture;
