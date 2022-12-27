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

entity sirv_AsyncResetRegVec_1 is 
  port( clock:  in std_logic;
        reset:  in std_logic; 
  	    io_d:   in std_logic_vector(4 downto 0);
  	    io_q:  out std_logic_vector(4 downto 0);
  	    io_en:  in std_logic  	        
  	);
end sirv_AsyncResetRegVec_1;

architecture impl of sirv_AsyncResetRegVec_1 is 
  signal reg_0_rst: std_ulogic;
  signal reg_0_clk: std_ulogic;
  signal reg_0_en : std_ulogic;
  signal reg_0_q  : std_ulogic;
  signal reg_0_d  : std_ulogic;
  signal reg_1_rst: std_ulogic;
  signal reg_1_clk: std_ulogic;
  signal reg_1_en : std_ulogic;
  signal reg_1_q  : std_ulogic;
  signal reg_1_d  : std_ulogic;
  signal reg_2_rst: std_ulogic;
  signal reg_2_clk: std_ulogic;
  signal reg_2_en : std_ulogic;
  signal reg_2_q  : std_ulogic;
  signal reg_2_d  : std_ulogic;
  signal reg_3_rst: std_ulogic;
  signal reg_3_clk: std_ulogic;
  signal reg_3_en : std_ulogic;
  signal reg_3_q  : std_ulogic;
  signal reg_3_d  : std_ulogic;
  signal reg_4_rst: std_ulogic;
  signal reg_4_clk: std_ulogic;
  signal reg_4_en : std_ulogic;
  signal reg_4_q  : std_ulogic;
  signal reg_4_d  : std_ulogic;
  signal T_8      : std_ulogic;
  signal T_9      : std_ulogic;
  signal T_10     : std_ulogic;
  signal T_11     : std_ulogic;
  signal T_12     : std_ulogic;
  signal T_13     : std_ulogic_vector(1 downto 0);
  signal T_14     : std_ulogic_vector(1 downto 0);
  signal T_15     : std_ulogic_vector(2 downto 0);
  signal T_16     : std_ulogic_vector(4 downto 0);

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
  reg_1: component sirv_AsyncResetReg port map ( rst=> reg_1_rst,
                                                 clk=> reg_1_clk,
                                                 en => reg_1_en,
                                                 q  => reg_1_q,
                                                 d  => reg_1_d
  	                                           );
  reg_2: component sirv_AsyncResetReg port map ( rst=> reg_2_rst,
                                                 clk=> reg_2_clk,
                                                 en => reg_2_en,
                                                 q  => reg_2_q,
                                                 d  => reg_2_d
  	                                           );
  reg_3: component sirv_AsyncResetReg port map ( rst=> reg_3_rst,
                                                 clk=> reg_3_clk,
                                                 en => reg_3_en,
                                                 q  => reg_3_q,
                                                 d  => reg_3_d
  	                                           );
  reg_4: component sirv_AsyncResetReg port map ( rst=> reg_4_rst,
                                                 clk=> reg_4_clk,
                                                 en => reg_4_en,
                                                 q  => reg_4_q,
                                                 d  => reg_4_d
  	                                           );
  io_q      <= T_16;
  reg_0_rst <= reset;
  reg_0_clk <= clock;
  reg_0_en  <= io_en;
  reg_0_d   <= T_8;
  reg_1_rst <= reset;
  reg_1_clk <= clock;
  reg_1_en  <= io_en;
  reg_1_d   <= T_9;
  reg_2_rst <= reset;
  reg_2_clk <= clock;
  reg_2_en  <= io_en;
  reg_2_d   <= T_10;
  reg_3_rst <= reset;
  reg_3_clk <= clock;
  reg_3_en  <= io_en;
  reg_3_d   <= T_11;
  reg_4_rst <= reset;
  reg_4_clk <= clock;
  reg_4_en  <= io_en;
  reg_4_d   <= T_12;
  T_8       <= io_d(0);
  T_9       <= io_d(1);
  T_10      <= io_d(2);
  T_11      <= io_d(3);
  T_12      <= io_d(4);
  T_13      <= (reg_1_q, reg_0_q);
  T_14      <= (reg_4_q, reg_3_q);
  T_15      <= (T_14, reg_2_q);
  T_16      <= (T_15, T_13);
end impl;