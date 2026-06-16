--------------------------------------------------------------------------------
-- File    : fir_top.vhd  (shared wrapper pattern for all labs)
-- Purpose : Thin synthesizable top that registers ALL I/O into flip-flops, so
--           the only timing-critical logic is INSIDE the FIR. Without this, the
--           critical path could be an I/O pad path and the lesson would be lost.
--
--           Sample input and result output are serialized to single-bit-ish
--           ports only conceptually; here we keep full buses but register them
--           hard at the boundary. The point is pedagogical isolation, not a real
--           board interface (the main project provides the real UART interface).
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fir_top is
  generic (
    G_SAMPLE_W : positive := 16;
    G_COEFF_W  : positive := 16;
    G_NUM_TAPS : positive := 8
  );
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;
    sample_valid_i : in  std_logic;
    sample_data_i  : in  std_logic_vector(G_SAMPLE_W-1 downto 0);
    result_valid_o : out std_logic;
    result_data_o  : out std_logic_vector(G_SAMPLE_W+G_COEFF_W-1 downto 0)
  );
end entity;

architecture rtl of fir_top is
  signal s_valid_q : std_logic := '0';
  signal s_data_q  : signed(G_SAMPLE_W-1 downto 0) := (others => '0');
  signal r_valid   : std_logic;
  signal r_data    : signed(G_SAMPLE_W+G_COEFF_W-1 downto 0);
  signal r_valid_q : std_logic := '0';
  signal r_data_q  : std_logic_vector(G_SAMPLE_W+G_COEFF_W-1 downto 0) := (others => '0');
begin

  -- Input registers (push toward IOB)
  p_in : process (clk)
  begin
    if rising_edge(clk) then
      s_valid_q <= sample_valid_i;
      s_data_q  <= signed(sample_data_i);
    end if;
  end process;

  u_fir : entity work.fir_parallel
    generic map (
      G_SAMPLE_W => G_SAMPLE_W,
      G_COEFF_W  => G_COEFF_W,
      G_NUM_TAPS => G_NUM_TAPS
    )
    port map (
      clk            => clk,
      rst            => rst,
      sample_valid_i => s_valid_q,
      sample_data_i  => s_data_q,
      result_valid_o => r_valid,
      result_data_o  => r_data
    );

  -- Output registers (push toward IOB)
  p_out : process (clk)
  begin
    if rising_edge(clk) then
      r_valid_q <= r_valid;
      r_data_q  <= std_logic_vector(r_data);
    end if;
  end process;

  result_valid_o <= r_valid_q;
  result_data_o  <= r_data_q;

end architecture;
