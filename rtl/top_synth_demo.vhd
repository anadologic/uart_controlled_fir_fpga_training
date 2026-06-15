--------------------------------------------------------------------------------
-- File    : top_synth_demo.vhd
-- Purpose : Top-level entity of the UART-controlled FIR processing demo.
--           Demonstrates hierarchical structure, KEEP_HIERARCHY, MARK_DEBUG,
--           and IOB attributes.
--
-- Command protocol (8-N-1 UART, default 115200 baud):
--   'S' : start sample generation / filtering    -> reply 'A'
--   'X' : stop                                   -> reply 'A'
--   'C' : clear sample RAM write pointer/counter -> reply 'A'
--   'R' : read status                            -> reply 'A' then
--         [status][last sample MSB..LSB]['D']
--   other bytes                                  -> reply 'E'
--
-- LEDs:
--   led_o(0) : processing enabled
--   led_o(1) : sample RAM full
--   led_o(2) : last filtered sample above threshold
--   led_o(3) : heartbeat blink
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.synth_demo_pkg.all;

entity top_synth_demo is
  generic (
    G_CLK_FREQ_HZ : positive := 100_000_000;
    G_UART_BAUD   : positive := 115_200;
    G_SAMPLE_W    : positive := 16;
    G_COEFF_W     : positive := 16;
    G_NUM_TAPS    : positive := 8;
    G_RAM_DEPTH   : positive := 1024
  );
  port (
    clk       : in  std_logic;
    rst_n     : in  std_logic;

    uart_rx_i : in  std_logic;
    uart_tx_o : out std_logic;

    led_o     : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of top_synth_demo is

  constant C_RESULT_W : positive := G_SAMPLE_W + G_COEFF_W;
  constant C_ADDR_W   : positive := clog2(G_RAM_DEPTH);

  -- Reset
  signal rst : std_logic;

  -- UART RX
  signal rx_valid : std_logic;
  signal rx_data  : byte_t;

  -- Command parser
  signal start_s, stop_s, clear_s, read_status_s : std_logic;
  signal rsp_valid, rsp_ready : std_logic;
  signal rsp_data : byte_t;
  signal parser_state_dbg : std_logic_vector(1 downto 0);

  -- Register bank
  signal enable_s    : std_logic;
  signal clear_pulse : std_logic;
  signal threshold_s : signed(G_SAMPLE_W-1 downto 0);
  signal status_s    : byte_t;
  signal busy_s      : std_logic;

  -- Sample generator -> FIR
  signal gen_enable : std_logic;
  signal gen_valid  : std_logic;
  signal gen_data   : signed(G_SAMPLE_W-1 downto 0);
  signal fir_valid  : std_logic;
  signal fir_data   : signed(C_RESULT_W-1 downto 0);

  -- Sample RAM
  signal ram_wr_en    : std_logic;
  signal wr_addr      : unsigned(C_ADDR_W-1 downto 0) := (others => '0');
  signal rd_addr      : unsigned(C_ADDR_W-1 downto 0);
  signal ram_rd_data  : std_logic_vector(C_RESULT_W-1 downto 0);
  signal ram_full     : std_logic := '0';
  signal sample_count : unsigned(15 downto 0) := (others => '0');

  -- Packet formatter
  signal fmt_busy      : std_logic;
  signal fmt_valid     : std_logic;
  signal fmt_ready     : std_logic;
  signal fmt_data      : byte_t;
  signal status_pend   : std_logic := '0';
  signal send_status_p : std_logic := '0';

  -- UART TX shared stream (parser response has priority)
  signal tx_valid : std_logic;
  signal tx_ready : std_logic;
  signal tx_data  : byte_t;

  -- LEDs
  signal heartbeat_cnt : unsigned(25 downto 0) := (others => '0');
  signal last_sample   : signed(G_SAMPLE_W-1 downto 0) := (others => '0');
  signal led_reg       : std_logic_vector(3 downto 0)  := (others => '0');

  -- Expose the parser state to the hardware debugger (ILA)
  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of parser_state_dbg : signal is "TRUE";

  -- Keep the FIR filter as a separate level in the synthesized netlist
  attribute KEEP_HIERARCHY : string;
  attribute KEEP_HIERARCHY of u_fir_filter : label is "yes";

  -- Pack the LED output registers into the I/O blocks
  attribute IOB : string;
  attribute IOB of led_reg : signal is "TRUE";

begin

  ------------------------------------------------------------------------------
  -- Reset synchronizer
  ------------------------------------------------------------------------------
  u_reset_sync : entity work.reset_sync
    generic map (
      G_SYNC_STAGES => 3
    )
    port map (
      clk   => clk,
      rst_n => rst_n,
      rst_o => rst
    );

  ------------------------------------------------------------------------------
  -- UART receive and command decode
  ------------------------------------------------------------------------------
  u_uart_rx : entity work.uart_rx
    generic map (
      G_CLK_FREQ_HZ => G_CLK_FREQ_HZ,
      G_UART_BAUD   => G_UART_BAUD
    )
    port map (
      clk        => clk,
      rst        => rst,
      rx_i       => uart_rx_i,
      rx_valid_o => rx_valid,
      rx_data_o  => rx_data
    );

  u_command_parser : entity work.command_parser
    port map (
      clk                => clk,
      rst                => rst,
      rx_valid_i         => rx_valid,
      rx_data_i          => rx_data,
      start_o            => start_s,
      stop_o             => stop_s,
      clear_o            => clear_s,
      read_status_o      => read_status_s,
      rsp_valid_o        => rsp_valid,
      rsp_data_o         => rsp_data,
      rsp_ready_i        => rsp_ready,
      parser_state_dbg_o => parser_state_dbg
    );

  u_register_bank : entity work.register_bank
    generic map (
      G_SAMPLE_W => G_SAMPLE_W
    )
    port map (
      clk            => clk,
      rst            => rst,
      start_i        => start_s,
      stop_i         => stop_s,
      clear_i        => clear_s,
      busy_i         => busy_s,
      error_i        => ram_full,
      sample_count_i => sample_count,
      enable_o       => enable_s,
      clear_o        => clear_pulse,
      threshold_o    => threshold_s,
      status_o       => status_s
    );

  busy_s <= enable_s and not ram_full;

  ------------------------------------------------------------------------------
  -- Processing datapath: generator -> FIR -> RAM
  ------------------------------------------------------------------------------
  gen_enable <= enable_s and not ram_full;

  u_sample_generator : entity work.sample_generator
    generic map (
      G_SAMPLE_W => G_SAMPLE_W
    )
    port map (
      clk            => clk,
      rst            => rst,
      enable_i       => gen_enable,
      sample_valid_o => gen_valid,
      sample_data_o  => gen_data,
      sample_ready_i => '1'  -- the sequential FIR always finishes in time
    );

  u_fir_filter : entity work.fir_filter
    generic map (
      G_SAMPLE_W => G_SAMPLE_W,
      G_COEFF_W  => G_COEFF_W,
      G_NUM_TAPS => G_NUM_TAPS
    )
    port map (
      clk            => clk,
      rst            => rst,
      sample_valid_i => gen_valid,
      sample_data_i  => gen_data,
      result_valid_o => fir_valid,
      result_data_o  => fir_data
    );

  ram_wr_en <= fir_valid and not ram_full;

  u_sample_ram : entity work.sample_ram
    generic map (
      G_DATA_W => C_RESULT_W,
      G_DEPTH  => G_RAM_DEPTH
    )
    port map (
      clk       => clk,
      wr_en_i   => ram_wr_en,
      wr_addr_i => wr_addr,
      wr_data_i => std_logic_vector(fir_data),
      rd_en_i   => '1',
      rd_addr_i => rd_addr,
      rd_data_o => ram_rd_data
    );

  -- Read back the most recently written sample
  rd_addr <= wr_addr - 1;

  -- Write pointer / sample counter / full flag
  p_wr_ctrl : process (clk)
  begin
    if rising_edge(clk) then
      if rst = '1' or clear_pulse = '1' then
        wr_addr      <= (others => '0');
        sample_count <= (others => '0');
        ram_full     <= '0';
      elsif ram_wr_en = '1' then
        if wr_addr = G_RAM_DEPTH-1 then
          ram_full <= '1';
        else
          wr_addr <= wr_addr + 1;
        end if;
        sample_count <= sample_count + 1;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Status read-back: latch the request until the formatter is free
  ------------------------------------------------------------------------------
  p_status_req : process (clk)
  begin
    if rising_edge(clk) then
      send_status_p <= '0';
      if rst = '1' then
        status_pend <= '0';
      else
        if read_status_s = '1' then
          status_pend <= '1';
        end if;
        if status_pend = '1' and fmt_busy = '0' and send_status_p = '0' then
          send_status_p <= '1';
          status_pend   <= '0';
        end if;
      end if;
    end if;
  end process;

  u_packet_formatter : entity work.packet_formatter
    generic map (
      G_DATA_W => C_RESULT_W
    )
    port map (
      clk           => clk,
      rst           => rst,
      send_status_i => send_status_p,
      send_sample_i => '0',
      status_i      => status_s,
      sample_i      => ram_rd_data,
      busy_o        => fmt_busy,
      tx_valid_o    => fmt_valid,
      tx_data_o     => fmt_data,
      tx_ready_i    => fmt_ready
    );

  ------------------------------------------------------------------------------
  -- UART TX with simple priority mux (parser response wins)
  ------------------------------------------------------------------------------
  tx_valid  <= rsp_valid or fmt_valid;
  tx_data   <= rsp_data when rsp_valid = '1' else fmt_data;
  rsp_ready <= tx_ready;
  fmt_ready <= tx_ready and not rsp_valid;

  u_uart_tx : entity work.uart_tx
    generic map (
      G_CLK_FREQ_HZ => G_CLK_FREQ_HZ,
      G_UART_BAUD   => G_UART_BAUD
    )
    port map (
      clk        => clk,
      rst        => rst,
      tx_valid_i => tx_valid,
      tx_data_i  => tx_data,
      tx_ready_o => tx_ready,
      tx_o       => uart_tx_o,
      tx_busy_o  => open
    );

  ------------------------------------------------------------------------------
  -- LEDs (registered outputs, packed into IOBs)
  ------------------------------------------------------------------------------
  p_leds : process (clk)
  begin
    if rising_edge(clk) then
      heartbeat_cnt <= heartbeat_cnt + 1;

      -- CLEAR resets the latched sample so LED2 (above-threshold) clears too.
      if rst = '1' or clear_pulse = '1' then
        last_sample <= (others => '0');
      elsif fir_valid = '1' then
        -- Scale the filter result back to sample width for the compare
        last_sample <= fir_data(C_RESULT_W-1 downto G_COEFF_W);
      end if;

      led_reg(0) <= enable_s;
      led_reg(1) <= ram_full;
      if last_sample > threshold_s then
        led_reg(2) <= '1';
      else
        led_reg(2) <= '0';
      end if;
      led_reg(3) <= heartbeat_cnt(heartbeat_cnt'high);
    end if;
  end process;

  led_o <= led_reg;

end architecture;
