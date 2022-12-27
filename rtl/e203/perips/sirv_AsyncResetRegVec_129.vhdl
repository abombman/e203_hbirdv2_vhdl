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

entity sirv_AsyncResetRegVec_129 is 
  port( clock:  in std_logic;
        reset:  in std_logic; 
  	    io_d:   in std_logic_vector(19 downto 0);
  	    io_q:  out std_logic_vector(19 downto 0);
  	    io_en:  in std_logic  	        
  	);
end sirv_AsyncResetRegVec_129;

architecture impl of sirv_AsyncResetRegVec_129 is 
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
  signal reg_5_rst: std_ulogic;
  signal reg_5_clk: std_ulogic;
  signal reg_5_en : std_ulogic;
  signal reg_5_q  : std_ulogic;
  signal reg_5_d  : std_ulogic;
  signal reg_6_rst: std_ulogic;
  signal reg_6_clk: std_ulogic;
  signal reg_6_en : std_ulogic;
  signal reg_6_q  : std_ulogic;
  signal reg_6_d  : std_ulogic;
  signal reg_7_rst: std_ulogic;
  signal reg_7_clk: std_ulogic;
  signal reg_7_en : std_ulogic;
  signal reg_7_q  : std_ulogic;
  signal reg_7_d  : std_ulogic;
  signal reg_8_rst: std_ulogic;
  signal reg_8_clk: std_ulogic;
  signal reg_8_en : std_ulogic;
  signal reg_8_q  : std_ulogic;
  signal reg_8_d  : std_ulogic;
  signal reg_9_rst: std_ulogic;
  signal reg_9_clk: std_ulogic;
  signal reg_9_en : std_ulogic;
  signal reg_9_q  : std_ulogic;
  signal reg_9_d  : std_ulogic;
  signal reg_10_rst: std_ulogic;
  signal reg_10_clk: std_ulogic;
  signal reg_10_en : std_ulogic;
  signal reg_10_q  : std_ulogic;
  signal reg_10_d  : std_ulogic;
  signal reg_11_rst: std_ulogic;
  signal reg_11_clk: std_ulogic;
  signal reg_11_en : std_ulogic;
  signal reg_11_q  : std_ulogic;
  signal reg_11_d  : std_ulogic;
  signal reg_12_rst: std_ulogic;
  signal reg_12_clk: std_ulogic;
  signal reg_12_en : std_ulogic;
  signal reg_12_q  : std_ulogic;
  signal reg_12_d  : std_ulogic;
  signal reg_13_rst: std_ulogic;
  signal reg_13_clk: std_ulogic;
  signal reg_13_en : std_ulogic;
  signal reg_13_q  : std_ulogic;
  signal reg_13_d  : std_ulogic;
  signal reg_14_rst: std_ulogic;
  signal reg_14_clk: std_ulogic;
  signal reg_14_en : std_ulogic;
  signal reg_14_q  : std_ulogic;
  signal reg_14_d  : std_ulogic;
  signal reg_15_rst: std_ulogic;
  signal reg_15_clk: std_ulogic;
  signal reg_15_en : std_ulogic;
  signal reg_15_q  : std_ulogic;
  signal reg_15_d  : std_ulogic;
  signal reg_16_rst: std_ulogic;
  signal reg_16_clk: std_ulogic;
  signal reg_16_en : std_ulogic;
  signal reg_16_q  : std_ulogic;
  signal reg_16_d  : std_ulogic;
  signal reg_17_rst: std_ulogic;
  signal reg_17_clk: std_ulogic;
  signal reg_17_en : std_ulogic;
  signal reg_17_q  : std_ulogic;
  signal reg_17_d  : std_ulogic;
  signal reg_18_rst: std_ulogic;
  signal reg_18_clk: std_ulogic;
  signal reg_18_en : std_ulogic;
  signal reg_18_q  : std_ulogic;
  signal reg_18_d  : std_ulogic;
  signal reg_19_rst: std_ulogic;
  signal reg_19_clk: std_ulogic;
  signal reg_19_en : std_ulogic;
  signal reg_19_q  : std_ulogic;
  signal reg_19_d  : std_ulogic;
  signal T_8       : std_ulogic;
  signal T_9       : std_ulogic;
  signal T_10      : std_ulogic;
  signal T_11      : std_ulogic;
  signal T_12      : std_ulogic;
  signal T_13      : std_ulogic;
  signal T_14      : std_ulogic;
  signal T_15      : std_ulogic;
  signal T_16      : std_ulogic;
  signal T_17      : std_ulogic;
  signal T_18      : std_ulogic;
  signal T_19      : std_ulogic;
  signal T_20      : std_ulogic;
  signal T_21      : std_ulogic;
  signal T_22      : std_ulogic;
  signal T_23      : std_ulogic;
  signal T_24      : std_ulogic;
  signal T_25      : std_ulogic;
  signal T_26      : std_ulogic;
  signal T_27      : std_ulogic;
  signal T_28      : std_ulogic_vector(1 downto 0);
  signal T_29      : std_ulogic_vector(1 downto 0);
  signal T_30      : std_ulogic_vector(2 downto 0);
  signal T_31      : std_ulogic_vector(4 downto 0);
  signal T_32      : std_ulogic_vector(1 downto 0);
  signal T_33      : std_ulogic_vector(1 downto 0);
  signal T_34      : std_ulogic_vector(2 downto 0);
  signal T_35      : std_ulogic_vector(4 downto 0);
  signal T_36      : std_ulogic_vector(9 downto 0);
  signal T_37      : std_ulogic_vector(1 downto 0);
  signal T_38      : std_ulogic_vector(1 downto 0);
  signal T_39      : std_ulogic_vector(2 downto 0);
  signal T_40      : std_ulogic_vector(4 downto 0);
  signal T_41      : std_ulogic_vector(1 downto 0);
  signal T_42      : std_ulogic_vector(1 downto 0);
  signal T_43      : std_ulogic_vector(2 downto 0);
  signal T_44      : std_ulogic_vector(4 downto 0);
  signal T_45      : std_ulogic_vector(9 downto 0);
  signal T_46      : std_ulogic_vector(19 downto 0);
  
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
  reg_5: component sirv_AsyncResetReg port map ( rst=> reg_5_rst,
                                                 clk=> reg_5_clk,
                                                 en => reg_5_en,
                                                 q  => reg_5_q,
                                                 d  => reg_5_d
  	                                           );
  reg_6: component sirv_AsyncResetReg port map ( rst=> reg_6_rst,
                                                 clk=> reg_6_clk,
                                                 en => reg_6_en,
                                                 q  => reg_6_q,
                                                 d  => reg_6_d
  	                                           );
  reg_7: component sirv_AsyncResetReg port map ( rst=> reg_7_rst,
                                                 clk=> reg_7_clk,
                                                 en => reg_7_en,
                                                 q  => reg_7_q,
                                                 d  => reg_7_d
  	                                           );
  reg_8: component sirv_AsyncResetReg port map ( rst=> reg_8_rst,
                                                 clk=> reg_8_clk,
                                                 en => reg_8_en,
                                                 q  => reg_8_q,
                                                 d  => reg_8_d
  	                                           );
  reg_9: component sirv_AsyncResetReg port map ( rst=> reg_9_rst,
                                                 clk=> reg_9_clk,
                                                 en => reg_9_en,
                                                 q  => reg_9_q,
                                                 d  => reg_9_d
  	                                           );
  reg_10: component sirv_AsyncResetReg port map (rst=> reg_10_rst,
                                                 clk=> reg_10_clk,
                                                 en => reg_10_en,
                                                 q  => reg_10_q,
                                                 d  => reg_10_d
  	                                           );
  reg_11: component sirv_AsyncResetReg port map (rst=> reg_11_rst,
                                                 clk=> reg_11_clk,
                                                 en => reg_11_en,
                                                 q  => reg_11_q,
                                                 d  => reg_11_d
  	                                           );
  reg_12: component sirv_AsyncResetReg port map (rst=> reg_12_rst,
                                                 clk=> reg_12_clk,
                                                 en => reg_12_en,
                                                 q  => reg_12_q,
                                                 d  => reg_12_d
  	                                           );
  reg_13: component sirv_AsyncResetReg port map (rst=> reg_13_rst,
                                                 clk=> reg_13_clk,
                                                 en => reg_13_en,
                                                 q  => reg_13_q,
                                                 d  => reg_13_d
  	                                           );
  reg_14: component sirv_AsyncResetReg port map (rst=> reg_14_rst,
                                                 clk=> reg_14_clk,
                                                 en => reg_14_en,
                                                 q  => reg_14_q,
                                                 d  => reg_14_d
  	                                           );
  reg_15: component sirv_AsyncResetReg port map (rst=> reg_15_rst,
                                                 clk=> reg_15_clk,
                                                 en => reg_15_en,
                                                 q  => reg_15_q,
                                                 d  => reg_15_d
  	                                           );
  reg_16: component sirv_AsyncResetReg port map (rst=> reg_16_rst,
                                                 clk=> reg_16_clk,
                                                 en => reg_16_en,
                                                 q  => reg_16_q,
                                                 d  => reg_16_d
  	                                           );
  reg_17: component sirv_AsyncResetReg port map (rst=> reg_17_rst,
                                                 clk=> reg_17_clk,
                                                 en => reg_17_en,
                                                 q  => reg_17_q,
                                                 d  => reg_17_d
  	                                           );
  reg_18: component sirv_AsyncResetReg port map (rst=> reg_18_rst,
                                                 clk=> reg_18_clk,
                                                 en => reg_18_en,
                                                 q  => reg_18_q,
                                                 d  => reg_18_d
  	                                           );
  reg_19: component sirv_AsyncResetReg port map (rst=> reg_19_rst,
                                                 clk=> reg_19_clk,
                                                 en => reg_19_en,
                                                 q  => reg_19_q,
                                                 d  => reg_19_d
  	                                           );
  io_q       <= T_46;
  reg_0_rst  <= reset;
  reg_0_clk  <= clock;
  reg_0_en   <= io_en;
  reg_0_d    <= T_8;
  reg_1_rst  <= reset;
  reg_1_clk  <= clock;
  reg_1_en   <= io_en;
  reg_1_d    <= T_9;
  reg_2_rst  <= reset;
  reg_2_clk  <= clock;
  reg_2_en   <= io_en;
  reg_2_d    <= T_10;
  reg_3_rst  <= reset;
  reg_3_clk  <= clock;
  reg_3_en   <= io_en;
  reg_3_d    <= T_11;
  reg_4_rst  <= reset;
  reg_4_clk  <= clock;
  reg_4_en   <= io_en;
  reg_4_d    <= T_12;
  reg_5_rst  <= reset;
  reg_5_clk  <= clock;
  reg_5_en   <= io_en;
  reg_5_d    <= T_13;
  reg_6_rst  <= reset;
  reg_6_clk  <= clock;
  reg_6_en   <= io_en;
  reg_6_d    <= T_14;
  reg_7_rst  <= reset;
  reg_7_clk  <= clock;
  reg_7_en   <= io_en;
  reg_7_d    <= T_15;
  reg_8_rst  <= reset;
  reg_8_clk  <= clock;
  reg_8_en   <= io_en;
  reg_8_d    <= T_16;
  reg_9_rst  <= reset;
  reg_9_clk  <= clock;
  reg_9_en   <= io_en;
  reg_9_d    <= T_17;
  reg_10_rst <= reset;
  reg_10_clk <= clock;
  reg_10_en  <= io_en;
  reg_10_d   <= T_18;
  reg_11_rst <= reset;
  reg_11_clk <= clock;
  reg_11_en  <= io_en;
  reg_11_d   <= T_19;
  reg_12_rst <= reset;
  reg_12_clk <= clock;
  reg_12_en  <= io_en;
  reg_12_d   <= T_20;
  reg_13_rst <= reset;
  reg_13_clk <= clock;
  reg_13_en  <= io_en;
  reg_13_d   <= T_21;
  reg_14_rst <= reset;
  reg_14_clk <= clock;
  reg_14_en  <= io_en;
  reg_14_d   <= T_22;
  reg_15_rst <= reset;
  reg_15_clk <= clock;
  reg_15_en  <= io_en;
  reg_15_d   <= T_23;
  reg_16_rst <= reset;
  reg_16_clk <= clock;
  reg_16_en  <= io_en;
  reg_16_d   <= T_24;
  reg_17_rst <= reset;
  reg_17_clk <= clock;
  reg_17_en  <= io_en;
  reg_17_d   <= T_25;
  reg_18_rst <= reset;
  reg_18_clk <= clock;
  reg_18_en  <= io_en;
  reg_18_d   <= T_26;
  reg_19_rst <= reset;
  reg_19_clk <= clock;
  reg_19_en  <= io_en;
  reg_19_d   <= T_27;
  T_8        <= io_d(0);
  T_9        <= io_d(1);
  T_10       <= io_d(2);
  T_11       <= io_d(3);
  T_12       <= io_d(4);
  T_13       <= io_d(5);
  T_14       <= io_d(6);
  T_15       <= io_d(7);
  T_16       <= io_d(8);
  T_17       <= io_d(9);
  T_18       <= io_d(10);
  T_19       <= io_d(11);
  T_20       <= io_d(12);
  T_21       <= io_d(13);
  T_22       <= io_d(14);
  T_23       <= io_d(15);
  T_24       <= io_d(16);
  T_25       <= io_d(17);
  T_26       <= io_d(18);
  T_27       <= io_d(19);
  T_28       <= (reg_1_q, reg_0_q);
  T_29       <= (reg_4_q, reg_3_q);
  T_30       <= (T_29, reg_2_q);
  T_31       <= (T_30, T_28);
  T_32       <= (reg_6_q, reg_5_q);
  T_33       <= (reg_9_q, reg_8_q);
  T_34       <= (T_33, reg_7_q);
  T_35       <= (T_34, T_32);
  T_36       <= (T_35, T_31);
  T_37       <= (reg_11_q, reg_10_q);
  T_38       <= (reg_14_q, reg_13_q);
  T_39       <= (T_38, reg_12_q);
  T_40       <= (T_39, T_37);
  T_41       <= (reg_16_q, reg_15_q);
  T_42       <= (reg_19_q, reg_18_q);
  T_43       <= (T_42, reg_17_q);
  T_44       <= (T_43, T_41);
  T_45       <= (T_44, T_40);
  T_46       <= (T_45, T_36);
end impl;