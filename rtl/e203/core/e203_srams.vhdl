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
--   The SRAM module to implement all SRAMs
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_srams is 
  port( 
  	  `if E203_HAS_ITCM = "TRUE" then
       itcm_ram_sd:    in std_logic; 
       itcm_ram_ds:    in std_logic; 
       itcm_ram_ls:    in std_logic; 
       itcm_ram_cs:    in std_logic; 
       itcm_ram_we:    in std_logic;
       itcm_ram_addr:  in std_logic_vector(E203_ITCM_RAM_AW-1 downto 0); 
       itcm_ram_wem:   in std_logic_vector(E203_ITCM_RAM_MW-1 downto 0); 
       itcm_ram_din:   in std_logic_vector(E203_ITCM_RAM_DW-1 downto 0); 
       itcm_ram_dout: out std_logic_vector(E203_ITCM_RAM_DW-1 downto 0);
       clk_itcm_ram:   in std_logic;
       rst_itcm:       in std_logic;
  	  `end if

  	  `if E203_HAS_DTCM = "TRUE" then
  	   dtcm_ram_sd:    in std_logic; 
       dtcm_ram_ds:    in std_logic; 
       dtcm_ram_ls:    in std_logic; 
       dtcm_ram_cs:    in std_logic; 
       dtcm_ram_we:    in std_logic;
       dtcm_ram_addr:  in std_logic_vector(E203_DTCM_RAM_AW-1 downto 0); 
       dtcm_ram_wem:   in std_logic_vector(E203_DTCM_RAM_MW-1 downto 0); 
       dtcm_ram_din:   in std_logic_vector(E203_DTCM_RAM_DW-1 downto 0); 
       dtcm_ram_dout: out std_logic_vector(E203_DTCM_RAM_DW-1 downto 0);
       clk_dtcm_ram:   in std_logic;  
       rst_dtcm:       in std_logic;   
  	  `end if
  	   test_mode:      in std_logic
  	);
end e203_srams;

architecture impl of e203_srams is 
 `if E203_HAS_ITCM = "TRUE" then
  signal itcm_ram_dout_pre: std_ulogic_vector(E203_ITCM_RAM_DW-1 downto 0);
  component e203_itcm_ram is 
    port( sd:    in std_logic; 
          ds:    in std_logic; 
          ls:    in std_logic; 
  
          cs:    in std_logic; 
          we:    in std_logic;
          addr:  in std_logic_vector(E203_ITCM_RAM_AW-1 downto 0); 
          wem:   in std_logic_vector(E203_ITCM_RAM_MW-1 downto 0); 
          din:   in std_logic_vector(E203_ITCM_RAM_DW-1 downto 0); 
          dout: out std_logic_vector(E203_ITCM_RAM_DW-1 downto 0);
  
          rst_n: in std_logic;  
          clk:   in std_logic   
    	);
  end component;
 `end if

 `if E203_HAS_DTCM = "TRUE" then
  signal dtcm_ram_dout_pre: std_ulogic_vector(E203_DTCM_RAM_DW-1 downto 0);
  component e203_dtcm_ram is 
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
  end component;
 `end if
begin
 `if E203_HAS_ITCM = "TRUE" then
  u_e203_itcm_ram: component e203_itcm_ram port map(
     sd    => itcm_ram_sd,
     ds    => itcm_ram_ds,
     ls    => itcm_ram_ls,
  
     cs    => itcm_ram_cs  ,
     we    => itcm_ram_we  ,
     addr  => itcm_ram_addr,
     wem   => itcm_ram_wem ,
     din   => itcm_ram_din ,
     dout  => itcm_ram_dout_pre,
     rst_n => rst_itcm     ,
     clk   => clk_itcm_ram  
    );
    
  -- Bob: we dont need this bypass here, actually the DFT tools will handle this SRAM black box 
  --assign itcm_ram_dout = test_mode ? itcm_ram_din : itcm_ram_dout_pre;
  itcm_ram_dout <= itcm_ram_dout_pre;
 `end if

 `if E203_HAS_DTCM = "TRUE" then
  u_e203_dtcm_ram: component e203_dtcm_ram port map(
     sd    => dtcm_ram_sd,
     ds    => dtcm_ram_ds,
     ls    => dtcm_ram_ls,
  
     cs    => dtcm_ram_cs  ,
     we    => dtcm_ram_we  ,
     addr  => dtcm_ram_addr,
     wem   => dtcm_ram_wem ,
     din   => dtcm_ram_din ,
     dout  => dtcm_ram_dout_pre,
     rst_n => rst_dtcm     ,
     clk   => clk_dtcm_ram 
    );
    
  -- Bob: we dont need this bypass here, actually the DFT tools will handle this SRAM black box 
  --assign dtcm_ram_dout = test_mode ? dtcm_ram_din : dtcm_ram_dout_pre;
  dtcm_ram_dout <= dtcm_ram_dout_pre;
 `end if
end impl;