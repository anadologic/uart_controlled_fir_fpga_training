--------------------------------------------------------------------------------
-- File    : fir_parallel.vhd  (LAB 1 - adder TREE)
-- Purpose : Same parallel 8-tap FIR as Lab 0, but the summation is a BALANCED
--           BINARY ADDER TREE instead of a linear chain.
--
--           Lab 0 chain  : acc = (((((((p0+p1)+p2)+p3)+p4)+p5)+p6)+p7)
--                          -> 7 adders in series   = 7 logic levels of add
--
--           Lab 1 tree   : level0 = p0+p1, p2+p3, p4+p5, p6+p7   (4 adders)
--                          level1 = (..)+(..), (..)+(..)         (2 adders)
--                          level2 = (..)+(..)                    (1 adder)
--                          -> depth = ceil(log2(8)) = 3 logic levels of add
--
--           SAME function, SAME multipliers, SAME area (roughly). The ONLY
--           change is the shape of the addition. That alone cuts the
--           combinational depth from 7 to 3, which raises Fmax / improves WNS.
--
--           THIS IS THE LESSON: structure, not just amount of logic, sets the
--           critical-path length. Restructuring is "free" timing.
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

  type sample_arr_t is array (0 to G_NUM_TAPS-1) of signed(G_SAMPLE_W-1 downto 0);
  type coeff_arr_t  is array (0 to G_NUM_TAPS-1) of signed(G_COEFF_W-1 downto 0);
  type acc_arr_t    is array (natural range <>) of signed(C_ACC_W-1 downto 0);

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

  -- Recursive balanced-tree adder over a slice of products.
  function f_tree_sum(v : acc_arr_t) return signed is
    variable n    : natural := v'length;
    variable half : natural;
    variable lo   : acc_arr_t(0 to (n/2) - 1);
    variable hi   : acc_arr_t(0 to (n - n/2) - 1);
  begin
    if n = 1 then
      return v(v'low);
    end if;
    half := n / 2;
    for i in 0 to half-1 loop
      lo(i) := v(v'low + i);
    end loop;
    for i in 0 to (n - half) - 1 loop
      hi(i) := v(v'low + half + i);
    end loop;
    return resize(f_tree_sum(lo) + f_tree_sum(hi), C_ACC_W);
  end function;

begin

  p_fir : process (clk)
    variable prods : acc_arr_t(0 to G_NUM_TAPS-1);
    variable prod  : signed(C_PROD_W-1 downto 0);
    variable acc   : signed(C_ACC_W-1 downto 0);
  begin
    if rising_edge(clk) then
      valid_r <= '0';

      if rst = '1' then
        delay_line <= (others => (others => '0'));
        result_r   <= (others => '0');
      else
        if sample_valid_i = '1' then
          delay_line <= sample_data_i & delay_line(0 to G_NUM_TAPS-2);

          -- products (same as Lab 0)
          for i in 0 to G_NUM_TAPS-1 loop
            if i = 0 then
              prod := sample_data_i * C_COEFF(0);
            else
              prod := delay_line(i-1) * C_COEFF(i);
            end if;
            prods(i) := resize(prod, C_ACC_W);
          end loop;

          -- balanced tree sum (the only structural change vs Lab 0)
          acc := f_tree_sum(prods);

          result_r <= resize(acc, C_PROD_W);
          valid_r  <= '1';
        end if;
      end if;
    end if;
  end process;

  result_valid_o <= valid_r;
  result_data_o  <= result_r;

end architecture;
