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
--  The clock gating cell
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;

entity e203_clkgate is 
  port(
        clk_in:    in std_logic;
        test_mode: in std_logic;
        clock_en:  in std_logic;
        clk_out: out std_logic 
  );
end e203_clkgate;

architecture impl of e203_clkgate is 
  signal enb : std_logic;  
begin

`if FPGA_SOURCE = "TRUE" then 
  -- In the FPGA, the clock gating is just pass through
  clk_out <= clk_in;
`end if 
`if FPGA_SOURCE = "FALSE" then
  enb <= (clock_en or test_mode);
  clk_out <= enb and clk_in;
`end if

end impl;