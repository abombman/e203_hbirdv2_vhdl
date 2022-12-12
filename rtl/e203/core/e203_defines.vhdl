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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;

package e203_defines_pkg is 

-------------------------------------------------------------
-- ISA relevant macro
`if E203_CFG_ADDR_SIZE_IS_16 = "TRUE" then
  constant E203_ADDR_SIZE: integer:= 16;
  constant E203_PC_SIZE:   integer:= 16;
`end if

`if E203_CFG_ADDR_SIZE_IS_24 = "TRUE" then
  constant E203_ADDR_SIZE: integer:= 24;
  constant E203_PC_SIZE:   integer:= 24;
`end if

`if E203_CFG_ADDR_SIZE_IS_32 = "TRUE" then
  constant E203_ADDR_SIZE: integer:= 32;
  constant E203_PC_SIZE:   integer:= 32;
`end if

`if E203_CFG_XLEN_IS_32 = "TRUE" then
  constant E203_XLEN:      integer:= 32;
  constant E203_XLEN_MW:   integer:= 4;
`end if

  constant E203_INSTR_SIZE: integer:= 32;

  constant E203_RFIDX_WIDTH: integer:= 5;

`if E203_CFG_REGNUM_IS_32 = "TRUE" then
  constant E203_RFREG_NUM: integer:= 32;
`end if

`if E203_CFG_REGNUM_IS_16 = "TRUE" then
  constant E203_RFREG_NUM: integer:= 16;
`end if

`if E203_CFG_REGNUM_IS_8 = "TRUE" then
  constant E203_RFREG_NUM: integer:= 8;
`end if

`if E203_CFG_REGNUM_IS_4 = "TRUE" then
  constant E203_RFREG_NUM: integer:= 4;
`end if

  constant E203_PPI_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0)                        := E203_CFG_PPI_ADDR_BASE;
  --constant E203_PPI_BASE_REGION: unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-4)   := E203_CFG_PPI_BASE_REGION;
  subtype  E203_PPI_BASE_REGION is unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-4);
  
  -- CLINT: 0x0200 0000 -- 0x0200 FFFF
  constant E203_CLINT_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0)                      := E203_CFG_CLINT_ADDR_BASE;
  --constant E203_CLINT_BASE_REGION: unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-16):= E203_CFG_CLINT_BASE_REGION;
  subtype  E203_CLINT_BASE_REGION is unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-16);
  
  -- PLIC: 0x0C00 0000 -- 0x0CFF FFFF
  constant E203_PLIC_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0)                       := E203_CFG_PLIC_ADDR_BASE;
  --constant E203_PLIC_BASE_REGION: unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-8)  := E203_CFG_PLIC_BASE_REGION;
  subtype  E203_PLIC_BASE_REGION is unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-8);
  
  -- FIO: 0xF000 0000 -- 0xFFFF FFFF
  constant E203_FIO_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0)                        := E203_CFG_FIO_ADDR_BASE;
  --constant E203_FIO_BASE_REGION: unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-4)   := E203_CFG_FIO_BASE_REGION;
  subtype  E203_FIO_BASE_REGION is unsigned(E203_CFG_ADDR_SIZE-1 downto E203_CFG_ADDR_SIZE-4);

  constant E203_DTCM_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0)                       := E203_CFG_DTCM_ADDR_BASE;
  constant E203_ITCM_ADDR_BASE: unsigned(E203_CFG_ADDR_SIZE-1 downto 0)                       := E203_CFG_ITCM_ADDR_BASE;

-------------------------------------------------------------
-- Interface relevant macro
  constant E203_HART_NUM:  integer:= 1;
  constant E203_HART_ID_W: integer:= 1;
  constant E203_LIRQ_NUM:  integer:= 1;
  constant E203_EVT_NUM:   integer:= 1;

`if E203_CFG_SYSMEM_DATA_WIDTH_IS_32 = "TRUE" then
  constant E203_SYSMEM_DATA_WIDTH: integer:= 32;
`end if

`if E203_CFG_SYSMEM_DATA_WIDTH_IS_64 = "TRUE" then
  constant E203_SYSMEM_DATA_WIDTH: integer:= 64;
`end if

-------------------------------------------------------------
-- ITCM relevant macro
`if E203_CFG_HAS_ITCM = "TRUE" then
  constant E203_ITCM_ADDR_WIDTH: integer:= E203_CFG_ITCM_ADDR_WIDTH;
  -- The ITCM size is 2^addr_width bytes, and ITCM is 64bits wide (8 bytes)
  --  so the DP is 2^addr_width/8
  --  so the AW is addr_width - 3
  constant E203_ITCM_RAM_DP: integer:= (2**(E203_CFG_ITCM_ADDR_WIDTH-3));
  constant E203_ITCM_RAM_AW: integer:= (E203_CFG_ITCM_ADDR_WIDTH-3);
  --constant E203_ITCM_BASE_REGION: unsigned(E203_ADDR_SIZE-1 downto E203_ITCM_ADDR_WIDTH):= E203_CFG_ITCM_ADDR_BASE(E203_ADDR_SIZE-1 downto E203_ITCM_ADDR_WIDTH);
  subtype  E203_ITCM_BASE_REGION is unsigned(E203_ADDR_SIZE-1 downto E203_ITCM_ADDR_WIDTH);
  constant E203_ITCM_DATA_WIDTH: integer:= 64;
  constant E203_ITCM_WMSK_WIDTH: integer:= 8;
  constant E203_ITCM_RAM_ECC_DW: integer:= 8;
  constant E203_ITCM_RAM_ECC_MW: integer:= 1;

  --ifndef E203_HAS_ECC
  constant E203_ITCM_RAM_DW: integer:= E203_ITCM_DATA_WIDTH;
  constant E203_ITCM_RAM_MW: integer:= E203_ITCM_WMSK_WIDTH;
  constant E203_ITCM_OUTS_NUM: integer:= 1;  -- If no-ECC, ITCM is 1 cycle latency then only allow 1 oustanding for external agent
`end if

-------------------------------------------------------------
-- DTCM relevant macro
`if E203_CFG_HAS_DTCM = "TRUE" then
  constant E203_DTCM_ADDR_WIDTH: integer:= E203_CFG_DTCM_ADDR_WIDTH;
  -- The DTCM size is 2^addr_width bytes, and DTCM is 32bits wide (4 bytes)
  --  so the DP is 2^addr_width/4
  --  so the AW is addr_width - 2
  constant E203_DTCM_RAM_DP: integer:= (2**(E203_CFG_DTCM_ADDR_WIDTH-2));
  constant E203_DTCM_RAM_AW: integer:= (E203_CFG_DTCM_ADDR_WIDTH-2);
  --constant E203_DTCM_BASE_REGION: unsigned(E203_ADDR_SIZE-1 downto E203_DTCM_ADDR_WIDTH):= E203_CFG_DTCM_ADDR_BASE(E203_ADDR_SIZE-1 downto E203_DTCM_ADDR_WIDTH);
  subtype  E203_DTCM_BASE_REGION is unsigned(E203_ADDR_SIZE-1 downto E203_DTCM_ADDR_WIDTH);
  constant E203_DTCM_DATA_WIDTH: integer:= 32;
  constant E203_DTCM_WMSK_WIDTH: integer:= 4;
  constant E203_DTCM_RAM_ECC_DW: integer:= 7;
  constant E203_DTCM_RAM_ECC_MW: integer:= 1;

  --ifndef E203_HAS_ECC
  constant E203_DTCM_RAM_DW: integer:= E203_DTCM_DATA_WIDTH;
  constant E203_DTCM_RAM_MW: integer:= E203_DTCM_WMSK_WIDTH;
  constant E203_DTCM_OUTS_NUM: integer:= 1;  -- If no-ECC, DTCM is 1 cycle latency then only allow 1 oustanding for external agent
`end if

-------------------------------------------------------------
-- MULDIV relevant macro

-------------------------------------------------------------
-- ALU relevant macro
  constant E203_MULDIV_ADDER_WIDTH: integer:= 35;
`if E203_CFG_SUPPORT_SHARE_MULDIV = "TRUE" then
  constant E203_ALU_ADDER_WIDTH: integer:= E203_MULDIV_ADDER_WIDTH;
`else 
  constant E203_ALU_ADDER_WIDTH: integer:= (E203_XLEN+1); 
`end if

-------------------------------------------------------------
-- MAS relevant macro
  constant E203_ASYNC_FF_LEVELS: integer:= 2;
  -- To cut down the loop between ALU write-back valid --> oitf_ret_ena --> oitf_ready ---> dispatch_ready --- > alu_i_valid
  -- we exclude the ret_ena from the ready signal
  -- so in order to back2back dispatch, we need at least 2 entries in OITF
`if E203_CFG_OITF_DEPTH_IS_2 = "TRUE" then
  constant E203_OITF_DEPTH: integer:= 2;
  constant E203_ITAG_WIDTH: integer:= 1;
`end if
`if E203_CFG_OITF_DEPTH_IS_4 = "TRUE" then
  constant E203_OITF_DEPTH: integer:= 4;
  constant E203_ITAG_WIDTH: integer:= 2;
`end if
`if E203_CFG_HAS_FPU = "TRUE" then
  `if E203_CFG_FPU_DOUBLE = "TRUE" then
    constant E203_FLEN: integer:= 64;
  `else 
    constant E203_FLEN: integer:= 32; 
  `end if 
`else 
  constant E203_FLEN: integer:= 32; 
`end if

-------------------------------------------------------------
-- Decode relevant macro
  constant E203_DECINFO_GRP_WIDTH:       integer:= 3;
  constant E203_DECINFO_GRP_ALU:         std_logic_vector(E203_DECINFO_GRP_WIDTH-1 downto 0):= (d"0", others=> '0');
  constant E203_DECINFO_GRP_AGU:         std_logic_vector(E203_DECINFO_GRP_WIDTH-1 downto 0):= (d"1", others=> '0');
  constant E203_DECINFO_GRP_BJP:         std_logic_vector(E203_DECINFO_GRP_WIDTH-1 downto 0):= (d"2", others=> '0');
  constant E203_DECINFO_GRP_CSR:         std_logic_vector(E203_DECINFO_GRP_WIDTH-1 downto 0):= (d"3", others=> '0');
  constant E203_DECINFO_GRP_MULDIV:      std_logic_vector(E203_DECINFO_GRP_WIDTH-1 downto 0):= (d"4", others=> '0');
  constant E203_DECINFO_GRP_NICE:        std_logic_vector(E203_DECINFO_GRP_WIDTH-1 downto 0):= (d"5", others=> '0');
  constant E203_DECINFO_GRP_FPU:         std_logic_vector(E203_DECINFO_GRP_WIDTH-1 downto 0):= (d"6", others=> '0');

  constant E203_DECINFO_GRP_FPU_WIDTH:   integer:= 2;
  constant E203_DECINFO_GRP_FPU_FLSU:    std_logic_vector(E203_DECINFO_GRP_FPU_WIDTH-1 downto 0):= (d"0", others=> '0');
  constant E203_DECINFO_GRP_FPU_FMAC:    std_logic_vector(E203_DECINFO_GRP_FPU_WIDTH-1 downto 0):= (d"1", others=> '0');
  constant E203_DECINFO_GRP_FPU_FDIV:    std_logic_vector(E203_DECINFO_GRP_FPU_WIDTH-1 downto 0):= (d"2", others=> '0');
  constant E203_DECINFO_GRP_FPU_FMIS:    std_logic_vector(E203_DECINFO_GRP_FPU_WIDTH-1 downto 0):= (d"3", others=> '0');
  
  constant E203_DECINFO_GRP_LSB:         integer:= 0;
  constant E203_DECINFO_GRP_MSB:         integer:= (E203_DECINFO_GRP_LSB + E203_DECINFO_GRP_WIDTH-1);
  --constant E203_DECINFO_GRP:             std_logic_vector(E203_DECINFO_GRP_MSB downto E203_DECINFO_GRP_LSB):= (d"7", others=> '0');    -- initial with '1'
  subtype  E203_DECINFO_GRP is           std_logic_vector(E203_DECINFO_GRP_MSB downto E203_DECINFO_GRP_LSB);
  
  constant E203_DECINFO_RV32_LSB:        integer:= (E203_DECINFO_GRP_MSB+1);
  constant E203_DECINFO_RV32_MSB:        integer:= (E203_DECINFO_RV32_LSB+1-1);
  --constant E203_DECINFO_RV32:            std_logic_vector(E203_DECINFO_RV32_MSB downto E203_DECINFO_RV32_LSB):= (others=> '1');        -- initial with '1'
  subtype  E203_DECINFO_RV32 is          std_logic_vector(E203_DECINFO_RV32_MSB downto E203_DECINFO_RV32_LSB);
 
  constant E203_DECINFO_SUBDECINFO_LSB:  integer:= (E203_DECINFO_RV32_MSB+1);

  -- ALU group
  constant E203_DECINFO_ALU_ADD_LSB:     integer:= E203_DECINFO_SUBDECINFO_LSB;
  constant E203_DECINFO_ALU_ADD_MSB:     integer:= (E203_DECINFO_ALU_ADD_LSB+1-1);
  --constant E203_DECINFO_ALU_ADD:         std_logic_vector(E203_DECINFO_ALU_ADD_MSB downto E203_DECINFO_ALU_ADD_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_ADD is       std_logic_vector(E203_DECINFO_ALU_ADD_MSB downto E203_DECINFO_ALU_ADD_LSB);
  
  constant E203_DECINFO_ALU_SUB_LSB:     integer:= (E203_DECINFO_ALU_ADD_MSB+1);
  constant E203_DECINFO_ALU_SUB_MSB:     integer:= (E203_DECINFO_ALU_SUB_LSB+1-1);
  --constant E203_DECINFO_ALU_SUB:         std_logic_vector(E203_DECINFO_ALU_SUB_MSB downto E203_DECINFO_ALU_SUB_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_SUB is       std_logic_vector(E203_DECINFO_ALU_SUB_MSB downto E203_DECINFO_ALU_SUB_LSB);
  
  constant E203_DECINFO_ALU_XOR_LSB:     integer:= (E203_DECINFO_ALU_SUB_MSB+1);
  constant E203_DECINFO_ALU_XOR_MSB:     integer:= (E203_DECINFO_ALU_XOR_LSB+1-1);
  --constant E203_DECINFO_ALU_XOR:         std_logic_vector(E203_DECINFO_ALU_XOR_MSB downto E203_DECINFO_ALU_XOR_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_XOR is       std_logic_vector(E203_DECINFO_ALU_XOR_MSB downto E203_DECINFO_ALU_XOR_LSB);
  
  constant E203_DECINFO_ALU_SLL_LSB:     integer:= (E203_DECINFO_ALU_XOR_MSB+1);
  constant E203_DECINFO_ALU_SLL_MSB:     integer:= (E203_DECINFO_ALU_SLL_LSB+1-1);
  --constant E203_DECINFO_ALU_SLL:         std_logic_vector(E203_DECINFO_ALU_SLL_MSB downto E203_DECINFO_ALU_SLL_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_SLL is        std_logic_vector(E203_DECINFO_ALU_SLL_MSB downto E203_DECINFO_ALU_SLL_LSB);
  
  constant E203_DECINFO_ALU_SRL_LSB:     integer:= (E203_DECINFO_ALU_SLL_MSB+1);
  constant E203_DECINFO_ALU_SRL_MSB:     integer:= (E203_DECINFO_ALU_SRL_LSB+1-1);
  --constant E203_DECINFO_ALU_SRL:         std_logic_vector(E203_DECINFO_ALU_SRL_MSB downto E203_DECINFO_ALU_SRL_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_SRL is       std_logic_vector(E203_DECINFO_ALU_SRL_MSB downto E203_DECINFO_ALU_SRL_LSB);
  
  constant E203_DECINFO_ALU_SRA_LSB:     integer:= (E203_DECINFO_ALU_SRL_MSB+1);
  constant E203_DECINFO_ALU_SRA_MSB:     integer:= (E203_DECINFO_ALU_SRA_LSB+1-1);
  --constant E203_DECINFO_ALU_SRA:         std_logic_vector(E203_DECINFO_ALU_SRA_MSB downto E203_DECINFO_ALU_SRA_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_SRA is       std_logic_vector(E203_DECINFO_ALU_SRA_MSB downto E203_DECINFO_ALU_SRA_LSB);
  
  constant E203_DECINFO_ALU_OR_LSB:      integer:= (E203_DECINFO_ALU_SRA_MSB+1);
  constant E203_DECINFO_ALU_OR_MSB:      integer:= (E203_DECINFO_ALU_OR_LSB+1-1);
  --constant E203_DECINFO_ALU_OR:          std_logic_vector(E203_DECINFO_ALU_OR_MSB downto E203_DECINFO_ALU_OR_LSB):=   (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_OR is        std_logic_vector(E203_DECINFO_ALU_OR_MSB downto E203_DECINFO_ALU_OR_LSB);
  
  constant E203_DECINFO_ALU_AND_LSB:     integer:= (E203_DECINFO_ALU_OR_MSB+1);
  constant E203_DECINFO_ALU_AND_MSB:     integer:= (E203_DECINFO_ALU_AND_LSB+1-1);
  --constant E203_DECINFO_ALU_AND:         std_logic_vector(E203_DECINFO_ALU_AND_MSB downto E203_DECINFO_ALU_AND_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_AND is        std_logic_vector(E203_DECINFO_ALU_AND_MSB downto E203_DECINFO_ALU_AND_LSB);
  
  constant E203_DECINFO_ALU_SLT_LSB:     integer:= (E203_DECINFO_ALU_AND_MSB+1);
  constant E203_DECINFO_ALU_SLT_MSB:     integer:= (E203_DECINFO_ALU_SLT_LSB+1-1);
  --constant E203_DECINFO_ALU_SLT:         std_logic_vector(E203_DECINFO_ALU_SLT_MSB downto E203_DECINFO_ALU_SLT_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_SLT is       std_logic_vector(E203_DECINFO_ALU_SLT_MSB downto E203_DECINFO_ALU_SLT_LSB);
  
  constant E203_DECINFO_ALU_SLTU_LSB:    integer:= (E203_DECINFO_ALU_SLT_MSB+1);
  constant E203_DECINFO_ALU_SLTU_MSB:    integer:= (E203_DECINFO_ALU_SLTU_LSB+1-1);
  --constant E203_DECINFO_ALU_SLTU:        std_logic_vector(E203_DECINFO_ALU_SLTU_MSB downto E203_DECINFO_ALU_SLTU_LSB):= (others=> '1');-- initial with '1'
  subtype  E203_DECINFO_ALU_SLTU is      std_logic_vector(E203_DECINFO_ALU_SLTU_MSB downto E203_DECINFO_ALU_SLTU_LSB);
  
  constant E203_DECINFO_ALU_LUI_LSB:     integer:= (E203_DECINFO_ALU_SLTU_MSB+1);
  constant E203_DECINFO_ALU_LUI_MSB:     integer:= (E203_DECINFO_ALU_LUI_LSB+1-1);
  --constant E203_DECINFO_ALU_LUI:         std_logic_vector(E203_DECINFO_ALU_LUI_MSB downto E203_DECINFO_ALU_LUI_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_LUI is       std_logic_vector(E203_DECINFO_ALU_LUI_MSB downto E203_DECINFO_ALU_LUI_LSB);
  
  constant E203_DECINFO_ALU_OP2IMM_LSB:  integer:= (E203_DECINFO_ALU_LUI_MSB+1);
  constant E203_DECINFO_ALU_OP2IMM_MSB:  integer:= (E203_DECINFO_ALU_OP2IMM_LSB+1-1);
  --constant E203_DECINFO_ALU_OP2IMM:      std_logic_vector(E203_DECINFO_ALU_OP2IMM_MSB downto E203_DECINFO_ALU_OP2IMM_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_OP2IMM is    std_logic_vector(E203_DECINFO_ALU_OP2IMM_MSB downto E203_DECINFO_ALU_OP2IMM_LSB);
  
  constant E203_DECINFO_ALU_OP1PC_LSB:   integer:= (E203_DECINFO_ALU_OP2IMM_MSB+1);
  constant E203_DECINFO_ALU_OP1PC_MSB:   integer:= (E203_DECINFO_ALU_OP1PC_LSB+1-1);
  --constant E203_DECINFO_ALU_OP1PC:       std_logic_vector(E203_DECINFO_ALU_OP1PC_MSB downto E203_DECINFO_ALU_OP1PC_LSB):= (others=> '1');    -- initial with '1'
  subtype  E203_DECINFO_ALU_OP1PC is     std_logic_vector(E203_DECINFO_ALU_OP1PC_MSB downto E203_DECINFO_ALU_OP1PC_LSB);
  
  constant E203_DECINFO_ALU_NOP_LSB:     integer:= (E203_DECINFO_ALU_OP1PC_MSB+1);
  constant E203_DECINFO_ALU_NOP_MSB:     integer:= (E203_DECINFO_ALU_NOP_LSB+1-1);
  --constant E203_DECINFO_ALU_NOP:         std_logic_vector(E203_DECINFO_ALU_NOP_MSB downto E203_DECINFO_ALU_NOP_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_NOP is       std_logic_vector(E203_DECINFO_ALU_NOP_MSB downto E203_DECINFO_ALU_NOP_LSB);
  
  constant E203_DECINFO_ALU_ECAL_LSB:    integer:= (E203_DECINFO_ALU_NOP_MSB+1);
  constant E203_DECINFO_ALU_ECAL_MSB:    integer:= (E203_DECINFO_ALU_ECAL_LSB+1-1);
  --constant E203_DECINFO_ALU_ECAL:        std_logic_vector(E203_DECINFO_ALU_ECAL_MSB downto E203_DECINFO_ALU_ECAL_LSB):= (others=> '1');-- initial with '1'
  subtype  E203_DECINFO_ALU_ECAL is      std_logic_vector(E203_DECINFO_ALU_ECAL_MSB downto E203_DECINFO_ALU_ECAL_LSB);
  
  constant E203_DECINFO_ALU_EBRK_LSB:    integer:= (E203_DECINFO_ALU_ECAL_MSB+1);
  constant E203_DECINFO_ALU_EBRK_MSB:    integer:= (E203_DECINFO_ALU_EBRK_LSB+1-1);
  --constant E203_DECINFO_ALU_EBRK:        std_logic_vector(E203_DECINFO_ALU_EBRK_MSB downto E203_DECINFO_ALU_EBRK_LSB):= (others=> '1');-- initial with '1'
  subtype  E203_DECINFO_ALU_EBRK is      std_logic_vector(E203_DECINFO_ALU_EBRK_MSB downto E203_DECINFO_ALU_EBRK_LSB);
  
  constant E203_DECINFO_ALU_WFI_LSB:     integer:= (E203_DECINFO_ALU_EBRK_MSB+1);
  constant E203_DECINFO_ALU_WFI_MSB:     integer:= (E203_DECINFO_ALU_WFI_LSB+1-1);
  --constant E203_DECINFO_ALU_WFI:         std_logic_vector(E203_DECINFO_ALU_WFI_MSB downto E203_DECINFO_ALU_WFI_LSB):= (others=> '1');  -- initial with '1'
  subtype  E203_DECINFO_ALU_WFI is       std_logic_vector(E203_DECINFO_ALU_WFI_MSB downto E203_DECINFO_ALU_WFI_LSB);
  
  constant E203_DECINFO_ALU_WIDTH:       integer:= (E203_DECINFO_ALU_WFI_MSB+1);

  -- AGU group
  constant E203_DECINFO_AGU_LOAD_LSB:    integer:= E203_DECINFO_SUBDECINFO_LSB;
  constant E203_DECINFO_AGU_LOAD_MSB:    integer:= (E203_DECINFO_AGU_LOAD_LSB+1-1);  
  subtype  E203_DECINFO_AGU_LOAD is      std_logic_vector(E203_DECINFO_AGU_LOAD_MSB downto E203_DECINFO_AGU_LOAD_LSB);
   
  constant E203_DECINFO_AGU_STORE_LSB:   integer:= (E203_DECINFO_AGU_LOAD_MSB+1);
  constant E203_DECINFO_AGU_STORE_MSB:   integer:= (E203_DECINFO_AGU_STORE_LSB+1-1);   
  subtype  E203_DECINFO_AGU_STORE is     std_logic_vector(E203_DECINFO_AGU_STORE_MSB downto E203_DECINFO_AGU_STORE_LSB);
	
  constant E203_DECINFO_AGU_SIZE_LSB:    integer:= (E203_DECINFO_AGU_STORE_MSB+1);
  constant E203_DECINFO_AGU_SIZE_MSB:    integer:= (E203_DECINFO_AGU_SIZE_LSB+2-1);   
  subtype  E203_DECINFO_AGU_SIZE is      std_logic_vector(E203_DECINFO_AGU_SIZE_MSB downto E203_DECINFO_AGU_SIZE_LSB);
   
  constant E203_DECINFO_AGU_USIGN_LSB:   integer:= (E203_DECINFO_AGU_SIZE_MSB+1);
  constant E203_DECINFO_AGU_USIGN_MSB:   integer:= (E203_DECINFO_AGU_USIGN_LSB+1-1);   
  subtype  E203_DECINFO_AGU_USIGN is     std_logic_vector(E203_DECINFO_AGU_USIGN_MSB downto E203_DECINFO_AGU_USIGN_LSB);
	
  constant E203_DECINFO_AGU_EXCL_LSB:    integer:= (E203_DECINFO_AGU_USIGN_MSB+1);
  constant E203_DECINFO_AGU_EXCL_MSB:    integer:= (E203_DECINFO_AGU_EXCL_LSB+1-1);   
  subtype  E203_DECINFO_AGU_EXCL is      std_logic_vector(E203_DECINFO_AGU_EXCL_MSB downto E203_DECINFO_AGU_EXCL_LSB);
   
  constant E203_DECINFO_AGU_AMO_LSB:     integer:= (E203_DECINFO_AGU_EXCL_MSB+1);
  constant E203_DECINFO_AGU_AMO_MSB:     integer:= (E203_DECINFO_AGU_AMO_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMO is       std_logic_vector(E203_DECINFO_AGU_AMO_MSB downto E203_DECINFO_AGU_AMO_LSB);
	
  constant E203_DECINFO_AGU_AMOSWAP_LSB: integer:= (E203_DECINFO_AGU_AMO_MSB+1);
  constant E203_DECINFO_AGU_AMOSWAP_MSB: integer:= (E203_DECINFO_AGU_AMOSWAP_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOSWAP is   std_logic_vector(E203_DECINFO_AGU_AMOSWAP_MSB downto E203_DECINFO_AGU_AMOSWAP_LSB);
	
  constant E203_DECINFO_AGU_AMOADD_LSB:  integer:= (E203_DECINFO_AGU_AMOSWAP_MSB+1);
  constant E203_DECINFO_AGU_AMOADD_MSB:  integer:= (E203_DECINFO_AGU_AMOADD_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOADD is    std_logic_vector(E203_DECINFO_AGU_AMOADD_MSB downto E203_DECINFO_AGU_AMOADD_LSB);
	
  constant E203_DECINFO_AGU_AMOAND_LSB:  integer:= (E203_DECINFO_AGU_AMOADD_MSB+1);
  constant E203_DECINFO_AGU_AMOAND_MSB:  integer:= (E203_DECINFO_AGU_AMOAND_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOAND is    std_logic_vector(E203_DECINFO_AGU_AMOAND_MSB downto E203_DECINFO_AGU_AMOAND_LSB);
	
  constant E203_DECINFO_AGU_AMOOR_LSB:   integer:= (E203_DECINFO_AGU_AMOAND_MSB+1);
  constant E203_DECINFO_AGU_AMOOR_MSB:   integer:= (E203_DECINFO_AGU_AMOOR_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOOR is     std_logic_vector(E203_DECINFO_AGU_AMOOR_MSB downto E203_DECINFO_AGU_AMOOR_LSB);
	
  constant E203_DECINFO_AGU_AMOXOR_LSB:  integer:= (E203_DECINFO_AGU_AMOOR_MSB+1);
  constant E203_DECINFO_AGU_AMOXOR_MSB:  integer:= (E203_DECINFO_AGU_AMOXOR_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOXOR is    std_logic_vector(E203_DECINFO_AGU_AMOXOR_MSB downto E203_DECINFO_AGU_AMOXOR_LSB);
	
  constant E203_DECINFO_AGU_AMOMAX_LSB:  integer:= (E203_DECINFO_AGU_AMOXOR_MSB+1);
  constant E203_DECINFO_AGU_AMOMAX_MSB:  integer:= (E203_DECINFO_AGU_AMOMAX_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOMAX is    std_logic_vector(E203_DECINFO_AGU_AMOMAX_MSB downto E203_DECINFO_AGU_AMOMAX_LSB);
	
  constant E203_DECINFO_AGU_AMOMIN_LSB:  integer:= (E203_DECINFO_AGU_AMOMAX_MSB+1);
  constant E203_DECINFO_AGU_AMOMIN_MSB:  integer:= (E203_DECINFO_AGU_AMOMIN_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOMIN is    std_logic_vector(E203_DECINFO_AGU_AMOMIN_MSB downto E203_DECINFO_AGU_AMOMIN_LSB);
	
  constant E203_DECINFO_AGU_AMOMAXU_LSB: integer:= (E203_DECINFO_AGU_AMOMIN_MSB+1);
  constant E203_DECINFO_AGU_AMOMAXU_MSB: integer:= (E203_DECINFO_AGU_AMOMAXU_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOMAXU is   std_logic_vector(E203_DECINFO_AGU_AMOMAXU_MSB downto E203_DECINFO_AGU_AMOMAXU_LSB);
	
  constant E203_DECINFO_AGU_AMOMINU_LSB: integer:= (E203_DECINFO_AGU_AMOMAXU_MSB+1);
  constant E203_DECINFO_AGU_AMOMINU_MSB: integer:= (E203_DECINFO_AGU_AMOMINU_LSB+1-1);   
  subtype  E203_DECINFO_AGU_AMOMINU is   std_logic_vector(E203_DECINFO_AGU_AMOMINU_MSB downto E203_DECINFO_AGU_AMOMINU_LSB);
	
  constant E203_DECINFO_AGU_OP2IMM_LSB:  integer:= (E203_DECINFO_AGU_AMOMINU_MSB+1);
  constant E203_DECINFO_AGU_OP2IMM_MSB:  integer:= (E203_DECINFO_AGU_OP2IMM_LSB+1-1);   
  subtype  E203_DECINFO_AGU_OP2IMM is    std_logic_vector(E203_DECINFO_AGU_OP2IMM_MSB downto E203_DECINFO_AGU_OP2IMM_LSB);

  constant E203_DECINFO_AGU_WIDTH:       integer:= (E203_DECINFO_AGU_OP2IMM_MSB+1);


  -- Bxx group
  constant E203_DECINFO_BJP_JUMP_LSB:    integer:= E203_DECINFO_SUBDECINFO_LSB;
  constant E203_DECINFO_BJP_JUMP_MSB:    integer:= (E203_DECINFO_BJP_JUMP_LSB+1-1);
  subtype  E203_DECINFO_BJP_JUMP is      std_logic_vector(E203_DECINFO_BJP_JUMP_MSB downto E203_DECINFO_BJP_JUMP_LSB);
  
  constant E203_DECINFO_BJP_BPRDT_LSB:   integer:= (E203_DECINFO_BJP_JUMP_MSB+1);
  constant E203_DECINFO_BJP_BPRDT_MSB:   integer:= (E203_DECINFO_BJP_BPRDT_LSB+1-1);
  subtype  E203_DECINFO_BJP_BPRDT is     std_logic_vector(E203_DECINFO_BJP_BPRDT_MSB downto E203_DECINFO_BJP_BPRDT_LSB);
  
  constant E203_DECINFO_BJP_BEQ_LSB:     integer:= (E203_DECINFO_BJP_BPRDT_MSB+1);
  constant E203_DECINFO_BJP_BEQ_MSB:     integer:= (E203_DECINFO_BJP_BEQ_LSB+1-1);
  subtype  E203_DECINFO_BJP_BEQ is       std_logic_vector(E203_DECINFO_BJP_BEQ_MSB downto E203_DECINFO_BJP_BEQ_LSB);
  
  constant E203_DECINFO_BJP_BNE_LSB:     integer:= (E203_DECINFO_BJP_BEQ_MSB+1);
  constant E203_DECINFO_BJP_BNE_MSB:     integer:= (E203_DECINFO_BJP_BNE_LSB+1-1);
  subtype  E203_DECINFO_BJP_BNE is       std_logic_vector(E203_DECINFO_BJP_BNE_MSB downto E203_DECINFO_BJP_BNE_LSB);
  
  constant E203_DECINFO_BJP_BLT_LSB:     integer:= (E203_DECINFO_BJP_BNE_MSB+1);
  constant E203_DECINFO_BJP_BLT_MSB:     integer:= (E203_DECINFO_BJP_BLT_LSB+1-1);
  subtype  E203_DECINFO_BJP_BLT is       std_logic_vector(E203_DECINFO_BJP_BLT_MSB downto E203_DECINFO_BJP_BLT_LSB);
  
  constant E203_DECINFO_BJP_BGT_LSB:     integer:= (E203_DECINFO_BJP_BLT_MSB+1);
  constant E203_DECINFO_BJP_BGT_MSB:     integer:= (E203_DECINFO_BJP_BGT_LSB+1-1);
  subtype  E203_DECINFO_BJP_BGT is       std_logic_vector(E203_DECINFO_BJP_BGT_MSB downto E203_DECINFO_BJP_BGT_LSB);
  
  constant E203_DECINFO_BJP_BLTU_LSB:    integer:= (E203_DECINFO_BJP_BGT_MSB+1);
  constant E203_DECINFO_BJP_BLTU_MSB:    integer:= (E203_DECINFO_BJP_BLTU_LSB+1-1);
  subtype  E203_DECINFO_BJP_BLTU is      std_logic_vector(E203_DECINFO_BJP_BLTU_MSB downto E203_DECINFO_BJP_BLTU_LSB);
  
  constant E203_DECINFO_BJP_BGTU_LSB:    integer:= (E203_DECINFO_BJP_BLTU_MSB+1);
  constant E203_DECINFO_BJP_BGTU_MSB:    integer:= (E203_DECINFO_BJP_BGTU_LSB+1-1);
  subtype  E203_DECINFO_BJP_BGTU is      std_logic_vector(E203_DECINFO_BJP_BGTU_MSB downto E203_DECINFO_BJP_BGTU_LSB);
  
  constant E203_DECINFO_BJP_BXX_LSB:     integer:= (E203_DECINFO_BJP_BGTU_MSB+1);
  constant E203_DECINFO_BJP_BXX_MSB:     integer:= (E203_DECINFO_BJP_BXX_LSB+1-1);
  subtype  E203_DECINFO_BJP_BXX is       std_logic_vector(E203_DECINFO_BJP_BXX_MSB downto E203_DECINFO_BJP_BXX_LSB);
  
  constant E203_DECINFO_BJP_MRET_LSB:    integer:= (E203_DECINFO_BJP_BXX_MSB+1);
  constant E203_DECINFO_BJP_MRET_MSB:    integer:= (E203_DECINFO_BJP_MRET_LSB+1-1);
  subtype  E203_DECINFO_BJP_MRET is      std_logic_vector(E203_DECINFO_BJP_MRET_MSB downto E203_DECINFO_BJP_MRET_LSB);
  
  constant E203_DECINFO_BJP_DRET_LSB:    integer:= (E203_DECINFO_BJP_MRET_MSB+1);
  constant E203_DECINFO_BJP_DRET_MSB:    integer:= (E203_DECINFO_BJP_DRET_LSB+1-1);
  subtype  E203_DECINFO_BJP_DRET is      std_logic_vector(E203_DECINFO_BJP_DRET_MSB downto E203_DECINFO_BJP_DRET_LSB);
  
  constant E203_DECINFO_BJP_FENCE_LSB:   integer:= (E203_DECINFO_BJP_DRET_MSB+1);
  constant E203_DECINFO_BJP_FENCE_MSB:   integer:= (E203_DECINFO_BJP_FENCE_LSB+1-1);
  subtype  E203_DECINFO_BJP_FENCE is     std_logic_vector(E203_DECINFO_BJP_FENCE_MSB downto E203_DECINFO_BJP_FENCE_LSB);
  
  constant E203_DECINFO_BJP_FENCEI_LSB:  integer:= (E203_DECINFO_BJP_FENCE_MSB+1);
  constant E203_DECINFO_BJP_FENCEI_MSB:  integer:= (E203_DECINFO_BJP_FENCEI_LSB+1-1);
  subtype  E203_DECINFO_BJP_FENCEI is    std_logic_vector(E203_DECINFO_BJP_FENCEI_MSB downto E203_DECINFO_BJP_FENCEI_LSB);

  constant E203_DECINFO_BJP_WIDTH:       integer:= (E203_DECINFO_BJP_FENCEI_MSB+1);

  -- CSR group
  constant E203_DECINFO_CSR_CSRRW_LSB:   integer:= E203_DECINFO_SUBDECINFO_LSB;
  constant E203_DECINFO_CSR_CSRRW_MSB:   integer:= (E203_DECINFO_CSR_CSRRW_LSB+1-1);   
  subtype E203_DECINFO_CSR_CSRRW is      std_logic_vector(E203_DECINFO_CSR_CSRRW_MSB downto E203_DECINFO_CSR_CSRRW_LSB);

  constant E203_DECINFO_CSR_CSRRS_LSB:   integer:= (E203_DECINFO_CSR_CSRRW_MSB+1);
  constant E203_DECINFO_CSR_CSRRS_MSB:   integer:= (E203_DECINFO_CSR_CSRRS_LSB+1-1);    
  subtype E203_DECINFO_CSR_CSRRS is      std_logic_vector(E203_DECINFO_CSR_CSRRS_MSB downto E203_DECINFO_CSR_CSRRS_LSB);

  constant E203_DECINFO_CSR_CSRRC_LSB:   integer:= (E203_DECINFO_CSR_CSRRS_MSB+1);
  constant E203_DECINFO_CSR_CSRRC_MSB:   integer:= (E203_DECINFO_CSR_CSRRC_LSB+1-1);    
  subtype E203_DECINFO_CSR_CSRRC is      std_logic_vector(E203_DECINFO_CSR_CSRRC_MSB downto E203_DECINFO_CSR_CSRRC_LSB); 

  constant E203_DECINFO_CSR_RS1IMM_LSB:  integer:= (E203_DECINFO_CSR_CSRRC_MSB+1);
  constant E203_DECINFO_CSR_RS1IMM_MSB:  integer:= (E203_DECINFO_CSR_RS1IMM_LSB+1-1);    
  subtype E203_DECINFO_CSR_RS1IMM is     std_logic_vector(E203_DECINFO_CSR_RS1IMM_MSB downto E203_DECINFO_CSR_RS1IMM_LSB);

  constant E203_DECINFO_CSR_ZIMMM_LSB:   integer:= (E203_DECINFO_CSR_RS1IMM_MSB+1);
  constant E203_DECINFO_CSR_ZIMMM_MSB:   integer:= (E203_DECINFO_CSR_ZIMMM_LSB+5-1);    
  subtype E203_DECINFO_CSR_ZIMMM is      std_logic_vector(E203_DECINFO_CSR_ZIMMM_MSB downto E203_DECINFO_CSR_ZIMMM_LSB);

  constant E203_DECINFO_CSR_RS1IS0_LSB:  integer:= (E203_DECINFO_CSR_ZIMMM_MSB+1);
  constant E203_DECINFO_CSR_RS1IS0_MSB:  integer:= (E203_DECINFO_CSR_RS1IS0_LSB+1-1);    
  subtype E203_DECINFO_CSR_RS1IS0 is      std_logic_vector(E203_DECINFO_CSR_RS1IS0_MSB downto E203_DECINFO_CSR_RS1IS0_LSB);

  constant E203_DECINFO_CSR_CSRIDX_LSB:  integer:= (E203_DECINFO_CSR_RS1IS0_MSB+1);
  constant E203_DECINFO_CSR_CSRIDX_MSB:  integer:= (E203_DECINFO_CSR_CSRIDX_LSB+12-1);    
  subtype E203_DECINFO_CSR_CSRIDX is     std_logic_vector(E203_DECINFO_CSR_CSRIDX_MSB downto E203_DECINFO_CSR_CSRIDX_LSB);

  constant E203_DECINFO_CSR_WIDTH:       integer:= (E203_DECINFO_CSR_CSRIDX_MSB+1);

  -- NICE group
  constant E203_DECINFO_NICE_INSTR_LSB:  integer:= E203_DECINFO_SUBDECINFO_LSB;
  constant E203_DECINFO_NICE_INSTR_MSB:  integer:= (E203_DECINFO_NICE_INSTR_LSB+27-1);    
  subtype E203_DECINFO_NICE_INSTR is     std_logic_vector(E203_DECINFO_NICE_INSTR_MSB downto E203_DECINFO_NICE_INSTR_LSB);    

  constant E203_DECINFO_FPU_GRP_LSB:     integer:= E203_DECINFO_SUBDECINFO_LSB;
  constant E203_DECINFO_FPU_GRP_MSB:     integer:= (E203_DECINFO_FPU_GRP_LSB + E203_DECINFO_GRP_FPU_WIDTH-1);    
  subtype E203_DECINFO_FPU_GRP is        std_logic_vector(E203_DECINFO_FPU_GRP_MSB downto E203_DECINFO_FPU_GRP_LSB);    
     
  constant E203_DECINFO_FPU_RM_LSB:      integer:= (E203_DECINFO_FPU_GRP_MSB+1);
  constant E203_DECINFO_FPU_RM_MSB:      integer:= (E203_DECINFO_FPU_RM_LSB+3-1);    
  subtype E203_DECINFO_FPU_RM is         std_logic_vector(E203_DECINFO_FPU_RM_MSB downto E203_DECINFO_FPU_RM_LSB);    
     
  constant E203_DECINFO_FPU_USERM_LSB:   integer:= (E203_DECINFO_FPU_RM_MSB+1);
  constant E203_DECINFO_FPU_USERM_MSB:   integer:= (E203_DECINFO_FPU_USERM_LSB+1-1);    
  subtype E203_DECINFO_FPU_USERM is      std_logic_vector(E203_DECINFO_FPU_USERM_MSB downto E203_DECINFO_FPU_USERM_LSB);

  constant E203_DECINFO_NICE_WIDTH:      integer:= (E203_DECINFO_NICE_INSTR_MSB+1);

  -- FLSU group
  constant E203_DECINFO_FLSU_LOAD_LSB:   integer:= (E203_DECINFO_FPU_USERM_MSB+1);
  constant E203_DECINFO_FLSU_LOAD_MSB:   integer:= (E203_DECINFO_FLSU_LOAD_LSB+1-1);   
  subtype E203_DECINFO_FLSU_LOAD is      std_logic_vector(E203_DECINFO_FLSU_LOAD_MSB downto E203_DECINFO_FLSU_LOAD_LSB); 
  
  constant E203_DECINFO_FLSU_STORE_LSB:  integer:= (E203_DECINFO_FLSU_LOAD_MSB+1);
  constant E203_DECINFO_FLSU_STORE_MSB:  integer:= (E203_DECINFO_FLSU_STORE_LSB+1-1);    
  subtype E203_DECINFO_FLSU_STORE is     std_logic_vector(E203_DECINFO_FLSU_STORE_MSB downto E203_DECINFO_FLSU_STORE_LSB); 
     
  constant E203_DECINFO_FLSU_DOUBLE_LSB: integer:= (E203_DECINFO_FLSU_STORE_MSB+1);
  constant E203_DECINFO_FLSU_DOUBLE_MSB: integer:= (E203_DECINFO_FLSU_DOUBLE_LSB+1-1);    
  subtype E203_DECINFO_FLSU_DOUBLE is    std_logic_vector(E203_DECINFO_FLSU_DOUBLE_MSB downto E203_DECINFO_FLSU_DOUBLE_LSB);
     
  constant E203_DECINFO_FLSU_OP2IMM_LSB: integer:= (E203_DECINFO_FLSU_DOUBLE_MSB+1);
  constant E203_DECINFO_FLSU_OP2IMM_MSB: integer:= (E203_DECINFO_FLSU_OP2IMM_LSB+1-1);    
  subtype E203_DECINFO_FLSU_OP2IMM is    std_logic_vector(E203_DECINFO_FLSU_OP2IMM_MSB downto E203_DECINFO_FLSU_OP2IMM_LSB); 

  constant E203_DECINFO_FLSU_WIDTH:      integer:= (E203_DECINFO_FLSU_OP2IMM_MSB+1);

  -- FDIV group
  constant E203_DECINFO_FDIV_DIV_LSB:    integer:= (E203_DECINFO_FPU_USERM_MSB+1);
  constant E203_DECINFO_FDIV_DIV_MSB:    integer:= (E203_DECINFO_FDIV_DIV_LSB+1-1);    
  subtype E203_DECINFO_FDIV_DIV is       std_logic_vector(E203_DECINFO_FDIV_DIV_MSB downto E203_DECINFO_FDIV_DIV_LSB); 
  
  constant E203_DECINFO_FDIV_SQRT_LSB:   integer:= (E203_DECINFO_FDIV_DIV_MSB+1);
  constant E203_DECINFO_FDIV_SQRT_MSB:   integer:= (E203_DECINFO_FDIV_SQRT_LSB+1-1);    
  subtype E203_DECINFO_FDIV_SQRT is      std_logic_vector(E203_DECINFO_FDIV_SQRT_MSB downto E203_DECINFO_FDIV_SQRT_LSB); 
  
  constant E203_DECINFO_FDIV_DOUBLE_LSB: integer:= (E203_DECINFO_FDIV_SQRT_MSB+1);
  constant E203_DECINFO_FDIV_DOUBLE_MSB: integer:= (E203_DECINFO_FDIV_DOUBLE_LSB+1-1);    
  subtype E203_DECINFO_FDIV_DOUBLE is    std_logic_vector(E203_DECINFO_FDIV_DOUBLE_MSB downto E203_DECINFO_FDIV_DOUBLE_LSB);

  constant E203_DECINFO_FDIV_WIDTH:      integer:= (E203_DECINFO_FDIV_DOUBLE_MSB+1);
  
  -- FMIS group
  constant E203_DECINFO_FMIS_FSGNJ_LSB:  integer:= (E203_DECINFO_FPU_USERM_MSB+1);
  constant E203_DECINFO_FMIS_FSGNJ_MSB:  integer:= (E203_DECINFO_FMIS_FSGNJ_LSB+1-1);    
  subtype E203_DECINFO_FMIS_FSGNJ is    std_logic_vector(E203_DECINFO_FMIS_FSGNJ_MSB downto E203_DECINFO_FMIS_FSGNJ_LSB); 
     
  constant E203_DECINFO_FMIS_FSGNJN_LSB: integer:= (E203_DECINFO_FMIS_FSGNJ_MSB+1);
  constant E203_DECINFO_FMIS_FSGNJN_MSB: integer:= (E203_DECINFO_FMIS_FSGNJN_LSB+1-1);    
  subtype E203_DECINFO_FMIS_FSGNJN is    std_logic_vector(E203_DECINFO_FMIS_FSGNJN_MSB downto E203_DECINFO_FMIS_FSGNJN_LSB); 
     
  constant E203_DECINFO_FMIS_FSGNJX_LSB: integer:= (E203_DECINFO_FMIS_FSGNJN_MSB+1);
  constant E203_DECINFO_FMIS_FSGNJX_MSB: integer:= (E203_DECINFO_FMIS_FSGNJX_LSB+1-1);   
  subtype E203_DECINFO_FMIS_FSGNJX is    std_logic_vector(E203_DECINFO_FMIS_FSGNJX_MSB downto E203_DECINFO_FMIS_FSGNJX_LSB);
     
  constant E203_DECINFO_FMIS_FMVXW_LSB:  integer:= (E203_DECINFO_FMIS_FSGNJX_MSB+1);
  constant E203_DECINFO_FMIS_FMVXW_MSB:  integer:= (E203_DECINFO_FMIS_FMVXW_LSB+1-1);   
  subtype E203_DECINFO_FMIS_FMVXW is     std_logic_vector(E203_DECINFO_FMIS_FMVXW_MSB downto E203_DECINFO_FMIS_FMVXW_LSB);
     
  constant E203_DECINFO_FMIS_FCLASS_LSB: integer:= (E203_DECINFO_FMIS_FMVXW_MSB+1);
  constant E203_DECINFO_FMIS_FCLASS_MSB: integer:= (E203_DECINFO_FMIS_FCLASS_LSB+1-1);    
  subtype E203_DECINFO_FMIS_FCLASS is    std_logic_vector(E203_DECINFO_FMIS_FCLASS_MSB downto E203_DECINFO_FMIS_FCLASS_LSB);
     
  constant E203_DECINFO_FMIS_FMVWX_LSB:  integer:= (E203_DECINFO_FMIS_FCLASS_MSB+1);
  constant E203_DECINFO_FMIS_FMVWX_MSB:  integer:= (E203_DECINFO_FMIS_FMVWX_LSB+1-1);    
  subtype E203_DECINFO_FMIS_FMVWX is     std_logic_vector(E203_DECINFO_FMIS_FMVWX_MSB downto E203_DECINFO_FMIS_FMVWX_LSB);
    
  constant E203_DECINFO_FMIS_CVTWS_LSB:  integer:= (E203_DECINFO_FMIS_FMVWX_MSB+1);
  constant E203_DECINFO_FMIS_CVTWS_MSB:  integer:= (E203_DECINFO_FMIS_CVTWS_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTWS is     std_logic_vector(E203_DECINFO_FMIS_CVTWS_MSB downto E203_DECINFO_FMIS_CVTWS_LSB);
     
  constant E203_DECINFO_FMIS_CVTWUS_LSB: integer:= (E203_DECINFO_FMIS_CVTWS_MSB+1);
  constant E203_DECINFO_FMIS_CVTWUS_MSB: integer:= (E203_DECINFO_FMIS_CVTWUS_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTWUS is    std_logic_vector(E203_DECINFO_FMIS_CVTWUS_MSB downto E203_DECINFO_FMIS_CVTWUS_LSB);
     
  constant E203_DECINFO_FMIS_CVTSW_LSB:  integer:= (E203_DECINFO_FMIS_CVTWUS_MSB+1);
  constant E203_DECINFO_FMIS_CVTSW_MSB:  integer:= (E203_DECINFO_FMIS_CVTSW_LSB+1-1);   
  subtype E203_DECINFO_FMIS_CVTSW is     std_logic_vector(E203_DECINFO_FMIS_CVTSW_MSB downto E203_DECINFO_FMIS_CVTSW_LSB);
     
  constant E203_DECINFO_FMIS_CVTSWU_LSB: integer:= (E203_DECINFO_FMIS_CVTSW_MSB+1);
  constant E203_DECINFO_FMIS_CVTSWU_MSB: integer:= (E203_DECINFO_FMIS_CVTSWU_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTSWU is    std_logic_vector(E203_DECINFO_FMIS_CVTSWU_MSB downto E203_DECINFO_FMIS_CVTSWU_LSB);
     
  constant E203_DECINFO_FMIS_CVTSD_LSB:  integer:= (E203_DECINFO_FMIS_CVTSWU_MSB+1);
  constant E203_DECINFO_FMIS_CVTSD_MSB:  integer:= (E203_DECINFO_FMIS_CVTSD_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTSD is     std_logic_vector(E203_DECINFO_FMIS_CVTSD_MSB downto E203_DECINFO_FMIS_CVTSD_LSB);
     
  constant E203_DECINFO_FMIS_CVTDS_LSB:  integer:= (E203_DECINFO_FMIS_CVTSD_MSB+1);
  constant E203_DECINFO_FMIS_CVTDS_MSB:  integer:= (E203_DECINFO_FMIS_CVTDS_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTDS is     std_logic_vector(E203_DECINFO_FMIS_CVTDS_MSB downto E203_DECINFO_FMIS_CVTDS_LSB);
     
  constant E203_DECINFO_FMIS_CVTWD_LSB:  integer:= (E203_DECINFO_FMIS_CVTDS_MSB+1);
  constant E203_DECINFO_FMIS_CVTWD_MSB:  integer:= (E203_DECINFO_FMIS_CVTWD_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTWD is     std_logic_vector(E203_DECINFO_FMIS_CVTWD_MSB downto E203_DECINFO_FMIS_CVTWD_LSB);
     
  constant E203_DECINFO_FMIS_CVTWUD_LSB: integer:= (E203_DECINFO_FMIS_CVTWD_MSB+1);
  constant E203_DECINFO_FMIS_CVTWUD_MSB: integer:= (E203_DECINFO_FMIS_CVTWUD_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTWUD is    std_logic_vector(E203_DECINFO_FMIS_CVTWUD_MSB downto E203_DECINFO_FMIS_CVTWUD_LSB);
     
  constant E203_DECINFO_FMIS_CVTDW_LSB:  integer:= (E203_DECINFO_FMIS_CVTWUD_MSB+1);
  constant E203_DECINFO_FMIS_CVTDW_MSB:  integer:= (E203_DECINFO_FMIS_CVTDW_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTDW is     std_logic_vector(E203_DECINFO_FMIS_CVTDW_MSB downto E203_DECINFO_FMIS_CVTDW_LSB);
     
  constant E203_DECINFO_FMIS_CVTDWU_LSB: integer:= (E203_DECINFO_FMIS_CVTDW_MSB+1);
  constant E203_DECINFO_FMIS_CVTDWU_MSB: integer:= (E203_DECINFO_FMIS_CVTDWU_LSB+1-1);    
  subtype E203_DECINFO_FMIS_CVTDWU is    std_logic_vector(E203_DECINFO_FMIS_CVTDWU_MSB downto E203_DECINFO_FMIS_CVTDWU_LSB);
     
  constant E203_DECINFO_FMIS_DOUBLE_LSB: integer:= (E203_DECINFO_FMIS_CVTDWU_MSB+1);
  constant E203_DECINFO_FMIS_DOUBLE_MSB: integer:= (E203_DECINFO_FMIS_DOUBLE_LSB+1-1);    
  subtype E203_DECINFO_FMIS_DOUBLE is    std_logic_vector(E203_DECINFO_FMIS_DOUBLE_MSB downto E203_DECINFO_FMIS_DOUBLE_LSB);

  constant E203_DECINFO_FMIS_WIDTH:      integer:= (E203_DECINFO_FMIS_DOUBLE_MSB+1);

   -- FMAC group
  constant E203_DECINFO_FMAC_FMADD_LSB:  integer:= (E203_DECINFO_FPU_USERM_MSB+1);
  constant E203_DECINFO_FMAC_FMADD_MSB:  integer:= (E203_DECINFO_FMAC_FMADD_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FMADD is     std_logic_vector(E203_DECINFO_FMAC_FMADD_MSB downto E203_DECINFO_FMAC_FMADD_LSB); 
  
  constant E203_DECINFO_FMAC_FMSUB_LSB:  integer:= (E203_DECINFO_FMAC_FMADD_MSB+1);
  constant E203_DECINFO_FMAC_FMSUB_MSB:  integer:= (E203_DECINFO_FMAC_FMSUB_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FMSUB is     std_logic_vector(E203_DECINFO_FMAC_FMSUB_MSB downto E203_DECINFO_FMAC_FMSUB_LSB); 
     
  constant E203_DECINFO_FMAC_FNMSUB_LSB: integer:= (E203_DECINFO_FMAC_FMSUB_MSB+1);
  constant E203_DECINFO_FMAC_FNMSUB_MSB: integer:= (E203_DECINFO_FMAC_FNMSUB_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FNMSUB is    std_logic_vector(E203_DECINFO_FMAC_FNMSUB_MSB downto E203_DECINFO_FMAC_FNMSUB_LSB);
     
  constant E203_DECINFO_FMAC_FNMADD_LSB: integer:= (E203_DECINFO_FMAC_FNMSUB_MSB+1);
  constant E203_DECINFO_FMAC_FNMADD_MSB: integer:= (E203_DECINFO_FMAC_FNMADD_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FNMADD is    std_logic_vector(E203_DECINFO_FMAC_FNMADD_MSB downto E203_DECINFO_FMAC_FNMADD_LSB);
     
  constant E203_DECINFO_FMAC_FADD_LSB:   integer:= (E203_DECINFO_FMAC_FNMADD_MSB+1);
  constant E203_DECINFO_FMAC_FADD_MSB:   integer:= (E203_DECINFO_FMAC_FADD_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FADD is      std_logic_vector(E203_DECINFO_FMAC_FADD_MSB downto E203_DECINFO_FMAC_FADD_LSB);
     
  constant E203_DECINFO_FMAC_FSUB_LSB:   integer:= (E203_DECINFO_FMAC_FADD_MSB+1);
  constant E203_DECINFO_FMAC_FSUB_MSB:   integer:= (E203_DECINFO_FMAC_FSUB_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FSUB is      std_logic_vector(E203_DECINFO_FMAC_FSUB_MSB downto E203_DECINFO_FMAC_FSUB_LSB);
     
  constant E203_DECINFO_FMAC_FMUL_LSB:   integer:= (E203_DECINFO_FMAC_FSUB_MSB+1);
  constant E203_DECINFO_FMAC_FMUL_MSB:   integer:= (E203_DECINFO_FMAC_FMUL_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FMUL is      std_logic_vector(E203_DECINFO_FMAC_FMUL_MSB downto E203_DECINFO_FMAC_FMUL_LSB);
     
  constant E203_DECINFO_FMAC_FMIN_LSB:   integer:= (E203_DECINFO_FMAC_FMUL_MSB+1);
  constant E203_DECINFO_FMAC_FMIN_MSB:   integer:= (E203_DECINFO_FMAC_FMIN_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FMIN is      std_logic_vector(E203_DECINFO_FMAC_FMIN_MSB downto E203_DECINFO_FMAC_FMIN_LSB);
     
  constant E203_DECINFO_FMAC_FMAX_LSB:   integer:= (E203_DECINFO_FMAC_FMIN_MSB+1);
  constant E203_DECINFO_FMAC_FMAX_MSB:   integer:= (E203_DECINFO_FMAC_FMAX_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FMAX is      std_logic_vector(E203_DECINFO_FMAC_FMAX_MSB downto E203_DECINFO_FMAC_FMAX_LSB);
     
  constant E203_DECINFO_FMAC_FEQ_LSB:    integer:= (E203_DECINFO_FMAC_FMAX_MSB+1);
  constant E203_DECINFO_FMAC_FEQ_MSB:    integer:= (E203_DECINFO_FMAC_FEQ_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FEQ is       std_logic_vector(E203_DECINFO_FMAC_FEQ_MSB downto E203_DECINFO_FMAC_FEQ_LSB);
     
  constant E203_DECINFO_FMAC_FLT_LSB:    integer:= (E203_DECINFO_FMAC_FEQ_MSB+1);
  constant E203_DECINFO_FMAC_FLT_MSB:    integer:= (E203_DECINFO_FMAC_FLT_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FLT is       std_logic_vector(E203_DECINFO_FMAC_FLT_MSB downto E203_DECINFO_FMAC_FLT_LSB);
     
  constant E203_DECINFO_FMAC_FLE_LSB:    integer:= (E203_DECINFO_FMAC_FLT_MSB+1);
  constant E203_DECINFO_FMAC_FLE_MSB:    integer:= (E203_DECINFO_FMAC_FLE_LSB+1-1);    
  subtype E203_DECINFO_FMAC_FLE is       std_logic_vector(E203_DECINFO_FMAC_FLE_MSB downto E203_DECINFO_FMAC_FLE_LSB);
     
  constant E203_DECINFO_FMAC_DOUBLE_LSB: integer:= (E203_DECINFO_FMAC_FLE_MSB+1);
  constant E203_DECINFO_FMAC_DOUBLE_MSB: integer:= (E203_DECINFO_FMAC_DOUBLE_LSB+1-1);    
  subtype E203_DECINFO_FMAC_DOUBLE is    std_logic_vector(E203_DECINFO_FMAC_DOUBLE_MSB downto E203_DECINFO_FMAC_DOUBLE_LSB);

  constant E203_DECINFO_FMAC_WIDTH:      integer:= (E203_DECINFO_FMAC_DOUBLE_MSB+1);

  -- MULDIV group
  constant E203_DECINFO_MULDIV_MUL_LSB:  integer:= E203_DECINFO_SUBDECINFO_LSB;
  constant E203_DECINFO_MULDIV_MUL_MSB:  integer:= (E203_DECINFO_MULDIV_MUL_LSB+1-1);    
  subtype E203_DECINFO_MULDIV_MUL is     std_logic_vector(E203_DECINFO_MULDIV_MUL_MSB downto E203_DECINFO_MULDIV_MUL_LSB);    
     
  constant E203_DECINFO_MULDIV_MULH_LSB: integer:= (E203_DECINFO_MULDIV_MUL_MSB+1);
  constant E203_DECINFO_MULDIV_MULH_MSB: integer:= (E203_DECINFO_MULDIV_MULH_LSB+1-1);    
  subtype E203_DECINFO_MULDIV_MULH is    std_logic_vector(E203_DECINFO_MULDIV_MULH_MSB downto E203_DECINFO_MULDIV_MULH_LSB); 
     
  constant E203_DECINFO_MULDIV_MULHSU_LSB: integer:= (E203_DECINFO_MULDIV_MULH_MSB+1);
  constant E203_DECINFO_MULDIV_MULHSU_MSB: integer:= (E203_DECINFO_MULDIV_MULHSU_LSB+1-1);    
  subtype E203_DECINFO_MULDIV_MULHSU is    std_logic_vector(E203_DECINFO_MULDIV_MULHSU_MSB downto E203_DECINFO_MULDIV_MULHSU_LSB); 
     
  constant E203_DECINFO_MULDIV_MULHU_LSB:integer:= (E203_DECINFO_MULDIV_MULHSU_MSB+1);
  constant E203_DECINFO_MULDIV_MULHU_MSB:integer:= (E203_DECINFO_MULDIV_MULHU_LSB+1-1);    
  subtype E203_DECINFO_MULDIV_MULHU is   std_logic_vector(E203_DECINFO_MULDIV_MULHU_MSB downto E203_DECINFO_MULDIV_MULHU_LSB);
     
  constant E203_DECINFO_MULDIV_DIV_LSB:  integer:= (E203_DECINFO_MULDIV_MULHU_MSB+1);
  constant E203_DECINFO_MULDIV_DIV_MSB:  integer:= (E203_DECINFO_MULDIV_DIV_LSB+1-1);    
  subtype E203_DECINFO_MULDIV_DIV is     std_logic_vector(E203_DECINFO_MULDIV_DIV_MSB downto E203_DECINFO_MULDIV_DIV_LSB); 
     
  constant E203_DECINFO_MULDIV_DIVU_LSB: integer:= (E203_DECINFO_MULDIV_DIV_MSB+1);
  constant E203_DECINFO_MULDIV_DIVU_MSB: integer:= (E203_DECINFO_MULDIV_DIVU_LSB+1-1);    
  subtype E203_DECINFO_MULDIV_DIVU is    std_logic_vector(E203_DECINFO_MULDIV_DIVU_MSB downto E203_DECINFO_MULDIV_DIVU_LSB);
     
  constant E203_DECINFO_MULDIV_REM_LSB:  integer:= (E203_DECINFO_MULDIV_DIVU_MSB+1);
  constant E203_DECINFO_MULDIV_REM_MSB:  integer:= (E203_DECINFO_MULDIV_REM_LSB+1-1);    
  subtype E203_DECINFO_MULDIV_REM is     std_logic_vector(E203_DECINFO_MULDIV_REM_MSB downto E203_DECINFO_MULDIV_REM_LSB);    
     
  constant E203_DECINFO_MULDIV_REMU_LSB: integer:= (E203_DECINFO_MULDIV_REM_MSB+1);
  constant E203_DECINFO_MULDIV_REMU_MSB: integer:= (E203_DECINFO_MULDIV_REMU_LSB+1-1);    
  subtype E203_DECINFO_MULDIV_REMU is    std_logic_vector(E203_DECINFO_MULDIV_REMU_MSB downto E203_DECINFO_MULDIV_REMU_LSB); 
     
  constant E203_DECINFO_MULDIV_B2B_LSB:  integer:= (E203_DECINFO_MULDIV_REMU_MSB+1);
  constant E203_DECINFO_MULDIV_B2B_MSB:  integer:= (E203_DECINFO_MULDIV_B2B_LSB+1-1);   
  subtype E203_DECINFO_MULDIV_B2B is     std_logic_vector(E203_DECINFO_MULDIV_B2B_MSB downto E203_DECINFO_MULDIV_B2B_LSB); 

  constant E203_DECINFO_MULDIV_WIDTH:    integer:= (E203_DECINFO_MULDIV_B2B_MSB+1);
  
  -- Choose the longest group as the final DEC info width
  constant E203_DECINFO_WIDTH:           integer:= (E203_DECINFO_NICE_WIDTH+1);

-------------------------------------------------------------
-- LSU relevant macro
-- Currently is OITF_DEPTH, In the future, if the ROCC
-- support multiple oustanding
-- we can enlarge this number to 2 or 4
-- Although we defined the OITF depth as 2, but for LSU, we still only allow 1 oustanding for LSU
  constant E203_LSU_OUTS_NUM:            integer:= 1;

-------------------------------------------------------------
-- BIU relevant macro
-- Currently is 1, In the future, if the DCache
-- support hit-under-miss (out of order return), then
-- we can enlarge this number to 2 or 4
  constant E203_BIU_OUTS_NUM:            integer:= E203_LSU_OUTS_NUM;
`if E203_LSU_OUTS_NUM_IS_1 = "TRUE" then
  constant E203_BIU_OUTS_CNT_W:          integer:= 1;
`end if


-- To cut the potential comb loop and critical path between LSU and IFU
--   and also core and external system, we always cut the ready by BIU Stage
--   You may argue: Always cut ready may potentially hurt throughput when the DP is just 1
--   but it is actually a Pseudo proposition because:
--     * If the BIU oustanding is just 1 in low end core, then we set DP as 1, and there is no 
--         throughput issue becuase just only 1 oustanding. Even for the PPI or FIO port ideally
--         if it is 0 cycle response and throughput can be bck-to-back ideally, but we just
--         sacrafy sacrifice this performance lost, since this is a low end core
--     * If the BIU oustanding is more than 1 in middle or high end core, then we
--         set DP as 2 as ping-pong buffer, and then throughput is back-to-back
--
  constant E203_BIU_CMD_CUT_READY:       integer:= 1;
  constant E203_BIU_RSP_CUT_READY:       integer:= 1;

-- If oustanding is just 1, then we just need 1 entry
-- If oustanding is more than 1, then we need ping-pong buffer to enhance throughput
--   You may argue: why not allow 0 depth to save areas, well this is to cut the potential
--   comb loop and critical path between LSU and IFU and external bus
`if E203_BIU_OUTS_NUM_IS_1 = "TRUE" then
  constant E203_BIU_CMD_DP:              integer:= 1;
  constant E203_BIU_RSP_DP_RAW:          integer:= 1;
`else
  constant E203_BIU_CMD_DP:              integer:= 2;
  constant E203_BIU_RSP_DP_RAW:          integer:= 2;
`end if

`if E203_TIMING_BOOST = "TRUE" then
  constant E203_BIU_RSP_DP:              integer:= E203_BIU_RSP_DP_RAW;
`else
  constant E203_BIU_RSP_DP:              integer:= 0;
`end if

end e203_defines_pkg;