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

--  Ensure your synthesis tool/compiler is configured for VHDL-2019
------------------------------------------------------------------------------                                                            
                                                                         
-- ====================================================================
-- 
-- Description:
--  This module to implement the extended CSR
--  current this is an empty module, user can hack it
--  become a real one if they want
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

`if E203_HAS_CSR_NICE = "TRUE" then

entity e203_extend_csr is 
  port( 
  	    -- The Handshake Interface 
  	    nice_csr_valid:  in std_logic;  
        nice_csr_ready: out std_logic;  

        nice_csr_addr:   in std_logic_vector(31 downto 0);
        nice_csr_wr:     in std_logic;
        nice_csr_wdata:  in std_logic_vector(31 downto 0);
        nice_csr_rdata: out std_logic_vector(31 downto 0);
        
        clk:             in std_logic;
        rst_n:           in std_logic
  );
end e203_extend_csr;

`end if