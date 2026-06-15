--------------------------------------------------------------------------------
-- File    : register_bank.vhd
-- Purpose : Control and status registers. Demonstrates flip-flop inference,
--           reset strategy, and the KEEP attribute on debug nets.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.synth_demo_pkg.all;

entity register_bank is
  generic (
    G_SAMPLE_W : positive := 16
  );
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;  -- synchronous active-high reset

    -- Control strobes from command_parser
    start_i        : in  std_logic;
    stop_i         : in  std_logic;
    clear_i        : in  std_logic;

    -- Status inputs from datapath
    busy_i         : in  std_logic;
    error_i        : in  std_logic;
    sample_count_i : in  unsigned(15 downto 0);

    -- Control outputs to datapath
    enable_o       : out std_logic;
    clear_o        : out std_logic;
    threshold_o    : out signed(G_SAMPLE_W-1 downto 0);

    -- Status output for read-back
    status_o       : out byte_t
  );
end entity;

architecture rtl of register_bank is

  constant C_THRESHOLD_DEFAULT : integer := 512;

  signal ctrl_enable : std_logic := '0';
  signal clear_r     : std_logic := '0';
  signal status_r    : byte_t    := (others => '0');
  signal threshold_r : signed(G_SAMPLE_W-1 downto 0)
                       := to_signed(C_THRESHOLD_DEFAULT, G_SAMPLE_W);

  signal dbg_reg : std_logic_vector(G_SAMPLE_W-1 downto 0) := (others => '0');

  -- Keep the debug register even though nothing downstream reads it.
  attribute KEEP : string;
  attribute KEEP of dbg_reg : signal is "TRUE";

begin

  p_regs : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        ctrl_enable <= '0';
        clear_r     <= '0';
        threshold_r <= to_signed(C_THRESHOLD_DEFAULT, G_SAMPLE_W);
        status_r    <= (others => '0');
      else
        -- Control register: set on START, cleared on STOP
        if start_i = '1' then
          ctrl_enable <= '1';
        elsif stop_i = '1' then
          ctrl_enable <= '0';
        end if;

        -- Clear strobe passthrough (registered)
        clear_r <= clear_i;

        -- Threshold register. START reloads it to the default so the register
        -- keeps a real write path (without one it would be constant-folded
        -- away during synthesis). CLEAR is left as a pure buffer reset, so the
        -- above-threshold LED stays off across repeated clears.
        if start_i = '1' then
          threshold_r <= to_signed(C_THRESHOLD_DEFAULT, G_SAMPLE_W);
        end if;

        -- Status register: busy / error flags plus sample count snapshot
        status_r <= busy_i & error_i & std_logic_vector(sample_count_i(5 downto 0));

        -- Debug register, preserved by the KEEP attribute
        dbg_reg <= std_logic_vector(threshold_r) xor
                   std_logic_vector(resize(sample_count_i, G_SAMPLE_W));
      end if;
    end if;
  end process;

  enable_o    <= ctrl_enable;
  clear_o     <= clear_r;
  threshold_o <= threshold_r;
  status_o    <= status_r;

end architecture;
