--------------------------------------------------------------------------------
-- File    : tb_top_synth_demo.vhd
-- Purpose : System-level testbench for top_synth_demo.
--           Acts as the PC terminal: sends UART command bytes and checks the
--           UART replies against the command protocol.
--
--           Sequence:
--             'Z' (unknown)     -> expect 'E'
--             'S' (start)       -> expect 'A', LED0 on
--             wait ~300 us      -> samples flow through the FIR into the RAM
--             'R' (read status) -> expect 'A' [status][4 sample bytes]['D']
--             'X' (stop)        -> expect 'A', LED0 off
--             'C' (clear)       -> expect 'A'
--
--           Self-checking: reports TEST PASSED / TEST FAILED.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.synth_demo_pkg.all;

entity tb_top_synth_demo is
end entity;

architecture sim of tb_top_synth_demo is

  constant C_CLK_PERIOD : time := 10 ns;        -- 100 MHz
  constant C_BIT_TIME   : time := 8680 ns;      -- 1 / 115200 baud

  signal clk     : std_logic := '0';
  signal rst_n   : std_logic := '0';
  signal uart_rx : std_logic := '1';            -- TB -> DUT serial line
  signal uart_tx : std_logic;                   -- DUT -> TB serial line
  signal led     : std_logic_vector(3 downto 0);

  signal sim_done : boolean := false;

  -- Monitor mailbox: the monitor process receives every byte the DUT
  -- transmits and stores it here; the main process consumes them in order.
  type byte_arr_t is array (0 to 63) of byte_t;
  signal mon_buf : byte_arr_t := (others => (others => '0'));
  signal mon_wr  : natural := 0;

  -- Drive one 8-N-1 byte onto the DUT receive line
  procedure uart_send_byte(
    constant data : in  byte_t;
    signal   txd  : out std_logic) is
  begin
    txd <= '0';                       -- start bit
    wait for C_BIT_TIME;
    for i in 0 to 7 loop              -- data bits, LSB first
      txd <= data(i);
      wait for C_BIT_TIME;
    end loop;
    txd <= '1';                       -- stop bit
    wait for C_BIT_TIME;
  end procedure;

begin

  u_dut : entity work.top_synth_demo
    port map (
      clk       => clk,
      rst_n     => rst_n,
      uart_rx_i => uart_rx,
      uart_tx_o => uart_tx,
      led_o     => led
    );

  p_clk : process
  begin
    while not sim_done loop
      clk <= '0';
      wait for C_CLK_PERIOD/2;
      clk <= '1';
      wait for C_CLK_PERIOD/2;
    end loop;
    wait;
  end process;

  -- UART monitor: continuously deserializes bytes from the DUT TX line.
  -- Runs concurrently with the stimulus so no reply byte is ever missed.
  p_uart_monitor : process
    variable b : byte_t;
  begin
    wait until falling_edge(uart_tx);
    wait for C_BIT_TIME/2;            -- middle of the start bit
    for i in 0 to 7 loop
      wait for C_BIT_TIME;            -- middle of each data bit
      b(i) := uart_tx;
    end loop;
    wait for C_BIT_TIME;              -- middle of the stop bit
    assert uart_tx = '1'
      report "UART monitor: stop bit violation" severity error;
    mon_buf(mon_wr mod 64) <= b;
    mon_wr <= mon_wr + 1;
  end process;

  p_main : process
    variable mon_rd : natural := 0;
    variable errors : natural := 0;
    variable rx_b   : byte_t;
    variable tmo    : boolean;

    -- Fetch the next byte received by the monitor (with timeout)
    procedure get_byte(
      variable data : out byte_t;
      variable t    : out boolean) is
    begin
      t := false;
      if mon_wr <= mon_rd then
        wait until mon_wr > mon_rd for 2 ms;
      end if;
      if mon_wr <= mon_rd then
        t    := true;
        data := (others => 'X');
      else
        data   := mon_buf(mon_rd mod 64);
        mon_rd := mon_rd + 1;
      end if;
    end procedure;

    procedure expect_byte(
      constant expected : in byte_t;
      constant name     : in string) is
      variable b : byte_t;
      variable t : boolean;
    begin
      get_byte(b, t);
      if t then
        report "ERROR: timeout waiting for " & name severity error;
        errors := errors + 1;
      elsif b /= expected then
        report "ERROR: " & name & ": expected " &
               integer'image(to_integer(unsigned(expected))) &
               ", got " & integer'image(to_integer(unsigned(b)))
          severity error;
        errors := errors + 1;
      else
        report "OK: " & name;
      end if;
    end procedure;

  begin
    ----------------------------------------------------------------------
    -- Reset
    ----------------------------------------------------------------------
    rst_n <= '0';
    wait for 200 ns;
    rst_n <= '1';
    wait for 2 us;

    ----------------------------------------------------------------------
    -- Unknown command -> 'E'
    ----------------------------------------------------------------------
    report "Sending unknown command 'Z'";
    uart_send_byte(x"5A", uart_rx);
    expect_byte(C_RSP_ERROR, "error reply to unknown command");

    ----------------------------------------------------------------------
    -- Start -> 'A', processing enabled
    ----------------------------------------------------------------------
    report "Sending 'S' (start)";
    uart_send_byte(C_CMD_START, uart_rx);
    expect_byte(C_RSP_ACK, "ack for start");

    -- Let roughly a hundred samples flow through the FIR into the RAM
    wait for 300 us;

    if led(0) /= '1' then
      report "ERROR: LED0 (enabled) should be on after start" severity error;
      errors := errors + 1;
    else
      report "OK: LED0 on after start";
    end if;

    ----------------------------------------------------------------------
    -- Read status -> 'A' [status][4 sample bytes]['D']
    ----------------------------------------------------------------------
    report "Sending 'R' (read status)";
    uart_send_byte(C_CMD_READ_STAT, uart_rx);
    expect_byte(C_RSP_ACK, "ack for read status");

    -- Status byte: bit7 = busy (must be 1), bit6 = RAM full (must be 0)
    get_byte(rx_b, tmo);
    if tmo then
      report "ERROR: timeout waiting for status byte" severity error;
      errors := errors + 1;
    else
      if rx_b(7) /= '1' then
        report "ERROR: status busy flag should be set while running"
          severity error;
        errors := errors + 1;
      end if;
      if rx_b(6) /= '0' then
        report "ERROR: status error/full flag should be clear"
          severity error;
        errors := errors + 1;
      end if;
      report "OK: status byte = " &
             integer'image(to_integer(unsigned(rx_b)));
    end if;

    -- Four sample bytes (filtered sample, MSB first); values depend on the
    -- triangle wave phase, so only their arrival is checked here
    for i in 0 to 3 loop
      get_byte(rx_b, tmo);
      if tmo then
        report "ERROR: timeout waiting for sample byte " & integer'image(i)
          severity error;
        errors := errors + 1;
      else
        report "OK: sample byte " & integer'image(i) & " = " &
               integer'image(to_integer(unsigned(rx_b)));
      end if;
    end loop;

    expect_byte(C_RSP_DONE, "packet terminator 'D'");

    ----------------------------------------------------------------------
    -- Stop -> 'A', processing disabled
    ----------------------------------------------------------------------
    report "Sending 'X' (stop)";
    uart_send_byte(C_CMD_STOP, uart_rx);
    expect_byte(C_RSP_ACK, "ack for stop");

    wait for 20 us;
    if led(0) /= '0' then
      report "ERROR: LED0 (enabled) should be off after stop" severity error;
      errors := errors + 1;
    else
      report "OK: LED0 off after stop";
    end if;

    ----------------------------------------------------------------------
    -- Clear -> 'A'
    ----------------------------------------------------------------------
    report "Sending 'C' (clear)";
    uart_send_byte(C_CMD_CLEAR, uart_rx);
    expect_byte(C_RSP_ACK, "ack for clear");

    ----------------------------------------------------------------------
    -- Summary
    ----------------------------------------------------------------------
    if errors = 0 then
      report "TEST PASSED: all UART command/reply checks succeeded"
        severity note;
    else
      report "TEST FAILED: " & integer'image(errors) & " error(s)"
        severity error;
    end if;

    sim_done <= true;
    wait;
  end process;

  p_watchdog : process
  begin
    wait for 5 ms;
    if not sim_done then
      report "TEST FAILED: watchdog timeout" severity failure;
    end if;
    wait;
  end process;

end architecture;
