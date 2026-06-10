--------------------------------------------------------------------------------
-- File    : sample_ram.vhd
-- Purpose : Single-clock RAM storing filtered samples.
--           Demonstrates block RAM inference and the RAM_STYLE attribute.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.synth_demo_pkg.all;

entity sample_ram is
  generic (
    G_DATA_W : positive := 32;
    G_DEPTH  : positive := 1024
  );
  port (
    clk       : in  std_logic;

    -- Write port
    wr_en_i   : in  std_logic;
    wr_addr_i : in  unsigned(clog2(G_DEPTH)-1 downto 0);
    wr_data_i : in  std_logic_vector(G_DATA_W-1 downto 0);

    -- Read port
    rd_en_i   : in  std_logic;
    rd_addr_i : in  unsigned(clog2(G_DEPTH)-1 downto 0);
    rd_data_o : out std_logic_vector(G_DATA_W-1 downto 0)
  );
end entity;

architecture rtl of sample_ram is

  type ram_t is array (0 to G_DEPTH-1) of std_logic_vector(G_DATA_W-1 downto 0);
  signal sample_mem : ram_t := (others => (others => '0'));

  -- Guide Vivado to infer block RAM (try "distributed" to compare LUTRAM).
  attribute RAM_STYLE : string;
  attribute RAM_STYLE of sample_mem : signal is "block";

begin

  p_write : process (clk)
  begin
    if rising_edge(clk) then
      if wr_en_i = '1' then
        sample_mem(to_integer(wr_addr_i)) <= wr_data_i;
      end if;
    end if;
  end process;

  -- Registered read (synchronous read is required for BRAM inference)
  p_read : process (clk)
  begin
    if rising_edge(clk) then
      if rd_en_i = '1' then
        rd_data_o <= sample_mem(to_integer(rd_addr_i));
      end if;
    end if;
  end process;

end architecture;
