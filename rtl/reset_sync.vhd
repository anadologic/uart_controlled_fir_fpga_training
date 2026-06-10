--------------------------------------------------------------------------------
-- File    : reset_sync.vhd
-- Purpose : Synchronize the external active-low reset into the system clock
--           domain. Demonstrates the ASYNC_REG attribute.
--           Asynchronous assertion, synchronous de-assertion.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity reset_sync is
  generic (
    G_SYNC_STAGES : positive := 3
  );
  port (
    clk   : in  std_logic;
    rst_n : in  std_logic;  -- asynchronous active-low reset input
    rst_o : out std_logic   -- synchronized active-high reset output
  );
end entity;

architecture rtl of reset_sync is

  signal rst_sync_ff : std_logic_vector(G_SYNC_STAGES-1 downto 0) := (others => '1');

  -- Tell Vivado these registers form an asynchronous synchronizer chain.
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of rst_sync_ff : signal is "TRUE";

begin

  p_sync : process (clk, rst_n)
  begin
    if rst_n = '0' then
      rst_sync_ff <= (others => '1');
    elsif rising_edge(clk) then
      rst_sync_ff <= rst_sync_ff(G_SYNC_STAGES-2 downto 0) & '0';
    end if;
  end process;

  rst_o <= rst_sync_ff(G_SYNC_STAGES-1);

end architecture;
