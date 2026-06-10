--------------------------------------------------------------------------------
-- File    : uart_tx.vhd
-- Purpose : UART transmitter, 8-N-1 format, ready/valid input interface.
--           Demonstrates FSM inference, counters, and shift registers.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
  generic (
    G_CLK_FREQ_HZ : positive := 100_000_000;
    G_UART_BAUD   : positive := 115_200
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;  -- synchronous active-high reset

    tx_valid_i : in  std_logic;
    tx_data_i  : in  std_logic_vector(7 downto 0);
    tx_ready_o : out std_logic;

    tx_o       : out std_logic;  -- serial output line
    tx_busy_o  : out std_logic
  );
end entity;

architecture rtl of uart_tx is

  constant C_BAUD_DIV : positive := G_CLK_FREQ_HZ / G_UART_BAUD;

  type tx_state_t is (ST_IDLE, ST_START, ST_DATA, ST_STOP);
  signal state : tx_state_t := ST_IDLE;

  signal baud_cnt : natural range 0 to C_BAUD_DIV-1 := 0;
  signal bit_cnt  : natural range 0 to 7            := 0;
  signal shreg    : std_logic_vector(7 downto 0)    := (others => '0');
  signal tx_r     : std_logic := '1';
  signal ready    : std_logic := '1';

begin

  p_fsm : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state    <= ST_IDLE;
        baud_cnt <= 0;
        bit_cnt  <= 0;
        tx_r     <= '1';
        ready    <= '1';
      else
        case state is

          when ST_IDLE =>
            tx_r  <= '1';
            ready <= '1';
            if tx_valid_i = '1' then
              shreg    <= tx_data_i;
              ready    <= '0';
              baud_cnt <= 0;
              state    <= ST_START;
            end if;

          when ST_START =>
            tx_r <= '0';                -- start bit
            if baud_cnt = C_BAUD_DIV-1 then
              baud_cnt <= 0;
              bit_cnt  <= 0;
              state    <= ST_DATA;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

          when ST_DATA =>
            tx_r <= shreg(0);           -- LSB first
            if baud_cnt = C_BAUD_DIV-1 then
              baud_cnt <= 0;
              shreg    <= '1' & shreg(7 downto 1);
              if bit_cnt = 7 then
                state <= ST_STOP;
              else
                bit_cnt <= bit_cnt + 1;
              end if;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

          when ST_STOP =>
            tx_r <= '1';                -- stop bit
            if baud_cnt = C_BAUD_DIV-1 then
              baud_cnt <= 0;
              state    <= ST_IDLE;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

  tx_o       <= tx_r;
  tx_ready_o <= ready;
  tx_busy_o  <= not ready;

end architecture;
