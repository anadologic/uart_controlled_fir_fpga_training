--------------------------------------------------------------------------------
-- File    : fir_parallel.vhd  (LAB 3 - DSP48 pipelined MAC mapping)
-- Purpose : Map each tap's multiply (and the first add) into a DSP48E1 slice
--           with its INTERNAL pipeline registers, instead of fabric LUT/CARRY.
--
--           The DSP48E1 has dedicated registers on its datapath:
--             A/B input regs -> M (multiplier) reg -> P (output/accum) reg
--           When the multiplier-accumulator is written so these registers are
--           inferred, the multiply runs at the DSP's full clock rate and the
--           result is already registered in hard silicon - no fabric routing
--           between multiply and its register.
--
--           Structure used here (per tap), all in DSP-friendly form:
--             a_r  <= sample           (DSP A register)
--             m_r  <= a_r * coeff      (DSP M register)   <- pipelined multiply
--           then the products feed the SAME pipelined adder tree as Lab 2.
--
--           USE_DSP = "yes" tells synthesis to prefer DSP slices for the
--           multipliers. The internal register inference is what makes the DSP
--           fast - a multiply with no surrounding registers cannot use the M
--           register and is much slower.
--
--           Latency here is 5 cycles (one extra for the DSP A register).
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
  constant C_LAT    : positive := 5;  -- +1 vs Lab 2 for the DSP A register

  type sample_arr_t is array (0 to G_NUM_TAPS-1) of signed(G_SAMPLE_W-1 downto 0);
  type coeff_arr_t  is array (0 to G_NUM_TAPS-1) of signed(G_COEFF_W-1 downto 0);
  type prod_arr_t   is array (0 to G_NUM_TAPS-1) of signed(C_PROD_W-1 downto 0);
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

  -- DSP-internal-style pipeline registers per tap
  signal a_r : sample_arr_t := (others => (others => '0'));  -- DSP A reg  (stage 1)
  signal m_r : prod_arr_t   := (others => (others => '0'));  -- DSP M reg  (stage 2)

  -- product values mapped to DSP slices
  attribute USE_DSP : string;
  attribute USE_DSP of m_r : signal is "yes";

  -- pipelined adder tree (same as Lab 2, shifted one stage later)
  signal l0_r   : acc4_t := (others => (others => '0'));  -- stage 3
  signal l1_r   : acc2_t := (others => (others => '0'));  -- stage 4
  signal result_r : signed(C_PROD_W-1 downto 0) := (others => '0');  -- stage 5

  signal valid_pipe : std_logic_vector(C_LAT-1 downto 0) := (others => '0');

begin

  p_fir : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        delay_line <= (others => (others => '0'));
        valid_pipe <= (others => '0');
        result_r   <= (others => '0');
      else
        if sample_valid_i = '1' then
          delay_line <= sample_data_i & delay_line(0 to G_NUM_TAPS-2);
        end if;
        valid_pipe <= valid_pipe(C_LAT-2 downto 0) & sample_valid_i;

        -- STAGE 1: DSP A register (operand into the DSP)
        for i in 0 to G_NUM_TAPS-1 loop
          if i = 0 then
            a_r(i) <= sample_data_i;
          else
            a_r(i) <= delay_line(i-1);
          end if;
        end loop;

        -- STAGE 2: DSP M register (the pipelined multiply, in-DSP)
        for i in 0 to G_NUM_TAPS-1 loop
          m_r(i) <= a_r(i) * C_COEFF(i);
        end loop;

        -- STAGE 3: tree level 0
        for j in 0 to 3 loop
          l0_r(j) <= resize(m_r(2*j), C_ACC_W) + resize(m_r(2*j+1), C_ACC_W);
        end loop;

        -- STAGE 4: tree level 1
        for k in 0 to 1 loop
          l1_r(k) <= resize(l0_r(2*k) + l0_r(2*k+1), C_ACC_W);
        end loop;

        -- STAGE 5: tree level 2 -> result
        result_r <= resize(l1_r(0) + l1_r(1), C_PROD_W);
      end if;
    end if;
  end process;

  result_valid_o <= valid_pipe(C_LAT-1);
  result_data_o  <= result_r;

end architecture;
