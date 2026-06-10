--------------------------------------------------------------------------------
-- File    : packet_formatter.vhd
-- Purpose : Format status/sample data into bytes for UART transmission.
--           Demonstrates FSM inference and multiplexing logic.
--
--           Packet on send_status_i : [status][sample MSB..LSB]['D']
--           Packet on send_sample_i : [sample MSB..LSB]['D']
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.synth_demo_pkg.all;

entity packet_formatter is
  generic (
    G_DATA_W : positive := 32  -- must be a multiple of 8
  );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;  -- synchronous active-high reset

    -- Request interface (one-cycle pulses, ignored while busy)
    send_status_i : in  std_logic;
    send_sample_i : in  std_logic;
    status_i      : in  byte_t;
    sample_i      : in  std_logic_vector(G_DATA_W-1 downto 0);

    busy_o        : out std_logic;

    -- Byte stream towards uart_tx (ready/valid)
    tx_valid_o    : out std_logic;
    tx_data_o     : out byte_t;
    tx_ready_i    : in  std_logic
  );
end entity;

architecture rtl of packet_formatter is

  constant C_SAMPLE_BYTES : positive := G_DATA_W / 8;

  type fmt_state_t is (F_IDLE, F_STATUS, F_SAMPLE, F_DONE);
  signal state : fmt_state_t := F_IDLE;

  signal status_hold : byte_t := (others => '0');
  signal data_sh     : std_logic_vector(G_DATA_W-1 downto 0) := (others => '0');
  signal byte_cnt    : natural range 0 to C_SAMPLE_BYTES-1   := 0;

  signal tx_valid_r : std_logic := '0';
  signal tx_data_r  : byte_t    := (others => '0');

begin

  p_fsm : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state      <= F_IDLE;
        tx_valid_r <= '0';
      else
        case state is

          when F_IDLE =>
            if send_status_i = '1' then
              status_hold <= status_i;
              data_sh     <= sample_i;
              state       <= F_STATUS;
            elsif send_sample_i = '1' then
              data_sh  <= sample_i;
              byte_cnt <= 0;
              state    <= F_SAMPLE;
            end if;

          when F_STATUS =>
            if tx_valid_r = '0' then
              tx_valid_r <= '1';
              tx_data_r  <= status_hold;
            elsif tx_ready_i = '1' then
              tx_valid_r <= '0';
              byte_cnt   <= 0;
              state      <= F_SAMPLE;
            end if;

          when F_SAMPLE =>
            -- Serialize the sample word MSB-byte first via a left shift
            if tx_valid_r = '0' then
              tx_valid_r <= '1';
              tx_data_r  <= data_sh(G_DATA_W-1 downto G_DATA_W-8);
            elsif tx_ready_i = '1' then
              tx_valid_r <= '0';
              data_sh    <= data_sh(G_DATA_W-9 downto 0) & x"00";
              if byte_cnt = C_SAMPLE_BYTES-1 then
                state <= F_DONE;
              else
                byte_cnt <= byte_cnt + 1;
              end if;
            end if;

          when F_DONE =>
            -- ASCII 'D' terminator byte
            if tx_valid_r = '0' then
              tx_valid_r <= '1';
              tx_data_r  <= C_RSP_DONE;
            elsif tx_ready_i = '1' then
              tx_valid_r <= '0';
              state      <= F_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

  busy_o     <= '0' when state = F_IDLE else '1';
  tx_valid_o <= tx_valid_r;
  tx_data_o  <= tx_data_r;

end architecture;
