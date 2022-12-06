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

entity e203_exu_csr is 
  port ( nonflush_cmt_ena: in std_logic;
  	    `if E203_HAS_NICE = "TRUE" then 
         nice_xs_off:     out std_logic;
  	    `end if
  	     csr_ena:          in std_logic;
  	     csr_wr_en:        in std_logic;
  	     csr_rd_en:        in std_logic;
         csr_idx:          in std_logic_vector(12-1 downto 0);

         csr_access_ilgl:  out std_logic;
         tm_stop:          out std_logic;
         core_cgstop:      out std_logic;
         tcm_cgstop:       out std_logic;
         itcm_nohold:      out std_logic;
         mdv_nob2b:        out std_logic;

         read_csr_dat:     out std_logic_vector(E203_XLEN-1 downto 0);
         wbck_csr_dat:      in std_logic_vector(E203_XLEN-1 downto 0);

         core_mhartid:      in std_logic_vector(E203_HART_ID_W-1 downto 0);
         ext_irq_r:         in std_logic;
  	     sft_irq_r:         in std_logic;
  	     tmr_irq_r:         in std_logic;

  	     status_mie_r:     out std_logic;
  	     mtie_r:           out std_logic;
  	     msie_r:           out std_logic;
  	     meie_r:           out std_logic;

  	     wr_dcsr_ena:      out std_logic;
  	     wr_dpc_ena:       out std_logic;
  	     wr_dscratch_ena:  out std_logic;

  	     dcsr_r:            in std_logic_vector(E203_XLEN-1 downto 0);
  	     dpc_r:             in std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     dscratch_r:        in std_logic_vector(E203_XLEN-1 downto 0);

  	     wr_csr_nxt:       out std_logic_vector(E203_XLEN-1 downto 0);

  	     dbg_mode:          in std_logic;
  	     dbg_stopcycle:     in std_logic;

  	     u_mode:           out std_logic;
  	     s_mode:           out std_logic;
  	     h_mode:           out std_logic;
  	     m_mode:           out std_logic;

  	     cmt_badaddr:       in std_logic_vector(E203_ADDR_SIZE-1 downto 0);
  	     cmt_badaddr_ena:   in std_logic;
  	     cmt_epc:           in std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     cmt_epc_ena:       in std_logic;
  	     cmt_cause:         in std_logic_vector(E203_XLEN-1 downto 0);
         cmt_cause_ena:     in std_logic;
         cmt_status_ena:    in std_logic;
         cmt_instret_ena:   in std_logic;
         
         cmt_mret_ena:      in std_logic;
         csr_epc_r:        out std_logic_vector(E203_PC_SIZE-1 downto 0);
         csr_dpc_r:        out std_logic_vector(E203_PC_SIZE-1 downto 0);
         csr_mtvec_r:      out std_logic_vector(E203_XLEN-1 downto 0);

  	     clk_aon:           in std_logic;
         clk:               in std_logic;
         rst_n:             in std_logic
  );
end e203_exu_csr;

architecture impl of e203_exu_csr is 
  signal wbck_csr_wen: std_logic;
  signal read_csr_ena: std_logic;
  signal priv_mode:    std_logic_vector(1 downto 0);
  signal sel_ustatus:  std_logic;
  signal sel_mstatus:  std_logic;
  signal rd_ustatus:   std_logic;
  signal rd_mstatus:   std_logic;
  signal wr_ustatus:   std_logic;
  signal wr_mstatus:   std_logic;
  signal status_mpie_r:   std_logic;
  signal status_mpie_ena: std_logic;
  signal status_mpie_nxt: std_logic;
  signal status_mie_ena:  std_logic;
  signal status_mie_nxt:  std_logic;
  signal status_fs_r:     std_logic_vector(1 downto 0);
  signal status_xs_r:     std_logic_vector(1 downto 0);
  signal status_sd_r:     std_logic;
  signal status_r:        std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mstatus:     std_logic_vector(E203_XLEN-1 downto 0);

  signal sel_mie:         std_logic;
  signal rd_mie:          std_logic;
  signal wr_mie:          std_logic;
  signal mie_ena:         std_logic;
  signal mie_r:           std_logic_vector(E203_XLEN-1 downto 0);
  signal mie_nxt:         std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mie:         std_logic_vector(E203_XLEN-1 downto 0);

  signal sel_mip:         std_logic;
  signal rd_mip:          std_logic;
  signal meip_r:          std_logic;
  signal msip_r:          std_logic;
  signal mtip_r:          std_logic;
  signal ip_r:            std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mip:         std_logic_vector(E203_XLEN-1 downto 0);

  signal sel_mtvec:       std_logic;
  signal rd_mtvec:        std_logic;
 `if E203_SUPPORT_MTVEC = "TRUE" then 
  signal wr_mtvec:        std_logic;
  signal mtvec_ena:       std_logic;
  signal mtvec_r:         std_logic_vector(E203_XLEN-1 downto 0);
  signal mtvec_nxt:       std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mtvec:       std_logic_vector(E203_XLEN-1 downto 0);
  -- THe vector table base is a configurable parameter, so we dont support writeable to it
 `else
  signal csr_mtvec:       std_logic_vector(E203_XLEN-1 downto 0);
 `end if
  
  signal sel_mscratch:    std_logic;
  signal rd_mscratch:     std_logic;
 `if E203_SUPPORT_MSCRATCH = "TRUE" then 
  signal wr_mscratch:     std_logic;
  signal mscratch_ena:    std_logic;
  signal mscratch_r:      std_logic_vector(E203_XLEN-1 downto 0);
  signal mscratch_nxt:    std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mscratch:    std_logic_vector(E203_XLEN-1 downto 0);
 `else
  signal csr_mscratch:    std_logic_vector(E203_XLEN-1 downto 0);
 `end if
  
  signal sel_mcycle:      std_logic;
  signal sel_mcycleh:     std_logic;
  signal sel_minstret:    std_logic;
  signal sel_minstreth:   std_logic;
  
  signal sel_counterstop: std_logic;
  signal sel_mcgstop:     std_logic;
  signal sel_itcmnohold:  std_logic;
  signal sel_mdvnob2b:    std_logic;
  
  signal rd_mcycle:       std_logic;
  signal rd_mcycleh:      std_logic;
  signal rd_minstret:     std_logic;
  signal rd_minstreth:    std_logic;
  
  signal rd_itcmnohold:   std_logic;
  signal rd_mdvnob2b:     std_logic;
  signal rd_counterstop:  std_logic;
  signal rd_mcgstop:      std_logic;

 `if E203_SUPPORT_MCYCLE_MINSTRET = "TRUE" then
  signal wr_mcycle:       std_logic;
  signal wr_mcycleh:      std_logic;
  signal wr_minstret:     std_logic; 
  signal wr_minstreth:    std_logic;
  
  signal wr_itcmnohold:   std_logic;
  signal wr_mdvnob2b:     std_logic;
  signal wr_counterstop:  std_logic;
  signal wr_mcgstop:      std_logic;
  
  signal mcycle_wr_ena:       std_logic;
  signal mcycleh_wr_ena:      std_logic;
  signal minstret_wr_ena:     std_logic;
  signal minstreth_wr_ena:    std_logic;
  
  signal itcmnohold_wr_ena:   std_logic;
  signal mdvnob2b_wr_ena:     std_logic;
  signal counterstop_wr_ena:  std_logic;
  signal mcgstop_wr_ena:      std_logic;

  signal mcycle_r:            std_logic_vector(E203_XLEN-1 downto 0);
  signal mcycleh_r:           std_logic_vector(E203_XLEN-1 downto 0);
  signal minstret_r:          std_logic_vector(E203_XLEN-1 downto 0);
  signal minstreth_r:         std_logic_vector(E203_XLEN-1 downto 0);

  signal cy_stop:             std_logic;
  signal ir_stop:             std_logic;

  signal stop_cycle_in_dbg:   std_logic;
  signal mcycle_ena:          std_logic;
  signal mcycleh_ena:         std_logic;
  signal minstret_ena:        std_logic;
  signal minstreth_ena:       std_logic;

  signal mcycle_nxt:          std_logic_vector(E203_XLEN-1 downto 0);
  signal mcycleh_nxt:         std_logic_vector(E203_XLEN-1 downto 0);
  signal minstret_nxt:        std_logic_vector(E203_XLEN-1 downto 0);
  signal minstreth_nxt:       std_logic_vector(E203_XLEN-1 downto 0);

  signal counterstop_r:       std_logic_vector(E203_XLEN-1 downto 0);
  signal counterstop_ena:     std_logic;
  signal counterstop_nxt:     std_logic_vector(E203_XLEN-1 downto 0);
 `end if

  signal csr_mcycle:          std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mcycleh:         std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_minstret:        std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_minstreth:       std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_counterstop:     std_logic_vector(E203_XLEN-1 downto 0);

  signal itcmnohold_r:        std_logic_vector(E203_XLEN-1 downto 0);
  signal itcmnohold_ena:      std_logic;
  signal itcmnohold_nxt:      std_logic_vector(E203_XLEN-1 downto 0);

  signal csr_itcmnohold:      std_logic_vector(E203_XLEN-1 downto 0);
  signal mdvnob2b_r:          std_logic_vector(E203_XLEN-1 downto 0);
  signal mdvnob2b_ena:        std_logic;
  signal mdvnob2b_nxt:        std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mdvnob2b:        std_logic_vector(E203_XLEN-1 downto 0);

  signal mcgstop_r:           std_logic_vector(E203_XLEN-1 downto 0);
  signal mcgstop_ena:         std_logic;
  signal mcgstop_nxt:         std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mcgstop:         std_logic_vector(E203_XLEN-1 downto 0);

  signal sel_mepc:            std_logic;
  signal rd_mepc:             std_logic;
  signal wr_mepc:             std_logic;
  signal epc_ena:             std_logic;
  signal epc_r:               std_logic_vector(E203_PC_SIZE-1 downto 0);
  signal epc_nxt:             std_logic_vector(E203_PC_SIZE-1 downto 0);
  signal csr_mepc:            std_logic_vector(E203_XLEN-1 downto 0);
  signal dummy_0:             std_logic;

  signal sel_mcause:          std_logic;
  signal rd_mcause:           std_logic;
  signal wr_mcause:           std_logic;
  signal cause_ena:           std_logic;
  signal cause_r:             std_logic_vector(E203_XLEN-1 downto 0);
  signal cause_nxt:           std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mcause:          std_logic_vector(E203_XLEN-1 downto 0);

  signal sel_mbadaddr:        std_logic;
  signal rd_mbadaddr:         std_logic;
  signal wr_mbadaddr:         std_logic;
  signal cmt_trap_badaddr_ena:std_logic;
  signal badaddr_ena:         std_logic;
  signal badaddr_r:           std_logic_vector(E203_ADDR_SIZE-1 downto 0);
  signal badaddr_nxt:         std_logic_vector(E203_ADDR_SIZE-1 downto 0);
  signal csr_mbadaddr:        std_logic_vector(E203_XLEN-1 downto 0);
  signal dummy_1:             std_logic;

  signal sel_misa:            std_logic;
  signal rd_misa:             std_logic;
  signal csr_misa:            std_logic_vector(E203_XLEN-1 downto 0);

  signal csr_mvendorid:       std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_marchid:         std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mimpid:          std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_mhartid:         std_logic_vector(E203_XLEN-1 downto 0);
  signal rd_mvendorid:        std_logic;
  signal rd_marchid:          std_logic;
  signal rd_mimpid:           std_logic;
  signal rd_mhartid:          std_logic;

  signal sel_dcsr:            std_logic;
  signal sel_dpc:             std_logic;
  signal sel_dscratch:        std_logic;
  signal rd_dcsr:             std_logic;
  signal rd_dpc:              std_logic;
  signal rd_dscratch:         std_logic;

  signal csr_dcsr:            std_logic_vector(E203_XLEN-1 downto 0);
  
 `if E203_PC_SIZE_IS_16 = "TRUE" then
  signal csr_dpc:             std_logic_vector(E203_XLEN-1 downto 0);
 `end if
 `if E203_PC_SIZE_IS_24 = "TRUE" then
  signal csr_dpc:             std_logic_vector(E203_XLEN-1 downto 0);
 `end if
 `if E203_PC_SIZE_IS_32 = "TRUE" then
  signal csr_dpc:             std_logic_vector(E203_XLEN-1 downto 0);
  signal csr_dscratch:        std_logic_vector(E203_XLEN-1 downto 0);
 `end if
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
  component sirv_gnrl_dffr is
    generic( DW: integer );
    port( 
          dnxt:  in std_logic_vector( DW-1 downto 0 );
          qout: out std_logic_vector( DW-1 downto 0 );
          clk:   in std_logic;
          rst_n: in std_logic
    );
  end component;
begin
  csr_access_ilgl <= '0';

  -- Only toggle when need to read or write to save power
  wbck_csr_wen <= csr_wr_en and csr_ena and (not csr_access_ilgl);
  read_csr_ena <= csr_rd_en and csr_ena and (not csr_access_ilgl);
  
  priv_mode <= 2b"00" when u_mode = '1' else 
               2b"01" when s_mode = '1' else
               2b"10" when h_mode = '1' else 
               2b"11" when m_mode = '1' else 
               2b"11";

  -- 0x000 URW ustatus User status register.
  --     * Since we support the user-level interrupt, hence we need to support UIE
  -- 0x300 MRW mstatus Machine status register.
  sel_ustatus <= csr_idx ?= 12x"000";
  sel_mstatus <= csr_idx ?= 12x"300";
  
  rd_ustatus <= sel_ustatus and csr_rd_en;
  rd_mstatus <= sel_mstatus and csr_rd_en;
  wr_ustatus <= sel_ustatus and csr_wr_en;
  wr_mstatus <= sel_mstatus and csr_wr_en;

  
  -- Note: the below implementation only apply to Machine-mode config,
  --       if other mode is also supported, these logics need to be updated
  -- Implement MPIE field
  
  -- The MPIE Feilds will be updates when: 
  status_mpie_ena <= 
        -- The CSR is written by CSR instructions
        (wr_mstatus and wbck_csr_wen) or
        -- The MRET instruction commited
        cmt_mret_ena or
        -- The Trap is taken
        cmt_status_ena;

  status_mpie_nxt <= 
                     --   See Priv SPEC:
                     --       When a trap is taken from privilege mode y into privilege
                     --       mode x, xPIE is set to the value of xIE;
                     -- So, When the Trap is taken, the MPIE is updated with the current MIE value
                     status_mie_r when cmt_status_ena = '1' else
                     --   See Priv SPEC:
                     --       When executing an xRET instruction, supposing xPP holds the value y, xIE
                     --       is set to xPIE; the privilege mode is changed to y; 
                     --       xPIE is set to 1;
                     -- So, When the MRET instruction commited, the MPIE is updated with 1
                     '1' when cmt_mret_ena = '1' else
                     -- When the CSR is written by CSR instructions
                     wbck_csr_dat(7) when ((wr_mstatus and wbck_csr_wen) = '1') else -- MPIE is in field 7 of mstatus
                     status_mpie_r; -- Unchanged 

  status_mpie_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                  port map (lden   => status_mpie_ena, 
                                                            dnxt(0)=> status_mpie_nxt,
                                                            qout(0)=> status_mpie_r,
                                                            clk    => clk,
                                                            rst_n  => rst_n
                                                           );

  -- Implement MIE field
  --
  -- The MIE Feilds will be updates same as MPIE
  status_mie_ena <= status_mpie_ena; 
  status_mie_nxt <= 
                    -- See Priv SPEC:
                    --       When a trap is taken from privilege mode y into privilege
                    --       mode x, xPIE is set to the value of xIE,
                    --       xIE is set to 0;
                    -- So, When the Trap is taken, the MIE is updated with 0
                    '0' when cmt_status_ena = '1' else
                    -- See Priv SPEC:
                    --       When executing an xRET instruction, supposing xPP holds the value y, xIE
                    --       is set to xPIE; the privilege mode is changed to y, xPIE is set to 1;
                    -- So, When the MRET instruction commited, the MIE is updated with MPIE
                    status_mpie_r when cmt_mret_ena = '1' else
                    -- When the CSR is written by CSR instructions
                    wbck_csr_dat(3) when ((wr_mstatus and wbck_csr_wen) = '1') else -- MIE is in field 3 of mstatus
                    status_mie_r; -- Unchanged 
  status_mie_dfflr: component sirv_gnrl_dfflr generic map (1)
                                                 port map (lden   => status_mie_ena, 
                                                           dnxt(0)=> status_mie_nxt,
                                                           qout(0)=> status_mie_r,
                                                           clk    => clk,
                                                           rst_n  => rst_n
                                                          );

  -- Implement SD field
  --
  --  See Priv SPEC:
  --    The SD bit is read-only 
  --    And is set when either the FS or XS bits encode a Dirty
  --      state (i.e., SD=((FS==11) OR (XS==11))).
  status_sd_r <= (status_fs_r ?= "11") or (status_xs_r ?= "11");
  status_xs_r <= "00"; 

  -- Implement XS field
  --
  --  See Priv SPEC:
  --  XS field is read-only
  --  The XS field represents a summary of all extensions' status
  --  But in E200 we implement XS exactly same as FS to make it usable by software to 
  --  disable extended accelerators

  -- If no (???WHY???, HAS NICE???) NICE coprocessor interface configured, the XS is just hardwired to 0 
 `if E203_HAS_NICE = "TRUE" then 
  nice_xs_off <= '0'; -- We just make this signal to 0
 `end if

  -- Implement FS field
 `if E203_HAS_FPU = "FALSE" then 
  -- If no FPU configured, the FS is just hardwired to 0(this condition sounds reasonable)
  status_fs_r <= "00"; 
 `end if

  -- Pack to the full mstatus register
  status_r(31)           <= status_sd_r;    -- SD
  status_r(30 downto 23) <= 8b"0";          -- Reserved
  status_r(22 downto 17) <= 6b"0";          -- TSR--MPRV
  status_r(16 downto 15) <= status_xs_r;    -- XS
  status_r(14 downto 13) <= status_fs_r;    -- FS
  status_r(12 downto 11) <= 2b"11";         -- MPP 
  status_r(10 downto 9 ) <= 2b"0";          -- Reserved
  status_r(8)            <= '0';            -- SPP
  status_r(7)            <= status_mpie_r;  -- MPIE
  status_r(6)            <= '0';            -- Reserved
  status_r(5)            <= '0';            -- SPIE 
  status_r(4)            <= '0';            -- UPIE 
  status_r(3)            <= status_mie_r;   -- MIE
  status_r(2)            <= '0';            -- Reserved
  status_r(1)            <= '0';            -- SIE 
  status_r(0)            <= '0';            -- UIE 

  csr_mstatus <= status_r;

  -- 0x004 URW uie User interrupt-enable register.
  --     * Since we dont delegate interrupt to user mode, hence it is as all 0s
  -- 0x304 MRW mie Machine interrupt-enable register.
  sel_mie <= (csr_idx ?= 12x"304");
  rd_mie  <= sel_mie and csr_rd_en;
  wr_mie  <= sel_mie and csr_wr_en;
  mie_ena <= wr_mie and wbck_csr_wen;

  mie_nxt(31 downto 12) <= 20b"0";
  mie_nxt(11)           <= wbck_csr_dat(11); -- MEIE
  mie_nxt(10 downto 8)  <= 3b"0";
  mie_nxt(7)            <= wbck_csr_dat( 7); -- MTIE
  mie_nxt(6 downto 4)   <= 3b"0";
  mie_nxt(3)            <= wbck_csr_dat( 3); -- MSIE
  mie_nxt(2 downto 0)   <= 3b"0";
  mie_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN)
                                          port map (mie_ena, mie_nxt, mie_r, clk, rst_n);
  csr_mie <= mie_r;
  meie_r <= csr_mie(11);
  mtie_r <= csr_mie( 7);
  msie_r <= csr_mie( 3);

  -- 0x044 URW uip User interrupt pending.
  --   We dont support delegation scheme, so no need to support the uip
  -- 0x344 MRW mip Machine interrupt pending
  sel_mip <= (csr_idx ?= 12x"344");
  rd_mip  <= sel_mip and csr_rd_en;

  -- wire wr_mip = sel_mip & csr_wr_en;
  -- The MxIP is read-only
  meip_dffr: component sirv_gnrl_dffr generic map (1)
                                         port map (dnxt(0) => ext_irq_r,
                                                   qout(0) => meip_r,
                                                   clk     => clk,
                                                   rst_n   => rst_n
                                                  );
  msip_dffr: component sirv_gnrl_dffr generic map (1)
                                         port map (dnxt(0) => sft_irq_r,
                                                   qout(0) => msip_r,
                                                   clk     => clk,
                                                   rst_n   => rst_n
                                                  );
  mtip_dffr: component sirv_gnrl_dffr generic map (1)
                                         port map (dnxt(0) => tmr_irq_r,
                                                   qout(0) => mtip_r,
                                                   clk     => clk,
                                                   rst_n   => rst_n
                                                  );
  ip_r(31 downto 12) <= 20b"0";
  ip_r(11)           <= meip_r;
  ip_r(10 downto 8)  <= 3b"0";
  ip_r(7)            <= mtip_r;
  ip_r(6 downto 4)   <= 3b"0";
  ip_r(3)            <= msip_r;
  ip_r(2 downto 0)   <= 3b"0";
  csr_mip <= ip_r;

  -- 0x005 URW utvec User trap handler base address.
  --   We dont support user trap, so no utvec needed
  -- 0x305 MRW mtvec Machine trap-handler base address.
  
  sel_mtvec <= (csr_idx ?= 12x"305");
  rd_mtvec  <= csr_rd_en and sel_mtvec;
 `if E203_SUPPORT_MTVEC = "TRUE" then
  wr_mtvec <= sel_mtvec and csr_wr_en;
  mtvec_ena <= (wr_mtvec and wbck_csr_wen);
  mtvec_nxt <= wbck_csr_dat;
  mtvec_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN)
                                            port map (mtvec_ena, mtvec_nxt, mtvec_r, clk, rst_n);
  csr_mtvec <= mtvec_r;
 `else
  -- THe vector table base is a configurable parameter, so we dont support writeable to it
  csr_mtvec <= E203_MTVEC_TRAP_BASE; -- E203_MTVEC_TRAP_BASE was NOT defined!
 `end if
  csr_mtvec_r <= csr_mtvec;
  
  -- 0x340 MRW mscratch
  sel_mscratch <= (csr_idx ?= 12x"340");
  rd_mscratch  <= sel_mscratch and csr_rd_en;
 `if E203_SUPPORT_MSCRATCH = "TRUE" then
  wr_mscratch  <= sel_mscratch and csr_wr_en;
  mscratch_ena <= wr_mscratch and wbck_csr_wen;
  mscratch_nxt <= wbck_csr_dat;
  mscratch_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN)
                                            port map (mscratch_ena, mscratch_nxt, mscratch_r, clk, rst_n);
  csr_mscratch <= mscratch_r;
 `else
  csr_mscratch <= (others => '0');
 `end if

  -- 0xB00 MRW mcycle 
  -- 0xB02 MRW minstret 
  -- 0xB80 MRW mcycleh
  -- 0xB82 MRW minstreth 
  sel_mcycle    <= (csr_idx ?= 12x"B00");
  sel_mcycleh   <= (csr_idx ?= 12x"B80");
  sel_minstret  <= (csr_idx ?= 12x"B02");
  sel_minstreth <= (csr_idx ?= 12x"B82");
  
  -- 0xBFF MRW counterstop 
  -- This register is our self-defined register to stop
  -- the cycle/time/instret counters to save dynamic powers
  sel_counterstop <= (csr_idx ?= 12x"BFF"); -- This address is not used by ISA
  -- 0xBFE MRW mcgstop 
  -- This register is our self-defined register to disable the 
  -- automaticall clock gating for CPU logics for debugging purpose
  sel_mcgstop <= (csr_idx ?= 12x"BFE"); -- This address is not used by ISA
  -- 0xBFD MRW itcmnohold 
  -- This register is our self-defined register to disble the 
  -- ITCM SRAM output holdup feature, if set, then we assume
  -- ITCM SRAM output cannot holdup last read value
  sel_itcmnohold <= (csr_idx ?= 12x"BFD"); -- This address is not used by ISA
  -- 0xBF0 MRW mdvnob2b 
  -- This register is our self-defined register to disble the 
  -- Mul/div back2back feature
  sel_mdvnob2b <= (csr_idx ?= 12x"BF0"); -- This address is not used by ISA
  
  rd_mcycle     <= csr_rd_en and sel_mcycle   ;
  rd_mcycleh    <= csr_rd_en and sel_mcycleh  ;
  rd_minstret   <= csr_rd_en and sel_minstret ;
  rd_minstreth  <= csr_rd_en and sel_minstreth;
  
  rd_itcmnohold <= csr_rd_en and sel_itcmnohold;
  rd_mdvnob2b   <= csr_rd_en and sel_mdvnob2b;
  rd_counterstop<= csr_rd_en and sel_counterstop;
  rd_mcgstop    <= csr_rd_en and sel_mcgstop;

 `if E203_SUPPORT_MCYCLE_MINSTRET = "TRUE" then
  wr_mcycle     <= csr_wr_en and sel_mcycle   ;
  wr_mcycleh    <= csr_wr_en and sel_mcycleh  ;
  wr_minstret   <= csr_wr_en and sel_minstret ; 
  wr_minstreth  <= csr_wr_en and sel_minstreth;
  
  wr_itcmnohold  <= csr_wr_en and sel_itcmnohold ;
  wr_mdvnob2b    <= csr_wr_en and sel_mdvnob2b ; -- what's this?
  wr_counterstop <= csr_wr_en and sel_counterstop;
  wr_mcgstop     <= csr_wr_en and sel_mcgstop;
  
  mcycle_wr_ena    <= (wr_mcycle    and wbck_csr_wen);
  mcycleh_wr_ena   <= (wr_mcycleh   and wbck_csr_wen);
  minstret_wr_ena  <= (wr_minstret  and wbck_csr_wen);
  minstreth_wr_ena <= (wr_minstreth and wbck_csr_wen);
  
  itcmnohold_wr_ena  <= (wr_itcmnohold  and wbck_csr_wen);
  mdvnob2b_wr_ena    <= (wr_mdvnob2b    and wbck_csr_wen);
  counterstop_wr_ena <= (wr_counterstop and wbck_csr_wen);
  mcgstop_wr_ena     <= (wr_mcgstop     and wbck_csr_wen);
  
  stop_cycle_in_dbg <= dbg_stopcycle and dbg_mode;
  mcycle_ena    <= mcycle_wr_ena    or 
                  ((not cy_stop) and (not stop_cycle_in_dbg) and ('1'));
  mcycleh_ena   <= mcycleh_wr_ena   or 
                  ((not cy_stop) and (not stop_cycle_in_dbg) and ((mcycle_r ?= (not (E203_XLEN-1 downto 0 => '0')))));
  minstret_ena  <= minstret_wr_ena  or
                  ((not ir_stop) and (not stop_cycle_in_dbg) and (cmt_instret_ena));
  minstreth_ena <= minstreth_wr_ena or
                  ((not ir_stop) and (not stop_cycle_in_dbg) and ((cmt_instret_ena and (minstret_r ?= (not (E203_XLEN-1 downto 0 => '0'))))));
  
  mcycle_nxt    <= wbck_csr_dat when mcycle_wr_ena    = '1' else std_logic_vector((unsigned(mcycle_r   ) + '1'));
  mcycleh_nxt   <= wbck_csr_dat when mcycleh_wr_ena   = '1' else std_logic_vector((unsigned(mcycleh_r  ) + '1'));
  minstret_nxt  <= wbck_csr_dat when minstret_wr_ena  = '1' else std_logic_vector((unsigned(minstret_r ) + '1'));
  minstreth_nxt <= wbck_csr_dat when minstreth_wr_ena = '1' else std_logic_vector((unsigned(minstreth_r) + '1'));
  
  -- We need to use the always-on clock for this counter
  mcycle_dfflr   : component sirv_gnrl_dfflr generic map (E203_XLEN) port map (mcycle_ena, mcycle_nxt, mcycle_r, clk_aon, rst_n);
  mcycleh_dfflr  : component sirv_gnrl_dfflr generic map (E203_XLEN) port map (mcycleh_ena, mcycleh_nxt, mcycleh_r, clk_aon, rst_n);
  minstret_dfflr : component sirv_gnrl_dfflr generic map (E203_XLEN) port map (minstret_ena, minstret_nxt, minstret_r, clk, rst_n);
  minstreth_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN) port map (minstreth_ena, minstreth_nxt, minstreth_r, clk, rst_n);
  
  counterstop_ena <= counterstop_wr_ena;
  counterstop_nxt <= (29b"0", wbck_csr_dat(2 downto 0)); -- Only LSB 3bits are useful
  counterstop_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN)
                                                  port map (counterstop_ena, counterstop_nxt, counterstop_r, clk, rst_n);
  
  csr_mcycle      <= mcycle_r;
  csr_mcycleh     <= mcycleh_r;
  csr_minstret    <= minstret_r;
  csr_minstreth   <= minstreth_r;
  csr_counterstop <= counterstop_r;
 `else
  csr_mcycle      <= (others => '0');
  csr_mcycleh     <= (others => '0');
  csr_minstret    <= (others => '0');
  csr_minstreth   <= (others => '0');
  csr_counterstop <= (others => '0');
 `end if

  itcmnohold_ena <= itcmnohold_wr_ena;
  itcmnohold_nxt <= (31b"0", wbck_csr_dat(0)); -- Only LSB 1bits are useful
  itcmnohold_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN)
                                                 port map (itcmnohold_ena, itcmnohold_nxt, itcmnohold_r, clk, rst_n);
  csr_itcmnohold <= itcmnohold_r;
  
  mdvnob2b_ena <= mdvnob2b_wr_ena;
  mdvnob2b_nxt <= (31b"0", wbck_csr_dat(0)); -- Only LSB 1bits are useful
  mdvnob2b_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN)
                                               port map (mdvnob2b_ena, mdvnob2b_nxt, mdvnob2b_r, clk, rst_n);
  csr_mdvnob2b <= mdvnob2b_r;
  
  cy_stop <= counterstop_r(0); -- Stop CYCLE   counter
  tm_stop <= counterstop_r(1); -- Stop TIME    counter
  ir_stop <= counterstop_r(2); -- Stop INSTRET counter
  
  itcm_nohold <= itcmnohold_r(0); -- ITCM no-hold up feature
  mdv_nob2b   <= mdvnob2b_r(0); -- Mul/Div no back2back feature

  mcgstop_ena <= mcgstop_wr_ena;
  mcgstop_nxt <= (30b"0", wbck_csr_dat(1 downto 0)); -- Only LSB 2bits are useful
  mcgstop_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN)
                                              port map (mcgstop_ena, mcgstop_nxt, mcgstop_r, clk, rst_n);
  csr_mcgstop <= mcgstop_r;
  core_cgstop <= mcgstop_r(0); -- Stop Core clock gating
  tcm_cgstop  <= mcgstop_r(1); -- Stop TCM  clock gating
  
  -- 0x041 URW uepc User exception program counter.
  --   We dont support user trap, so no uepc needed
  -- 0x341 MRW mepc Machine exception program counter.
  sel_mepc <= (csr_idx ?= 12x"341");
  rd_mepc  <= sel_mepc and csr_rd_en;
  wr_mepc  <= sel_mepc and csr_wr_en;
  epc_ena  <= (wr_mepc and wbck_csr_wen) or cmt_epc_ena;
  
  epc_nxt(E203_PC_SIZE-1 downto 1) <= cmt_epc(E203_PC_SIZE-1 downto 1) when cmt_epc_ena = '1' else
                                      wbck_csr_dat(E203_PC_SIZE-1 downto 1);
  epc_nxt(0) <= '0'; -- Must not hold PC which will generate the misalign exception according to ISA
  epc_dfflr: component sirv_gnrl_dfflr generic map (E203_PC_SIZE) 
                                          port map (epc_ena, epc_nxt, epc_r, clk, rst_n);
  
  (dummy_0, csr_mepc) <= (E203_XLEN+1-E203_PC_SIZE-1 downto 0 => '0') & epc_r;
  csr_epc_r <= csr_mepc;

  -- 0x042 URW ucause User trap cause.
  --   We dont support user trap, so no ucause needed
  -- 0x342 MRW mcause Machine trap cause.
  sel_mcause <= (csr_idx ?= 12x"342");
  rd_mcause  <= sel_mcause and csr_rd_en;
  wr_mcause  <= sel_mcause and csr_wr_en;
  cause_ena  <= (wr_mcause and wbck_csr_wen) or cmt_cause_ena;
  cause_nxt(31) <= cmt_cause(31) when cmt_cause_ena = '1' else wbck_csr_dat(31);
  cause_nxt(30 downto 4) <= 27b"0";
  cause_nxt(3 downto 0) <= cmt_cause(3 downto 0) when cmt_cause_ena = '1' else wbck_csr_dat(3 downto 0);
  cause_dfflr: component sirv_gnrl_dfflr generic map (E203_XLEN) 
                                            port map (cause_ena, cause_nxt, cause_r, clk, rst_n);
  csr_mcause <= cause_r;

  -- 0x043 URW ubadaddr User bad address.
  --   We dont support user trap, so no ubadaddr needed
  -- 0x343 MRW mbadaddr Machine bad address.
  sel_mbadaddr <= (csr_idx ?= 12x"343");
  rd_mbadaddr <= sel_mbadaddr and csr_rd_en;
  wr_mbadaddr <= sel_mbadaddr and csr_wr_en;
  cmt_trap_badaddr_ena <= cmt_badaddr_ena;
  badaddr_ena <= (wr_mbadaddr and wbck_csr_wen) or cmt_trap_badaddr_ena;
  
  badaddr_nxt <= cmt_badaddr when cmt_trap_badaddr_ena = '1' else wbck_csr_dat(E203_ADDR_SIZE-1 downto 0);
  badaddr_dfflr: component sirv_gnrl_dfflr generic map (E203_ADDR_SIZE)
                                              port map (badaddr_ena, badaddr_nxt, badaddr_r, clk, rst_n);
  
  (dummy_1, csr_mbadaddr) <= (E203_XLEN+1-E203_ADDR_SIZE-1 downto 0 => '0') & badaddr_r;
  
  -- We dont support the delegation scheme, so no need to implement
  --   delegete registers
  
  -- 0x301 MRW misa ISA and extensions
  sel_misa <= (csr_idx ?= 12x"301");
  rd_misa  <= sel_misa and csr_rd_en;

  -- Only implemented the M mode, IMC or EMC
  csr_misa <= (
      2b"1"
     ,4b"0" --              WIRI
     ,1b"0" --              25 Z Reserved
     ,1b"0" --              24 Y Reserved
     ,1b"0" --              23 X Non-standard extensions present
     ,1b"0" --              22 W Reserved
     ,1b"0" --              21 V Tentatively reserved for Vector extension 20 U User mode implemented
     ,1b"0" --              20 U User mode implemented
     ,1b"0" --              19 T Tentatively reserved for Transactional Memory extension
     ,1b"0" --              18 S Supervisor mode implemented
     ,1b"0" --              17 R Reserved
     ,1b"0" --              16 Q Quad-precision floating-point extension
     ,1b"0" --              15 P Tentatively reserved for Packed-SIMD extension
     ,1b"0" --              14 O Reserved
     ,1b"0" --              13 N User-level interrupts supported
     ,1b"1" --              12 M Integer Multiply/Divide extension
     ,1b"0" --              11 L Tentatively reserved for Decimal Floating-Point extension
     ,1b"0" --              10 K Reserved
     ,1b"0" --              9 J Reserved
    `if E203_RFREG_NUM_IS_32 = "TRUE" then
     ,1b"1" -- 8 I RV32I/64I/128I base ISA
	 `else
     ,1b"0"
    `end if
     ,1b"0" --              7 H Hypervisor mode implemented
     ,1b"0" --              6 G Additional standard extensions present
    `if E203_HAS_FPU = "FALSE" then
     ,1b"0" --              5 F Single-precision floating-point extension
    `end if
    `if E203_RFREG_NUM_IS_32 = "TRUE" then
     ,1b"0" --              4 E RV32E base ISA
    `else
     ,1b"1"             
    `end if
    `if E203_HAS_FPU = "FALSE" then
     ,1b"0" --              3 D Double-precision floating-point extension
    `end if
     ,1b"1" --              2 C Compressed extension
     ,1b"0" --              1 B Tentatively reserved for Bit operations extension
    `if E203_SUPPORT_AMO = "TRUE" then
     ,1b"1" --              0 A Atomic extension
    `end if
    `if E203_SUPPORT_AMO = "FALSE" then
     ,1b"0" --              0 A Atomic extension
    `end if
              );

  -- Machine Information Registers
  -- 0xF11 MRO mvendorid Vendor ID.
  -- 0xF12 MRO marchid Architecture ID.
  -- 0xF13 MRO mimpid Implementation ID.
  -- 0xF14 MRO mhartid Hardware thread ID.
  csr_mvendorid <= (11 downto 0 => x"536", others => '0');
  csr_marchid   <= (15 downto 0 => x"E203", others => '0');
  csr_mimpid    <= (3 downto 0 => x"1", others => '0');
  csr_mhartid   <= (E203_XLEN-E203_HART_ID_W-1 downto 0 => '0') & core_mhartid;
  rd_mvendorid <= csr_rd_en and (csr_idx ?= 12x"F11");
  rd_marchid   <= csr_rd_en and (csr_idx ?= 12x"F12");
  rd_mimpid    <= csr_rd_en and (csr_idx ?= 12x"F13");
  rd_mhartid   <= csr_rd_en and (csr_idx ?= 12x"F14");
  
  -- 0x7b0 Debug Control and Status
  -- 0x7b1 Debug PC
  -- 0x7b2 Debug Scratch Register
  -- 0x7a0 Trigger selection register
  sel_dcsr     <= (csr_idx ?= 12x"7b0");
  sel_dpc      <= (csr_idx ?= 12x"7b1");
  sel_dscratch <= (csr_idx ?= 12x"7b2");
  
  rd_dcsr     <= dbg_mode and csr_rd_en and sel_dcsr    ;
  rd_dpc      <= dbg_mode and csr_rd_en and sel_dpc     ;
  rd_dscratch <= dbg_mode and csr_rd_en and sel_dscratch;
  
  
  wr_dcsr_ena     <= dbg_mode and csr_wr_en and sel_dcsr    ;
  wr_dpc_ena      <= dbg_mode and csr_wr_en and sel_dpc     ;
  wr_dscratch_ena <= dbg_mode and csr_wr_en and sel_dscratch;
  
  wr_csr_nxt      <= wbck_csr_dat;
  
  csr_dcsr <= dcsr_r;
 `if E203_PC_SIZE_IS_16 = "TRUE" then
  csr_dpc  <= (E203_XLEN-E203_PC_SIZE-1 downto 0 => '0') & dpc_r;
 `end if
 `if E203_PC_SIZE_IS_24 = "TRUE" then
  csr_dpc  <= (E203_XLEN-E203_PC_SIZE-1 downto 0 => '0') & dpc_r;
  `end if
 `if E203_PC_SIZE_IS_32 = "TRUE" then
  csr_dpc  <= dpc_r;
 `end if
  csr_dscratch <= dscratch_r;
  
  csr_dpc_r <= dpc_r;

  --  Generate the Read path
  --  Currently we only support the M mode to simplify the implementation and 
  --      reduce the gatecount because we are a privite core
  u_mode <= '0';
  s_mode <= '0';
  h_mode <= '0';
  m_mode <= '1';
  read_csr_dat <= (E203_XLEN-1 downto 0 => '0') 
          -- | ({`E203_XLEN{rd_ustatus  }} & csr_ustatus  )
          or ((E203_XLEN-1 downto 0 => rd_mstatus    ) and csr_mstatus    )
          or ((E203_XLEN-1 downto 0 => rd_mie        ) and csr_mie        )
          or ((E203_XLEN-1 downto 0 => rd_mtvec      ) and csr_mtvec      )
          or ((E203_XLEN-1 downto 0 => rd_mepc       ) and csr_mepc       )
          or ((E203_XLEN-1 downto 0 => rd_mscratch   ) and csr_mscratch   )
          or ((E203_XLEN-1 downto 0 => rd_mcause     ) and csr_mcause     )
          or ((E203_XLEN-1 downto 0 => rd_mbadaddr   ) and csr_mbadaddr   )
          or ((E203_XLEN-1 downto 0 => rd_mip        ) and csr_mip        )
          or ((E203_XLEN-1 downto 0 => rd_misa       ) and csr_misa       )
          or ((E203_XLEN-1 downto 0 => rd_mvendorid  ) and csr_mvendorid  )
          or ((E203_XLEN-1 downto 0 => rd_marchid    ) and csr_marchid    )
          or ((E203_XLEN-1 downto 0 => rd_mimpid     ) and csr_mimpid     )
          or ((E203_XLEN-1 downto 0 => rd_mhartid    ) and csr_mhartid    )
          or ((E203_XLEN-1 downto 0 => rd_mcycle     ) and csr_mcycle     )
          or ((E203_XLEN-1 downto 0 => rd_mcycleh    ) and csr_mcycleh    )
          or ((E203_XLEN-1 downto 0 => rd_minstret   ) and csr_minstret   )
          or ((E203_XLEN-1 downto 0 => rd_minstreth  ) and csr_minstreth  )
          or ((E203_XLEN-1 downto 0 => rd_counterstop) and csr_counterstop) -- Self-defined
          or ((E203_XLEN-1 downto 0 => rd_mcgstop    ) and csr_mcgstop    ) -- Self-defined
          or ((E203_XLEN-1 downto 0 => rd_itcmnohold ) and csr_itcmnohold ) -- Self-defined
          or ((E203_XLEN-1 downto 0 => rd_mdvnob2b   ) and csr_mdvnob2b   ) -- Self-defined
          or ((E203_XLEN-1 downto 0 => rd_dcsr       ) and csr_dcsr       )
          or ((E203_XLEN-1 downto 0 => rd_dpc        ) and csr_dpc        )
          or ((E203_XLEN-1 downto 0 => rd_dscratch   ) and csr_dscratch   )
          ;

end impl;