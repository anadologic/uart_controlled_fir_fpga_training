--------------------------------------------------------------------------------
-- File    : synth_demo_pkg.vhd
-- Purpose : Common constants, types, and subtypes for the synthesis training
--           demo design.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package synth_demo_pkg is

  -- UART byte subtype
  subtype byte_t is std_logic_vector(7 downto 0);

  -- Command opcodes (ASCII)
  constant C_CMD_START     : byte_t := x"53"; -- 'S'
  constant C_CMD_STOP      : byte_t := x"58"; -- 'X'
  constant C_CMD_READ_STAT : byte_t := x"52"; -- 'R'
  constant C_CMD_CLEAR     : byte_t := x"43"; -- 'C'

  -- Response bytes (ASCII)
  constant C_RSP_ACK   : byte_t := x"41"; -- 'A'
  constant C_RSP_BUSY  : byte_t := x"42"; -- 'B'
  constant C_RSP_DONE  : byte_t := x"44"; -- 'D'
  constant C_RSP_ERROR : byte_t := x"45"; -- 'E'

  -- Command parser FSM state type
  type parser_state_t is (
    ST_IDLE,
    ST_DECODE,
    ST_EXECUTE,
    ST_REPLY
  );

  -- Ceiling log2, used to size address vectors from depth generics
  function clog2(n : positive) return natural;

end package;

package body synth_demo_pkg is

  function clog2(n : positive) return natural is
    variable v : natural  := 0;
    variable p : positive := 1;
  begin
    while p < n loop
      p := p * 2;
      v := v + 1;
    end loop;
    return v;
  end function;

end package body;
