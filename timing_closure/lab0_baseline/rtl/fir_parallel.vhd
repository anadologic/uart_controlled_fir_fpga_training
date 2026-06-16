--------------------------------------------------------------------------------
-- File    : fir_parallel.vhd  (LAB 0 - baseline, deliberately stressed)
-- Purpose : Fully parallel / unrolled 8-tap FIR. Every tap is multiplied and
--           summed in ONE clock cycle as a single combinational cloud:
--
--               result = sum_{i=0..N-1} ( sample[i] * coeff[i] )
--
--           The sum is built as a LINEAR ADDER CHAIN (acc = acc + prod[i]),
--           which is the worst case: N-1 adders in series.
--
--           This is the "before" design for the whole module. With the fast
--           clock in xdc/, it fails timing (WNS < 0). Later labs change ONE
--           thing each to recover the slack.
--
-- Function : identical to the project's sequential fir_filter (same triangular
--            coefficients, same 8 taps, same widths), so results match.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir_parallel is
  generic (
    G_SAMPLE_W : positive := 16;
    G_COEFF_W  : positive := 16;
    G_NUM_TAPS : positive := 8
  );
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;  -- synchronous active-high

    sample_valid_i : in  std_logic;
    sample_data_i  : in  signed(G_SAMPLE_W-1 downto 0);

    result_valid_o : out std_logic;
    result_data_o  : out signed(G_SAMPLE_W+G_COEFF_W-1 downto 0)
  );
end entity;

architecture rtl of fir_parallel is

  -- log2 ceiling for accumulator guard bits (local copy, no package dependency
  -- so each lab folder is self-contained)
  function clog2(n : positive) return natural is
    variable v : natural  := 0;
    variable p : positive := 1;
  begin
    while p < n loop p := p * 2; v := v + 1; end loop;
    return v;
  end function;

  constant C_PROD_W : positive := G_SAMPLE_W + G_COEFF_W;
  constant C_ACC_W  : positive := C_PROD_W + clog2(G_NUM_TAPS);

  type sample_arr_t is array (0 to G_NUM_TAPS-1) of signed(G_SAMPLE_W-1 downto 0);
  type coeff_arr_t  is array (0 to G_NUM_TAPS-1) of signed(G_COEFF_W-1 downto 0);

  -- Same triangular coefficients as fir_filter.vhd
  function f_init_coeffs return coeff_arr_t is
    variable v : coeff_arr_t;
    variable w : integer;
  begin
    for i in 0 to G_NUM_TAPS-1 loop
      if i < (G_NUM_TAPS+1)/2 then w := i + 1; else w := G_NUM_TAPS - i; end if;
      v(i) := to_signed(w * 256, G_COEFF_W);
    end loop;
    return v;
  end function;

  constant C_COEFF : coeff_arr_t := f_init_coeffs;

  signal delay_line : sample_arr_t := (others => (others => '0'));
  signal valid_r    : std_logic := '0';
  signal result_r   : signed(C_PROD_W-1 downto 0) := (others => '0');

begin

  p_fir : process (clk)
    variable acc  : signed(C_ACC_W-1 downto 0);
    variable prod : signed(C_PROD_W-1 downto 0);
  begin
    if rising_edge(clk) then
      valid_r <= '0';

      if rst = '1' then
        delay_line <= (others => (others => '0'));
        result_r   <= (others => '0');
      else
        if sample_valid_i = '1' then
          -- shift the new sample in
          delay_line <= sample_data_i & delay_line(0 to G_NUM_TAPS-2);

          -- ====================================================================
          -- THE STRESSED PATH: a single combinational multiply-add cloud,
          -- summed as a LINEAR CHAIN. With G_NUM_TAPS = 8 this is 8 multipliers
          -- feeding a chain of 7 adders, all between the input registers and
          -- result_r. That is the long path the fast clock cannot meet.
          --
          -- (We sum the freshly-shifted samples: the new sample plus the
          --  existing taps, matching the sequential filter's behavior.)
          -- ====================================================================
          acc := (others => '0');
          for i in 0 to G_NUM_TAPS-1 loop
            if i = 0 then
              prod := sample_data_i * C_COEFF(0);
            else
              prod := delay_line(i-1) * C_COEFF(i);
            end if;
            acc := acc + resize(prod, C_ACC_W);   -- chained add: acc depends on previous acc
          end loop;

          result_r <= resize(acc, C_PROD_W);
          valid_r  <= '1';
        end if;
      end if;
    end if;
  end process;

  result_valid_o <= valid_r;
  result_data_o  <= result_r;

end architecture;
