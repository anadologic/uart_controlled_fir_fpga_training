--------------------------------------------------------------------------------
-- File    : sample_generator.vhd
-- Purpose : Generate input samples for the FIR filter (no external ADC
--           needed). Demonstrates counters and arithmetic logic.
--           Produces a triangle wave, one sample every C_RATE_DIV clocks.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sample_generator is
  generic (
    G_SAMPLE_W : positive := 16
  );
  port (
    clk            : in  std_logic;
    rst            : in  std_logic;  -- synchronous active-high reset

    enable_i       : in  std_logic;  -- generate samples while asserted

    sample_valid_o : out std_logic;
    sample_data_o  : out signed(G_SAMPLE_W-1 downto 0);
    sample_ready_i : in  std_logic
  );
end entity;

architecture rtl of sample_generator is

  -- New sample every 256 clock cycles (slow enough for the sequential FIR)
  constant C_RATE_DIV : positive := 256;

  -- Triangle amplitude and step
  constant C_AMPLITUDE : integer := 2**(G_SAMPLE_W-3);
  constant C_STEP      : integer := 64;

  signal tick_cnt : natural range 0 to C_RATE_DIV-1 := 0;
  signal wave     : signed(G_SAMPLE_W-1 downto 0)   := (others => '0');
  signal dir_up   : std_logic := '1';
  signal valid_r  : std_logic := '0';

begin

  p_gen : process (clk)
  begin
    if rising_edge(clk) then
      valid_r <= '0';

      if rst = '1' then
        tick_cnt <= 0;
        wave     <= (others => '0');
        dir_up   <= '1';
      elsif enable_i = '1' then
        if tick_cnt = C_RATE_DIV-1 then
          tick_cnt <= 0;
          if sample_ready_i = '1' then
            -- Triangle wave: count up to +C_AMPLITUDE, down to -C_AMPLITUDE
            if dir_up = '1' then
              if wave >= to_signed(C_AMPLITUDE, G_SAMPLE_W) then
                dir_up <= '0';
                wave   <= wave - C_STEP;
              else
                wave <= wave + C_STEP;
              end if;
            else
              if wave <= to_signed(-C_AMPLITUDE, G_SAMPLE_W) then
                dir_up <= '1';
                wave   <= wave + C_STEP;
              else
                wave <= wave - C_STEP;
              end if;
            end if;
            valid_r <= '1';
          end if;
        else
          tick_cnt <= tick_cnt + 1;
        end if;
      end if;
    end if;
  end process;

  sample_valid_o <= valid_r;
  sample_data_o  <= wave;

end architecture;
