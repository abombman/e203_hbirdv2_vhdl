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
--  The mini-decode module to decode the instruction in IFU 
-- 
-- ====================================================================                                                                        
                                                                         
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.config_pkg.all;
use work.e203_defines_pkg.all;

entity e203_ifu_minidec is 
  port(

      --------------------------------------------------------------
      -- The IR stage to Decoder
      --------------------------------------------------------------
      instr:            in std_logic_vector(E203_INSTR_SIZE-1 downto 0);
  
      --------------------------------------------------------------
      -- The Decoded Info-Bus
      --------------------------------------------------------------
      dec_rs1en:       out std_logic;
      dec_rs2en:       out std_logic;
      dec_rs1idx:      out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0); 
      dec_rs2idx:      out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
      
      dec_mulhsu:      out std_logic;
      dec_mul:         out std_logic;
      dec_div:         out std_logic;
      dec_rem:         out std_logic;
      dec_divu:        out std_logic;
      dec_remu:        out std_logic;

      dec_rv32:        out std_logic;
      dec_bjp:         out std_logic;
      dec_jal:         out std_logic;
      dec_jalr:        out std_logic;
      dec_bxx:         out std_logic;
      dec_jalr_rs1idx: out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0); 
      dec_bjp_imm:     out std_logic_vector(E203_XLEN-1 downto 0)

  );
end e203_ifu_minidec;

architecture impl of e203_ifu_minidec is 
  component e203_exu_decode is 
    port(
        i_instr:             in  std_logic_vector(E203_INSTR_SIZE-1 downto 0);
        i_pc:                in  std_logic_vector(E203_PC_SIZE-1 downto 0);
        i_prdt_taken:        in  std_logic;
        i_muldiv_b2b:        in  std_logic;
        i_misalgn:           in  std_logic;
        i_buserr:            in  std_logic;
        dbg_mode:            in  std_logic;
       
        dec_misalgn:         out std_logic;
        dec_buserr:          out std_logic;
        dec_ilegl:           out std_logic;
        dec_rs1x0:           out std_logic;
        dec_rs2x0:           out std_logic;
        dec_rs1en:           out std_logic;
        dec_rs2en:           out std_logic;
        dec_rdwen:           out std_logic;
               
        dec_rs1idx:          out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
        dec_rs2idx:          out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
        dec_rdidx:           out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
        dec_info:            out std_logic_vector(E203_DECINFO_WIDTH-1 downto 0);
        dec_imm:             out std_logic_vector(E203_XLEN-1 downto 0);
        dec_pc:              out std_logic_vector(E203_PC_SIZE-1 downto 0);

        --`ifdef E203_HAS_NICE//{
        dec_nice:            out std_logic;
        nice_xs_off:         in  std_logic;
        nice_cmt_off_ilgl_o: out std_logic;
        --`endif//}

        dec_mulhsu:          out std_logic;
        dec_mul:             out std_logic;
        dec_div:             out std_logic;
        dec_rem:             out std_logic;
        dec_divu:            out std_logic;
        dec_remu:            out std_logic;     
        dec_rv32:            out std_logic;
        dec_bjp:             out std_logic;
        dec_jal:             out std_logic;
        dec_jalr:            out std_logic;
        dec_bxx:             out std_logic;    
        dec_jalr_rs1idx:     out std_logic_vector(E203_RFIDX_WIDTH-1 downto 0);
        dec_bjp_imm:         out std_logic_vector(E203_XLEN-1 downto 0)
    );
  end component;
begin 
  u_e203_exu_decode: component e203_exu_decode port map (
                                                          i_instr            => instr,
                                                          i_pc               => (E203_PC_SIZE-1 downto 0 => '0'),
                                                          i_prdt_taken       => '0', 
                                                          i_muldiv_b2b       => '0', 
 
                                                          i_misalgn          => '0',
                                                          i_buserr           => '0',
 
                                                          dbg_mode           => '0',
 
                                                          dec_misalgn        => OPEN,
                                                          dec_buserr         => OPEN,
                                                          dec_ilegl          => OPEN,
 
                                                          dec_rs1x0          => OPEN,
                                                          dec_rs2x0          => OPEN,
                                                          dec_rs1en          => dec_rs1en,
                                                          dec_rs2en          => dec_rs2en,
                                                          dec_rdwen          => OPEN,
                                                          dec_rs1idx         => dec_rs1idx,
                                                          dec_rs2idx         => dec_rs2idx,
                                                          dec_rdidx          => OPEN,
                                                          dec_info           => OPEN,  
                                                          dec_imm            => OPEN,
                                                          dec_pc             => OPEN,
                                                       
                                                       `if E203_HAS_NICE = "TRUE" then
                                                          dec_nice           => OPEN,
                                                          nice_xs_off        => '0',  
                                                          nice_cmt_off_ilgl_o=> OPEN,
                                                       `end if

                                                          dec_mulhsu         => dec_mulhsu,
                                                          dec_mul            => dec_mul   ,
                                                          dec_div            => dec_div   ,
                                                          dec_rem            => dec_rem   ,
                                                          dec_divu           => dec_divu  ,
                                                          dec_remu           => dec_remu  ,
         
                                                          dec_rv32           => dec_rv32,
                                                          dec_bjp            => dec_bjp ,
                                                          dec_jal            => dec_jal ,
                                                          dec_jalr           => dec_jalr,
                                                          dec_bxx            => dec_bxx ,

                                                          dec_jalr_rs1idx    => dec_jalr_rs1idx,
                                                          dec_bjp_imm        => dec_bjp_imm      
                                                         );
end impl;
