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
--   The Regfile module to implement the core's general purpose registers file
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_regfile is 
  port ( read_src1_idx:  in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         read_src2_idx:  in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         read_src1_dat: out std_logic_vector(E203_XLEN-1 downto 0);
         read_src2_dat: out std_logic_vector(E203_XLEN-1 downto 0);

         wbck_dest_wen:  in std_logic;
         wbck_dest_idx:  in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         wbck_dest_dat:  in std_logic_vector(E203_XLEN-1 downto 0);

         x1_r:          out std_logic_vector(E203_XLEN-1 downto 0);
         
         test_mode:      in std_logic;
         clk:            in std_logic;
         rst_n:          in std_logic
  );
end e203_exu_regfile;

architecture impl of e203_exu_regfile is 
  type regfile_type is array(E203_RFREG_NUM-1 downto 0) of std_logic_vector(E203_XLEN-1 downto 0);
  signal rf_r:   regfile_type;
  signal rf_wen: std_logic_vector(E203_XLEN-1 downto 0);
  
  -- wbck_dest_is(i) is archi-scope signal. watch out file sirv_gnrl_icbs.vhdl, line 240 and 259.
  -- signal wbck_dest_is: std_logic_vector(E203_RFREG_NUM-1 downto 0);
  component sirv_gnrl_dffl is
    generic( DW: integer := 32 );
    port( 	  
    	    lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic
    );
  end component;

 `if E203_REGFILE_LATCH_BASED = "TRUE" then
  signal wbck_dest_dat_r: std_logic_vector(E203_XLEN-1 downto 0);
  signal clk_rf_ltch:     std_logic_vector(E203_RFREG_NUM-1 downto 0);
  component sirv_gnrl_dffl is
    generic( DW: integer );
    port( 	  
    	  lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic
    );
  end component;
  component e203_clkgate is 
    port(
          clk_in:    in std_logic;
          test_mode: in std_logic;
          clock_en:  in std_logic;
          clk_out:  out std_logic 
    );
  end component;
  component sirv_gnrl_ltch is
    generic( DW: integer );
    port( 
          lden:  in std_logic;   	  
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 )
    );
  end component;
 `end if

begin
 `if E203_REGFILE_LATCH_BASED = "TRUE" then
  -- Use DFF to buffer the write-port 
  wbck_dat_dffl: component sirv_gnrl_dffl generic map (E203_XLEN)
                                             port map (wbck_dest_wen, wbck_dest_dat, wbck_dest_dat_r, clk);
 `end if

  regfile: for i in 0 to E203_RFREG_NUM-1 generate
    rf0: if i = 0 generate
    -- x0 cannot be write since it is constant-zeros
    rf_wen(i) <= '0';
    rf_r(i) <= (E203_XLEN-1 downto 0 => '0');
   `if E203_REGFILE_LATCH_BASED = "TRUE" then
    clk_rf_ltch(i) <= '0';
   `end if 
    end generate;

    rfno0: if i > 0 generate
      signal wbck_dest_is_i: std_logic; -- every generation for index i instants one wbck_dest_is_i signal.
                                        -- use local signal is better way.
    begin
    -- wbck_dest_is(i) is archi-scope signal.
    -- watch out file sirv_gnrl_icbs.vhdl line 240 and 259.
    -- wbck_dest_is(i) <= '1' when (to_integer(unsigned(wbck_dest_idx)) = i) else
    -- 	                  '0'; 
    wbck_dest_is_i <= '1' when (to_integer(unsigned(wbck_dest_idx)) = i) else
     	              '0'; 	               
    rf_wen(i) <= wbck_dest_wen and wbck_dest_is_i;
   `if E203_REGFILE_LATCH_BASED = "TRUE" then
    u_e203_clkgate: component e203_clkgate port map( clk_in   => clk,
                                                     test_mode=> test_mode,
                                                     clock_en => rf_wen(i),
                                                     clk_out  => clk_rf_ltch(i)
    	                                           );
    --from write-enable to clk_rf_ltch to rf_ltch
    rf_ltch: component sirv_gnrl_ltch generic map (E203_XLEN)
                                         port map (clk_rf_ltch(i), wbck_dest_dat_r, rf_r(i));
   `end if
   `if E203_REGFILE_LATCH_BASED = "FALSE" then
    rf_dffl: component sirv_gnrl_dffl generic map (E203_XLEN)
                                         port map (rf_wen(i), wbck_dest_dat, rf_r(i), clk);
   `end if    
    end generate;
  end generate;
  read_src1_dat <= rf_r(to_integer(unsigned(read_src1_idx)));
  read_src2_dat <= rf_r(to_integer(unsigned(read_src2_idx)));
  x1_r          <= rf_r(1);
end impl;