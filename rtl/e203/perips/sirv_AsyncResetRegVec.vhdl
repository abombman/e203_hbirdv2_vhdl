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

entity sirv_AsyncResetRegVec is 
  port( clock:  in std_logic;
        reset:  in std_logic; 
  	    io_d:   in std_logic;
  	    io_q:  out std_logic;
  	    io_en:  in std_logic  	        
  	);
end sirv_AsyncResetRegVec;
  
architecture impl of sirv_AsyncResetRegVec is 
  signal reg_0_rst: std_ulogic;
  signal reg_0_clk: std_ulogic;
  signal reg_0_en:  std_ulogic;
  signal reg_0_q:   std_ulogic;
  signal reg_0_d:   std_ulogic;

  component sirv_AsyncResetReg is 
    port( d:   in std_logic;
    	    q:  out std_logic;
    	    en:  in std_logic;
    	    clk: in std_logic;
          rst: in std_logic      
    );
  end component;
begin
  reg_0: component sirv_AsyncResetReg port map ( rst=> reg_0_rst,
                                                 clk=> reg_0_clk,
                                                 en => reg_0_en,
                                                 q  => reg_0_q,
                                                 d  => reg_0_d
  	                                           );
  io_q      <= reg_0_q;
  reg_0_rst <= reset;
  reg_0_clk <= clock;
  reg_0_en  <= io_en;
  reg_0_d   <= io_d;
end impl;