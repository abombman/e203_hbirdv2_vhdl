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
                                                                         
-- ====================================================================
-- 
-- Description:
--   The DTCM-SRAM module to implement DTCM SRAM
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

`if E203_HAS_DTCM = "TRUE" then
entity e203_dtcm_ram is 
  port( sd:    in std_logic; 
        ds:    in std_logic; 
        ls:    in std_logic; 

        cs:    in std_logic; 
        we:    in std_logic;
        addr:  in std_logic_vector(E203_DTCM_RAM_AW-1 downto 0); 
        wem:   in std_logic_vector(E203_DTCM_RAM_MW-1 downto 0); 
        din:   in std_logic_vector(E203_DTCM_RAM_DW-1 downto 0); 
        dout: out std_logic_vector(E203_DTCM_RAM_DW-1 downto 0);

        rst_n: in std_logic;  
        clk:   in std_logic   
  	);
end e203_dtcm_ram;

architecture impl of e203_dtcm_ram is 
  component sirv_gnrl_ram is 
    generic ( DP:           integer;
              DW:           integer;
              FORCE_X2ZERO: integer;
              MW:           integer;
              AW:           integer  
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
  end component;
begin
  u_e203_dtcm_gnrl_ram: component sirv_gnrl_ram generic map(
                                                             FORCE_X2ZERO => 1, -- Always force X to zeros
                                                             DP => E203_DTCM_RAM_DP,
                                                             DW => E203_DTCM_RAM_DW,
                                                             MW => E203_DTCM_RAM_MW,
                                                             AW => E203_DTCM_RAM_AW 
                                                           )
                                                   port map(
                                                             sd  => sd,
                                                             ds  => ds,
                                                             ls  => ls,
                                                          
                                                             rst_n => rst_n,
                                                             clk  => clk ,
                                                             cs   => cs  ,
                                                             we   => we  ,
                                                             addr => addr,
                                                             din  => din ,
                                                             wem  => wem ,
                                                             dout => dout
                                                           );
end impl;
`end if
