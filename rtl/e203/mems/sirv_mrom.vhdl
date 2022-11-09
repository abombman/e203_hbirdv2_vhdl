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

--=====================================================================
--
-- Description:
--  The module is the mask ROM
--
-- ====================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sirv_mrom is
  generic( AW: integer:= 12;
  	       DW: integer:= 32;
  	       DP: integer:= 1024
  );
  port( rom_addr:  in std_logic_vector(AW-1 downto 0);
  	    rom_dout: out std_logic_vector(DW-1 downto 0)
  );
end sirv_mrom;

architecture impl of sirv_mrom is 
  type mask_rom_t is array(0 to DP-1) of std_logic_vector(Dw-1 downto 0);
  signal mask_rom: mask_rom_t;
begin
  rom_dout <= mask_rom(to_integer(unsigned(rom_addr)));
  
  -- Just jump to the ITCM base address
  jump_to_ram_gen: if (TRUE) generate
    rom_gen: for i in 0 to DP-1 generate
      rom0_gen: if i = 0 generate
        mask_rom(i) <= X"7f_ff_f2_97"; -- auipc   t0, 0x7ffff  
      end generate;
      rom1_gen: if i = 1 generate
        mask_rom(i) <= X"00_02_80_67"; -- jr      t0
      end generate;
      rom_non01_gen: if i > 1 generate
        mask_rom(i) <= X"00_00_00_00";
      end generate;
    end generate; 
  end generate;
  
  -- This is the freedom bootrom version, put here have a try
  --  The actual executed trace is as below:
  --  CYC: 8615 PC:00001000 IR:0100006f DASM: j       pc + 0x10         
  --  CYC: 8618 PC:00001010 IR:204002b7 DASM: lui     t0, 0x20400       xpr[5] = 0x20400000
  --  CYC: 8621 PC:00001014 IR:00028067 DASM: jr      t0                

  -- The 20400000 is the flash address
  -- MEMORY
  -- {
  --   flash (rxai!w) : ORIGIN = 0x20400000, LENGTH = 512M
  --   ram (wxa!ri) : ORIGIN = 0x80000000, LENGTH = 16K
  -- }
  jump_to_non_ram_gen: if (FALSE) generate
    rom_gen: for i in 0 to DP-1 generate
      rom0_gen: if i = 0 generate
        mask_rom(i) <= X"01_00_00_6f"; 
      end generate;
      rom1_gen: if i = 1 generate
        mask_rom(i) <= X"00_00_00_13"; 
      end generate;
      rom2_gen: if i = 2 generate
        mask_rom(i) <= X"00_00_00_13"; 
      end generate;
      rom3_gen: if i = 3 generate
        mask_rom(i) <= X"00_00_66_61"; 
      end generate;
      rom4_gen: if i = 4 generate
        mask_rom(i) <= X"20_40_02_b7"; 
      end generate;
      rom5_gen: if i = 5 generate
        mask_rom(i) <= X"00_02_80_67"; 
      end generate;
      rom_other_gen: if i > 5 generate
        mask_rom(i) <= X"00_00_00_00";
      end generate;
    end generate;
  end generate;

  -- In the https://github.com/sifive/freedom/blob/master/bootrom/xip/xip.S
  --  ASM code is as below:
  --  //  // See LICENSE for license details.
  --// Execute in place
  --// Jump directly to XIP_TARGET_ADDR
  --
  --  .text
  --  .option norvc
  --  .globl _start
  --_start:
  --  j 1f
  --  nop
  --  nop
  --#ifdef CONFIG_STRING
  --  .word cfg_string
  --#else
  --  .word 0  // Filled in by GenerateBootROM in Chisel
  --#endif
  --
  --1:
  --  li t0, XIP_TARGET_ADDR
  --  jr t0
  --
  --  .section .rodata
  --#ifdef CONFIG_STRING
  --cfg_string:
  --  .incbin CONFIG_STRING
  --#endif
end impl;