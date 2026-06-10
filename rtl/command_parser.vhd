--------------------------------------------------------------------------------
-- File    : command_parser.vhd
-- Purpose : Decode UART command bytes and generate control strobes.
--           Demonstrates FSM inference, FSM_ENCODING, and MARK_DEBUG.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.synth_demo_pkg.all;

entity command_parser is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;  -- synchronous active-high reset

    -- From uart_rx
    rx_valid_i    : in  std_logic;
    rx_data_i     : in  byte_t;

    -- Control strobes (one-cycle pulses)
    start_o       : out std_logic;
    stop_o        : out std_logic;
    clear_o       : out std_logic;
    read_status_o : out std_logic;

    -- Response byte towards uart_tx (ready/valid)
    rsp_valid_o   : out std_logic;
    rsp_data_o    : out byte_t;
    rsp_ready_i   : in  std_logic;

    -- Parser state exposed for debug
    parser_state_dbg_o : out std_logic_vector(1 downto 0)
  );
end entity;

architecture rtl of command_parser is

  signal parser_state : parser_state_t := ST_IDLE;

  -- Let Vivado choose the state encoding (one-hot, gray, ...) and report it.
  attribute FSM_ENCODING : string;
  attribute FSM_ENCODING of parser_state : signal is "auto";

  signal cmd_byte : byte_t := (others => '0');
  signal cmd_ok   : std_logic := '0';

  signal start_r, stop_r, clear_r, read_status_r : std_logic := '0';
  signal rsp_valid_r : std_logic := '0';
  signal rsp_data_r  : byte_t    := (others => '0');

  signal parser_state_dbg : std_logic_vector(1 downto 0) := "00";

  -- Preserve the debug encoding of the state for an ILA probe.
  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of parser_state_dbg : signal is "TRUE";

begin

  p_fsm : process (clk)
  begin
    if rising_edge(clk) then
      -- Strobes default to zero -> one-cycle pulses
      start_r       <= '0';
      stop_r        <= '0';
      clear_r       <= '0';
      read_status_r <= '0';

      if rst = '1' then
        parser_state <= ST_IDLE;
        rsp_valid_r  <= '0';
      else
        case parser_state is

          when ST_IDLE =>
            if rx_valid_i = '1' then
              cmd_byte     <= rx_data_i;
              parser_state <= ST_DECODE;
            end if;

          when ST_DECODE =>
            if cmd_byte = C_CMD_START or cmd_byte = C_CMD_STOP or
               cmd_byte = C_CMD_READ_STAT or cmd_byte = C_CMD_CLEAR then
              cmd_ok <= '1';
            else
              cmd_ok <= '0';
            end if;
            parser_state <= ST_EXECUTE;

          when ST_EXECUTE =>
            if cmd_byte = C_CMD_START then
              start_r <= '1';
            elsif cmd_byte = C_CMD_STOP then
              stop_r <= '1';
            elsif cmd_byte = C_CMD_CLEAR then
              clear_r <= '1';
            elsif cmd_byte = C_CMD_READ_STAT then
              read_status_r <= '1';
            end if;

            if cmd_ok = '1' then
              rsp_data_r <= C_RSP_ACK;
            else
              rsp_data_r <= C_RSP_ERROR;
            end if;
            rsp_valid_r  <= '1';
            parser_state <= ST_REPLY;

          when ST_REPLY =>
            if rsp_valid_r = '1' and rsp_ready_i = '1' then
              rsp_valid_r  <= '0';
              parser_state <= ST_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

  start_o       <= start_r;
  stop_o        <= stop_r;
  clear_o       <= clear_r;
  read_status_o <= read_status_r;

  rsp_valid_o <= rsp_valid_r;
  rsp_data_o  <= rsp_data_r;

  with parser_state select parser_state_dbg <=
    "00" when ST_IDLE,
    "01" when ST_DECODE,
    "10" when ST_EXECUTE,
    "11" when ST_REPLY;

  parser_state_dbg_o <= parser_state_dbg;

end architecture;
