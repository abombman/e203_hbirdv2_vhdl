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

entity sirv_ResetCatchAndSync is 
  port( clock:          in std_logic;
        reset:          in std_logic;
        test_mode:      in std_logic;
        io_sync_reset: out std_logic
  	);
end sirv_ResetCatchAndSync;

architecture impl of sirv_ResetCatchAndSync is
  signal reset_n_catch_reg_clock: std_ulogic;
  signal reset_n_catch_reg_reset: std_ulogic;
  signal reset_n_catch_reg_io_d:  std_ulogic_vector(2 downto 0);
  signal reset_n_catch_reg_io_q:  std_ulogic_vector(2 downto 0);
  signal reset_n_catch_reg_io_en: std_ulogic;
  signal T_6:                     std_ulogic_vector(1 downto 0);
  signal T_7:                     std_ulogic_vector(2 downto 0);
  signal T_8:                     std_ulogic;
  signal T_9:                     std_ulogic;

  component sirv_AsyncResetRegVec_36 is 
    port( clock:  in std_logic;
          reset:  in std_logic;
          io_d:   in std_logic_vector(2 downto 0);
          io_q:  out std_logic_vector(2 downto 0);
          io_en:  in std_logic
    );
  end component;
begin
  reset_n_catch_reg: component sirv_AsyncResetRegVec_36 
                      port map ( clock=> reset_n_catch_reg_clock,
                                 reset=> reset_n_catch_reg_reset,
                                 io_d => reset_n_catch_reg_io_d,
                                 io_q => reset_n_catch_reg_io_q,
                                 io_en=> reset_n_catch_reg_io_en
                               );
  io_sync_reset <= reset when test_mode = '1' else T_9;
  reset_n_catch_reg_clock <= clock;
  reset_n_catch_reg_reset <= reset;
  reset_n_catch_reg_io_d <= T_7;
  reset_n_catch_reg_io_en <= '1';
  T_6 <= reset_n_catch_reg_io_q(2 downto 1);
  T_7 <= ('1', T_6);
  T_8 <= reset_n_catch_reg_io_q(0);
  T_9 <= not T_8;
end impl;