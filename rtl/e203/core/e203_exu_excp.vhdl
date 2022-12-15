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
--   The module to handle the different exceptions
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_exu_excp is 
  port ( 
         commit_trap:      out std_logic;
         core_wfi:         out std_logic;     
         wfi_halt_ifu_req: out std_logic;
         wfi_halt_exu_req: out std_logic;
         wfi_halt_ifu_ack:  in std_logic;
         wfi_halt_exu_ack:  in std_logic;

         amo_wait:          in std_logic;

         alu_excp_i_ready: out std_logic;
         alu_excp_i_valid:  in std_logic;
         alu_excp_i_ld:     in std_logic;
  	     alu_excp_i_stamo:  in std_logic;
  	     alu_excp_i_misalgn: in std_logic;
         alu_excp_i_buserr:  in std_logic;
  	     alu_excp_i_ecall:   in std_logic;
  	     alu_excp_i_ebreak:  in std_logic;
         alu_excp_i_wfi:     in std_logic;
  	     alu_excp_i_ifu_misalgn: in std_logic;
  	     alu_excp_i_ifu_buserr:  in std_logic;
         alu_excp_i_ifu_ilegl:   in std_logic;
  	     alu_excp_i_badaddr:     in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
  	     alu_excp_i_pc:          in std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     alu_excp_i_instr:       in std_logic_vector(E203_INSTR_SIZE-1 downto 0);
  	     alu_excp_i_pc_vld:      in std_logic;

         longp_excp_i_ready:    out std_logic;
         longp_excp_i_valid:     in std_logic;
         longp_excp_i_ld:        in std_logic;
  	     longp_excp_i_st:        in std_logic; -- 1: load, 0: store
  	     longp_excp_i_buserr:    in std_logic; -- The load/store bus-error exception generated
         longp_excp_i_insterr:   in std_logic;
  	     longp_excp_i_badaddr:   in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
  	     longp_excp_i_pc:        in std_logic_vector(E203_PC_SIZE-1 downto 0);

         excpirq_flush_ack:             in std_logic;
  	     excpirq_flush_req:            out std_logic;
  	     nonalu_excpirq_flush_req_raw: out std_logic;
         excpirq_flush_add_op1:        out std_logic_vector(E203_PC_SIZE-1 downto 0);
         excpirq_flush_add_op2:        out std_logic_vector(E203_PC_SIZE-1 downto 0);     
        `if E203_TIMING_BOOST = "TRUE" then
         excpirq_flush_pc:             out std_logic_vector(E203_PC_SIZE-1 downto 0);
        `end if

         csr_mtvec_r:                   in std_logic_vector(E203_XLEN-1 downto 0);
         cmt_dret_ena:                  in std_logic;
         cmt_ena:                       in std_logic;
         
         cmt_badaddr:                  out std_logic_vector(E203_ADDR_SIZE-1 downto 0);
         cmt_epc:                      out std_logic_vector(E203_PC_SIZE-1 downto 0);
         cmt_cause:                    out std_logic_vector(E203_XLEN-1 downto 0);
         cmt_badaddr_ena:              out std_logic;
         cmt_epc_ena:                  out std_logic;
         cmt_cause_ena:                out std_logic;
         cmt_status_ena:               out std_logic;
         
         cmt_dpc:                      out std_logic_vector(E203_PC_SIZE-1 downto 0);
         cmt_dpc_ena:                  out std_logic;
         cmt_dcause:                   out std_logic_vector(3-1 downto 0);
         cmt_dcause_ena:               out std_logic;
         
         dbg_irq_r:                     in std_logic;
         lcl_irq_r:                     in std_logic_vector(E203_LIRQ_NUM-1 downto 0);
         ext_irq_r:                     in std_logic;
         sft_irq_r:                     in std_logic;
         tmr_irq_r:                     in std_logic;

         status_mie_r:                  in std_logic;
         mtie_r:                        in std_logic;
         msie_r:                        in std_logic;
         meie_r:                        in std_logic;
  	     
  	     dbg_mode:                      in std_logic;
  	     dbg_halt_r:                    in std_logic;
  	     dbg_step_r:                    in std_logic;
  	     dbg_ebreakm_r:                 in std_logic;

  	     oitf_empty:                    in std_logic;
         
         u_mode:                        in std_logic; 
         s_mode:                        in std_logic; 
         h_mode:                        in std_logic; 
         m_mode:                        in std_logic; 
         
         excp_active:                  out std_logic;
         
         clk:                           in std_logic;  
         rst_n:                         in std_logic  
  	   );
end e203_exu_excp;

architecture impl of e203_exu_excp is 
  signal irq_req_active:           std_ulogic;
  signal nonalu_dbg_entry_req_raw: std_ulogic;
  signal wfi_req_hsked:            std_ulogic;
  signal wfi_flag_set:             std_ulogic;
  signal wfi_irq_req:              std_ulogic;
  signal dbg_entry_req:            std_ulogic;
  signal wfi_flag_r:               std_ulogic;
  signal wfi_flag_clr:             std_ulogic;
  signal wfi_flag_ena:             std_ulogic;
  signal wfi_flag_nxt:             std_ulogic;

  signal wfi_cmt_ena:              std_ulogic;
  signal wfi_halt_req_set:         std_ulogic;
  signal wfi_halt_req_clr:         std_ulogic;
  signal wfi_halt_req_ena:         std_ulogic;
  signal wfi_halt_req_nxt:         std_ulogic;
  signal wfi_halt_req_r:           std_ulogic;
  
  signal irq_req:                  std_ulogic;
  signal longp_need_flush:         std_ulogic;
  signal alu_need_flush:           std_ulogic;
  signal dbg_ebrk_req:             std_ulogic;
  signal dbg_trig_req:             std_ulogic;
  signal longp_excp_flush_req:     std_ulogic;
  
  signal dbg_entry_flush_req:         std_ulogic;
  signal alu_excp_i_ready4dbg:        std_ulogic;
  signal irq_flush_req:               std_ulogic;
  signal alu_excp_flush_req:          std_ulogic;
  signal nonalu_dbg_entry_req:        std_ulogic;
  signal alu_excp_i_ready4nondbg:     std_ulogic;
  signal alu_ebreakm_flush_req_novld: std_ulogic;
  signal alu_dbgtrig_flush_req_novld: std_ulogic;
  signal all_excp_flush_req:          std_ulogic;
  signal excpirq_taken_ena:           std_ulogic;
  signal excp_taken_ena:              std_ulogic;
  signal irq_taken_ena:               std_ulogic;
  signal dbg_entry_taken_ena:         std_ulogic;

  signal step_req_r:                  std_ulogic;
  signal alu_ebreakm_flush_req:       std_ulogic;
  signal alu_dbgtrig_flush_req:       std_ulogic;
  signal dbg_step_req:                std_ulogic;
  signal dbg_irq_req:                 std_ulogic;
  signal nonalu_dbg_irq_req:          std_ulogic;
  signal dbg_halt_req:                std_ulogic;
  signal nonalu_dbg_halt_req:         std_ulogic;
  signal step_req_set:                std_ulogic;
  signal step_req_clr:                std_ulogic;
  signal step_req_ena:                std_ulogic;
  signal step_req_nxt:                std_ulogic;
  signal dbg_entry_mask:              std_ulogic;

  signal irq_mask:                    std_ulogic;
  signal wfi_irq_mask:                std_ulogic;
  signal irq_req_raw:                 std_ulogic;
  signal irq_cause:                   std_ulogic_vector(E203_XLEN-1 downto 0);
  signal alu_excp_i_ebreak4excp:      std_ulogic;
  signal alu_excp_i_ebreak4dbg:       std_ulogic;

  signal longp_excp_flush_req_ld:          std_ulogic;
  signal longp_excp_flush_req_st:          std_ulogic;
  signal longp_excp_flush_req_insterr:     std_ulogic;
  signal alu_excp_flush_req_ld:            std_ulogic;
  signal alu_excp_flush_req_stamo:         std_ulogic;
  signal alu_excp_flush_req_ebreak:        std_ulogic;
  signal alu_excp_flush_req_ecall:         std_ulogic;
  signal alu_excp_flush_req_ifu_misalgn:   std_ulogic;
  signal alu_excp_flush_req_ifu_buserr:    std_ulogic;
  signal alu_excp_flush_req_ifu_ilegl:     std_ulogic;
  signal alu_excp_flush_req_ld_misalgn:    std_ulogic;
  signal alu_excp_flush_req_ld_buserr:     std_ulogic;
  signal alu_excp_flush_req_stamo_misalgn: std_ulogic;
  signal alu_excp_flush_req_stamo_buserr:  std_ulogic;
  signal longp_excp_flush_req_ld_buserr:   std_ulogic;
  signal longp_excp_flush_req_st_buserr:   std_ulogic;
  signal excp_flush_by_alu_agu:            std_ulogic;
  signal excp_flush_by_longp_ldst:         std_ulogic;
  signal excp_cause:                       std_ulogic_vector(E203_XLEN-1 downto 0);
  signal excp_flush_req_ld_misalgn:        std_ulogic;
  signal excp_flush_req_ld_buserr:         std_ulogic;
  signal cmt_badaddr_update:               std_ulogic;
  signal cmt_dcause_set:                   std_ulogic;
  signal cmt_dcause_clr:                   std_ulogic;
  signal set_dcause_nxt:                   std_ulogic_vector(2 downto 0);
  
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
  --//////////////////////////////////////////////////////////////////////////
  -- Because the core's clock may be gated when it is idle, we need to check
  --  if the interrupts is coming, and generate an active indication, and use
  --  this active signal to turn on core's clock
  excp_active <= irq_req_active and nonalu_dbg_entry_req_raw;


  --//////////////////////////////////////////////////////////////////////////
  -- WFI flag generation
  --
  wfi_req_hsked <= (wfi_halt_ifu_req and wfi_halt_ifu_ack and wfi_halt_exu_req and wfi_halt_exu_ack)
                          ;
  -- The wfi_flag will be set if there is a new WFI instruction halt req handshaked
  wfi_flag_set <= wfi_req_hsked;
  -- The wfi_flag will be cleared if there is interrupt pending, or debug entry request
  wfi_flag_clr <= (wfi_irq_req or dbg_entry_req); -- & wfi_flag_r;// Here we cannot use this flag_r
  wfi_flag_ena <= wfi_flag_set or wfi_flag_clr;
  -- If meanwhile set and clear, then clear preempt
  wfi_flag_nxt <= wfi_flag_set and (not wfi_flag_clr);
  wfi_flag_dfflr: component sirv_gnrl_dfflr generic map (1)
                                               port map (lden    => wfi_flag_ena,
                                                         dnxt(0) => wfi_flag_nxt,
                                                         qout(0) => wfi_flag_r,
                                                         clk     => clk,
                                                         rst_n   => rst_n
                                                        );
  core_wfi <= wfi_flag_r and (not wfi_flag_clr);

  -- The wfi_halt_req will be set if there is a new WFI instruction committed
  -- And note in debug mode WFI is treated as nop
  wfi_cmt_ena <= alu_excp_i_wfi and cmt_ena;
  wfi_halt_req_set <= wfi_cmt_ena and (not dbg_mode);
  -- The wfi_halt_req will be cleared same as wfi_flag_r
  wfi_halt_req_clr <= wfi_flag_clr;
  wfi_halt_req_ena <= wfi_halt_req_set or wfi_halt_req_clr;
  -- If meanwhile set and clear, then clear preempt
  wfi_halt_req_nxt <= wfi_halt_req_set and (not wfi_halt_req_clr);
  wfi_halt_req_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                   port map (lden    => wfi_halt_req_ena,
                                                             dnxt(0) => wfi_halt_req_nxt,
                                                             qout(0) => wfi_halt_req_r,
                                                             clk     => clk,
                                                             rst_n   => rst_n
                                                            ); 
  -- In order to make sure the flush to IFU and halt to IFU is not asserte at same cycle
  --   we use the clr signal here to qualify it
  wfi_halt_ifu_req <= (wfi_halt_req_r and (not wfi_halt_req_clr));
  -- To cut the comb loops, we dont use the clr signal here to qualify, 
  --   the outcome is the halt-to-exu will be deasserted 1 cycle later than to-IFU
  --   but it doesnt matter much.
  wfi_halt_exu_req <= wfi_halt_req_r;

  --//////////////////////////////////////////////////////////////////////////
  -- The Exception generate included several cases, priority from top to down
  --   *** Long-pipe triggered exception
  --       ---- Must wait the PC vld 
  --   *** DebugMode-entry triggered exception (included ALU ebreakm)
  --       ---- Must wait the OITF empty and PC vld 
  --   *** IRQ triggered exception
  --       ---- Must wait the OITF empty and PC vld 
  --   *** ALU triggered exception (excluded the ebreakm into debug-mode)  
  --       ---- Must wait the OITF empty 
  
  -- Exclude the pc_vld for longp, to just always make sure the longp can always accepted
  longp_excp_flush_req <= longp_need_flush;
  longp_excp_i_ready <= excpirq_flush_ack;

  --   ^^^ Below we qualified the pc_vld signal to IRQ and Debug-entry req, why? 
  --       -- The Asyn-precise-excp (include IRQ and Debug-entry exception) 
  --            need to use the next upcoming (not yet commited) instruction's PC
  --            for the mepc value, so we must wait next valid instruction coming
  --            and use its PC.
  --       -- The pc_vld indicate is just used to indicate next instruction's valid
  --            PC value.
  --   ^^^ Then the questions are coming, is there a possible that there is no pc_vld
  --         comes forever? and then this async-precise-exception never
  --         get served, and then become a deadlock?
  --       -- It should not be. Becuase:
  --            The IFU is always actively fetching next instructions, never stop,
  --            so ideally it will always provide next valid instructions as
  --            long as the Ifetch-path (bus to external memory or ITCM) is not hang 
  --            (no bus response returned).
  --            ^^^ Then if there possible the Ifetch-path is hang? For examples:
  --                  -- The Ifetched external memory does not provide response because of the External IRQ is not
  --                       accepted by core.
  --                          ** How could it be? This should not happen, otherwise it is a SoC bug.
  --

  dbg_entry_flush_req  <= dbg_entry_req and oitf_empty and alu_excp_i_pc_vld and (not longp_need_flush);
  alu_excp_i_ready4dbg <= (excpirq_flush_ack and oitf_empty and alu_excp_i_pc_vld and (not longp_need_flush));

  irq_flush_req       <= irq_req and oitf_empty and alu_excp_i_pc_vld
                         and (not dbg_entry_req)
                         and (not longp_need_flush);

  alu_excp_flush_req  <= alu_excp_i_valid and alu_need_flush and oitf_empty 
                         and (not irq_req)
                         and (not dbg_entry_req)
                         and (not longp_need_flush);

  alu_excp_i_ready4nondbg <= (      excpirq_flush_ack 
                               and oitf_empty
                               and (not irq_req) 
                               and (not nonalu_dbg_entry_req) 
                               and (not longp_need_flush)
                             ) when alu_need_flush = '1' else   
                          -- The other higher priorty flush will override ALU commit
                             (     (not irq_req)
                               and (not nonalu_dbg_entry_req)
                               and (not longp_need_flush)
                             );

  alu_excp_i_ready <= alu_excp_i_ready4dbg when (alu_ebreakm_flush_req_novld or alu_dbgtrig_flush_req_novld) = '1' else
                      alu_excp_i_ready4nondbg;




  excpirq_flush_req  <= longp_excp_flush_req or dbg_entry_flush_req or irq_flush_req or alu_excp_flush_req;
  all_excp_flush_req <= longp_excp_flush_req or alu_excp_flush_req;

  nonalu_excpirq_flush_req_raw <= 
                                  longp_need_flush or 
                                  nonalu_dbg_entry_req_raw or
                                  irq_req;


  excpirq_taken_ena <= excpirq_flush_req and excpirq_flush_ack;
  commit_trap       <= excpirq_taken_ena;

  excp_taken_ena      <= all_excp_flush_req  and excpirq_taken_ena;
  irq_taken_ena       <= irq_flush_req       and excpirq_taken_ena;
  dbg_entry_taken_ena <= dbg_entry_flush_req and excpirq_taken_ena;

  excpirq_flush_add_op1 <= (11 downto 0 => x"800", others => '0') when dbg_entry_flush_req = '1' else
                           (11 downto 0 => x"808", others => '0') when (all_excp_flush_req and dbg_mode) = '1' else
                           csr_mtvec_r;
  excpirq_flush_add_op2 <= (E203_PC_SIZE-1 downto 0 =>'0') when dbg_entry_flush_req = '1' else
                           (E203_PC_SIZE-1 downto 0 =>'0') when (all_excp_flush_req and dbg_mode) = '1' else
                           (E203_PC_SIZE-1 downto 0 =>'0');

 `if E203_TIMING_BOOST = "TRUE" then
  excpirq_flush_pc <= (11 downto 0 => x"800", others => '0') when dbg_entry_flush_req = '1' else
                      (11 downto 0 => x"808", others => '0') when (all_excp_flush_req and dbg_mode) = '1' else
                       csr_mtvec_r;
 `end if

  --//////////////////////////////////////////////////////////////////////////
  -- The Long-pipe triggered Exception 
  --                 
  longp_need_flush <= longp_excp_i_valid; -- The longp come to excp
                                          --   module always ask for excepiton

  --//////////////////////////////////////////////////////////////////////////
  -- The DebugMode-entry triggered Exception 
  --
  -- The priority from top to down
  -- dbg_trig_req ? 3'd2 : 
  -- dbg_ebrk_req ? 3'd1 : 
  -- dbg_irq_req  ? 3'd3 : 
  -- dbg_step_req ? 3'd4 :
  -- dbg_halt_req ? 3'd5 : 
  -- Since the step_req_r is last cycle generated indicated, means last instruction is single-step
  --   and it have been commited in non debug-mode, and then this cyclc step_req_r is the of the highest priority
  dbg_step_req <= step_req_r;
  dbg_trig_req <= alu_dbgtrig_flush_req and (not step_req_r);
  dbg_ebrk_req <= alu_ebreakm_flush_req and (not alu_dbgtrig_flush_req) and(not step_req_r);
  dbg_irq_req  <= dbg_irq_r  and (not alu_ebreakm_flush_req) and (not alu_dbgtrig_flush_req) and (not step_req_r);
  nonalu_dbg_irq_req  <= dbg_irq_r and (not step_req_r);
  -- The step have higher priority, and will preempt the halt
  dbg_halt_req <= dbg_halt_r and (not dbg_irq_r) and (not alu_ebreakm_flush_req) and (not alu_dbgtrig_flush_req) and (not step_req_r) and (not dbg_step_r);
  nonalu_dbg_halt_req <= dbg_halt_r and (not dbg_irq_r) and (not step_req_r) and (not dbg_step_r);
  
  -- The debug-step request will be set when currently the step_r is high, and one 
  --   instruction (in non debug_mode) have been executed
  -- The step request will be clear when 
  --   core enter into the debug-mode 
  step_req_set <= (not dbg_mode) and dbg_step_r and cmt_ena and (not dbg_entry_taken_ena);
  step_req_clr <= dbg_entry_taken_ena;
  step_req_ena <= step_req_set or step_req_clr;
  step_req_nxt <= step_req_set or (not step_req_clr);
  step_req_dfflr: component sirv_gnrl_dfflr  generic map (1)
                                                port map (lden    => step_req_ena,
                                                          dnxt(0) => step_req_nxt,
                                                          qout(0) => step_req_r,
                                                          clk     => clk,
                                                          rst_n   => rst_n
                                                         );

  -- The debug-mode will mask off the debug-mode-entry
  dbg_entry_mask <= dbg_mode;
  dbg_entry_req <= (not dbg_entry_mask) and (
                -- Why do we put a AMO_wait here, because the AMO instructions 
                --   is atomic, we must wait it to complete its all atomic operations
                --   and during wait cycles irq must be masked, otherwise the irq_req
                --   will block ALU commit (including AMO) and cause a deadlock
                --   
                -- Note: Only the async irq and halt and trig need to have this amo_wait to check
                --   others are sync event, no need to check with this
                                               (dbg_irq_req  and (not amo_wait))
                                            or (dbg_halt_req and (not amo_wait))
                                            or  dbg_step_req
                                            or (dbg_trig_req and (not amo_wait))
                                            or  dbg_ebrk_req
                                            );
  nonalu_dbg_entry_req <= (not dbg_entry_mask) and (
                                                      (nonalu_dbg_irq_req and (not amo_wait))
                                                   or (nonalu_dbg_halt_req and (not amo_wait))
                                                   or dbg_step_req
                                                   );
  nonalu_dbg_entry_req_raw <= (not dbg_entry_mask) and (
                                                          dbg_irq_r 
                                                       or dbg_halt_r
                                                       or step_req_r
                                                       );

  
  --//////////////////////////////////////////////////////////////////////////
  -- The IRQ triggered Exception 
  --
  -- The debug mode will mask off the interrupts
  -- The single-step mode will mask off the interrupts
  irq_mask <= dbg_mode or dbg_step_r or (not status_mie_r) 
              -- Why do we put a AMO_wait here, because the AMO instructions 
              --   is atomic, we must wait it to complete its all atomic operations
              --   and during wait cycles irq must be masked, otherwise the irq_req
              --   will block ALU commit (including AMO) and cause a deadlock
              -- Dont need to worry about the clock gating issue, if amo_wait,
              --   then defefinitely the ALU is active, and clock on
              or amo_wait;
  wfi_irq_mask <= dbg_mode or dbg_step_r;
              -- Why dont we put amo_wait here, because this is for IRQ to wake
              --   up the core from sleep mode, the core was in sleep mode, then 
              --   means there is no chance for it to still executing the AMO instructions
              --   with oustanding uops, so we dont need to worry about it.
  irq_req_raw <= (-- (|lcl_irq_r) // not support this now
                     (ext_irq_r and meie_r) 
                  or (sft_irq_r and msie_r) 
                  or (tmr_irq_r and mtie_r)
                 );
  irq_req     <= (not irq_mask) and irq_req_raw;
  wfi_irq_req <= (not wfi_irq_mask) and irq_req_raw;

  irq_req_active <= wfi_irq_req when wfi_flag_r = '1' else
                    irq_req; 

  irq_cause(31) <= '1';
  irq_cause(30 downto 4) <= 27b"0";
  irq_cause(3 downto 0) <=  4d"3"  when (sft_irq_r and msie_r) = '1' else  -- 3  Machine software interrupt
                            4d"7"  when (tmr_irq_r and mtie_r) = '1' else  -- 7  Machine timer interrupt
                            4d"11" when (ext_irq_r and meie_r) = '1' else  -- 11 Machine external interrupt
                            4b"0";

  
  --//////////////////////////////////////////////////////////////////////////
  -- The ALU triggered Exception 

  -- The ebreak instruction will generated regular exception when the ebreakm
  --    bit of DCSR reg is not set
  alu_excp_i_ebreak4excp <= (alu_excp_i_ebreak and ((not dbg_ebreakm_r) or dbg_mode));
  -- The ebreak instruction will enter into the debug-mode when the ebreakm
  --    bit of DCSR reg is set
  alu_excp_i_ebreak4dbg <= alu_excp_i_ebreak 
                           and (not alu_need_flush) -- override by other alu exceptions
                           and dbg_ebreakm_r 
                           and (not dbg_mode); -- Not in debug mode

  alu_ebreakm_flush_req <= alu_excp_i_valid and alu_excp_i_ebreak4dbg;
  alu_ebreakm_flush_req_novld <= alu_excp_i_ebreak4dbg;
 `if E203_SUPPORT_TRIGM = "FALSE" then
  -- We dont support the HW Trigger Module yet
  alu_dbgtrig_flush_req_novld <= '0';
  alu_dbgtrig_flush_req <= '0';
 `end if

  alu_need_flush <= 
            (  alu_excp_i_misalgn 
            or alu_excp_i_buserr 
            or alu_excp_i_ebreak4excp
            or alu_excp_i_ecall
            or alu_excp_i_ifu_misalgn  
            or alu_excp_i_ifu_buserr  
            or alu_excp_i_ifu_ilegl  
            );

  --//////////////////////////////////////////////////////////////////////////
  -- Update the CSRs (Mcause, .etc)
  longp_excp_flush_req_ld <= longp_excp_flush_req and longp_excp_i_ld;
  longp_excp_flush_req_st <= longp_excp_flush_req and longp_excp_i_st;

  longp_excp_flush_req_insterr <= longp_excp_flush_req and longp_excp_i_insterr;

  alu_excp_flush_req_ld    <= alu_excp_flush_req and alu_excp_i_ld;
  alu_excp_flush_req_stamo <= alu_excp_flush_req and alu_excp_i_stamo;

  alu_excp_flush_req_ebreak      <= (alu_excp_flush_req and alu_excp_i_ebreak4excp);
  alu_excp_flush_req_ecall       <= (alu_excp_flush_req and alu_excp_i_ecall);
  alu_excp_flush_req_ifu_misalgn <= (alu_excp_flush_req and alu_excp_i_ifu_misalgn);
  alu_excp_flush_req_ifu_buserr  <= (alu_excp_flush_req and alu_excp_i_ifu_buserr);
  alu_excp_flush_req_ifu_ilegl   <= (alu_excp_flush_req and alu_excp_i_ifu_ilegl);

  alu_excp_flush_req_ld_misalgn    <= (alu_excp_flush_req_ld    and alu_excp_i_misalgn); -- ALU load misalign
  alu_excp_flush_req_ld_buserr     <= (alu_excp_flush_req_ld    and alu_excp_i_buserr);  -- ALU load bus error
  alu_excp_flush_req_stamo_misalgn <= (alu_excp_flush_req_stamo and alu_excp_i_misalgn); -- ALU store/AMO misalign
  alu_excp_flush_req_stamo_buserr  <= (alu_excp_flush_req_stamo and alu_excp_i_buserr);  -- ALU store/AMO bus error
  longp_excp_flush_req_ld_buserr   <= (longp_excp_flush_req_ld  and longp_excp_i_buserr);-- Longpipe load bus error
  longp_excp_flush_req_st_buserr   <= (longp_excp_flush_req_st  and longp_excp_i_buserr);-- Longpipe store bus error

  excp_flush_by_alu_agu <= 
                alu_excp_flush_req_ld_misalgn    
              or alu_excp_flush_req_ld_buserr     
              or alu_excp_flush_req_stamo_misalgn 
              or alu_excp_flush_req_stamo_buserr;

  excp_flush_by_longp_ldst <= 
                     longp_excp_flush_req_ld_buserr   
                   or longp_excp_flush_req_st_buserr;


  
  excp_cause(31 downto 5) <= 27b"0";
  excp_cause(4 downto 0)  <= 
    5d"0" when alu_excp_flush_req_ifu_misalgn = '1' else -- Instruction address misaligned
    5d"1" when alu_excp_flush_req_ifu_buserr  = '1' else -- Instruction access fault
    5d"2" when alu_excp_flush_req_ifu_ilegl   = '1' else -- Illegal instruction
    5d"3" when alu_excp_flush_req_ebreak      = '1' else -- Breakpoint
    5d"4" when alu_excp_flush_req_ld_misalgn  = '1' else -- load address misalign
    5d"5" when (longp_excp_flush_req_ld_buserr or alu_excp_flush_req_ld_buserr) = '1' else -- load access fault
    5d"6" when alu_excp_flush_req_stamo_misalgn = '1' else -- Store/AMO address misalign
    5d"7" when (longp_excp_flush_req_st_buserr or alu_excp_flush_req_stamo_buserr) = '1' else -- Store/AMO access fault
    5d"8" when (alu_excp_flush_req_ecall and u_mode) = '1' else -- Environment call from U-mode
    5d"9" when (alu_excp_flush_req_ecall and s_mode) = '1' else -- Environment call from S-mode
    5d"10" when (alu_excp_flush_req_ecall and h_mode) = '1' else -- Environment call from H-mode
    5d"11" when (alu_excp_flush_req_ecall and m_mode) = '1' else -- Environment call from M-mode
    5d"16" when longp_excp_flush_req_insterr = '1' else -- This only happened for the NICE long instructions actually  
    5x"1F"; -- Otherwise a reserved value

  -- mbadaddr is an XLEN-bit read-write register formatted as shown in Figure 3.21. When 
  --    * a hardware breakpoint is triggered,
  --    * an instruction-fetch address-misaligned or access exception
  --    * load  address-misaligned or access exception
  --    * store address-misaligned or access exception
  --   occurs, mbadaddr is written with the faulting address. 
  -- In Priv SPEC v1.10, the mbadaddr have been replaced to mtval, and added following points:
  --    * On an illegal instruction trap, mtval is written with the first XLEN bits of the faulting 
  --        instruction . 
  --    * For other exceptions, mtval is set to zero, but a future standard may redefine mtval's
  --        setting for other exceptions.
  --
  excp_flush_req_ld_misalgn <= alu_excp_flush_req_ld_misalgn;
  excp_flush_req_ld_buserr  <= alu_excp_flush_req_ld_buserr or longp_excp_flush_req_ld_buserr;
    
  -- wire cmt_badaddr_update = all_excp_flush_req & 
  --           (  
  --             alu_excp_flush_req_ebreak      
  --           | alu_excp_flush_req_ifu_misalgn 
  --           | alu_excp_flush_req_ifu_buserr  
  --           | excp_flush_by_alu_agu 
  --           | excp_flush_by_longp_ldst);
  --  Per Priv Spec v1.10, all trap need to update this register
  --   * When a trap is taken into M-mode, mtval is written with exception-specific
  --      information to assist software in handling the trap.
  cmt_badaddr_update <= excpirq_flush_req;

  cmt_badaddr <= longp_excp_i_badaddr when excp_flush_by_longp_ldst = '1' else
                 alu_excp_i_badaddr   when excp_flush_by_alu_agu    = '1' else
                 alu_excp_i_pc        when   (alu_excp_flush_req_ebreak      
                                           or alu_excp_flush_req_ifu_misalgn 
                                           or alu_excp_flush_req_ifu_buserr) = '1' else
                 alu_excp_i_instr     when alu_excp_flush_req_ifu_ilegl = '1' else
                 (E203_ADDR_SIZE-1 downto 0 => '0');

  -- We use the exact PC of long-instruction when exception happened, but 
  --   to note since the later instruction may already commited, so long-pipe
  --   excpetion is async-imprecise exceptions
  cmt_epc <= longp_excp_i_pc when longp_excp_i_valid = '1' else
             alu_excp_i_pc;

  cmt_cause <= excp_cause when excp_taken_ena = '1' else
               irq_cause;

  -- Any trap include exception and irq (exclude dbg_irq) will update mstatus register
  -- In the debug mode, epc/cause/status/badaddr will not update badaddr
  cmt_epc_ena     <= (not dbg_mode) and (excp_taken_ena or irq_taken_ena);
  cmt_cause_ena   <= cmt_epc_ena;
  cmt_status_ena  <= cmt_epc_ena;
  cmt_badaddr_ena <= cmt_epc_ena and cmt_badaddr_update;

  cmt_dpc <= alu_excp_i_pc; -- The ALU PC is the current next commiting PC (not yet commited)
  cmt_dpc_ena <= dbg_entry_taken_ena;

  cmt_dcause_set <= dbg_entry_taken_ena;
  cmt_dcause_clr <= cmt_dret_ena;
  set_dcause_nxt <= 3d"2" when dbg_trig_req = '1' else 
                    3d"1" when dbg_ebrk_req = '1' else 
                    3d"3" when dbg_irq_req  = '1' else 
                    3d"4" when dbg_step_req = '1' else
                    3d"5" when dbg_halt_req = '1' else 
                    3d"0" ;

  cmt_dcause_ena <= cmt_dcause_set or cmt_dcause_clr;
  cmt_dcause <= set_dcause_nxt when cmt_dcause_set = '1' else
                3d"0";
end impl;