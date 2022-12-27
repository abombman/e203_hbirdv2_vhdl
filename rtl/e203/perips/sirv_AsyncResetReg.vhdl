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
--  module sirv_jtag_dtm
--  Ensure your synthesis tool/compiler is configured for VHDL-2019
------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_AsyncResetReg is 
  port( d:   in std_logic;
  	    q:  out std_logic;
  	    en:  in std_logic;
  	    clk: in std_logic;
        rst: in std_logic      
  	);
end sirv_AsyncResetReg;

architecture impl of sirv_AsyncResetReg is 
  signal load: std_ulogic;
  signal qout: std_ulogic;
begin
  load<= d when en = '1' else
  	     qout;
  process (clk, rst) begin
    if (rst = '1') then
      qout<= '0';
    elsif rising_edge(clk) then
      qout<= load;
    end if;
  end process;
  q<= qout;
end impl;