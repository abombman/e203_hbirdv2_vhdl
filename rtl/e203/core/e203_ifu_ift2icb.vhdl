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
--  The Lite-BPU module to handle very simple branch predication at IFU 
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_ifu_ift2icb is 
  port ( 
  	     itcm_nohold:       in std_logic;

  	     -- Fetch Interface to memory system, internal protocol
         --    * IFetch REQ channel
  	     ifu_req_valid:     in std_logic;  -- Handshake valid
  	     ifu_req_ready:    out std_logic;  -- Handshake ready

  	     -- Note: the req-addr can be unaligned with the length indicated
         --       by req_len signal.
         --       The targetd (ITCM, ICache or Sys-MEM) ctrl modules 
         --       will handle the unalign cases and split-and-merge works
  	     ifu_req_pc:        in std_logic_vector(E203_PC_SIZE-1 downto 0);  -- Fetch PC
  	     ifu_req_seq:       in std_logic;  -- This request is a sequential instruction fetch
  	     ifu_req_seq_rv32:  in std_logic;  -- This request is incremented 32bits fetch
         ifu_req_last_pc:   in std_logic_vector(E203_PC_SIZE-1 downto 0);  -- The last accessed
                                                                           -- PC address (i.e., pc_r)
  	     --  * IFetch RSP channel
  	     ifu_rsp_valid:    out std_logic;  -- Response valid
  	     ifu_rsp_ready:     in std_logic;  -- Response ready
  	     ifu_rsp_err:      out std_logic;  -- Response error
         -- Note: the RSP channel always return a valid instruction
         --   fetched from the fetching start PC address.
         --   The targetd (ITCM, ICache or Sys-MEM) ctrl modules 
         --   will handle the unalign cases and split-and-merge works
         --output ifu_rsp_replay,   // Response error
         ifu_rsp_instr:    out std_logic_vector(32-1 downto 0); -- Response instruction

         `if E203_HAS_ITCM = "TRUE" then 
         -- The ITCM address region indication signal
         itcm_region_indic:       in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         -- Bus Interface to ITCM, internal protocol called ICB (Internal Chip Bus)
         --    * Bus cmd channel
         ifu2itcm_icb_cmd_valid: out std_logic;  -- Handshake valid
  	     ifu2itcm_icb_cmd_ready:  in std_logic;  -- Handshake ready
  	     -- Note: The data on rdata or wdata channel must be naturally
         --       aligned, this is in line with the AXI definition
         ifu2itcm_icb_cmd_addr:  out std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);  -- Bus transaction start addr

         --    * Bus RSP channel
         ifu2itcm_icb_rsp_valid:  in std_logic;  -- Response valid 
  	     ifu2itcm_icb_rsp_ready: out std_logic;  -- Response ready
  	     ifu2itcm_icb_rsp_err:    in std_logic;  -- Response error
  	     -- Note: the RSP rdata is inline with AXI definition
  	     ifu2itcm_icb_rsp_rdata:  in std_logic_vector(E203_ITCM_DATA_WIDTH-1 downto 0);    
         `end if
         
         `if E203_HAS_MEM_ITF = "TRUE" then 
         -- Bus Interface to System Memory, internal protocol called ICB (Internal Chip Bus)
         --    * Bus cmd channel
         ifu2biu_icb_cmd_valid:  out std_logic;  -- Handshake valid
  	     ifu2biu_icb_cmd_ready:   in std_logic;  -- Handshake ready
  	     -- Note: The data on rdata or wdata channel must be naturally
         --       aligned, this is in line with the AXI definition
         ifu2biu_icb_cmd_addr:   out std_logic_vector(E203_ADDR_SIZE-1 downto 0);  -- Bus transaction start addr 
         
         --    * Bus RSP channel
         ifu2biu_icb_rsp_valid:   in std_logic;  -- Response valid 
  	     ifu2biu_icb_rsp_ready:  out std_logic;  -- Response ready
  	     ifu2biu_icb_rsp_err:     in std_logic;  -- Response error
  	     -- Note: the RSP rdata is inline with AXI definition
  	     ifu2biu_icb_rsp_rdata:   in std_logic_vector(E203_SYSMEM_DATA_WIDTH-1 downto 0);
  	     --input  ifu2biu_replay,
         `end if

         -- The holdup indicating the target is not accessed by other agents 
         -- since last accessed by IFU, and the output of it is holding up
         -- last value. 
         `if E203_HAS_ITCM = "TRUE" then
         ifu2itcm_holdup:         in std_logic;
         --input  ifu2itcm_replay,
         `end if

         clk:               in std_logic;
         rst_n:             in std_logic
  );
end e203_ifu_ift2icb;

architecture impl of e203_ifu_ift2icb is 
  signal i_ifu_rsp_valid:       std_logic;
  signal i_ifu_rsp_ready:       std_logic;
  signal i_ifu_rsp_err:         std_logic;
  signal i_ifu_rsp_instr:       std_logic_vector(E203_INSTR_SIZE-1   downto 0);
  signal ifu_rsp_bypbuf_i_data: std_logic_vector(E203_INSTR_SIZE+1-1 downto 0);
  signal ifu_rsp_bypbuf_o_data: std_logic_vector(E203_INSTR_SIZE+1-1 downto 0);

`if E203_HAS_ITCM = "TRUE" then
  signal ifu_req_pc2itcm:       std_logic;
  signal ifu_icb_cmd2itcm:      std_logic;
  signal icb_cmd2itcm_r:        std_logic;
  signal ifu2itcm_icb_rsp_instr:std_logic_vector(31 downto 0);
`end if

`if E203_HAS_MEM_ITF = "TRUE" then
  signal ifu_req_pc2mem:        std_logic;
  signal ifu_icb_cmd2biu:       std_logic;
  signal icb_cmd2biu_r:         std_logic;
  signal ifu2biu_icb_rsp_instr: std_logic_vector(31 downto 0);
  signal ifu2biu_icb_cmd_valid_pre: std_logic;
  signal ifu2biu_icb_cmd_addr_pre:  std_logic_vector(E203_ADDR_SIZE-1 downto 0);
  signal ifu2biu_icb_cmd_ready_pre: std_logic;
`end if
  
  signal ifu_req_lane_cross:    std_logic;
  signal ifu_req_lane_begin:    std_logic;
 
  signal req_lane_status:       std_logic;
  signal req_lane_cross_r:      std_logic;
  signal ifu_req_lane_same:     std_logic;

  signal ifu_req_lane_holdup:   std_logic;

  signal ifu_req_hsked:         std_logic;
  signal i_ifu_rsp_hsked:       std_logic;
  signal ifu_icb_cmd_valid:     std_logic;
  signal ifu_icb_cmd_ready:     std_logic;
  signal ifu_icb_cmd_hsked:     std_logic;
  signal ifu_icb_rsp_valid:     std_logic;
  signal ifu_icb_rsp_ready:     std_logic;
  signal ifu_icb_rsp_hsked:     std_logic;

  signal req_need_2uop_r:       std_logic;
  signal req_need_0uop_r:       std_logic;
 
  constant ICB_STATE_WIDTH:     integer:= 2;
  -- State 0: The idle state, means there is no any oustanding ifetch request
  constant ICB_STATE_IDLE:      std_logic_vector(ICB_STATE_WIDTH-1 downto 0):= "00";
  -- State 1: Issued first request and wait response
  constant ICB_STATE_1ST:       std_logic_vector(ICB_STATE_WIDTH-1 downto 0):= "01";
  -- State 2: Wait to issue second request
  constant ICB_STATE_WAIT2ND:   std_logic_vector(ICB_STATE_WIDTH-1 downto 0):= "10";
  -- State 3: Issued second request and wait response
  constant ICB_STATE_2ND:       std_logic_vector(ICB_STATE_WIDTH-1 downto 0):= "11";

  signal   icb_state_nxt:       std_logic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal   icb_state_r:         std_logic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal   icb_state_ena:       std_logic;
  signal   state_idle_nxt:      std_logic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal   state_1st_nxt:       std_logic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal   state_wait2nd_nxt:   std_logic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal   state_2nd_nxt:       std_logic_vector(ICB_STATE_WIDTH-1 downto 0);
  signal state_idle_exit_ena:   std_logic;
  signal state_1st_exit_ena:    std_logic;
  signal state_wait2nd_exit_ena:std_logic;
  signal state_2nd_exit_ena:    std_logic;
  signal icb_sta_is_idle:       std_logic;
  signal icb_sta_is_1st:        std_logic;
  signal icb_sta_is_wait2nd:    std_logic;
  signal icb_sta_is_2nd:        std_logic;
  signal ifu_icb_rsp2leftover:  std_logic;
  signal is_icb_rsp2leftover:   std_logic;
  signal req_same_cross_holdup_r:std_logic;
  signal req_same_cross_holdup:  std_logic;
  signal req_need_2uop:          std_logic;
  signal req_need_0uop:          std_logic;

  signal ifu_icb_cmd_addr:       std_logic_vector(E203_PC_SIZE-1 downto 0);
  
  signal icb_cmd_addr_2_1_ena:   std_logic;
  signal icb_cmd_addr_2_1_r:     std_logic_vector(1 downto 0);

  signal leftover_ena:           std_logic;
  signal leftover_nxt:           std_logic_vector(15 downto 0);
  signal leftover_r:             std_logic_vector(15 downto 0);
  signal leftover_err_nxt:       std_logic;
  signal leftover_err_r:         std_logic;
  signal holdup2leftover_sel:    std_logic;
  signal holdup2leftover_ena:    std_logic;
  signal put2leftover_data:      std_logic_vector(15 downto 0);

  signal uop1st2leftover_sel:    std_logic;
  signal uop1st2leftover_ena:    std_logic;
  signal uop1st2leftover_err:    std_logic;

  signal rsp_instr_sel_leftover: std_logic;
  signal rsp_instr_sel_icb_rsp:  std_logic;
  signal ifu_icb_rsp_rdata_lsb16:std_logic_vector(15 downto 0);

  signal ifu_icb_rsp_instr:      std_logic_vector(31 downto 0);
  signal ifu_icb_rsp_err:        std_logic;

  signal holdup_gen_fake_rsp_valid: std_logic;
  
  signal ifu_icb_rsp2ir_ready:   std_logic;
  signal ifu_icb_rsp2ir_valid:   std_logic;

  signal ifu_req_valid_pos:      std_logic;
  signal icb_addr_sel_1stnxtalgn:std_logic;
  signal icb_addr_sel_2ndnxtalgn:std_logic;
  signal icb_addr_sel_cur:       std_logic;
  signal nxtalgn_plus_offset:    signed(E203_PC_SIZE-1 downto 0);
  signal icb_algn_nxt_lane_addr: std_logic_vector(E203_PC_SIZE-1 downto 0);

  signal ifu_req_ready_condi:    std_logic;

  component sirv_gnrl_bypbuf is
    generic(
            DP: integer;
            DW: integer
    );
    port(                         
          i_vld:  in std_logic;
          i_rdy: out std_logic;
          i_dat:  in std_logic_vector( DW-1 downto 0 );

          o_vld: out std_logic;
          o_rdy:  in std_logic;
          o_dat: out std_logic_vector( DW-1 downto 0 );
          
          clk:    in std_logic;
          rst_n:  in std_logic 
    );
  end component;
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
  component sirv_gnrl_dffl is
    generic( DW: integer );
    port(     
          lden:  in std_logic;
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic
    );
  end component;
begin
`if E203_HAS_ITCM = "FALSE" then
  `if E203_HAS_MEM_ITF = "FALSE" then
  `error "!!! ERROR: There is no ITCM and no System interface, where to fetch the instructions? must be wrong configuration."
  `end if
`end if  
  
  --///////////////////////////////////////////////////////
  -- We need to instante this bypbuf for several reasons:
  --   * The IR stage ready signal is generated from EXU stage which 
  --      incoperated several timing critical source (e.g., ECC error check, .etc)
  --      and this ready signal will be back-pressure to ifetch rsponse channel here
  --   * If there is no such bypbuf, the ifetch response channel may stuck waiting
  --      the IR stage to be cleared, and this may end up with a deadlock, becuase 
  --      EXU stage may access the BIU or ITCM and they are waiting the IFU to accept
  --      last instruction access to make way of BIU and ITCM for LSU to access
  ifu_rsp_bypbuf_i_data <= (
                             i_ifu_rsp_err,
                             i_ifu_rsp_instr
                           );

  (
    ifu_rsp_err,
    ifu_rsp_instr
  ) <= ifu_rsp_bypbuf_o_data;

  u_e203_ifetch_rsp_bypbuf: component sirv_gnrl_bypbuf generic map ( DP => 1,
  	                                                                  DW => E203_INSTR_SIZE+1
  	                                                                )
                                                          port map ( i_vld  => i_ifu_rsp_valid,
                                                                     i_rdy  => i_ifu_rsp_ready,
                                                              
                                                                     o_vld  => ifu_rsp_valid,
                                                                     o_rdy  => ifu_rsp_ready,
                                                              
                                                                     i_dat  => ifu_rsp_bypbuf_i_data,
                                                                     o_dat  => ifu_rsp_bypbuf_o_data,
                                                               
                                                                     clk    => clk  ,
                                                                     rst_n  => rst_n
                                                          	       );
  
  -- ===========================================================================
  --////////////////////////////////////////////////////////////
  --////////////////////////////////////////////////////////////
  --///// The itfctrl scheme introduction
  --
  -- The instruction fetch is very tricky due to two reasons and purposes:
  --   (1) We want to save area and dynamic power as much as possible
  --   (2) The 32bits-length instructon may be in unaligned address
  --
  -- In order to acheive above-mentioned purposes we define the tricky
  --   fetch scheme detailed as below.
  --
  --/////
  -- Firstly, several phrases are introduced here:
  --   * Fetching target: the target address region including
  --         ITCM,
  --         System Memory Fetch Interface or ICache
  --            (Note: Sys Mem and I cache are Exclusive with each other)
  --   * Fetching target's Lane: The Lane here means the fetching 
  --       target can read out one lane of data at one time. 
  --       For example: 
  --        * ITCM is 64bits wide SRAM, then it can read out one 
  --          aligned 64bits one time (as a lane)
  --        * System Memory is 32bits wide bus, then it can read out one 
  --          aligned 32bits one time (as a lane)
  --        * ICache line is N-Bytes wide SRAM, then it can read out one 
  --          aligned N-Bytes one time (as a lane)
  --   * Lane holding-up: The read-out Lane could be holding up there
  --       For examaple:
  --        * ITCM is impelemented as SRAM, the output of SRAM (readout lane)
  --          will keep holding up and not change until next time the SRAM
  --          is accessed (CS asserted) by new transaction
  --        * ICache data ram is impelemented as SRAM, the output of
  --          SRAM (readout lane) will keep holding up and not change until
  --          next time the SRAM is accessed (CS asserted) by new transaction
  --        * The system memory bus is from outside core peripheral or memory
  --          we dont know if it will hold-up. Hence, we assume it is not
  --          hoding up
  --   * Crossing Lane: Since the 32bits-length instruction maybe unaligned with 
  --       word address boundry, then it could be in a cross-lane address
  --       For example: 
  --        * If it is crossing 64bits boundry, then it is crossing ITCM Lane
  --        * If it is crossing 32bits boundry, then it is crossing System Memory Lane
  --        * If it is crossing N-Bytes boundry, then it is crossing ICache Lane
  --   * IR register: The fetch instruction will be put into IR register which 
  --       is to be used by decoder to decoding it at EXU stage
  --       The Lower 16bits of IR will always be loaded with new coming
  --       instructions, but in order to save dynamic power, the higher 
  --       16bits IR will only be loaded when incoming instruction is
  --       32bits-length (checked by mini-decode module upfront IR 
  --       register)
  --       Note: The source of IR register Din depends on different
  --         situations described in detailed fetching sheme
  --   * Leftover buffer: The ifetch will always speculatively fetch a 32bits
  --       back since we dont know the instruction to be fetched is 32bits or
  --       16bits length (until after it read-back and decoded by mini-decoder).
  --       When the new fetch is crossing lane-boundry from current lane
  --       to next lane, and if the current lane read-out value is holding up.
  --       Then new 32bits instruction to be fetched can be concatated by 
  --       "current holding-up lane's upper 16bits" and "next lane's lower 16bits".
  --       To make it in one cycle, we push the "current holding-up lane's 
  --       upper 16bits" into leftover buffer (16bits) and only issue one ifetch
  --       request to memory system, and when it responded with rdata-back, 
  --       directly concatate the upper 16bits rdata-back with leftover buffer
  --       to become the full 32bits instruction.
  --
  -- The new ifetch request could encounter several cases:
  --   * If the new ifetch address is in the same lane portion as last fetch
  --     address (current PC):
  --     ** If it is crossing the lane boundry, and the current lane rdout is 
  --        holding up, then
  --        ---- Push current lane rdout's upper 16bits into leftover buffer
  --        ---- Issue ICB cmd request with next lane address 
  --        ---- After the response rdata back:
  --            ---- Put the leftover buffer value into IR lower 16bits
  --            ---- Put rdata lower 16bits into IR upper 16bits if instr is 32bits-long
  --
  --     ** If it is crossing the lane boundry, but the current lane rdout is not 
  --        holding up, then
  --        ---- First cycle Issue ICB cmd request with current lane address 
  --            ---- Put rdata upper 16bits into leftover buffer
  --        ---- Second cycle Issue ICB cmd request with next lane address 
  --            ---- Put the leftover buffer value into IR lower 16bits
  --            ---- Put rdata upper 16bits into IR upper 16bits if instr is 32bits-long
  --
  --     ** If it is not crossing the lane boundry, and the current lane rdout is 
  --        holding up, then
  --        ---- Not issue ICB cmd request, just directly use current holding rdata
  --            ---- Put aligned rdata into IR (upper 16bits 
  --                    only loaded when instr is 32bits-long)
  --
  --     ** If it is not crossing the lane boundry, but the current lane rdout is 
  --        not holding up, then
  --        ---- Issue ICB cmd request with current lane address, just directly use
  --               current holding rdata
  --            ---- Put aligned rdata into IR (upper 16bits 
  --                    only loaded when instr is 32bits-long)
  --   
  --
  --   * If the new ifetch address is in the different lane portion as last fetch
  --     address (current PC):
  --     ** If it is crossing the lane boundry, regardless the current lane rdout is 
  --        holding up or not, then
  --        ---- First cycle Issue ICB cmd reqeust with current lane address 
  --            ---- Put rdata upper 16bits into leftover buffer
  --        ---- Second cycle Issue ICB cmd reqeust with next lane address 
  --            ---- Put the leftover buffer value into IR lower 16bits
  --            ---- Put rdata upper 16bits into IR upper 16bits if instr is 32bits-long
  --
  --     ** If it is not crossing the lane boundry, then
  --        ---- Issue ICB cmd request with current lane address, just directly use
  --               current holding rdata
  --            ---- Put aligned rdata into IR (upper 16bits 
  --                    only loaded when instr is 32bits-long)
  --
  -- ===========================================================================
  
  `if E203_HAS_ITCM = "TRUE" then
    ifu_req_pc2itcm <= (ifu_req_pc(E203_ITCM_BASE_REGION'range) ?= itcm_region_indic(E203_ITCM_BASE_REGION'range));
  `end if

  `if E203_HAS_MEM_ITF = "TRUE" then
    ifu_req_pc2mem <= '1'
  `if E203_HAS_ITCM = "TRUE" then
                      and (not ifu_req_pc2itcm)
  `end if
                      ;
  `end if
  
  -- The current accessing PC is crossing the lane boundry
  ifu_req_lane_cross <= '0'
  `if E203_HAS_ITCM = "TRUE" then
                        or (ifu_req_pc2itcm
  `if E203_ITCM_DATA_WIDTH_IS_32 = "TRUE" then
                        and (ifu_req_pc(1) ?= '1')
  `end if
  `if E203_ITCM_DATA_WIDTH_IS_64 = "TRUE" then
                        and (ifu_req_pc(2 downto 1) ?= "11")
  `end if
                        )
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
                        or (ifu_req_pc2mem
  `if E203_SYSMEM_DATA_WIDTH_IS_32 = "TRUE" then
                        and (ifu_req_pc(1) ?= '1')
  `end if
  `if E203_SYSMEM_DATA_WIDTH_IS_64 = "TRUE" then
                        and (ifu_req_pc(2 downto 1) ?= "11")
  `end if
                        )
  `end if
                        ;

  -- The current accessing PC is begining of the lane boundry
  ifu_req_lane_begin <= '0'
  `if E203_HAS_ITCM = "TRUE" then
                        or (ifu_req_pc2itcm
  `if E203_ITCM_DATA_WIDTH_IS_32 = "TRUE" then
                        and (ifu_req_pc(1) ?= '0')
  `end if
  `if E203_ITCM_DATA_WIDTH_IS_64 = "TRUE" then
                        and (ifu_req_pc(2 downto 1) ?= "00")
  `end if
                        )
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then
                        or (ifu_req_pc2mem
  `if E203_SYSMEM_DATA_WIDTH_IS_32 = "TRUE" then
                        and (ifu_req_pc(1) ?= '0')
  `end if
  `if E203_SYSMEM_DATA_WIDTH_IS_64 = "TRUE" then
                        and (ifu_req_pc(2 downto 1) ?= "00")
  `end if
                        )
  `end if
                        ;

  -- The scheme to check if the current accessing PC is same as last accessed ICB address
  --   is as below:
  --     * We only treat this case as true when it is sequentially instruction-fetch
  --         reqeust, and it is crossing the boundry as unalgned (1st 16bits and 2nd 16bits
  --         is crossing the boundry)
  --         ** If the ifetch request is the begining of lane boundry, and sequential fetch,
  --            Then:
  --                 **** If the last time it was prefetched ahead, then this time is accessing
  --                        the same address as last time. Otherwise not.
  --         ** If the ifetch request is not the begining of lane boundry, and sequential fetch,
  --            Then:
  --                 **** It must be access the same address as last time.
  --     * Note: All other non-sequential cases (e.g., flush, branch or replay) are not
  --          treated as this case
  --  
  req_lane_status   <= req_lane_cross_r when ifu_req_lane_begin = '1' else '1';
  ifu_req_lane_same <= ifu_req_seq and req_lane_status;

  -- The current accessing PC is same as last accessed ICB address
  ifu_req_lane_holdup <= '0'
  `if E203_HAS_ITCM = "TRUE" then
                        or (ifu_req_pc2itcm and ifu2itcm_holdup and (not itcm_nohold))  
  `end if
                        ;

  ifu_req_hsked   <= ifu_req_valid and ifu_req_ready;
  i_ifu_rsp_hsked <= i_ifu_rsp_valid and i_ifu_rsp_ready;
  ifu_icb_cmd_hsked <= ifu_icb_cmd_valid and ifu_icb_cmd_ready;
  ifu_icb_rsp_hsked <= ifu_icb_rsp_valid and ifu_icb_rsp_ready;

  -- Implement the state machine for the ifetch req interface
  -- Define some common signals and reused later to save gatecounts
  icb_sta_is_idle    <= (icb_state_r ?= ICB_STATE_IDLE   );
  icb_sta_is_1st     <= (icb_state_r ?= ICB_STATE_1ST    );
  icb_sta_is_wait2nd <= (icb_state_r ?= ICB_STATE_WAIT2ND);
  icb_sta_is_2nd     <= (icb_state_r ?= ICB_STATE_2ND    );
  
  -- **** If the current state is idle,
  -- If a new request come, next state is ICB_STATE_1ST
  state_idle_exit_ena <= icb_sta_is_idle and ifu_req_hsked;
  state_idle_nxt      <= ICB_STATE_1ST;

  -- **** If the current state is 1st,
  -- If a response come, exit this state
  is_icb_rsp2leftover<= ifu_icb_rsp_hsked when ifu_icb_rsp2leftover = '1' else i_ifu_rsp_hsked;
  state_1st_exit_ena <= icb_sta_is_1st and is_icb_rsp2leftover;

  state_1st_nxt      <= 
                     -- If it need two requests but the ifetch request is not ready to be 
                     --   accepted, then next state is ICB_STATE_WAIT2ND
                     ICB_STATE_WAIT2ND when (req_need_2uop_r and (not ifu_icb_cmd_ready)) = '1' else
                     -- If it need two requests and the ifetch request is ready to be 
                     --   accepted, then next state is ICB_STATE_2ND
                     ICB_STATE_2ND when (req_need_2uop_r and ifu_icb_cmd_ready) = '1' else
                     -- If it need zero or one requests and new req handshaked, then 
                     --   next state is ICB_STATE_1ST
                     -- If it need zero or one requests and no new req handshaked, then
                     --   next state is ICB_STATE_IDLE
                     ICB_STATE_1ST when ifu_req_hsked = '1' else
                     ICB_STATE_IDLE
                     ;
  
  -- **** If the current state is wait-2nd,
  -- If the ICB CMD is ready, then next state is ICB_STATE_2ND
  state_wait2nd_exit_ena <= icb_sta_is_wait2nd and ifu_icb_cmd_ready;
  state_wait2nd_nxt      <= ICB_STATE_2ND;

  -- **** If the current state is 2nd,
  -- If a response come, exit this state
  state_2nd_exit_ena     <=  icb_sta_is_2nd and i_ifu_rsp_hsked;
  -- If meanwhile new req handshaked, then next state is ICB_STATE_1ST
  -- otherwise, back to IDLE
  state_2nd_nxt          <=  ICB_STATE_1ST when ifu_req_hsked = '1' else
                             ICB_STATE_IDLE;

  -- The state will only toggle when each state is meeting the condition to exit:
  icb_state_ena <= state_idle_exit_ena or state_1st_exit_ena or state_wait2nd_exit_ena or state_2nd_exit_ena;
  
  -- The next-state is onehot mux to select different entries
  icb_state_nxt <= 
                      ((ICB_STATE_WIDTH-1 downto 0 => state_idle_exit_ena   ) and state_idle_nxt   )
                   or ((ICB_STATE_WIDTH-1 downto 0 => state_1st_exit_ena    ) and state_1st_nxt    )
                   or ((ICB_STATE_WIDTH-1 downto 0 => state_wait2nd_exit_ena) and state_wait2nd_nxt)
                   or ((ICB_STATE_WIDTH-1 downto 0 => state_2nd_exit_ena    ) and state_2nd_nxt    )
                   ;
  icb_state_dfflr: component sirv_gnrl_dfflr generic map (ICB_STATE_WIDTH)
                                                port map (icb_state_ena, icb_state_nxt, icb_state_r, clk, rst_n);

  -- Save the same_cross_holdup flags for this ifetch request to be used
  req_same_cross_holdup <= ifu_req_lane_same and ifu_req_lane_cross and ifu_req_lane_holdup;
  req_need_2uop         <= ( ifu_req_lane_same and ifu_req_lane_cross and (not ifu_req_lane_holdup))
                             or ((not ifu_req_lane_same) and ifu_req_lane_cross);
  req_need_0uop         <= ifu_req_lane_same and (not ifu_req_lane_cross) and ifu_req_lane_holdup;
  req_same_cross_holdup_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => ifu_req_hsked,
                                                          dnxt(0)=> req_same_cross_holdup,
                                                          qout(0)=> req_same_cross_holdup_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  req_need_2uop_dfflr:         component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => ifu_req_hsked,
                                                          dnxt(0)=> req_need_2uop,
                                                          qout(0)=> req_need_2uop_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  req_need_0uop_dfflr:         component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => ifu_req_hsked,
                                                          dnxt(0)=> req_need_0uop,
                                                          qout(0)=> req_need_0uop_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  req_lane_cross_dfflr:         component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => ifu_req_hsked,
                                                          dnxt(0)=> ifu_req_lane_cross,
                                                          qout(0)=> req_lane_cross_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );

  -- Save the indicate flags for this ICB transaction to be used
  `if E203_HAS_ITCM = "TRUE" then
  icb2itcm_dfflr:               component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => ifu_icb_cmd_hsked,
                                                          dnxt(0)=> ifu_icb_cmd2itcm,
                                                          qout(0)=> icb_cmd2itcm_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );
  `end if
  
  `if E203_HAS_MEM_ITF = "TRUE" then
  icb2mem_dfflr:                component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => ifu_icb_cmd_hsked,
                                                          dnxt(0)=> ifu_icb_cmd2biu,
                                                          qout(0)=> icb_cmd2biu_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );  
  `end if

  icb_cmd_addr_2_1_ena <= ifu_icb_cmd_hsked or ifu_req_hsked;
  icb_addr_2_1_dffl: component sirv_gnrl_dffl generic map (2)
                                                 port map (icb_cmd_addr_2_1_ena, ifu_icb_cmd_addr(2 downto 1), icb_cmd_addr_2_1_r, clk);
  
  -- Implement Leftover Buffer
  -- The leftover buffer will be loaded into two cases
  -- Please see "The itfctrl scheme introduction" for more details 
  --    * Case #1: Loaded when the last holdup upper 16bits put into leftover
  --    * Case #2: Loaded when the 1st request uop rdata upper 16bits put into leftover
  holdup2leftover_sel <= req_same_cross_holdup;
  holdup2leftover_ena <= ifu_req_hsked and holdup2leftover_sel;

  put2leftover_data   <= 16b"0" 
  `if E203_HAS_ITCM = "TRUE" then
                         or ((15 downto 0 => icb_cmd2itcm_r) and ifu2itcm_icb_rsp_rdata(E203_ITCM_DATA_WIDTH-1 downto E203_ITCM_DATA_WIDTH-16))
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then 
                         or ((15 downto 0 => icb_cmd2biu_r) and ifu2biu_icb_rsp_rdata(E203_SYSMEM_DATA_WIDTH-1 downto E203_SYSMEM_DATA_WIDTH-16))
  `end if 
                         ;

  uop1st2leftover_sel <= ifu_icb_rsp2leftover;
  uop1st2leftover_ena <= ifu_icb_rsp_hsked and uop1st2leftover_sel; 

  uop1st2leftover_err <= '0' 
  `if E203_HAS_ITCM = "TRUE" then
                         or (icb_cmd2itcm_r and ifu2itcm_icb_rsp_err)
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then 
                         or (icb_cmd2biu_r and ifu2biu_icb_rsp_err)
  `end if
                         ;
  
  leftover_ena <= holdup2leftover_ena or uop1st2leftover_ena;
  leftover_nxt <= put2leftover_data(15 downto 0); 
  leftover_err_nxt <= (uop1st2leftover_sel and uop1st2leftover_err);
  leftover_dffl: component sirv_gnrl_dffl generic map (16)
                                             port map (leftover_ena, leftover_nxt,     leftover_r,     clk);
  leftover_err_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                port map (lden   => leftover_ena,
                                                          dnxt(0)=> leftover_err_nxt,
                                                          qout(0)=> leftover_err_r,
                                                          clk    => clk,
                                                          rst_n  => rst_n
                                                         );  
  
  -- Generate the ifetch response channel
  -- 
  -- The ifetch response instr will have 2 sources
  -- Please see "The itfctrl scheme introduction" for more details 
  --    * Source #1: The concatenation by {rdata[15:0],leftover}, when
  --          ** the state is in 2ND uop
  --          ** the state is in 1ND uop but it is same-cross-holdup case
  --    * Source #2: The rdata-aligned, when
  --           ** not selecting leftover
  rsp_instr_sel_leftover <= ( icb_sta_is_1st and req_same_cross_holdup_r ) or icb_sta_is_2nd;
  rsp_instr_sel_icb_rsp  <= not rsp_instr_sel_leftover;
  ifu_icb_rsp_rdata_lsb16<= 16b"0" 
  `if E203_HAS_ITCM = "TRUE" then
                         or ((15 downto 0 => icb_cmd2itcm_r) and ifu2itcm_icb_rsp_rdata(15 downto 0))
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then 
                         or ((15 downto 0 => icb_cmd2biu_r) and ifu2biu_icb_rsp_rdata(15 downto 0))
  `end if
                         ;

  -- The fetched instruction from ICB rdata bus need to be aligned by PC LSB bits
  `if E203_HAS_ITCM = "TRUE" then
  ifu2itcm_icb_rsp_instr <= 
    `if E203_ITCM_DATA_WIDTH_IS_32 = "TRUE" then
                             ifu2itcm_icb_rsp_rdata;
    `elsif E203_ITCM_DATA_WIDTH_IS_64 = "TRUE" then
                             ((31 downto 0 => (icb_cmd_addr_2_1_r ?= "00")) and ifu2itcm_icb_rsp_rdata(31 downto  0)) 
                          or ((31 downto 0 => (icb_cmd_addr_2_1_r ?= "01")) and ifu2itcm_icb_rsp_rdata(47 downto 16)) 
                          or ((31 downto 0 => (icb_cmd_addr_2_1_r ?= "10")) and ifu2itcm_icb_rsp_rdata(63 downto 32))
                          ;
    `else
      `error "!!! ERROR: There must be something wrong, we dont support the width 
              other than 32bits and 64bits, leave this message to catch this error by 
              compilation message."
    `end if
  `end if
  
  `if E203_HAS_MEM_ITF = "TRUE" then
  ifu2biu_icb_rsp_instr <= 
    `if E203_SYSMEM_DATA_WIDTH_IS_32 = "TRUE" then
                             ifu2biu_icb_rsp_rdata;
    `elsif E203_SYSMEM_DATA_WIDTH_IS_64 = "TRUE" then
                             ((31 downto 0 => (icb_cmd_addr_2_1_r ?= "00")) and ifu2biu_icb_rsp_rdata(31 downto  0)) 
                          or ((31 downto 0 => (icb_cmd_addr_2_1_r ?= "01")) and ifu2biu_icb_rsp_rdata(47 downto 16)) 
                          or ((31 downto 0 => (icb_cmd_addr_2_1_r ?= "10")) and ifu2biu_icb_rsp_rdata(63 downto 32))
                          ;
    `else
      `error "!!! ERROR: There must be something wrong, we dont support the width 
              other than 32bits and 64bits, leave this message to catch this error by 
              compilation message."
    `end if
  `end if
  
  ifu_icb_rsp_instr   <= 32b"0" 
  `if E203_HAS_ITCM = "TRUE" then
                         or ((31 downto 0 => icb_cmd2itcm_r) and ifu2itcm_icb_rsp_instr)
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then 
                         or ((31 downto 0 => icb_cmd2biu_r) and ifu2biu_icb_rsp_instr)
  `end if 
                         ;

  uop1st2leftover_err <= '0' 
  `if E203_HAS_ITCM = "TRUE" then
                         or (icb_cmd2itcm_r and ifu2itcm_icb_rsp_err)
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then 
                         or (icb_cmd2biu_r and ifu2biu_icb_rsp_err)
  `end if
                         ;

  i_ifu_rsp_instr <=   ((31 downto 0 => rsp_instr_sel_leftover) and (ifu_icb_rsp_rdata_lsb16, leftover_r))
                    or ((31 downto 0 => rsp_instr_sel_icb_rsp ) and ifu_icb_rsp_instr);
  i_ifu_rsp_err   <=   (rsp_instr_sel_leftover and or(ifu_icb_rsp_rdata_lsb16 & leftover_r))
                    or (rsp_instr_sel_icb_rsp and ifu_icb_rsp_err);

  --//If the response is to leftover, it is always can be accepted,
  --//  so there is no chance to turn over the value, and no need 
  --//  to replay, but the data from the response channel (from
  --//  ITCM) may be turned over, so need to be replayed
  --wire ifu_icb_rsp_replay;
  --assign ifu_rsp_replay = 
  --            (rsp_instr_sel_leftover & (|{ifu_icb_rsp_replay, 1'b0}))
  --          | (rsp_instr_sel_icb_rsp  & ifu_icb_rsp_replay);
  --        
  -- The ifetch response valid will have 2 sources
  --    Source #1: Did not issue ICB CMD request, and just use last holdup values, then
  --               we generate a fake response valid
  holdup_gen_fake_rsp_valid <= icb_sta_is_1st and req_need_0uop_r;
  
  --    Source #2: Did issue ICB CMD request, use ICB response valid. But not each response
  --               valid will be sent to ifetch-response. The ICB response data will put 
  --               into the leftover buffer when:
  --                    It need two uops and itf-state is in 1ST stage (the leftover
  --                    buffer is always ready to accept this)
  ifu_icb_rsp2leftover <= req_need_2uop_r and icb_sta_is_1st;
  ifu_icb_rsp2ir_valid <= '0' when ifu_icb_rsp2leftover = '1' else ifu_icb_rsp_valid;
  ifu_icb_rsp_ready    <= '1' when ifu_icb_rsp2leftover = '1' else ifu_icb_rsp2ir_ready;

  i_ifu_rsp_valid      <= holdup_gen_fake_rsp_valid or ifu_icb_rsp2ir_valid;
  ifu_icb_rsp2ir_ready <= i_ifu_rsp_ready;

  -- Generate the ICB response channel
  --
  -- The ICB response valid to ifetch generated in two cases:
  --    * Case #1: The itf need two uops, and it is in 2ND state response
  --    * Case #2: The itf need only one uop, and it is in 1ND state response
  ifu_icb_rsp_valid <= '0' 
  `if E203_HAS_ITCM = "TRUE" then
                         or (icb_cmd2itcm_r and ifu2itcm_icb_rsp_valid)
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then 
                         or (icb_cmd2biu_r and ifu2biu_icb_rsp_valid)
  `end if
                         ;
  
  --  //   Explain the performance impacts
  --  //      because there is a over killing, that the very 1st time ifu to access ITCM it actually
  --  //      does not need to be replayed, but it just did replay becuase the holdup is not set but we dont care
  --assign ifu_icb_rsp_replay = 1'b0
  --                  `ifdef E203_HAS_ITCM //{
  --                    | (icb_cmd2itcm_r & ifu2itcm_replay)
  --                  `endif//}
  --                  `ifdef E203_HAS_MEM_ITF //{
  --                    | (icb_cmd2biu_r & ifu2biu_replay)
  --                  `endif//}
  --                     ;
  
  -- Generate the ICB command channel
  --
  -- The ICB cmd valid will be generated in two cases:
  --   * Case #1: When the new ifetch-request is coming, and it is not "need zero 
  --              uops"
  --   * Case #2: When the ongoing ifetch is "need 2 uops", and:
  --                ** itf-state is in 1ST state and its response is handshaking (about
  --                    to finish the 1ST state)
  --                ** or it is already in WAIT2ND state
  ifu_icb_cmd_valid <= (ifu_req_valid_pos and (not req_need_0uop)) or 
                       (req_need_2uop_r and (((icb_sta_is_1st and ifu_icb_rsp_hsked) or icb_sta_is_wait2nd)));
  
  -- The ICB cmd address will be generated in 3 cases:
  --   * Case #1: Use next lane-aligned address, when 
  --                 ** It is same-cross-holdup case for 1st uop
  --                 The next-lane-aligned address can be generated by 
  --                 current request-PC plus 16bits. To optimize the
  --                 timing, we try to use last-fetched-PC (flop clean)
  --                 to caculate. So we caculate it by 
  --                 last-fetched-PC (flopped value pc_r) truncated
  --                 with lane-offset and plus a lane siz
  icb_addr_sel_1stnxtalgn <= holdup2leftover_sel;
  
  --   * Case #2: Use next lane-aligned address, when
  --                 ** It need 2 uops, and it is 1ST or WAIT2ND stage
  --                 The next-lane-aligned address can be generated by
  --                 last request-PC plus 16bits. 
  icb_addr_sel_2ndnxtalgn <= req_need_2uop_r and (icb_sta_is_1st or icb_sta_is_wait2nd);

  --   * Case #3: Use current ifetch address in 1st uop, when 
  --                 ** It is not above two cases

  icb_addr_sel_cur <= (not icb_addr_sel_1stnxtalgn) and (not icb_addr_sel_2ndnxtalgn);
  nxtalgn_plus_offset <= to_signed(2,E203_PC_SIZE) when icb_addr_sel_2ndnxtalgn = '1' else 
                         to_signed(6,E203_PC_SIZE) when ifu_req_seq_rv32        = '1' else
                         to_signed(4,E203_PC_SIZE);

  -- Since we always fetch 32bits
  icb_algn_nxt_lane_addr <= std_logic_vector(signed(ifu_req_last_pc) + nxtalgn_plus_offset);                       
  ifu_icb_cmd_addr <=    ((E203_PC_SIZE-1 downto 0 => (icb_addr_sel_1stnxtalgn or icb_addr_sel_2ndnxtalgn)) and icb_algn_nxt_lane_addr)
                      or ((E203_PC_SIZE-1 downto 0 => icb_addr_sel_cur) and ifu_req_pc);

  -- Generate the ifetch req channel ready signal
  --
  -- Ifu req channel will be ready when the ICB CMD channel is ready and 
  --    * the itf-state is idle
  --    * or only need zero or one uop, and in 1ST state response is backing
  --    * or need two uops, and in 2ND state response is backing 
  ifu_req_ready_condi <=         icb_sta_is_idle 
                        or ((not req_need_2uop_r) and icb_sta_is_1st and i_ifu_rsp_hsked)
                        or (     req_need_2uop_r  and icb_sta_is_2nd and i_ifu_rsp_hsked) 
                        ;
  ifu_req_ready     <= ifu_icb_cmd_ready and ifu_req_ready_condi; 
  ifu_req_valid_pos <= ifu_req_valid     and ifu_req_ready_condi; -- Handshake valid

  -- Dispatch the ICB CMD and RSP Channel to ITCM and System Memory
  --   according to the address range 
  `if E203_HAS_ITCM = "TRUE" then
  ifu_icb_cmd2itcm       <= (ifu_icb_cmd_addr(E203_ITCM_BASE_REGION'range) ?= itcm_region_indic(E203_ITCM_BASE_REGION'range));
  ifu2itcm_icb_cmd_valid <= ifu_icb_cmd_valid and ifu_icb_cmd2itcm;
  ifu2itcm_icb_cmd_addr  <= ifu_icb_cmd_addr(E203_ITCM_ADDR_WIDTH-1 downto 0);
  ifu2itcm_icb_rsp_ready <= ifu_icb_rsp_ready;
  `end if 

  `if E203_HAS_MEM_ITF = "TRUE" then
  ifu_icb_cmd2biu <= '1' 
  `if E203_HAS_ITCM = "TRUE" then
                      and (not ifu_icb_cmd2itcm)
  `end if
                      ;
  ifu2biu_icb_cmd_valid_pre <= ifu_icb_cmd_valid and ifu_icb_cmd2biu;
  ifu2biu_icb_cmd_addr_pre  <= ifu_icb_cmd_addr(E203_ADDR_SIZE-1 downto 0);
  ifu2biu_icb_rsp_ready     <= ifu_icb_rsp_ready;
  `end if 

  ifu_icb_cmd_ready <= '0' 
  `if E203_HAS_ITCM = "TRUE" then
                        or (ifu_icb_cmd2itcm and ifu2itcm_icb_cmd_ready)
  `end if
  `if E203_HAS_MEM_ITF = "TRUE" then 
                        or (ifu_icb_cmd2biu and ifu2biu_icb_cmd_ready_pre)
  `end if
                         ; 

  `if E203_HAS_MEM_ITF = "TRUE" then
  ifu2biu_icb_cmd_addr      <= ifu2biu_icb_cmd_addr_pre;
  ifu2biu_icb_cmd_valid     <= ifu2biu_icb_cmd_valid_pre;
  ifu2biu_icb_cmd_ready_pre <= ifu2biu_icb_cmd_ready;
  `end if
  
end impl;