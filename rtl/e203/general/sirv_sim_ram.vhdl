------------------------------------------------------------------------------
-- Copyright 2018-2020 Nuclei System Technology, Inc.                
--                                                                         
--   Licensed under the Apache License, Version 2.0 (the "License");         
-- you may not use this file except in compliance with the License.        
-- You may obtain a copy of the License at                                 
--                                                                         
--     http://www.apache.org/licenses/LICENSE-2.0                          
--                                                                         
--   Unless required by applicable law or agreed to in writing, software    
-- distributed under the License is distributed on an "AS IS" BASIS,       
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and     
-- limitations under the License.                                          
------------------------------------------------------------------------------
-- Description:
--  
--  Ensure your synthesis tool/compiler is configured for VHDL-2019
------------------------------------------------------------------------------

--=====================================================================
--
-- Description:
--  The simulation model of SRAM
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_sim_ram is 
  generic ( DP:           integer := 512;
            FORCE_X2ZERO: integer := 0;
            DW:           integer := 32;
            MW:           integer := 4;
            AW:           integer := 32 
  );
  port ( clk:  in  std_logic; 
         din:  in  std_logic_vector(DW-1 downto 0);
         addr: in  std_logic_vector(AW-1 downto 0);
         cs:   in  std_logic;
         we:   in  std_logic;
         wem:  in  std_logic_vector(MW-1 downto 0);  -- write mask?
         dout: out std_logic_vector(DW-1 downto 0)
  );
end sirv_sim_ram;


architecture impl of sirv_sim_ram is
  type mem_type is array (0 to DP-1) of std_ulogic_vector(DW-1 downto 0);
  signal mem_r:    mem_type;
  signal addr_r:   u_unsigned(AW-1 downto 0);
  signal wen:      std_ulogic_vector(MW-1 downto 0);
  signal ren:      std_ulogic;
  signal dout_pre: std_ulogic_vector(DW-1 downto 0);
begin
  ren <= cs and (not we);
  wen <= (MW-1 downto 0 => (cs and we)) and wem;
  
  process(clk) is
  begin
    if rising_edge(clk) then
      if ren = '1' then
        addr_r<= u_unsigned(addr);
      end if;
    end if;  	
  end process; 

  mem: for i in 0 to (MW-1) generate
  begin
  --  last: if ((8*i+8) > DW) generate  -- why? could be happen? 
  --    process(clk)
  --    begin
  --      if rising_edge(clk) then
  --        if wen(i) = '1' then
  --          mem_r(to_integer(u_unsigned(addr)))((DW-1) downto (8*i))<= din((8*i+7) downto (8*i));
  --        end if;
  --      end if;
  --    end process;
  --  end generate;
    non_last: if ((8*i+8) <= DW) generate
      process(clk)
      begin
        if rising_edge(clk) then
          if wen(i) = '1' then
            mem_r(to_integer(u_unsigned(addr)))((8*i+7) downto (8*i))<= din((8*i+7) downto (8*i));
          end if;
        end if;
      end process;
    end generate;
  end generate;

  dout_pre <= mem_r(to_integer(addr_r));

  force_x_to_zero: if (FORCE_X2ZERO = 1) generate
    force_x_gen: for i in 0 to DW-1 generate
    `if SYNTHESIS = "FALSE" then
      dout(i) <= '0' when dout_pre(i) = 'x' else
      	         dout_pre(i);
    `end if
    `if SYNTHESIS = "TRUE" then
      dout(i) <= dout_pre(i);
    `end if
    end generate;
  end generate;

  no_force_x_to_zero: if (FORCE_X2ZERO = 0) generate
    dout <= dout_pre;
  end generate;
end impl; -- impl