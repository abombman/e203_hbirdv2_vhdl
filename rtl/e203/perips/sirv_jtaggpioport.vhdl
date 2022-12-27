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

entity sirv_jtaggpioport is 
  port( clock                :  in std_logic;
        reset                :  in std_logic;
        io_jtag_TCK          : out std_logic;
        io_jtag_TMS          : out std_logic;
        io_jtag_TDI          : out std_logic;
        io_jtag_TDO          :  in std_logic;
        io_jtag_TRST         : out std_logic;
        io_jtag_DRV_TDO      :  in std_logic;
        io_pins_TCK_i_ival   :  in std_logic;
        io_pins_TCK_o_oval   : out std_logic;
        io_pins_TCK_o_oe     : out std_logic;
        io_pins_TCK_o_ie     : out std_logic;
        io_pins_TCK_o_pue    : out std_logic;
        io_pins_TCK_o_ds     : out std_logic;
        io_pins_TMS_i_ival   :  in std_logic;
        io_pins_TMS_o_oval   : out std_logic;
        io_pins_TMS_o_oe     : out std_logic;
        io_pins_TMS_o_ie     : out std_logic;
        io_pins_TMS_o_pue    : out std_logic;
        io_pins_TMS_o_ds     : out std_logic;
        io_pins_TDI_i_ival   :  in std_logic;
        io_pins_TDI_o_oval   : out std_logic;
        io_pins_TDI_o_oe     : out std_logic; 
        io_pins_TDI_o_ie     : out std_logic;
        io_pins_TDI_o_pue    : out std_logic;
        io_pins_TDI_o_ds     : out std_logic; 
        io_pins_TDO_i_ival   :  in std_logic;
        io_pins_TDO_o_oval   : out std_logic;
        io_pins_TDO_o_oe     : out std_logic;
        io_pins_TDO_o_ie     : out std_logic;
        io_pins_TDO_o_pue    : out std_logic;
        io_pins_TDO_o_ds     : out std_logic;
        io_pins_TRST_n_i_ival:  in std_logic;
        io_pins_TRST_n_o_oval: out std_logic;
        io_pins_TRST_n_o_oe  : out std_logic;
        io_pins_TRST_n_o_ie  : out std_logic;
        io_pins_TRST_n_o_pue : out std_logic;
        io_pins_TRST_n_o_ds  : out std_logic
  );
end sirv_jtaggpioport;

architecture impl of sirv_jtaggpioport is 
  signal T_101: std_ulogic;
  signal T_117: std_ulogic;
begin
   
  io_jtag_TCK           <= T_101;
  io_jtag_TMS           <= io_pins_TMS_i_ival;
  io_jtag_TDI           <= io_pins_TDI_i_ival;
  io_jtag_TRST          <= T_117;
  io_pins_TCK_o_oval    <= '0';
  io_pins_TCK_o_oe      <= '0';
  io_pins_TCK_o_ie      <= '1';
  io_pins_TCK_o_pue     <= '1';
  io_pins_TCK_o_ds      <= '0';
  io_pins_TMS_o_oval    <= '0';
  io_pins_TMS_o_oe      <= '0';
  io_pins_TMS_o_ie      <= '1';
  io_pins_TMS_o_pue     <= '1';
  io_pins_TMS_o_ds      <= '0';
  io_pins_TDI_o_oval    <= '0';
  io_pins_TDI_o_oe      <= '0';
  io_pins_TDI_o_ie      <= '1';
  io_pins_TDI_o_pue     <= '1';
  io_pins_TDI_o_ds      <= '0';
  io_pins_TDO_o_oval    <= io_jtag_TDO;
  io_pins_TDO_o_oe      <= io_jtag_DRV_TDO;
  io_pins_TDO_o_ie      <= '0';
  io_pins_TDO_o_pue     <= '0';
  io_pins_TDO_o_ds      <= '0';
  io_pins_TRST_n_o_oval <= '0';
  io_pins_TRST_n_o_oe   <= '0';
  io_pins_TRST_n_o_ie   <= '1';
  io_pins_TRST_n_o_pue  <= '1';
  io_pins_TRST_n_o_ds   <= '0';
  T_101 <= io_pins_TCK_i_ival; -- assign T_101 <= $unsigned(io_pins_TCK_i_ival);
  T_117 <= not io_pins_TRST_n_i_ival;
end impl;