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
--   The IFU to implement entire instruction fetch unit. 
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_ifu is 
  port ( 
  	     inspect_pc:       out std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     ifu_active:       out std_logic;
  	     itcm_nohold:       in std_logic;
  	     pc_rtvec:          in std_logic_vector(E203_PC_SIZE-1 downto 0);

  	     `if E203_HAS_ITCM = "TRUE" then
         ifu2itcm_holdup:   in std_logic;
         
         -- The ITCM address region indication signal
         itcm_region_indic: in std_logic_vector(E203_ADDR_SIZE-1 downto 0);

  	     -- Bus Interface to ITCM, internal protocol called ICB (Internal Chip Bus)
         --    * Bus cmd channel
  	     ifu2itcm_icb_cmd_valid: out std_logic;  -- Handshake valid
  	     ifu2itcm_icb_cmd_ready:  in std_logic;  -- Handshake ready
         -- Note: The data on rdata or wdata channel must be naturally
         --       aligned, this is in line with the AXI definition
  	     ifu2itcm_icb_cmd_addr:  out std_logic_vector(E203_ITCM_ADDR_WIDTH-1 downto 0);

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
         ifu2biu_icb_cmd_valid:  out std_logic; -- Handshake valid
         ifu2biu_icb_cmd_ready:   in std_logic; -- Handshake ready
         -- Note: The data on rdata or wdata channel must be naturally
         --       aligned, this is in line with the AXI definition
         ifu2biu_icb_cmd_addr:   out std_logic_vector(E203_ADDR_SIZE-1 downto 0); -- Bus transaction start addr

         --    * Bus RSP channel
  	     ifu2biu_icb_rsp_valid:   in std_logic;  -- Response valid
  	     ifu2biu_icb_rsp_ready:  out std_logic;  -- Response ready
  	     ifu2biu_icb_rsp_err:     in std_logic;  -- Response error
         -- Note: the RSP rdata is inline with AXI definition
         ifu2biu_icb_rsp_rdata:   in std_logic_vector(E203_SYSMEM_DATA_WIDTH-1 downto 0);
         `end if
         
         -- The IR stage to EXU interface
         ifu_o_ir:         out std_logic_vector(E203_INSTR_SIZE-1 downto 0); -- The instruction register
         ifu_o_pc:         out std_logic_vector(E203_PC_SIZE-1 downto 0);    -- The PC register along with
         ifu_o_pc_vld:     out std_logic;
         ifu_o_misalgn:    out std_logic; -- The fetch misalign
         ifu_o_buserr:     out std_logic; -- The fetch bus error
         ifu_o_rs1idx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         ifu_o_rs2idx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         ifu_o_prdt_taken: out std_logic;  -- The Bxx is predicted as taken
         ifu_o_muldiv_b2b: out std_logic;  -- The mul/div back2back case
         ifu_o_valid:      out std_logic;  -- Handshake signals with EXU stage
         ifu_o_ready:       in std_logic;

         pipe_flush_ack:   out std_logic;
         pipe_flush_req:    in std_logic;
         pipe_flush_add_op1:in std_logic_vector(E203_PC_SIZE-1 downto 0);
         pipe_flush_add_op2:in std_logic_vector(E203_PC_SIZE-1 downto 0);
         `if E203_TIMING_BOOST = "TRUE" then
         pipe_flush_pc:     in std_logic_vector(E203_PC_SIZE-1 downto 0);
         `end if

         -- The halt request come from other commit stage
         --   If the ifu_halt_req is asserting, then IFU will stop fetching new 
         --     instructions and after the oustanding transactions are completed,
         --     asserting the ifu_halt_ack as the response.
         --   The IFU will resume fetching only after the ifu_halt_req is deasserted
         ifu_halt_req:      in std_logic;
  	     ifu_halt_ack:     out std_logic;

  	     oitf_empty:        in std_logic;
  	     rf2ifu_x1:         in std_logic_vector(E203_XLEN-1 downto 0);
         rf2ifu_rs1:        in std_logic_vector(E203_XLEN-1 downto 0);  	     
         dec2ifu_rden:      in std_logic;
         dec2ifu_rs1en:     in std_logic;
         dec2ifu_rdidx:     in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         dec2ifu_mulhsu:    in std_logic;
         dec2ifu_div:       in std_logic;
  	     dec2ifu_rem:       in std_logic;
  	     dec2ifu_divu:      in std_logic;
  	     dec2ifu_remu:      in std_logic;

         clk:               in std_logic;
         rst_n:             in std_logic
  );
end e203_ifu;

architecture impl of e203_ifu is 
  signal ifu_req_valid:    std_ulogic;
  signal ifu_req_ready:    std_ulogic;
  signal ifu_req_pc:       std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal ifu_req_seq:      std_ulogic;
  signal ifu_req_seq_rv32: std_ulogic;
  signal ifu_req_last_pc:  std_ulogic_vector(E203_PC_SIZE-1 downto 0);
  signal ifu_rsp_valid:    std_ulogic;
  signal ifu_rsp_ready:    std_ulogic;
  signal ifu_rsp_err:      std_ulogic;
  signal ifu_rsp_instr:    std_ulogic_vector(E203_INSTR_SIZE-1 downto 0);
  
  component e203_ifu_ifetch is 
  port ( 
  	     inspect_pc:       out std_logic_vector(E203_PC_SIZE-1 downto 0);
  	     pc_rtvec:          in std_logic_vector(E203_PC_SIZE-1 downto 0);

  	     -- Fetch Interface to memory system, internal protocol
         --    * IFetch REQ channel
  	     ifu_req_valid:    out std_logic;  -- Handshake valid
  	     ifu_req_ready:     in std_logic;  -- Handshake ready

  	     -- Note: the req-addr can be unaligned with the length indicated
         --       by req_len signal.
         --       The targetd (ITCM, ICache or Sys-MEM) ctrl modules 
         --       will handle the unalign cases and split-and-merge works
  	     ifu_req_pc:       out std_logic_vector(E203_PC_SIZE-1 downto 0);  -- Fetch PC
  	     ifu_req_seq:      out std_logic;  -- This request is a sequential instruction fetch
  	     ifu_req_seq_rv32: out std_logic;  -- This request is incremented 32bits fetch
         ifu_req_last_pc:  out std_logic_vector(E203_PC_SIZE-1 downto 0);  -- The last accessed
                                                                           -- PC address (i.e., pc_r)
  	     --  * IFetch RSP channel
  	     ifu_rsp_valid:     in std_logic;  -- Response valid
  	     ifu_rsp_ready:    out std_logic;  -- Response ready
  	     ifu_rsp_err:       in std_logic;  -- Response error
         -- Note: the RSP channel always return a valid instruction
         --   fetched from the fetching start PC address.
         --   The targetd (ITCM, ICache or Sys-MEM) ctrl modules 
         --   will handle the unalign cases and split-and-merge works
         --input  ifu_rsp_replay,
         ifu_rsp_instr:     in std_logic_vector(E203_INSTR_SIZE-1 downto 0);

         -- The IR stage to EXU interface
         ifu_o_ir:         out std_logic_vector(E203_INSTR_SIZE-1 downto 0); -- The instruction register
         ifu_o_pc:         out std_logic_vector(E203_PC_SIZE-1 downto 0);    -- The PC register along with
         ifu_o_pc_vld:     out std_logic;
         ifu_o_rs1idx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         ifu_o_rs2idx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         ifu_o_prdt_taken: out std_logic;  -- The Bxx is predicted as taken
         ifu_o_misalgn:    out std_logic;  -- The fetch misalign 
         ifu_o_buserr:     out std_logic;  -- The fetch bus error
         ifu_o_muldiv_b2b: out std_logic;  -- The mul/div back2back case
         ifu_o_valid:      out std_logic;  -- Handshake signals with EXU stage
         ifu_o_ready:       in std_logic;

         pipe_flush_ack:   out std_logic;
         pipe_flush_req:    in std_logic;
         pipe_flush_add_op1:in std_logic_vector(E203_PC_SIZE-1 downto 0);
         pipe_flush_add_op2:in std_logic_vector(E203_PC_SIZE-1 downto 0);
         `if E203_TIMING_BOOST = "TRUE" then
         pipe_flush_pc:     in std_logic_vector(E203_PC_SIZE-1 downto 0);
         `end if

         -- The halt request come from other commit stage
         --   If the ifu_halt_req is asserting, then IFU will stop fetching new 
         --     instructions and after the oustanding transactions are completed,
         --     asserting the ifu_halt_ack as the response.
         --   The IFU will resume fetching only after the ifu_halt_req is deasserted
         ifu_halt_req:      in std_logic;
  	     ifu_halt_ack:     out std_logic;

  	     oitf_empty:        in std_logic;
  	     rf2ifu_x1:         in std_logic_vector(E203_XLEN-1 downto 0);
         rf2ifu_rs1:        in std_logic_vector(E203_XLEN-1 downto 0);
  	     dec2ifu_rs1en:     in std_logic;
         dec2ifu_rden:      in std_logic;
         dec2ifu_rdidx:     in std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
         dec2ifu_mulhsu:    in std_logic;
         dec2ifu_div:       in std_logic;
  	     dec2ifu_rem:       in std_logic;
  	     dec2ifu_divu:      in std_logic;
  	     dec2ifu_remu:      in std_logic;

         clk:               in std_logic;
         rst_n:             in std_logic
  );
  end component;
  component e203_ifu_ift2icb is 
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
  end component; 
begin
  u_e203_ifu_ifetch: component e203_ifu_ifetch 
                      port map ( inspect_pc         =>inspect_pc        ,
                                 pc_rtvec           =>pc_rtvec          ,  
                                 ifu_req_valid      =>ifu_req_valid     ,
                                 ifu_req_ready      =>ifu_req_ready     ,
                                 ifu_req_pc         =>ifu_req_pc        ,
                                 ifu_req_seq        =>ifu_req_seq       ,
                                 ifu_req_seq_rv32   =>ifu_req_seq_rv32  ,
                                 ifu_req_last_pc    =>ifu_req_last_pc   ,
                                 ifu_rsp_valid      =>ifu_rsp_valid     ,
                                 ifu_rsp_ready      =>ifu_rsp_ready     ,
                                 ifu_rsp_err        =>ifu_rsp_err       ,
                                 
                                 ifu_rsp_instr      =>ifu_rsp_instr     ,
                                 ifu_o_ir           =>ifu_o_ir          ,
                                 ifu_o_pc           =>ifu_o_pc          ,
                                 ifu_o_pc_vld       =>ifu_o_pc_vld      ,
                                 ifu_o_misalgn      =>ifu_o_misalgn     ,
                                 ifu_o_buserr       =>ifu_o_buserr      ,
                                 ifu_o_rs1idx       =>ifu_o_rs1idx      ,
                                 ifu_o_rs2idx       =>ifu_o_rs2idx      ,
                                 ifu_o_prdt_taken   =>ifu_o_prdt_taken  ,
                                 ifu_o_muldiv_b2b   =>ifu_o_muldiv_b2b  ,
                                 ifu_o_valid        =>ifu_o_valid       ,
                                 ifu_o_ready        =>ifu_o_ready       ,
                                 pipe_flush_ack     =>pipe_flush_ack    , 
                                 pipe_flush_req     =>pipe_flush_req    ,
                                 pipe_flush_add_op1 =>pipe_flush_add_op1,     
                                 `if E203_TIMING_BOOST = "TRUE" then
                                 pipe_flush_pc      =>pipe_flush_pc     ,  
                                 `end if
                                 pipe_flush_add_op2 =>pipe_flush_add_op2, 
                                 ifu_halt_req       =>ifu_halt_req      ,
                                 ifu_halt_ack       =>ifu_halt_ack      ,
          
                                 oitf_empty         =>oitf_empty        ,
                                 rf2ifu_x1          =>rf2ifu_x1         ,
                                 rf2ifu_rs1         =>rf2ifu_rs1        ,
                                 dec2ifu_rden       =>dec2ifu_rden      ,
                                 dec2ifu_rs1en      =>dec2ifu_rs1en     ,
                                 dec2ifu_rdidx      =>dec2ifu_rdidx     ,
                                 dec2ifu_mulhsu     =>dec2ifu_mulhsu    ,
                                 dec2ifu_div        =>dec2ifu_div       ,
                                 dec2ifu_rem        =>dec2ifu_rem       ,
                                 dec2ifu_divu       =>dec2ifu_divu      ,
                                 dec2ifu_remu       =>dec2ifu_remu      ,
     
                                 clk                =>clk               ,
                                 rst_n              =>rst_n              
                      	       );
  u_e203_ifu_ift2icb: component e203_ifu_ift2icb
                       port map ( ifu_req_valid          => ifu_req_valid   ,
                                  ifu_req_ready          => ifu_req_ready   ,
                                  ifu_req_pc             => ifu_req_pc      ,
                                  ifu_req_seq            => ifu_req_seq     ,
                                  ifu_req_seq_rv32       => ifu_req_seq_rv32,
                                  ifu_req_last_pc        => ifu_req_last_pc ,
                                  ifu_rsp_valid          => ifu_rsp_valid   ,
                                  ifu_rsp_ready          => ifu_rsp_ready   ,
                                  ifu_rsp_err            => ifu_rsp_err     ,
                                             
                                  ifu_rsp_instr          => ifu_rsp_instr   ,
                                  itcm_nohold            => itcm_nohold     ,
                                
                                  `if E203_HAS_ITCM = "TRUE" then
                                  itcm_region_indic      => itcm_region_indic     ,
                                  ifu2itcm_icb_cmd_valid => ifu2itcm_icb_cmd_valid,
                                  ifu2itcm_icb_cmd_ready => ifu2itcm_icb_cmd_ready,
                                  ifu2itcm_icb_cmd_addr  => ifu2itcm_icb_cmd_addr ,
                                  ifu2itcm_icb_rsp_valid => ifu2itcm_icb_rsp_valid,
                                  ifu2itcm_icb_rsp_ready => ifu2itcm_icb_rsp_ready,
                                  ifu2itcm_icb_rsp_err   => ifu2itcm_icb_rsp_err  ,
                                  ifu2itcm_icb_rsp_rdata => ifu2itcm_icb_rsp_rdata,
                                  `end if
                                
                                
                                  `if E203_HAS_MEM_ITF = "TRUE" then
                                  ifu2biu_icb_cmd_valid => ifu2biu_icb_cmd_valid,
                                  ifu2biu_icb_cmd_ready => ifu2biu_icb_cmd_ready,
                                  ifu2biu_icb_cmd_addr  => ifu2biu_icb_cmd_addr ,
                                  ifu2biu_icb_rsp_valid => ifu2biu_icb_rsp_valid,
                                  ifu2biu_icb_rsp_ready => ifu2biu_icb_rsp_ready,
                                  ifu2biu_icb_rsp_err   => ifu2biu_icb_rsp_err  ,
                                  ifu2biu_icb_rsp_rdata => ifu2biu_icb_rsp_rdata,  
                                  `end if
                                
                                  `if E203_HAS_ITCM = "TRUE" then
                                  ifu2itcm_holdup       => ifu2itcm_holdup,
                                  `end if
                                
                                  clk                   => clk            ,
                                  rst_n                 => rst_n           
                       	        );
  ifu_active <= '1'; -- Seems the IFU never rest at block level
end impl;