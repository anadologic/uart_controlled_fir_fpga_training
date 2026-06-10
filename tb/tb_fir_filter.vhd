--------------------------------------------------------------------------------
-- File    : tb_fir_filter.vhd
-- Purpose : Unit-level testbench for fir_filter.
--           Applies a unit impulse and checks that the filter outputs its own
--           coefficient sequence (the impulse response of an FIR filter is
--           exactly its coefficients).
--           Self-checking: reports TEST PASSED / TEST FAILED.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.synth_demo_pkg.all;

entity tb_fir_filter is
end entity;

architecture sim of tb_fir_filter is

  constant C_SAMPLE_W   : positive := 16;
  constant C_COEFF_W    : positive := 16;
  constant C_NUM_TAPS   : positive := 8;
  constant C_CLK_PERIOD : time     := 10 ns;
  constant C_RESULT_W   : positive := C_SAMPLE_W + C_COEFF_W;

  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal sample_valid : std_logic := '0';
  signal sample_data  : signed(C_SAMPLE_W-1 downto 0) := (others => '0');
  signal result_valid : std_logic;
  signal result_data  : signed(C_RESULT_W-1 downto 0);

  signal sim_done : boolean := false;

  -- Same coefficient formula as f_init_coeffs in fir_filter.vhd
  function f_coeff(i : natural) return integer is
    variable w : integer;
  begin
    if i < (C_NUM_TAPS+1)/2 then
      w := i + 1;
    else
      w := C_NUM_TAPS - i;
    end if;
    return w * 256;
  end function;

begin

  u_dut : entity work.fir_filter
    generic map (
      G_SAMPLE_W => C_SAMPLE_W,
      G_COEFF_W  => C_COEFF_W,
      G_NUM_TAPS => C_NUM_TAPS
    )
    port map (
      clk            => clk,
      rst            => rst,
      sample_valid_i => sample_valid,
      sample_data_i  => sample_data,
      result_valid_o => result_valid,
      result_data_o  => result_data
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

  p_stim : process
    variable errors   : natural := 0;
    variable expected : integer;
  begin
    rst <= '1';
    wait for 100 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- Feed a unit impulse followed by zeros; each output sample must equal
    -- one coefficient of the filter, then zero once the impulse has left
    -- the delay line.
    for n in 0 to C_NUM_TAPS+1 loop

      if n = 0 then
        sample_data <= to_signed(1, C_SAMPLE_W);   -- the impulse
      else
        sample_data <= to_signed(0, C_SAMPLE_W);
      end if;
      sample_valid <= '1';
      wait until rising_edge(clk);
      sample_valid <= '0';

      wait until rising_edge(clk) and result_valid = '1' for 10 us;

      if result_valid /= '1' then
        report "ERROR: no result_valid for sample " & integer'image(n)
          severity error;
        errors := errors + 1;
      else
        if n < C_NUM_TAPS then
          expected := f_coeff(n);
        else
          expected := 0;
        end if;

        if result_data /= to_signed(expected, C_RESULT_W) then
          report "ERROR: sample " & integer'image(n) &
                 ": expected " & integer'image(expected) &
                 ", got " & integer'image(to_integer(result_data))
            severity error;
          errors := errors + 1;
        else
          report "OK: sample " & integer'image(n) &
                 " = " & integer'image(expected);
        end if;
      end if;

    end loop;

    if errors = 0 then
      report "TEST PASSED: impulse response matches the coefficient ROM"
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
    wait for 500 us;
    if not sim_done then
      report "TEST FAILED: watchdog timeout" severity failure;
    end if;
    wait;
  end process;

end architecture;
