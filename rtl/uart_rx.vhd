--------------------------------------------------------------------------------
-- File    : uart_rx.vhd
-- Purpose : UART receiver, 8-N-1 format. Demonstrates FSM inference,
--           counters, and shift registers.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
  generic (
    G_CLK_FREQ_HZ : positive := 100_000_000;
    G_UART_BAUD   : positive := 115_200
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;  -- synchronous active-high reset

    rx_i       : in  std_logic;  -- serial input line

    rx_valid_o : out std_logic;  -- one-cycle pulse when a byte is received
    rx_data_o  : out std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of uart_rx is

  constant C_BAUD_DIV : positive := G_CLK_FREQ_HZ / G_UART_BAUD;

  type rx_state_t is (ST_IDLE, ST_START, ST_DATA, ST_STOP, ST_VALID);
  signal state : rx_state_t := ST_IDLE;

  -- 2-FF synchronizer for the asynchronous serial input
  signal rx_meta : std_logic := '1';
  signal rx_sync : std_logic := '1';

  attribute ASYNC_REG : string;
  attribute ASYNC_REG of rx_meta : signal is "TRUE";
  attribute ASYNC_REG of rx_sync : signal is "TRUE";

  signal baud_cnt : natural range 0 to C_BAUD_DIV-1 := 0;
  signal bit_cnt  : natural range 0 to 7            := 0;
  signal shreg    : std_logic_vector(7 downto 0)    := (others => '0');
  signal rx_valid : std_logic := '0';

begin

  -- Input double-register synchronizer
  p_sync : process (clk)
  begin
    if rising_edge(clk) then
      rx_meta <= rx_i;
      rx_sync <= rx_meta;
    end if;
  end process;

  -- Receive FSM: IDLE -> START -> DATA -> STOP -> VALID
  p_fsm : process (clk)
  begin
    if rising_edge(clk) then
      rx_valid <= '0';

      if rst = '1' then
        state    <= ST_IDLE;
        baud_cnt <= 0;
        bit_cnt  <= 0;
      else
        case state is

          when ST_IDLE =>
            if rx_sync = '0' then       -- start bit edge detected
              state    <= ST_START;
              baud_cnt <= 0;
            end if;

          when ST_START =>
            -- Wait half a bit period and re-check the start bit (glitch filter)
            if baud_cnt = C_BAUD_DIV/2 - 1 then
              baud_cnt <= 0;
              if rx_sync = '0' then
                state   <= ST_DATA;
                bit_cnt <= 0;
              else
                state <= ST_IDLE;       -- false start
              end if;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

          when ST_DATA =>
            -- Sample each data bit in its center, LSB first
            if baud_cnt = C_BAUD_DIV-1 then
              baud_cnt <= 0;
              shreg    <= rx_sync & shreg(7 downto 1);
              if bit_cnt = 7 then
                state <= ST_STOP;
              else
                bit_cnt <= bit_cnt + 1;
              end if;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

          when ST_STOP =>
            if baud_cnt = C_BAUD_DIV-1 then
              baud_cnt <= 0;
              if rx_sync = '1' then     -- valid stop bit
                state <= ST_VALID;
              else
                state <= ST_IDLE;       -- framing error, drop byte
              end if;
            else
              baud_cnt <= baud_cnt + 1;
            end if;

          when ST_VALID =>
            rx_valid <= '1';
            state    <= ST_IDLE;

        end case;
      end if;
    end if;
  end process;

  rx_valid_o <= rx_valid;
  rx_data_o  <= shreg;

end architecture;
