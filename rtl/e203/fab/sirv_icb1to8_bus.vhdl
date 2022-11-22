----------------------------------------------------------------------------
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

--=====================================================================
--
-- Description:
--  The Bus Fab module for 1-to-8 bus
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_icb1to8_bus is 
  generic( ICB_FIFO_DP:         integer := 0; -- This is to optionally add the pipeline stage for ICB bus
                                              --   if the depth is 0, then means pass through, not add pipeline
                                              --   if the depth is 2, then means added one ping-pong buffer stage
  	       ICB_FIFO_CUT_READY:  integer := 1; -- This is to cut the back-pressure signal if you set as 1
           AW:                  integer := 32;
           DW:                  integer := 32;
           SPLT_FIFO_OUTS_NUM:  integer := 1;
           SPLT_FIFO_CUT_READY: integer := 1;
           
           O0_BASE_ADDR:        std_logic_vector(AW-1 downto 0):= X"0000_1000"; 
           O0_BASE_REGION_LSB:  integer := 12;

           O1_BASE_ADDR:        std_logic_vector(AW-1 downto 0):= X"0000_1000"; 
           O1_BASE_REGION_LSB:  integer := 12;

           O2_BASE_ADDR:        std_logic_vector(AW-1 downto 0):= X"0000_1000"; 
           O2_BASE_REGION_LSB:  integer := 12;

           O3_BASE_ADDR:        std_logic_vector(AW-1 downto 0):= X"0000_1000"; 
           O3_BASE_REGION_LSB:  integer := 12;

           O4_BASE_ADDR:        std_logic_vector(AW-1 downto 0):= X"0000_1000"; 
           O4_BASE_REGION_LSB:  integer := 12;

           O5_BASE_ADDR:        std_logic_vector(AW-1 downto 0):= X"0000_1000"; 
           O5_BASE_REGION_LSB:  integer := 12;

           O6_BASE_ADDR:        std_logic_vector(AW-1 downto 0):= X"0000_1000"; 
           O6_BASE_REGION_LSB:  integer := 12;

           O7_BASE_ADDR:        std_logic_vector(AW-1 downto 0):= X"0000_1000"; 
           O7_BASE_REGION_LSB:  integer := 12
  );
  port ( o0_icb_enable:        in  std_logic;
         o1_icb_enable:        in  std_logic;
         o2_icb_enable:        in  std_logic;
         o3_icb_enable:        in  std_logic;
         o4_icb_enable:        in  std_logic;
         o5_icb_enable:        in  std_logic;
         o6_icb_enable:        in  std_logic;
         o7_icb_enable:        in  std_logic;

         i_icb_cmd_valid:      in  std_logic;
         i_icb_cmd_ready:     out  std_logic;         
         i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
         i_icb_cmd_read:       in  std_logic;
         i_icb_cmd_burst:      in  std_logic_vector(1 downto 0);
         i_icb_cmd_beat:       in  std_logic_vector(1 downto 0); 
         i_icb_cmd_wdata:      in  std_logic_vector(DW-1 downto 0);
         i_icb_cmd_wmask:      in  std_logic_vector(DW/8-1 downto 0);
         i_icb_cmd_lock:       in  std_logic;
         i_icb_cmd_excl:       in  std_logic;
         i_icb_cmd_size:       in  std_logic_vector(1 downto 0);
         
         i_icb_rsp_valid:     out  std_logic;
         i_icb_rsp_ready:      in  std_logic;
         i_icb_rsp_err:       out  std_logic;
         i_icb_rsp_excl_ok:   out  std_logic;
         i_icb_rsp_rdata:     out  std_logic_vector(DW-1 downto 0);
 
         o0_icb_cmd_valid:     out  std_logic; 
         o0_icb_cmd_ready:      in  std_logic;      
         o0_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o0_icb_cmd_read:      out  std_logic;
         o0_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o0_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o0_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o0_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o0_icb_cmd_lock:      out  std_logic;
         o0_icb_cmd_excl:      out  std_logic;
         o0_icb_cmd_size:      out  std_logic_vector(1 downto 0);
            
         o0_icb_rsp_valid:      in  std_logic; 
         o0_icb_rsp_ready:     out  std_logic; 
         o0_icb_rsp_err:        in  std_logic;
         o0_icb_rsp_excl_ok:    in  std_logic;
         o0_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);
         
         o1_icb_cmd_valid:     out  std_logic; 
         o1_icb_cmd_ready:      in  std_logic;      
         o1_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o1_icb_cmd_read:      out  std_logic;
         o1_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o1_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o1_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o1_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o1_icb_cmd_lock:      out  std_logic;
         o1_icb_cmd_excl:      out  std_logic;
         o1_icb_cmd_size:      out  std_logic_vector(1 downto 0);
          
         o1_icb_rsp_valid:      in  std_logic; 
         o1_icb_rsp_ready:     out  std_logic; 
         o1_icb_rsp_err:        in  std_logic;
         o1_icb_rsp_excl_ok:    in  std_logic;
         o1_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);

         o2_icb_cmd_valid:     out  std_logic; 
         o2_icb_cmd_ready:      in  std_logic;      
         o2_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o2_icb_cmd_read:      out  std_logic;
         o2_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o2_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o2_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o2_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o2_icb_cmd_lock:      out  std_logic;
         o2_icb_cmd_excl:      out  std_logic;
         o2_icb_cmd_size:      out  std_logic_vector(1 downto 0);
          
         o2_icb_rsp_valid:      in  std_logic; 
         o2_icb_rsp_ready:     out  std_logic; 
         o2_icb_rsp_err:        in  std_logic;
         o2_icb_rsp_excl_ok:    in  std_logic;
         o2_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);

         o3_icb_cmd_valid:     out  std_logic; 
         o3_icb_cmd_ready:      in  std_logic;      
         o3_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o3_icb_cmd_read:      out  std_logic;
         o3_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o3_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o3_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o3_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o3_icb_cmd_lock:      out  std_logic;
         o3_icb_cmd_excl:      out  std_logic;
         o3_icb_cmd_size:      out  std_logic_vector(1 downto 0);
          
         o3_icb_rsp_valid:      in  std_logic; 
         o3_icb_rsp_ready:     out  std_logic; 
         o3_icb_rsp_err:        in  std_logic;
         o3_icb_rsp_excl_ok:    in  std_logic;
         o3_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);

         o4_icb_cmd_valid:     out  std_logic; 
         o4_icb_cmd_ready:      in  std_logic;      
         o4_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o4_icb_cmd_read:      out  std_logic;
         o4_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o4_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o4_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o4_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o4_icb_cmd_lock:      out  std_logic;
         o4_icb_cmd_excl:      out  std_logic;
         o4_icb_cmd_size:      out  std_logic_vector(1 downto 0);
          
         o4_icb_rsp_valid:      in  std_logic; 
         o4_icb_rsp_ready:     out  std_logic; 
         o4_icb_rsp_err:        in  std_logic;
         o4_icb_rsp_excl_ok:    in  std_logic;
         o4_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);

         o5_icb_cmd_valid:     out  std_logic; 
         o5_icb_cmd_ready:      in  std_logic;      
         o5_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o5_icb_cmd_read:      out  std_logic;
         o5_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o5_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o5_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o5_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o5_icb_cmd_lock:      out  std_logic;
         o5_icb_cmd_excl:      out  std_logic;
         o5_icb_cmd_size:      out  std_logic_vector(1 downto 0);
          
         o5_icb_rsp_valid:      in  std_logic; 
         o5_icb_rsp_ready:     out  std_logic; 
         o5_icb_rsp_err:        in  std_logic;
         o5_icb_rsp_excl_ok:    in  std_logic;
         o5_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);

         o6_icb_cmd_valid:     out  std_logic; 
         o6_icb_cmd_ready:      in  std_logic;      
         o6_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o6_icb_cmd_read:      out  std_logic;
         o6_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o6_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o6_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o6_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o6_icb_cmd_lock:      out  std_logic;
         o6_icb_cmd_excl:      out  std_logic;
         o6_icb_cmd_size:      out  std_logic_vector(1 downto 0);
          
         o6_icb_rsp_valid:      in  std_logic; 
         o6_icb_rsp_ready:     out  std_logic; 
         o6_icb_rsp_err:        in  std_logic;
         o6_icb_rsp_excl_ok:    in  std_logic;
         o6_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);

         o7_icb_cmd_valid:     out  std_logic; 
         o7_icb_cmd_ready:      in  std_logic;      
         o7_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
         o7_icb_cmd_read:      out  std_logic;
         o7_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
         o7_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
         o7_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
         o7_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
         o7_icb_cmd_lock:      out  std_logic;
         o7_icb_cmd_excl:      out  std_logic;
         o7_icb_cmd_size:      out  std_logic_vector(1 downto 0);
          
         o7_icb_rsp_valid:      in  std_logic; 
         o7_icb_rsp_ready:     out  std_logic; 
         o7_icb_rsp_err:        in  std_logic;
         o7_icb_rsp_excl_ok:    in  std_logic;
         o7_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);

         clk:                   in  std_logic;
         rst_n:                 in  std_logic        
  );
end sirv_icb1to8_bus;

architecture impl of sirv_icb1to8_bus is 
  constant BASE_REGION_MSB:        integer:= (AW-1);
  constant SPLT_I_NUM     :        integer:= 9;
      
  signal deft_icb_cmd_valid:       std_logic; 
  signal deft_icb_cmd_ready:       std_logic;      
  signal deft_icb_cmd_addr:        std_logic_vector(AW-1 downto 0);
  signal deft_icb_cmd_read:        std_logic;
  signal deft_icb_cmd_burst:       std_logic_vector(1 downto 0);
  signal deft_icb_cmd_beat:        std_logic_vector(1 downto 0);
  signal deft_icb_cmd_wdata:       std_logic_vector(DW-1 downto 0);
  signal deft_icb_cmd_wmask:       std_logic_vector(DW/8-1 downto 0);
  signal deft_icb_cmd_lock:        std_logic;
  signal deft_icb_cmd_excl:        std_logic;
  signal deft_icb_cmd_size:        std_logic_vector(1 downto 0);
      
  signal deft_icb_rsp_valid:       std_logic; 
  signal deft_icb_rsp_ready:       std_logic; 
  signal deft_icb_rsp_err:         std_logic;
  signal deft_icb_rsp_excl_ok:     std_logic;
  signal deft_icb_rsp_rdata:       std_logic_vector(DW-1 downto 0);

  signal splt_bus_icb_cmd_valid:   std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_cmd_ready:   std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_cmd_addr:    std_logic_vector(SPLT_I_NUM*AW  -1 downto 0);
  signal splt_bus_icb_cmd_read:    std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_cmd_burst:   std_logic_vector(SPLT_I_NUM*2   -1 downto 0);
  signal splt_bus_icb_cmd_beat:    std_logic_vector(SPLT_I_NUM*2   -1 downto 0);
  signal splt_bus_icb_cmd_wdata:   std_logic_vector(SPLT_I_NUM*DW  -1 downto 0);
  signal splt_bus_icb_cmd_wmask:   std_logic_vector(SPLT_I_NUM*DW/8-1 downto 0);
  signal splt_bus_icb_cmd_lock:    std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_cmd_excl:    std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_cmd_size:    std_logic_vector(SPLT_I_NUM*2   -1 downto 0);

  signal splt_bus_icb_rsp_valid:   std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_rsp_ready:   std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_rsp_err:     std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_rsp_excl_ok: std_logic_vector(SPLT_I_NUM*1   -1 downto 0);
  signal splt_bus_icb_rsp_rdata:   std_logic_vector(SPLT_I_NUM*DW  -1 downto 0);

  signal buf_icb_cmd_valid:        std_logic; 
  signal buf_icb_cmd_ready:        std_logic;      
  signal buf_icb_cmd_addr:         std_logic_vector(AW-1 downto 0);
  signal buf_icb_cmd_read:         std_logic;
  signal buf_icb_cmd_burst:        std_logic_vector(1 downto 0);
  signal buf_icb_cmd_beat:         std_logic_vector(1 downto 0);
  signal buf_icb_cmd_wdata:        std_logic_vector(DW-1 downto 0);
  signal buf_icb_cmd_wmask:        std_logic_vector(DW/8-1 downto 0);
  signal buf_icb_cmd_lock:         std_logic;
  signal buf_icb_cmd_excl:         std_logic;
  signal buf_icb_cmd_size:         std_logic_vector(1 downto 0);
       
  signal buf_icb_rsp_valid:        std_logic; 
  signal buf_icb_rsp_ready:        std_logic; 
  signal buf_icb_rsp_err:          std_logic;
  signal buf_icb_rsp_excl_ok:      std_logic;
  signal buf_icb_rsp_rdata:        std_logic_vector(DW-1 downto 0);
     
  signal icb_cmd_o0:               std_logic;
  signal icb_cmd_o1:               std_logic;
  signal icb_cmd_o2:               std_logic;
  signal icb_cmd_o3:               std_logic;
  signal icb_cmd_o4:               std_logic;
  signal icb_cmd_o5:               std_logic;
  signal icb_cmd_o6:               std_logic;
  signal icb_cmd_o7:               std_logic;
  signal buf_cmd_addr_c0:          std_logic;
  signal buf_cmd_addr_c1:          std_logic;
  signal buf_cmd_addr_c2:          std_logic;
  signal buf_cmd_addr_c3:          std_logic;
  signal buf_cmd_addr_c4:          std_logic;
  signal buf_cmd_addr_c5:          std_logic;
  signal buf_cmd_addr_c6:          std_logic;
  signal buf_cmd_addr_c7:          std_logic;
     
  signal icb_cmd_deft:             std_logic;
  signal buf_icb_splt_indic:       std_logic_vector(SPLT_I_NUM-1 downto 0);

  component sirv_gnrl_icb_buffer is 
    generic( OUTS_CNT_W:     integer; 
             AW:             integer;
             DW:             integer;
             CMD_CUT_READY:  integer;
             RSP_CUT_READY:  integer;
             CMD_DP:         integer;
             RSP_DP:         integer; 
             USR_W:          integer         
    );
    port ( icb_buffer_active:   out  std_logic;
           
           i_icb_cmd_valid:      in  std_logic;
           i_icb_cmd_ready:     out  std_logic;
           i_icb_cmd_read:       in  std_logic_vector(1-1 downto 0);
           i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
           i_icb_cmd_wdata:      in  std_logic_vector(DW-1 downto 0);
           i_icb_cmd_wmask:      in  std_logic_vector(DW/8-1 downto 0);
           i_icb_cmd_lock:       in  std_logic;
           i_icb_cmd_excl:       in  std_logic;
           i_icb_cmd_size:       in  std_logic_vector(1 downto 0);
           i_icb_cmd_burst:      in  std_logic_vector(1 downto 0);
           i_icb_cmd_beat:       in  std_logic_vector(1 downto 0); 
           i_icb_cmd_usr:        in  std_logic_vector(USR_W-1 downto 0);
           
           i_icb_rsp_valid:     out  std_logic;
           i_icb_rsp_ready:      in  std_logic;
           i_icb_rsp_err:       out  std_logic;
           i_icb_rsp_excl_ok:   out  std_logic;
           i_icb_rsp_rdata:     out  std_logic_vector(DW-1 downto 0);
           i_icb_rsp_usr:       out  std_logic_vector(USR_W-1 downto 0);
   
           o_icb_cmd_valid:     out  std_logic; 
           o_icb_cmd_ready:      in  std_logic; 
           o_icb_cmd_read:      out  std_logic_vector(1-1 downto 0); 
           o_icb_cmd_addr:      out  std_logic_vector(AW-1 downto 0);
           o_icb_cmd_wdata:     out  std_logic_vector(DW-1 downto 0);
           o_icb_cmd_wmask:     out  std_logic_vector(DW/8-1 downto 0);
           o_icb_cmd_lock:      out  std_logic;
           o_icb_cmd_excl:      out  std_logic;
           o_icb_cmd_size:      out  std_logic_vector(1 downto 0);
           o_icb_cmd_burst:     out  std_logic_vector(1 downto 0);
           o_icb_cmd_beat:      out  std_logic_vector(1 downto 0);
           o_icb_cmd_usr:       out  std_logic_vector(USR_W-1 downto 0);
       
           o_icb_rsp_valid:      in  std_logic; 
           o_icb_rsp_ready:     out  std_logic; 
           o_icb_rsp_err:        in  std_logic;
           o_icb_rsp_excl_ok:    in  std_logic;
           o_icb_rsp_rdata:      in  std_logic_vector(DW-1 downto 0);
           o_icb_rsp_usr:        in  std_logic_vector(USR_W-1 downto 0);
     
           clk:                  in  std_logic;
           rst_n:                in  std_logic        
    );
  end component;
  component sirv_gnrl_icb_splt is 
    generic( 
             AW:             integer;
             DW:             integer;
             -- The number of outstanding supported        
             FIFO_OUTS_NUM:  integer;
             FIFO_CUT_READY: integer;
             -- SPLT_NUM=4 ports, so 2 bits for port id
             SPLT_NUM:       integer;
             SPLT_PTR_1HOT:  integer;      -- Currently we always use 1HOT (i.e., this is configured as 1)
                                           -- do not try to configure it as 0, becuase we never use it and verify it
             SPLT_PTR_W:     integer;
             ALLOW_DIFF:     integer;
             ALLOW_0CYCL_RSP:integer;
             VLD_MSK_PAYLOAD:integer;
             USR_W:          integer
    );
    port ( 
           i_icb_splt_indic:     in  std_logic_vector(SPLT_NUM-1 downto 0);
  
           i_icb_cmd_valid:      in  std_logic;
           i_icb_cmd_ready:     out  std_logic;
           i_icb_cmd_read:       in  std_logic_vector(1-1 downto 0);
           i_icb_cmd_addr:       in  std_logic_vector(AW-1 downto 0);
           i_icb_cmd_wdata:      in  std_logic_vector(DW-1 downto 0);
           i_icb_cmd_wmask:      in  std_logic_vector(DW/8-1 downto 0);
           i_icb_cmd_burst:      in  std_logic_vector(1 downto 0);
           i_icb_cmd_beat:       in  std_logic_vector(1 downto 0); 
           i_icb_cmd_lock:       in  std_logic;
           i_icb_cmd_excl:       in  std_logic;
           i_icb_cmd_size:       in  std_logic_vector(1 downto 0); 
           i_icb_cmd_usr:        in  std_logic_vector(USR_W-1 downto 0);
           
           i_icb_rsp_valid:     out  std_logic;
           i_icb_rsp_ready:      in  std_logic;
           i_icb_rsp_err:       out  std_logic;
           i_icb_rsp_excl_ok:   out  std_logic;
           i_icb_rsp_rdata:     out  std_logic_vector(DW-1 downto 0);
           i_icb_rsp_usr:       out  std_logic_vector(USR_W-1 downto 0);
   
           o_bus_icb_cmd_ready:  in  std_logic_vector(SPLT_NUM*1-1 downto 0); 
           o_bus_icb_cmd_valid: out  std_logic_vector(SPLT_NUM*1-1 downto 0);     
           o_bus_icb_cmd_read:  out  std_logic_vector(SPLT_NUM*1-1 downto 0); 
           o_bus_icb_cmd_addr:  out  std_logic_vector(SPLT_NUM*AW-1 downto 0);
           o_bus_icb_cmd_wdata: out  std_logic_vector(SPLT_NUM*DW-1 downto 0);
           o_bus_icb_cmd_wmask: out  std_logic_vector(SPLT_NUM*DW/8-1 downto 0);
           o_bus_icb_cmd_burst: out  std_logic_vector(SPLT_NUM*2-1 downto 0);
           o_bus_icb_cmd_beat:  out  std_logic_vector(SPLT_NUM*2-1 downto 0);
           o_bus_icb_cmd_lock:  out  std_logic_vector(SPLT_NUM*1-1 downto 0);
           o_bus_icb_cmd_excl:  out  std_logic_vector(SPLT_NUM*1-1 downto 0);
           o_bus_icb_cmd_size:  out  std_logic_vector(SPLT_NUM*2-1 downto 0);
           o_bus_icb_cmd_usr:   out  std_logic_vector(SPLT_NUM*USR_W-1 downto 0);
       
           o_bus_icb_rsp_valid:  in  std_logic_vector(SPLT_NUM*1-1 downto 0); 
           o_bus_icb_rsp_ready: out  std_logic_vector(SPLT_NUM*1-1 downto 0); 
           o_bus_icb_rsp_err:    in  std_logic_vector(SPLT_NUM*1-1 downto 0);
           o_bus_icb_rsp_excl_ok:in  std_logic_vector(SPLT_NUM*1-1 downto 0);
           o_bus_icb_rsp_rdata:  in  std_logic_vector(SPLT_NUM*DW-1 downto 0);
           o_bus_icb_rsp_usr:    in  std_logic_vector(SPLT_NUM*USR_W-1 downto 0);
     
           clk:                  in  std_logic;
           rst_n:                in  std_logic        
    );
  end component;
begin
  u_sirv_gnrl_icb_buffer: component sirv_gnrl_icb_buffer
                          generic map( OUTS_CNT_W   => SPLT_FIFO_OUTS_NUM,
                                       AW           => AW,
                                       DW           => DW, 
                                       CMD_DP       => ICB_FIFO_DP,
                                       RSP_DP       => ICB_FIFO_DP,
                                       CMD_CUT_READY=> ICB_FIFO_CUT_READY,
                                       RSP_CUT_READY=> ICB_FIFO_CUT_READY,
                                       USR_W        => 1
                                     )
                             port map( icb_buffer_active => open,
                                       i_icb_cmd_valid   => i_icb_cmd_valid,
                                       i_icb_cmd_ready   => i_icb_cmd_ready,
                                       i_icb_cmd_read(0) => i_icb_cmd_read ,
                                       i_icb_cmd_addr    => i_icb_cmd_addr ,
                                       i_icb_cmd_wdata   => i_icb_cmd_wdata,
                                       i_icb_cmd_wmask   => i_icb_cmd_wmask,
                                       i_icb_cmd_lock    => i_icb_cmd_lock ,
                                       i_icb_cmd_excl    => i_icb_cmd_excl ,
                                       i_icb_cmd_size    => i_icb_cmd_size ,
                                       i_icb_cmd_burst   => i_icb_cmd_burst,
                                       i_icb_cmd_beat    => i_icb_cmd_beat ,
                                       i_icb_cmd_usr     => "0",
                                                       
                                       i_icb_rsp_valid   => i_icb_rsp_valid,
                                       i_icb_rsp_ready   => i_icb_rsp_ready,
                                       i_icb_rsp_err     => i_icb_rsp_err  ,
                                       i_icb_rsp_excl_ok => i_icb_rsp_excl_ok,
                                       i_icb_rsp_rdata   => i_icb_rsp_rdata,
                                       i_icb_rsp_usr     => OPEN,
    
                                       o_icb_cmd_valid   => buf_icb_cmd_valid,
                                       o_icb_cmd_ready   => buf_icb_cmd_ready,
                                       o_icb_cmd_read(0) => buf_icb_cmd_read ,
                                       o_icb_cmd_addr    => buf_icb_cmd_addr ,
                                       o_icb_cmd_wdata   => buf_icb_cmd_wdata,
                                       o_icb_cmd_wmask   => buf_icb_cmd_wmask,
                                       o_icb_cmd_lock    => buf_icb_cmd_lock ,
                                       o_icb_cmd_excl    => buf_icb_cmd_excl ,
                                       o_icb_cmd_size    => buf_icb_cmd_size ,
                                       o_icb_cmd_burst   => buf_icb_cmd_burst,
                                       o_icb_cmd_beat    => buf_icb_cmd_beat ,
                                       o_icb_cmd_usr     => OPEN,
                                                           
                                       o_icb_rsp_valid   => buf_icb_rsp_valid,
                                       o_icb_rsp_ready   => buf_icb_rsp_ready,
                                       o_icb_rsp_err     => buf_icb_rsp_err  ,
                                       o_icb_rsp_excl_ok => buf_icb_rsp_excl_ok,
                                       o_icb_rsp_rdata   => buf_icb_rsp_rdata,
                                       o_icb_rsp_usr     => "0",

                                       clk               => clk,
                                       rst_n             => rst_n
                                   );
  
  -- CMD Channel
  ( o0_icb_cmd_valid,
    o1_icb_cmd_valid,
    o2_icb_cmd_valid,
    o3_icb_cmd_valid,
    o4_icb_cmd_valid,
    o5_icb_cmd_valid,
    o6_icb_cmd_valid,
    o7_icb_cmd_valid,
    deft_icb_cmd_valid
  ) <= splt_bus_icb_cmd_valid;
 
  ( o0_icb_cmd_addr,
    o1_icb_cmd_addr,
    o2_icb_cmd_addr,
    o3_icb_cmd_addr,
    o4_icb_cmd_addr,
    o5_icb_cmd_addr,
    o6_icb_cmd_addr,
    o7_icb_cmd_addr,
    deft_icb_cmd_addr
  ) <= splt_bus_icb_cmd_addr;
 
  ( o0_icb_cmd_read,
    o1_icb_cmd_read,
    o2_icb_cmd_read,
    o3_icb_cmd_read,
    o4_icb_cmd_read,
    o5_icb_cmd_read,
    o6_icb_cmd_read,
    o7_icb_cmd_read,
    deft_icb_cmd_read
  ) <= splt_bus_icb_cmd_read;
 
  ( o0_icb_cmd_burst,
    o1_icb_cmd_burst,
    o2_icb_cmd_burst,
    o3_icb_cmd_burst,
    o4_icb_cmd_burst,
    o5_icb_cmd_burst,
    o6_icb_cmd_burst,
    o7_icb_cmd_burst,
    deft_icb_cmd_burst
  ) <= splt_bus_icb_cmd_burst;
 
  ( o0_icb_cmd_beat,
    o1_icb_cmd_beat,
    o2_icb_cmd_beat,
    o3_icb_cmd_beat,
    o4_icb_cmd_beat,
    o5_icb_cmd_beat,
    o6_icb_cmd_beat,
    o7_icb_cmd_beat,
    deft_icb_cmd_beat
  ) <= splt_bus_icb_cmd_beat;

  ( o0_icb_cmd_wdata,
    o1_icb_cmd_wdata,
    o2_icb_cmd_wdata,
    o3_icb_cmd_wdata,
    o4_icb_cmd_wdata,
    o5_icb_cmd_wdata,
    o6_icb_cmd_wdata,
    o7_icb_cmd_wdata,
    deft_icb_cmd_wdata
  ) <= splt_bus_icb_cmd_wdata;

  ( o0_icb_cmd_wmask,
    o1_icb_cmd_wmask,
    o2_icb_cmd_wmask,
    o3_icb_cmd_wmask,
    o4_icb_cmd_wmask,
    o5_icb_cmd_wmask,
    o6_icb_cmd_wmask,
    o7_icb_cmd_wmask,
    deft_icb_cmd_wmask
  ) <= splt_bus_icb_cmd_wmask;
  
  ( o0_icb_cmd_lock,
    o1_icb_cmd_lock,
    o2_icb_cmd_lock,
    o3_icb_cmd_lock,
    o4_icb_cmd_lock,
    o5_icb_cmd_lock,
    o6_icb_cmd_lock,
    o7_icb_cmd_lock,
    deft_icb_cmd_lock
  ) <= splt_bus_icb_cmd_lock;

  ( o0_icb_cmd_excl,
    o1_icb_cmd_excl,
    o2_icb_cmd_excl,
    o3_icb_cmd_excl,
    o4_icb_cmd_excl,
    o5_icb_cmd_excl,
    o6_icb_cmd_excl,
    o7_icb_cmd_excl,
    deft_icb_cmd_excl
  ) <= splt_bus_icb_cmd_excl;
   
  ( o0_icb_cmd_size,
    o1_icb_cmd_size,
    o2_icb_cmd_size,
    o3_icb_cmd_size,
    o4_icb_cmd_size,
    o5_icb_cmd_size,
    o6_icb_cmd_size,
    o7_icb_cmd_size,
    deft_icb_cmd_size
  ) <= splt_bus_icb_cmd_size;

  splt_bus_icb_cmd_ready <= (
                             o0_icb_cmd_ready,
                             o1_icb_cmd_ready,
                             o2_icb_cmd_ready,
                             o3_icb_cmd_ready,
                             o4_icb_cmd_ready,
                             o5_icb_cmd_ready,
                             o6_icb_cmd_ready,
                             o7_icb_cmd_ready,
                             deft_icb_cmd_ready
                            );

  -- RSP Channel
  splt_bus_icb_rsp_valid <= ( 
                             o0_icb_rsp_valid,
                             o1_icb_rsp_valid,
                             o2_icb_rsp_valid,
                             o3_icb_rsp_valid,
                             o4_icb_rsp_valid,
                             o5_icb_rsp_valid,
                             o6_icb_rsp_valid,
                             o7_icb_rsp_valid,
                             deft_icb_rsp_valid
                            );

  splt_bus_icb_rsp_err <= ( 
                           o0_icb_rsp_err,
                           o1_icb_rsp_err,
                           o2_icb_rsp_err,
                           o3_icb_rsp_err,
                           o4_icb_rsp_err,
                           o5_icb_rsp_err,
                           o6_icb_rsp_err,
                           o7_icb_rsp_err,
                           deft_icb_rsp_err
                          );

  splt_bus_icb_rsp_excl_ok <= ( 
                               o0_icb_rsp_excl_ok,
                               o1_icb_rsp_excl_ok,
                               o2_icb_rsp_excl_ok,
                               o3_icb_rsp_excl_ok,
                               o4_icb_rsp_excl_ok,
                               o5_icb_rsp_excl_ok,
                               o6_icb_rsp_excl_ok,
                               o7_icb_rsp_excl_ok,
                               deft_icb_rsp_excl_ok
                              );

  splt_bus_icb_rsp_rdata <= ( 
                             o0_icb_rsp_rdata,
                             o1_icb_rsp_rdata,
                             o2_icb_rsp_rdata,
                             o3_icb_rsp_rdata,
                             o4_icb_rsp_rdata,
                             o5_icb_rsp_rdata,
                             o6_icb_rsp_rdata,
                             o7_icb_rsp_rdata,
                             deft_icb_rsp_rdata
                            );

  ( 
   o0_icb_rsp_ready,
   o1_icb_rsp_ready,
   o2_icb_rsp_ready,
   o3_icb_rsp_ready,
   o4_icb_rsp_ready,
   o5_icb_rsp_ready,
   o6_icb_rsp_ready,
   o7_icb_rsp_ready,
   deft_icb_rsp_ready
  ) <= splt_bus_icb_rsp_ready;

  buf_cmd_addr_c0<= '1' when (to_integer(unsigned(buf_icb_cmd_addr(BASE_REGION_MSB downto O0_BASE_REGION_LSB))) =
                              to_integer(unsigned(O0_BASE_ADDR(BASE_REGION_MSB downto O0_BASE_REGION_LSB)))) else
                    '0';
  icb_cmd_o0<= buf_icb_cmd_valid and buf_cmd_addr_c0 and o0_icb_enable;

  buf_cmd_addr_c1<= '1' when (to_integer(unsigned(buf_icb_cmd_addr(BASE_REGION_MSB downto O1_BASE_REGION_LSB))) =
                              to_integer(unsigned(O1_BASE_ADDR(BASE_REGION_MSB downto O1_BASE_REGION_LSB)))) else
                    '0';
  icb_cmd_o1<= buf_icb_cmd_valid and buf_cmd_addr_c1 and o1_icb_enable;

  buf_cmd_addr_c2<= '1' when (to_integer(unsigned(buf_icb_cmd_addr(BASE_REGION_MSB downto O2_BASE_REGION_LSB))) =
                              to_integer(unsigned(O2_BASE_ADDR(BASE_REGION_MSB downto O2_BASE_REGION_LSB)))) else
                    '0';
  icb_cmd_o2<= buf_icb_cmd_valid and buf_cmd_addr_c2 and o2_icb_enable;

  buf_cmd_addr_c3<= '1' when (to_integer(unsigned(buf_icb_cmd_addr(BASE_REGION_MSB downto O3_BASE_REGION_LSB))) =
                              to_integer(unsigned(O3_BASE_ADDR(BASE_REGION_MSB downto O3_BASE_REGION_LSB)))) else
                    '0';
  icb_cmd_o3<= buf_icb_cmd_valid and buf_cmd_addr_c3 and o3_icb_enable;

  buf_cmd_addr_c4<= '1' when (to_integer(unsigned(buf_icb_cmd_addr(BASE_REGION_MSB downto O4_BASE_REGION_LSB))) =
                              to_integer(unsigned(O4_BASE_ADDR(BASE_REGION_MSB downto O4_BASE_REGION_LSB)))) else
                    '0';
  icb_cmd_o4<= buf_icb_cmd_valid and buf_cmd_addr_c4 and o4_icb_enable;

  buf_cmd_addr_c5<= '1' when (to_integer(unsigned(buf_icb_cmd_addr(BASE_REGION_MSB downto O5_BASE_REGION_LSB))) =
                              to_integer(unsigned(O5_BASE_ADDR(BASE_REGION_MSB downto O5_BASE_REGION_LSB)))) else
                    '0';
  icb_cmd_o5<= buf_icb_cmd_valid and buf_cmd_addr_c5 and o5_icb_enable;

  buf_cmd_addr_c6<= '1' when (to_integer(unsigned(buf_icb_cmd_addr(BASE_REGION_MSB downto O6_BASE_REGION_LSB))) =
                              to_integer(unsigned(O6_BASE_ADDR(BASE_REGION_MSB downto O6_BASE_REGION_LSB)))) else
                    '0';
  icb_cmd_o6<= buf_icb_cmd_valid and buf_cmd_addr_c6 and o6_icb_enable;

  buf_cmd_addr_c7<= '1' when (to_integer(unsigned(buf_icb_cmd_addr(BASE_REGION_MSB downto O7_BASE_REGION_LSB))) =
                              to_integer(unsigned(O7_BASE_ADDR(BASE_REGION_MSB downto O7_BASE_REGION_LSB)))) else
                    '0';
  icb_cmd_o7<= buf_icb_cmd_valid and buf_cmd_addr_c7 and o7_icb_enable;
  
  icb_cmd_deft <=     (not icb_cmd_o0)
                  and (not icb_cmd_o1)
                  and (not icb_cmd_o2)
                  and (not icb_cmd_o3)
                  and (not icb_cmd_o4)
                  and (not icb_cmd_o5)
                  and (not icb_cmd_o6)
                  and (not icb_cmd_o7);

  buf_icb_splt_indic <= ( 
                         icb_cmd_o0,
                         icb_cmd_o1,
                         icb_cmd_o2,
                         icb_cmd_o3,
                         icb_cmd_o4,
                         icb_cmd_o5,
                         icb_cmd_o6,
                         icb_cmd_o7,
                         icb_cmd_deft
                       );
  u_i_icb_splt: component sirv_gnrl_icb_splt
                generic map( ALLOW_DIFF      => 0, -- Dont allow different branches oustanding
                             ALLOW_0CYCL_RSP => 1, -- Allow the 0 cycle response because in BIU the splt
                                                   --  is after the buffer, and will directly talk to the external
                                                   --  bus, where maybe the ROM is 0 cycle responsed.
                             FIFO_OUTS_NUM   => SPLT_FIFO_OUTS_NUM ,
                             FIFO_CUT_READY  => SPLT_FIFO_CUT_READY,
                             SPLT_NUM        => SPLT_I_NUM,
                             SPLT_PTR_W      => SPLT_I_NUM,
                             SPLT_PTR_1HOT   => 1,
                             VLD_MSK_PAYLOAD => 1,
                             USR_W           => 1,
                             AW              => AW,
                             DW              => DW 
                         )
                   port map( i_icb_splt_indic      => buf_icb_splt_indic,        

                             i_icb_cmd_valid       => buf_icb_cmd_valid,
                             i_icb_cmd_ready       => buf_icb_cmd_ready,
                             i_icb_cmd_read(0)     => buf_icb_cmd_read ,
                             i_icb_cmd_addr        => buf_icb_cmd_addr ,
                             i_icb_cmd_wdata       => buf_icb_cmd_wdata,
                             i_icb_cmd_wmask       => buf_icb_cmd_wmask,
                             i_icb_cmd_burst       => buf_icb_cmd_burst,
                             i_icb_cmd_beat        => buf_icb_cmd_beat ,
                             i_icb_cmd_excl        => buf_icb_cmd_excl ,
                             i_icb_cmd_lock        => buf_icb_cmd_lock ,
                             i_icb_cmd_size        => buf_icb_cmd_size ,
                             i_icb_cmd_usr         => "0"              ,
 
                             i_icb_rsp_valid       => buf_icb_rsp_valid  ,
                             i_icb_rsp_ready       => buf_icb_rsp_ready  ,
                             i_icb_rsp_err         => buf_icb_rsp_err    ,
                             i_icb_rsp_excl_ok     => buf_icb_rsp_excl_ok,
                             i_icb_rsp_rdata       => buf_icb_rsp_rdata  ,
                             i_icb_rsp_usr         => OPEN               ,
                                                        
                             o_bus_icb_cmd_ready   => splt_bus_icb_cmd_ready,
                             o_bus_icb_cmd_valid   => splt_bus_icb_cmd_valid,
                             o_bus_icb_cmd_read    => splt_bus_icb_cmd_read ,
                             o_bus_icb_cmd_addr    => splt_bus_icb_cmd_addr ,
                             o_bus_icb_cmd_wdata   => splt_bus_icb_cmd_wdata,
                             o_bus_icb_cmd_wmask   => splt_bus_icb_cmd_wmask,
                             o_bus_icb_cmd_burst   => splt_bus_icb_cmd_burst,
                             o_bus_icb_cmd_beat    => splt_bus_icb_cmd_beat ,
                             o_bus_icb_cmd_excl    => splt_bus_icb_cmd_excl ,
                             o_bus_icb_cmd_lock    => splt_bus_icb_cmd_lock ,
                             o_bus_icb_cmd_size    => splt_bus_icb_cmd_size ,
                             o_bus_icb_cmd_usr     => OPEN                  ,
  
                             o_bus_icb_rsp_valid   => splt_bus_icb_rsp_valid,
                             o_bus_icb_rsp_ready   => splt_bus_icb_rsp_ready,
                             o_bus_icb_rsp_err     => splt_bus_icb_rsp_err  ,
                             o_bus_icb_rsp_excl_ok => splt_bus_icb_rsp_excl_ok,
                             o_bus_icb_rsp_rdata   => splt_bus_icb_rsp_rdata  ,
                             o_bus_icb_rsp_usr     => (SPLT_I_NUM-1 downto 0 => '0'),
                                                      
                             clk                   => clk,
                             rst_n                 => rst_n
                           );
                   
  --/////////////////////////////////////////////////////////////
  -- Implement the default slave
  deft_icb_cmd_ready <= deft_icb_rsp_ready;

  -- 0 Cycle response
  deft_icb_rsp_valid   <= deft_icb_cmd_valid;
  deft_icb_rsp_err     <= '1';
  deft_icb_rsp_excl_ok <= '0';
  deft_icb_rsp_rdata   <= (DW-1 downto 0 => '0');
  
end impl;