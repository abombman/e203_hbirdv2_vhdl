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
--   This module to implement the AGU (address generation unit for load/store 
--   and AMO instructions), which is mostly share the datapath with ALU module
--   to save gatecount to mininum
-- 
-- ====================================================================                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_alu_lsuagu is 
  port ( -- The Handshake Interface 
  	     agu_i_valid:  in std_logic; -- Handshake valid
  	     agu_i_ready: out std_logic; -- Handshake ready

  	     agu_i_rs1:    in std_logic_vector(E203_XLEN-1 downto 0);
         agu_i_rs2:    in std_logic_vector(E203_XLEN-1 downto 0);
         agu_i_imm:    in std_logic_vector(E203_XLEN-1 downto 0);
         agu_i_info:   in std_logic_vector(E203_DECINFO_AGU_WIDTH-1 downto 0);
         agu_i_itag:   in std_logic_vector(E203_ITAG_WIDTH-1 downto 0);

         agu_i_longpipe: out std_logic;
         flush_req:       in std_logic;  
         flush_pulse:     in std_logic;
         amo_wait:       out std_logic;  
         oitf_empty:      in std_logic;

         -- The AGU Write-Back/Commit Interface
         agu_o_valid:      out std_logic; -- Handshake valid
  	     agu_o_ready:       in std_logic; -- Handshake ready  
  	     agu_o_wbck_wdat:  out std_logic_vector(E203_XLEN-1 downto 0); 
         agu_o_wbck_err:   out std_logic;
         -- The Commit Interface for all ldst and amo instructions
         agu_o_cmt_misalgn: out std_logic;
         agu_o_cmt_ld:      out std_logic;
         agu_o_cmt_stamo:   out std_logic;
         agu_o_cmt_buserr:  out std_logic;
         agu_o_cmt_badaddr: out std_logic_vector(E203_ADDR_SIZE-1 downto 0);

         -- The ICB Interface to LSU-ctrl
         --    * Bus cmd channel
         agu_icb_cmd_valid:  out  std_logic; -- Handshake valid
         agu_icb_cmd_ready:   in  std_logic; -- Handshake ready
         -- Note: The data on rdata or wdata channel must be naturally
         --       aligned, this is in line with the AXI definition
         agu_icb_cmd_addr:     out std_logic_vector(E203_ADDR_SIZE-1 downto 0); -- Bus transaction start addr
         agu_icb_cmd_read:     out std_logic;                                -- Read or write
         agu_icb_cmd_wdata:    out std_logic_vector(E203_XLEN-1 downto 0);
         agu_icb_cmd_wmask:    out std_logic_vector(E203_XLEN/8-1 downto 0);
         agu_icb_cmd_back2agu: out std_logic;
         agu_icb_cmd_lock:     out std_logic;
         agu_icb_cmd_excl:     out std_logic;
         agu_icb_cmd_size:     out std_logic_vector(1 downto 0);
         agu_icb_cmd_itag:     out std_logic_vector(E203_ITAG_WIDTH-1 downto 0);
         agu_icb_cmd_usign:    out std_logic;

         --    * Bus RSP channel
         agu_icb_rsp_valid:     in  std_logic; -- Response valid
         agu_icb_rsp_ready:    out  std_logic; -- Response ready
         agu_icb_rsp_err:       in  std_logic; -- Response error
         agu_icb_rsp_excl_ok:   in  std_logic;
         -- Note: the RSP rdata is inline with AXI definition
         agu_icb_rsp_rdata:     in std_logic_vector(E203_XLEN-1 downto 0);

         -- To share the ALU datapath, generate interface to ALU
         --   for single-issue machine, seems the AGU must be shared with ALU, otherwise
         --   it wasted the area for no points 
         -- 
         -- The operands and info to ALU
         agu_req_alu_op1:  out std_logic_vector(E203_XLEN-1 downto 0);
         agu_req_alu_op2:  out std_logic_vector(E203_XLEN-1 downto 0);
         agu_req_alu_swap: out std_logic;
         agu_req_alu_add:  out std_logic;
         agu_req_alu_and:  out std_logic;
         agu_req_alu_or:   out std_logic;
         agu_req_alu_xor:  out std_logic;
         agu_req_alu_max:  out std_logic;
         agu_req_alu_min:  out std_logic;
         agu_req_alu_maxu: out std_logic;
         agu_req_alu_minu: out std_logic;
         agu_req_alu_res:   in std_logic_vector(E203_XLEN-1 downto 0);
         
         -- The Shared-Buffer interface to ALU-Shared-Buffer
         agu_sbf_0_ena:    out std_logic;
         agu_sbf_0_nxt:    out std_logic_vector(E203_XLEN-1 downto 0);
         agu_sbf_0_r:       in std_logic_vector(E203_XLEN-1 downto 0);
         
         agu_sbf_1_ena:    out std_logic;
         agu_sbf_1_nxt:    out std_logic_vector(E203_XLEN-1 downto 0);
         agu_sbf_1_r:       in std_logic_vector(E203_XLEN-1 downto 0);

         clk:               in std_logic;  
         rst_n:             in std_logic  
  	   );
end e203_exu_alu_lsuagu;
  
architecture impl of e203_exu_alu_lsuagu is 
  signal icb_sta_is_idle: std_ulogic;
  signal flush_block:     std_ulogic;
  signal agu_i_load:      std_ulogic;
  signal agu_i_store:     std_ulogic;
  signal agu_i_amo:       std_ulogic;
  signal agu_i_size:      std_ulogic_vector(1 downto 0);
  signal agu_i_usign:     std_ulogic;
  signal agu_i_excl:      std_ulogic;
  signal agu_i_amoswap:   std_ulogic;
  signal agu_i_amoadd:    std_ulogic;
  signal agu_i_amoand:    std_ulogic;
  signal agu_i_amoor:     std_ulogic;
  signal agu_i_amoxor:    std_ulogic;
  signal agu_i_amomax:    std_ulogic;
  signal agu_i_amomin:    std_ulogic;
  signal agu_i_amomaxu:   std_ulogic;
  signal agu_i_amominu:   std_ulogic;

  signal agu_icb_cmd_hsked: std_ulogic;

 `if E203_SUPPORT_AMO = "TRUE" then 
  signal agu_icb_rsp_hsked: std_ulogic;         
 `end if
 `if E203_SUPPORT_AMO = "FALSE" then
   `if E203_SUPPORT_UNALGNLDST = "FALSE" then
    signal agu_icb_rsp_hsked: std_ulogic;
   `end if         
 `end if

  signal agu_i_size_b:    std_ulogic;
  signal agu_i_size_hw:   std_ulogic;
  signal agu_i_size_w:    std_ulogic;

  signal agu_i_addr_unalgn:   std_ulogic;
  signal state_last_exit_ena: std_ulogic;

 `if E203_SUPPORT_AMO = "TRUE" then 
  signal state_idle_exit_ena: std_ulogic;
  signal unalgn_flg_r:        std_ulogic;
  signal unalgn_flg_set:      std_ulogic;
  signal unalgn_flg_clr:      std_ulogic;
  signal unalgn_flg_ena:      std_ulogic;
  signal unalgn_flg_nxt:      std_ulogic;         
 `end if 

  signal agu_addr_unalgn:     std_ulogic;

  signal agu_i_unalgnld:      std_ulogic;
  signal agu_i_unalgnst:      std_ulogic;
  signal agu_i_unalgnldst:    std_ulogic;
  signal agu_i_algnld:        std_ulogic;
  signal agu_i_algnst:        std_ulogic;
  signal agu_i_algnldst:      std_ulogic;  

 `if E203_SUPPORT_AMO = "TRUE" then 
  signal agu_i_unalgnamo:     std_ulogic;
  signal agu_i_algnamo:       std_ulogic;         
 `end if

  signal agu_i_ofst0:         std_ulogic;
  
  constant ICB_STATE_WIDTH:   integer:= 4;
  signal icb_state_ena:       std_ulogic;
  signal icb_state_nxt:       std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal icb_state_r:         std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0);

  -- State 0: The idle state, means there is no any oustanding ifetch request
  constant ICB_STATE_IDLE:    std_ulogic_vector(3 downto 0):= "0000";
 `if E203_SUPPORT_AMO = "TRUE" then 
  -- State  : Issued first request and wait response
  constant ICB_STATE_1ST:     std_ulogic_vector(3 downto 0):= "0001";
  -- State  : Wait to issue second request
  constant ICB_STATE_WAIT2ND: std_ulogic_vector(3 downto 0):= "0010";
  -- State  : Issued second request and wait response
  constant ICB_STATE_2ND:     std_ulogic_vector(3 downto 0):= "0011";
  -- State  : For AMO instructions, in this state, read-data was in leftover
  --            buffer for ALU calculation 
  constant ICB_STATE_AMOALU:  std_ulogic_vector(3 downto 0):= "0100";
  -- State  : For AMO instructions, in this state, ALU have caculated the new
  --            result and put into leftover buffer again 
  constant ICB_STATE_AMORDY:  std_ulogic_vector(3 downto 0):= "0101";
  -- State  : For AMO instructions, in this state, the response data have been returned
  --            and the write back result to commit/wback interface
  constant ICB_STATE_WBCK:    std_ulogic_vector(3 downto 0):= "0110";      
 `end if

 `if E203_SUPPORT_AMO = "TRUE" then 
  signal state_idle_nxt:      std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal state_1st_nxt:       std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal state_wait2nd_nxt:   std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal state_2nd_nxt:       std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0); 
  signal state_amoalu_nxt:    std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal state_amordy_nxt:    std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0); 
  signal state_wbck_nxt:      std_ulogic_vector(ICB_STATE_WIDTH-1 downto 0);         
 `end if

 `if E203_SUPPORT_AMO = "TRUE" then 
  signal state_1st_exit_ena:     std_ulogic;
  signal state_wait2nd_exit_ena: std_ulogic;
  signal state_2nd_exit_ena:     std_ulogic;
  signal state_amoalu_exit_ena:  std_ulogic;
  signal state_amordy_exit_ena:  std_ulogic;
  signal state_wbck_exit_ena:    std_ulogic;         
 `end if

 `if E203_SUPPORT_AMO = "TRUE" then 
  signal icb_sta_is_1st:         std_ulogic;
  signal icb_sta_is_amoalu:      std_ulogic;
  signal icb_sta_is_amordy:      std_ulogic;
  signal icb_sta_is_wait2nd:     std_ulogic;
  signal icb_sta_is_2nd:         std_ulogic;
  signal icb_sta_is_wbck:        std_ulogic;         
 `end if
 `if E203_SUPPORT_AMO = "TRUE" then 
  signal state_idle_to_exit:     std_ulogic;
 `end if

  signal icb_sta_is_last:        std_ulogic;

  signal leftover_ena:           std_ulogic;
  signal leftover_nxt:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal leftover_r:             std_ulogic_vector(E203_XLEN-1 downto 0);
  signal leftover_err_nxt:       std_ulogic;
  signal leftover_err_r:         std_ulogic;

  signal leftover_1_r:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal leftover_1_ena:         std_ulogic;
  signal leftover_1_nxt:         std_ulogic_vector(E203_XLEN-1 downto 0);
  
  `if E203_SUPPORT_AMO = "TRUE" then 
  signal amo_1stuop:             std_ulogic;
  signal amo_2nduop:             std_ulogic;         
 `end if
  
  signal agu_addr_gen_op2:       std_ulogic_vector(E203_XLEN-1 downto 0);

  signal algnst_wdata:           std_ulogic_vector(E203_XLEN-1 downto 0);
  signal algnst_wmask:           std_ulogic_vector(E203_XLEN/8-1 downto 0);

  signal leftover_error_no:      std_ulogic_vector(E203_XLEN/8-1 downto 0);
  
  component sirv_gnrl_dfflr is
    generic( DW: integer );
    port( 
    	  lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;

begin 
  -- When there is a nonalu_flush which is going to flush the ALU, then we need to mask off it
  flush_block   <= flush_req and icb_sta_is_idle; 

  agu_i_load    <= agu_i_info(E203_DECINFO_AGU_LOAD 'right) and (not flush_block);
  agu_i_store   <= agu_i_info(E203_DECINFO_AGU_STORE'right) and (not flush_block);
  agu_i_amo     <= agu_i_info(E203_DECINFO_AGU_AMO  'right) and (not flush_block);

  agu_i_size    <= agu_i_info(E203_DECINFO_AGU_SIZE   'range);
  agu_i_usign   <= agu_i_info(E203_DECINFO_AGU_USIGN  'right);
  agu_i_excl    <= agu_i_info(E203_DECINFO_AGU_EXCL   'right);
  agu_i_amoswap <= agu_i_info(E203_DECINFO_AGU_AMOSWAP'right);
  agu_i_amoadd  <= agu_i_info(E203_DECINFO_AGU_AMOADD 'right);
  agu_i_amoand  <= agu_i_info(E203_DECINFO_AGU_AMOAND 'right);
  agu_i_amoor   <= agu_i_info(E203_DECINFO_AGU_AMOOR  'right);
  agu_i_amoxor  <= agu_i_info(E203_DECINFO_AGU_AMOXOR 'right);
  agu_i_amomax  <= agu_i_info(E203_DECINFO_AGU_AMOMAX 'right);
  agu_i_amomin  <= agu_i_info(E203_DECINFO_AGU_AMOMIN 'right);
  agu_i_amomaxu <= agu_i_info(E203_DECINFO_AGU_AMOMAXU'right);
  agu_i_amominu <= agu_i_info(E203_DECINFO_AGU_AMOMINU'right);

  agu_icb_cmd_hsked <= agu_icb_cmd_valid and agu_icb_cmd_ready; 
 `if E203_SUPPORT_AMO = "TRUE" then
  agu_icb_rsp_hsked <= agu_icb_rsp_valid and agu_icb_rsp_ready; 
 `end if
  -- These strange ifdef/ifndef rather than the ifdef-else, because of 
  --   our internal text processing scripts need this style
 `if E203_SUPPORT_AMO = "FALSE" then
   `if E203_SUPPORT_UNALGNLDST = "FALSE" then
    agu_icb_rsp_hsked = '0';
   `end if         
 `end if

  agu_i_size_b  <= (agu_i_size ?= 2b"00");
  agu_i_size_hw <= (agu_i_size ?= 2b"01");
  agu_i_size_w  <= (agu_i_size ?= 2b"10");

  agu_i_addr_unalgn <= 
        (agu_i_size_hw and  agu_icb_cmd_addr(0))
     or (agu_i_size_w  and  (or(agu_icb_cmd_addr(1 downto 0))));

 `if E203_SUPPORT_AMO = "FALSE" then
  -- Set when the ICB state is starting and it is unalign
  unalgn_flg_set <= agu_i_addr_unalgn and state_idle_exit_ena;
  -- Clear when the ICB state is entering
  unalgn_flg_clr <= unalgn_flg_r and state_last_exit_ena;
  unalgn_flg_ena <= unalgn_flg_set or unalgn_flg_clr;
  unalgn_flg_nxt <= unalgn_flg_set or (not unalgn_flg_clr);
  unalgn_flg_dffl: component sirv_gnrl_dfflr generic map (1)
                                                port map (lden    => unalgn_flg_ena, 
                                                          dnxt(0) => unalgn_flg_nxt, 
                                                          qout(0) => unalgn_flg_r, 
                                                          clk     => clk,
                                                          rst_n   => rst_n
                                                	     );
 `end if

  agu_addr_unalgn <= 
 `if E203_SUPPORT_UNALGNLDST = "FALSE" then
   `if E203_SUPPORT_AMO = "TRUE" then
    agu_i_addr_unalgn when icb_sta_is_idle = '1' else unalgn_flg_r;
   `end if
   `if E203_SUPPORT_AMO = "FALSE" then
    agu_i_addr_unalgn;
   `end if
 `end if

 
  agu_i_unalgnld   <= (agu_addr_unalgn and agu_i_load);
  agu_i_unalgnst   <= (agu_addr_unalgn and agu_i_store) ;
  agu_i_unalgnldst <= (agu_i_unalgnld or agu_i_unalgnst);
  agu_i_algnld     <= (not agu_addr_unalgn) and agu_i_load;
  agu_i_algnst     <= (not agu_addr_unalgn) and agu_i_store;
  agu_i_algnldst   <= (agu_i_algnld or agu_i_algnst);

 `if E203_SUPPORT_AMO = "TRUE" then
  agu_i_unalgnamo <= (agu_addr_unalgn and agu_i_amo);
  agu_i_algnamo   <= ((not agu_addr_unalgn) and agu_i_amo) ;
 `end if

  agu_i_ofst0  <= agu_i_amo or ((agu_i_load or agu_i_store) and agu_i_excl); 

  -- Define some common signals and reused later to save gatecounts
  icb_sta_is_idle    <= (icb_state_r ?= ICB_STATE_IDLE   );
 `if E203_SUPPORT_AMO = "TRUE" then
  icb_sta_is_1st     <= (icb_state_r ?= ICB_STATE_1ST    );
  icb_sta_is_amoalu  <= (icb_state_r ?= ICB_STATE_AMOALU );
  icb_sta_is_amordy  <= (icb_state_r ?= ICB_STATE_AMORDY );
  icb_sta_is_wait2nd <= (icb_state_r ?= ICB_STATE_WAIT2ND);
  icb_sta_is_2nd     <= (icb_state_r ?= ICB_STATE_2ND    );
  icb_sta_is_wbck    <= (icb_state_r ?= ICB_STATE_WBCK   );
 `end if


 `if E203_SUPPORT_AMO = "TRUE" then
  -- **** If the current state is idle,
  -- If a new load-store come and the ICB cmd channel is handshaked, next
  --   state is ICB_STATE_1ST
  state_idle_to_exit <=    (( agu_i_algnamo
                           -- Why do we add an oitf empty signal here? because
                           --   it is better to start AMO state-machine when the 
                           --   long-pipes are completed, to avoid the long-pipes 
                           --   have error-return which need to flush the pipeline
                           --   and which also need to wait the AMO state-machine
                           --   to complete first, in corner cases it may end 
                           --   up with deadlock.
                           -- Force to wait oitf empty before doing amo state-machine
                           --   may hurt performance, but we dont care it. In e203 implementation
                           --   the AMO was not target for performance.
                          and oitf_empty)
                           );
  state_idle_exit_ena <= icb_sta_is_idle and state_idle_to_exit 
                         and agu_icb_cmd_hsked and (not flush_pulse);
  state_idle_nxt      <= ICB_STATE_1ST;

  -- **** If the current state is 1st,
  -- If a response come, exit this state
  state_1st_exit_ena <= icb_sta_is_1st and (agu_icb_rsp_hsked or flush_pulse);
  state_1st_nxt      <= ICB_STATE_IDLE when flush_pulse = '1' else 
                        (
                          ICB_STATE_AMOALU
                        );
     
  -- **** If the current state is AMOALU 
  -- Since the ALU is must be holdoff now, it can always be
  --   served and then enter into next state
  state_amoalu_exit_ena <= icb_sta_is_amoalu and ( '1' or flush_pulse);
  state_amoalu_nxt      <= ICB_STATE_IDLE when flush_pulse = '1' else ICB_STATE_AMORDY;
            
  -- **** If the current state is AMORDY
  -- It always enter into next state
  state_amordy_exit_ena <= icb_sta_is_amordy and ( '1' or flush_pulse);
  state_amordy_nxt      <= ICB_STATE_IDLE when flush_pulse = '1' else 
                           (
                            -- AMO after caculated read-modify-result, need to issue 2nd uop as store
                            --   back to memory, hence two ICB needed and we dont care the performance,
                            --   so always let it jump to wait2nd state
                            ICB_STATE_WAIT2ND
                           );

  -- **** If the current state is wait-2nd,
  state_wait2nd_exit_ena <= icb_sta_is_wait2nd and (agu_icb_cmd_ready or flush_pulse);
  -- If the ICB CMD is ready, then next state is ICB_STATE_2ND
  state_wait2nd_nxt      <= ICB_STATE_IDLE when flush_pulse = '1' else ICB_STATE_2ND;
  
  -- **** If the current state is 2nd,
  -- If a response come, exit this state
  state_2nd_exit_ena <= icb_sta_is_2nd and (agu_icb_rsp_hsked or flush_pulse);
  state_2nd_nxt      <= ICB_STATE_IDLE when flush_pulse = '1' else
                        (
                          ICB_STATE_WBCK 
                        );

  -- **** If the current state is wbck,
  -- If it can be write back, exit this state
  state_wbck_exit_ena <= icb_sta_is_wbck and (agu_o_ready or flush_pulse);
  state_wbck_nxt      <= ICB_STATE_IDLE when flush_pulse = '1' else 
                         (
                           ICB_STATE_IDLE 
                         );
 `end if

  -- The state will only toggle when each state is meeting the condition to exit:
  icb_state_ena <= '0' 
                `if E203_SUPPORT_AMO = "TRUE" then
                   or state_idle_exit_ena    or state_1st_exit_ena  
                   or state_amoalu_exit_ena  or state_amordy_exit_ena  
                   or state_wait2nd_exit_ena or state_2nd_exit_ena   
                   or state_wbck_exit_ena 
                `end if
                 ;

  -- The next-state is onehot mux to select different entries
  icb_state_nxt <= 
                     ((ICB_STATE_WIDTH-1 downto 0 => '0'))
                `if E203_SUPPORT_AMO = "TRUE" then
                  or ((ICB_STATE_WIDTH-1 downto 0 => state_idle_exit_ena   ) and state_idle_nxt   )
                  or ((ICB_STATE_WIDTH-1 downto 0 => state_1st_exit_ena    ) and state_1st_nxt    )
                  or ((ICB_STATE_WIDTH-1 downto 0 => state_amoalu_exit_ena ) and state_amoalu_nxt )
                  or ((ICB_STATE_WIDTH-1 downto 0 => state_amordy_exit_ena ) and state_amordy_nxt )
                  or ((ICB_STATE_WIDTH-1 downto 0 => state_wait2nd_exit_ena) and state_wait2nd_nxt)
                  or ((ICB_STATE_WIDTH-1 downto 0 => state_2nd_exit_ena    ) and state_2nd_nxt    )
                  or ((ICB_STATE_WIDTH-1 downto 0 => state_wbck_exit_ena   ) and state_wbck_nxt   )
                `end if
                     ;


  icb_state_dfflr: component sirv_gnrl_dfflr generic map (ICB_STATE_WIDTH)
                                                port map (icb_state_ena, icb_state_nxt, icb_state_r, clk, rst_n);


 `if E203_SUPPORT_AMO = "TRUE" then
  icb_sta_is_last <= icb_sta_is_wbck;
 `end if 
 `if E203_SUPPORT_AMO = "FALSE" then
  icb_sta_is_last <= '0'; 
 `end if
 `if E203_SUPPORT_AMO = "TRUE" then
  state_last_exit_ena <= state_wbck_exit_ena;
 `end if
 `if E203_SUPPORT_AMO = "FALSE" then
  state_last_exit_ena <= '0';
 `end if

 `if E203_SUPPORT_UNALGNLDST = "FALSE" then
 `else 
   `ifndef E203_SUPPORT_AMO = "FALSE" then
   `error "!!!! This config is not supported, must be something wrong"
   `end if
 `end if


  -- Indicate there is no oustanding memory transactions
 `if E203_SUPPORT_AMO = "TRUE" then
  -- As long as the statemachine started, we must wait it to be empty
  -- We cannot really kill this instruction when IRQ comes, becuase
  -- the AMO uop alreay write data into the memory, and we must commit
  -- this instructions
  amo_wait <= not icb_sta_is_idle;
 `end if
 `if E203_SUPPORT_AMO = "FALSE" then
  amo_wait = '0'; -- If no AMO or UNaligned supported, then always 0
 `end if

  -- Implement the leftover 0 buffer
 `if E203_SUPPORT_AMO = "TRUE" then
  amo_1stuop <= icb_sta_is_1st and agu_i_algnamo;
  amo_2nduop <= icb_sta_is_2nd and agu_i_algnamo;
 `end if
  leftover_ena <= agu_icb_rsp_hsked and (
                  '0'
                 `if E203_SUPPORT_AMO = "TRUE" then
                  or amo_1stuop 
                  or amo_2nduop 
                 `end if
                  );
  leftover_nxt <= 
                     (E203_XLEN-1 downto 0 => '0')
               `if E203_SUPPORT_AMO = "TRUE" then
                 or ((E203_XLEN-1 downto 0 => amo_1stuop) and agu_icb_rsp_rdata) -- Load the data from bus
                 or ((E203_XLEN-1 downto 0 => amo_2nduop) and leftover_r)        -- Unchange the value of leftover_r
               `end if
                  ;
                                   
  leftover_err_nxt <= '0' 
                  `if E203_SUPPORT_AMO = "TRUE" then
                    or (amo_1stuop and  agu_icb_rsp_err)                    -- 1st error from the bus
                    or (amo_2nduop and (agu_icb_rsp_err or leftover_err_r)) -- second error merged
                  `end if
                  ;
  
  -- The instantiation of leftover buffer is actually shared with the ALU SBF-0 Buffer
  agu_sbf_0_ena <= leftover_ena;
  agu_sbf_0_nxt <= leftover_nxt;
  leftover_r    <= agu_sbf_0_r;

  -- The error bit is implemented here
  icb_leftover_err_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                       port map (lden    => leftover_ena, 
                                                                 dnxt(0) => leftover_err_nxt, 
                                                                 qout(0) => leftover_err_r, 
                                                                 clk     => clk,
                                                                 rst_n   => rst_n
                                                       	        );
  
  leftover_1_ena <= '0' 
                `if E203_SUPPORT_AMO = "TRUE" then
                  or icb_sta_is_amoalu 
                `end if
                  ;
  leftover_1_nxt <= agu_req_alu_res;
  
  -- The instantiation of last_icb_addr buffer is actually shared with the ALU SBF-1 Buffer
  agu_sbf_1_ena   <= leftover_1_ena;
  agu_sbf_1_nxt   <= leftover_1_nxt;
  leftover_1_r    <= agu_sbf_1_r;


  agu_req_alu_add <= '0'
                    `if E203_SUPPORT_AMO = "TRUE" then
                     or (icb_sta_is_amoalu and agu_i_amoadd)
                     -- In order to let AMO 2nd uop have correct address
                     or (agu_i_amo and (icb_sta_is_wait2nd or icb_sta_is_2nd or icb_sta_is_wbck))
                    `end if
                     -- To cut down the timing loop from agu_i_valid // | (icb_sta_is_idle & agu_i_valid)
                     --   we dont need this signal at all
                     or icb_sta_is_idle
                     ;

  agu_req_alu_op1 <= agu_i_rs1 when icb_sta_is_idle = '1' else
                    `if E203_SUPPORT_AMO = "TRUE" then
                     leftover_r when icb_sta_is_amoalu = '1' else
                     -- In order to let AMO 2nd uop have correct address
                     agu_i_rs1 when ((agu_i_amo and (icb_sta_is_wait2nd or icb_sta_is_2nd or icb_sta_is_wbck)) = '1') else 
                    `end if
                    `if E203_SUPPORT_UNALGNLDST = "FALSE" then
                     (E203_XLEN-1 downto 0 => '0')
                    `else
                    `error "The expression do not exist in orignal version, i add it. Was it right?" 
                    `end if
                     ;

  agu_addr_gen_op2 <= (E203_XLEN-1 downto 0 => '0') when agu_i_ofst0 = '1' else agu_i_imm;
  agu_req_alu_op2  <= agu_addr_gen_op2 when icb_sta_is_idle = '1' else
                     `if E203_SUPPORT_AMO = "TRUE" then
                      agu_i_rs2 when icb_sta_is_amoalu = '1' else
                      -- In order to let AMO 2nd uop have correct address
                      agu_addr_gen_op2 when ((agu_i_amo and (icb_sta_is_wait2nd or icb_sta_is_2nd or icb_sta_is_wbck)) = '1') else
                     `end if
                     `if E203_SUPPORT_UNALGNLDST = "FALSE" then
                      (E203_XLEN-1 downto 0 => '0')
                     `else
                     `error "The expression do not exist in orignal version, i add it. Was it right?" 
                     `end if
                     ;

 `if E203_SUPPORT_AMO = "TRUE" then
  agu_req_alu_swap <= (icb_sta_is_amoalu and agu_i_amoswap);
  agu_req_alu_and  <= (icb_sta_is_amoalu and agu_i_amoand );
  agu_req_alu_or   <= (icb_sta_is_amoalu and agu_i_amoor  );
  agu_req_alu_xor  <= (icb_sta_is_amoalu and agu_i_amoxor );
  agu_req_alu_max  <= (icb_sta_is_amoalu and agu_i_amomax );
  agu_req_alu_min  <= (icb_sta_is_amoalu and agu_i_amomin );
  agu_req_alu_maxu <= (icb_sta_is_amoalu and agu_i_amomaxu);
  agu_req_alu_minu <= (icb_sta_is_amoalu and agu_i_amominu);
 `end if
 `if E203_SUPPORT_AMO = "FALSE" then
  agu_req_alu_swap <= 1'b0;
  agu_req_alu_and  <= 1'b0;
  agu_req_alu_or   <= 1'b0;
  agu_req_alu_xor  <= 1'b0;
  agu_req_alu_max  <= 1'b0;
  agu_req_alu_min  <= 1'b0;
  agu_req_alu_maxu <= 1'b0;
  agu_req_alu_minu <= 1'b0;
 `end if



  -- Implement the AGU op handshake ready signal
  --
  -- The AGU op handshakeke interface will be ready when
  --   * If it is unaligned instructions, then it will just 
  --       directly pass out the write-back interface, hence it will only be 
  --       ready when the write-back interface is ready
  --   * If it is not unaligned load/store instructions, then it will just 
  --       directly pass out the instruction to LSU-ctrl interface, hence it need to check
  --       the AGU ICB interface is ready, but it also need to ask write-back interface 
  --       for commit, so, also need to check if write-back interfac is ready
  --       
 `if E203_SUPPORT_UNALGNLDST = "FALSE" then
 `else 
 `ERROR "This UNALIGNED load/store is not supported, must be something wrong" 
 `end if 

  agu_i_ready <= state_last_exit_ena when
                 ( '0'
             `if E203_SUPPORT_AMO = "TRUE" then
                  or agu_i_algnamo 
             `end if
                 ) = '1' else
                 (agu_icb_cmd_ready and agu_o_ready) ;
  
  -- The aligned load/store instruction will be dispatched to LSU as long pipeline
  --   instructions
  agu_i_longpipe <= agu_i_algnldst;
  
  -- Implement the Write-back interfaces (unaligned and AMO instructions) 

  -- The AGU write-back will be valid when:
  --   * For the aligned load/store
  --       Directly passed to ICB interface, but also need to pass 
  --       to write-back interface asking for commit
  agu_o_valid <= 
                `if E203_SUPPORT_AMO = "TRUE" then
                 -- For the unaligned load/store and aligned AMO, it will enter 
                 --   into the state machine and let the last state to send back
                 --   to the commit stage
                 icb_sta_is_last 
                `end if
                 -- For the aligned load/store and unaligned AMO, it will be send
                 --   to the commit stage right the same cycle of agu_i_valid
                 or (
                      agu_i_valid and ( agu_i_algnldst 
                `if E203_SUPPORT_UNALGNLDST = "FALSE" then
                 -- If not support the unaligned load/store by hardware, then 
                 -- the unaligned load/store will be treated as exception
                 -- and it will also be send to the commit stage right the
                 -- same cycle of agu_i_valid
                      or agu_i_unalgnldst
                `end if
                `if E203_SUPPORT_AMO = "TRUE" then
                      or agu_i_unalgnamo 
                `end if
                    )
                 -- Since it is issuing to commit stage and 
                 -- LSU at same cycle, so we must qualify the icb_cmd_ready signal from LSU
                 -- to make sure it is out to commit/LSU at same cycle
                 -- To cut the critical timing  path from longpipe signal
                 -- we always assume the AGU will need icb_cmd_ready
                 and agu_icb_cmd_ready
                    );

  agu_o_wbck_wdat <= (E203_XLEN-1 downto 0 => '0')
                 `if E203_SUPPORT_AMO = "TRUE" then
                    or ((E203_XLEN-1 downto 0 => agu_i_algnamo  ) and leftover_r) 
                    or ((E203_XLEN-1 downto 0 => agu_i_unalgnamo) and (E203_XLEN-1 downto 0 => '0')) 
                 `end if
                  ;

  agu_o_cmt_buserr <= ('0' 
                  `if E203_SUPPORT_AMO = "TRUE" then
                      or (agu_i_algnamo    and leftover_err_r) 
                      or (agu_i_unalgnamo  and '0') 
                  `end if
                      );
  agu_o_cmt_badaddr <= agu_icb_cmd_addr;


  agu_o_cmt_misalgn <= ('0'
                   `if E203_SUPPORT_AMO = "TRUE" then
                       or agu_i_unalgnamo 
                   `end if
                       or (agu_i_unalgnldst) -- We dont support unaligned load/store regardless it is AMO or not
                       );
  agu_o_cmt_ld      <= agu_i_load and (not agu_i_excl); 
  agu_o_cmt_stamo   <= agu_i_store or agu_i_amo or agu_i_excl;

  
  -- The exception or error result cannot write-back
  agu_o_wbck_err <= agu_o_cmt_buserr or agu_o_cmt_misalgn;

  agu_icb_rsp_ready <= '1';


  

  agu_icb_cmd_valid <= 
                     ((agu_i_algnldst and agu_i_valid)
                     -- We must qualify the agu_o_ready signal from commit stage
                     -- to make sure it is out to commit/LSU at same cycle
                     and (agu_o_ready)
                     )
                   `if E203_SUPPORT_AMO = "TRUE" then
                     or (agu_i_algnamo and (
                                           (icb_sta_is_idle and agu_i_valid 
                                            -- We must qualify the agu_o_ready signal from commit stage
                                            -- to make sure it is out to commit/LSU at same cycle
                                            and agu_o_ready)
                                            or icb_sta_is_wait2nd))
                     or (agu_i_unalgnamo and '0') 
                   `end if
                     ;
  agu_icb_cmd_addr <= agu_req_alu_res(E203_ADDR_SIZE-1 downto 0);

  agu_icb_cmd_read <= 
                   (agu_i_algnldst and agu_i_load) 
                  `if E203_SUPPORT_AMO = "TRUE" then
                   or (agu_i_algnamo and icb_sta_is_idle and '1')
                   or (agu_i_algnamo and icb_sta_is_wait2nd and '0') 
                  `end if
                   ;

  -- The AGU ICB CMD Wdata sources:
  --   * For the aligned store instructions
  --       Directly passed to AGU ICB, wdata is op2 repetitive form, 
  --       wmask is generated according to the LSB and size

  algnst_wdata <= 
             ((E203_XLEN-1 downto 0 => agu_i_size_b ) and (agu_i_rs2(7 downto 0) & agu_i_rs2(7 downto 0) & agu_i_rs2(7 downto 0) & agu_i_rs2(7 downto 0)))
          or ((E203_XLEN-1 downto 0 => agu_i_size_hw) and (agu_i_rs2(15 downto 0) & agu_i_rs2(15 downto 0)))
          or ((E203_XLEN-1 downto 0 => agu_i_size_w ) and agu_i_rs2(31 downto 0));
  
  algnst_wmask <= 
             ((E203_XLEN/8-1 downto 0 => agu_i_size_b ) and (4b"0001" sll to_integer(u_unsigned(agu_icb_cmd_addr(1 downto 0)))))
          or ((E203_XLEN/8-1 downto 0 => agu_i_size_hw) and (4b"0011" sll to_integer(u_unsigned'(agu_icb_cmd_addr(1) & '0')))) -- a useful trick for u_unsigned'() on page 257
          or ((E203_XLEN/8-1 downto 0 => agu_i_size_w ) and (4b"1111"));

          
  agu_icb_cmd_wdata <= 
                   `if E203_SUPPORT_AMO = "TRUE" then
                    leftover_1_r when agu_i_amo = '1' else
                   `end if
                    algnst_wdata;

  leftover_error_no <= 4x"0" when leftover_err_r = '1' else 4x"F";
  agu_icb_cmd_wmask <=
                   `if E203_SUPPORT_AMO = "TRUE" then
                    -- If the 1st uop have bus-error, then not write the data for 2nd uop
                    leftover_error_no when agu_i_amo = '1' else
                   `end if
                    algnst_wmask; 

  agu_icb_cmd_back2agu <= '0'
                      `if E203_SUPPORT_AMO = "TRUE" then
                       or agu_i_algnamo  
                      `end if
                       ;
  -- We dont support lock and exclusive in such 2 stage simple implementation
  agu_icb_cmd_lock <= '0' 
                  `if E203_SUPPORT_AMO = "TRUE" then
                   or (agu_i_algnamo and icb_sta_is_idle)
                  `end if
                   ;
  agu_icb_cmd_excl <= '0'
                  `if E203_SUPPORT_AMO = "TRUE" then
                   or agu_i_excl
                  `end if
                   ;

  agu_icb_cmd_itag  <= agu_i_itag;
  agu_icb_cmd_usign <= agu_i_usign;
  agu_icb_cmd_size  <= agu_i_size;

end impl;