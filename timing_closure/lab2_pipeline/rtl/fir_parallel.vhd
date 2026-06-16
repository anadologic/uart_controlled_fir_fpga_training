--------------------------------------------------------------------------------
-- File    : fir_parallel.vhd  (LAB 2 - PIPELINED adder tree)
-- Purpose : Same balanced tree as Lab 1, but now each tree level is its own
--           PIPELINE STAGE, separated by registers. The long combinational
--           cloud is sliced into short per-stage clouds.
--
--           Pipeline (latency = 4 cycles from sample_valid to result_valid):
--             stage 1 : products            prod_r(i)  = sample[i]*coeff[i]
--             stage 2 : tree level 0        l0_r(j)    = prod_r(2j)+prod_r(2j+1)
--             stage 3 : tree level 1        l1_r(k)    = l0_r(2k)+l0_r(2k+1)
--             stage 4 : tree level 2        result_r   = l1_r(0)+l1_r(1)
--
--           Now the worst path between any two registers is ONE multiply OR
--           ONE add - not the whole cloud. Fmax rises dramatically.
--
--           COST: latency (4 cycles) and flip-flops (the pipeline registers).
--           This is the fundamental trade: throughput/Fmax for latency+area.
--
--           A valid pipeline (valid_pipe) shifts alongside the data so
--           result_valid_o asserts exactly when result_r is the matching result.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir_parallel is
  generic (
    G_SAMPLE_W : positive := 16;
    G_COEFF_W  : positive := 16;
    G_NUM_TAPS : positive := 8   -- this lab is written for the 8-tap (3-level) tree
  );
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    sample_valid_i : in  std_logic;
    sample_data_i  : in  signed(G_SAMPLE_W-1 downto 0);
    result_valid_o : out std_logic;
    result_data_o  : out signed(G_SAMPLE_W+G_COEFF_W-1 downto 0)
  );
end entity;

architecture rtl of fir_parallel is

  function clog2(n : positive) return natural is
    variable v : natural  := 0;
    variable p : positive := 1;
  begin
    while p < n loop p := p * 2; v := v + 1; end loop;
    return v;
  end function;

  constant C_PROD_W : positive := G_SAMPLE_W + G_COEFF_W;
  constant C_ACC_W  : positive := C_PROD_W + clog2(G_NUM_TAPS);
  constant C_LAT    : positive := 4;  -- pipeline depth (cycles)

  type sample_arr_t is array (0 to G_NUM_TAPS-1) of signed(G_SAMPLE_W-1 downto 0);
  type coeff_arr_t  is array (0 to G_NUM_TAPS-1) of signed(G_COEFF_W-1 downto 0);
  type acc8_t       is array (0 to 7) of signed(C_ACC_W-1 downto 0);
  type acc4_t       is array (0 to 3) of signed(C_ACC_W-1 downto 0);
  type acc2_t       is array (0 to 1) of signed(C_ACC_W-1 downto 0);

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

  -- pipeline registers, one set per stage
  signal prod_r : acc8_t := (others => (others => '0'));  -- stage 1
  signal l0_r   : acc4_t := (others => (others => '0'));  -- stage 2
  signal l1_r   : acc2_t := (others => (others => '0'));  -- stage 3
  signal result_r : signed(C_PROD_W-1 downto 0) := (others => '0');  -- stage 4

  -- valid travels with the data
  signal valid_pipe : std_logic_vector(C_LAT-1 downto 0) := (others => '0');

begin

  p_fir : process (clk)
    variable prod : signed(C_PROD_W-1 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        delay_line <= (others => (others => '0'));
        valid_pipe <= (others => '0');
        result_r   <= (others => '0');
      else
        -- delay line + valid shift register
        if sample_valid_i = '1' then
          delay_line <= sample_data_i & delay_line(0 to G_NUM_TAPS-2);
        end if;
        valid_pipe <= valid_pipe(C_LAT-2 downto 0) & sample_valid_i;

        -- STAGE 1: products (registered)
        for i in 0 to G_NUM_TAPS-1 loop
          if i = 0 then
            prod := sample_data_i * C_COEFF(0);
          else
            prod := delay_line(i-1) * C_COEFF(i);
          end if;
          prod_r(i) <= resize(prod, C_ACC_W);
        end loop;

        -- STAGE 2: tree level 0 (registered)
        for j in 0 to 3 loop
          l0_r(j) <= resize(prod_r(2*j) + prod_r(2*j+1), C_ACC_W);
        end loop;

        -- STAGE 3: tree level 1 (registered)
        for k in 0 to 1 loop
          l1_r(k) <= resize(l0_r(2*k) + l0_r(2*k+1), C_ACC_W);
        end loop;

        -- STAGE 4: tree level 2 -> result (registered)
        result_r <= resize(l1_r(0) + l1_r(1), C_PROD_W);
      end if;
    end if;
  end process;

  result_valid_o <= valid_pipe(C_LAT-1);
  result_data_o  <= result_r;

end architecture;
