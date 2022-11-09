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
--  The top level RAM module
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_gnrl_ram is 
  generic ( DP:           integer := 32;
            DW:           integer := 32;
            FORCE_X2ZERO: integer := 1;
            MW:           integer := 4;
            AW:           integer := 15 
  );
  port ( sd:    in  std_logic;
         ds:    in  std_logic;
         ls:    in  std_logic;
 
         rst_n: in  std_logic;
         clk:   in  std_logic; 
         cs:    in  std_logic;
         we:    in  std_logic;
         addr:  in  std_logic_vector(AW-1 downto 0);
         din:   in  std_logic_vector(DW-1 downto 0);
         wem:   in  std_logic_vector(MW-1 downto 0);  -- write mask?
         dout:  out std_logic_vector(DW-1 downto 0)
  );
end sirv_gnrl_ram;

--To add the ASIC or FPGA or Sim-model control here
-- This is the Sim-model
--

architecture impl of sirv_gnrl_ram is
  component sirv_sim_ram is 
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
  end component;

begin
`if FPGA_SOURCE ="TRUE" Then 
  u_sirv_sim_ram: component sirv_sim_ram generic map (FORCE_X2ZERO=> 0,
                                                      DP          => DP,
                                                      AW          => AW,
                                                      MW          => MW,
                                                      DW          => DW)
                                            port map (clk  => clk,
                                                      din  => din,
                                                      addr => addr,
                                                      cs   => cs,
                                                      we   => we,
                                                      wem  => wem,
                                                      dout => dout);
`end if
`if FPGA_SOURCE ="FALSE" Then 
  u_sirv_sim_ram: component sirv_sim_ram generic map (FORCE_X2ZERO=> FORCE_X2ZERO,
                                                      DP          => DP,
                                                      AW          => AW,
                                                      MW          => MW,
                                                      DW          => DW)
                                            port map (clk  => clk,
                                                      din  => din,
                                                      addr => addr,
                                                      cs   => cs,
                                                      we   => we,
                                                      wem  => wem,
                                                      dout => dout);
`end if
end impl;