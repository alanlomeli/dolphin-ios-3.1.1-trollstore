// Copyright 2018 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#include "Core/DSP/Interpreter/DSPIntTables.h"

#include <array>

#include "Common/CommonTypes.h"
#include "Core/DSP/DSPTables.h"
#include "Core/DSP/Interpreter/DSPIntExtOps.h"
#include "Core/DSP/Interpreter/DSPInterpreter.h"

namespace DSP::Interpreter
{
struct InterpreterOpInfo
{
  u16 opcode;
  u16 opcode_mask;
  InterpreterFunction function;
};

// clang-format off
constexpr std::array<InterpreterOpInfo, 124> s_opcodes
{{
  {0x0000, 0xfffc, nop},

  {0x0004, 0xfffc, dar},
  {0x0008, 0xfffc, iar},
  {0x000c, 0xfffc, subarn},
  {0x0010, 0xfff0, addarn},

  {0x0021, 0xffff, halt},

  {0x02d0, 0xfff0, ret},

  {0x02ff, 0xffff, rti},

  {0x02b0, 0xfff0, call},

  {0x0270, 0xfff0, ifcc},

  {0x0290, 0xfff0, jcc},

  {0x1700, 0xff10, jmprcc},

  {0x1710, 0xff10, callr},

  {0x1200, 0xff00, sbclr},
  {0x1300, 0xff00, sbset},

  {0x1400, 0xfec0, lsl},
  {0x1440, 0xfec0, lsr},
  {0x1480, 0xfec0, asl},
  {0x14c0, 0xfec0, asr},

  // these two were discovered by ector
  {0x02ca, 0xffff, lsrn},
  {0x02cb, 0xffff, asrn},

  {0x0080, 0xffe0, lri},
  {0x00c0, 0xffe0, lr},
  {0x00e0, 0xffe0, sr},

  {0x1c00, 0xfc00, mrr},

  {0x1600, 0xff00, si},

  {0x0400, 0xfe00, addis},
  {0x0600, 0xfe00, cmpis},
  {0x0800, 0xf800, lris},

  {0x0200, 0xfeff, addi},
  {0x0220, 0xfeff, xori},
  {0x0240, 0xfeff, andi},
  {0x0260, 0xfeff, ori},
  {0x0280, 0xfeff, cmpi},

  {0x02a0, 0xfeff, andf},
  {0x02c0, 0xfeff, andcf},

  {0x0210, 0xfefc, ilrr},
  {0x0214, 0xfefc, ilrrd},
  {0x0218, 0xfefc, ilrri},
  {0x021c, 0xfefc, ilrrn},

  // LOOPS
  {0x0040, 0xffe0, loop},
  {0x0060, 0xffe0, bloop},
  {0x1000, 0xff00, loopi},
  {0x1100, 0xff00, bloopi},

  // load and store value pointed by indexing reg and increment; LRR/SRR variants
  {0x1800, 0xff80, lrr},
  {0x1880, 0xff80, lrrd},
  {0x1900, 0xff80, lrri},
  {0x1980, 0xff80, lrrn},

  {0x1a00, 0xff80, srr},
  {0x1a80, 0xff80, srrd},
  {0x1b00, 0xff80, srri},
  {0x1b80, 0xff80, srrn},

  // 2
  {0x2000, 0xf800, lrs},
  {0x2800, 0xf800, srs},

  // opcodes that can be extended

  // 3 - main opcode defined by 9 bits, extension defined by last 7 bits!!
  {0x3000, 0xfc80, xorr},
  {0x3400, 0xfc80, andr},
  {0x3800, 0xfc80, orr},
  {0x3c00, 0xfe80, andc},
  {0x3e00, 0xfe80, orc},
  {0x3080, 0xfe80, xorc},
  {0x3280, 0xfe80, notc},
  {0x3480, 0xfc80, lsrnrx},
  {0x3880, 0xfc80, asrnrx},
  {0x3c80, 0xfe80, lsrnr},
  {0x3e80, 0xfe80, asrnr},

  // 4
  {0x4000, 0xf800, addr},
  {0x4800, 0xfc00, addax},
  {0x4c00, 0xfe00, add},
  {0x4e00, 0xfe00, addp},

  // 5
  {0x5000, 0xf800, subr},
  {0x5800, 0xfc00, subax},
  {0x5c00, 0xfe00, sub},
  {0x5e00, 0xfe00, subp},

  // 6
  {0x6000, 0xf800, movr},
  {0x6800, 0xfc00, movax},
  {0x6c00, 0xfe00, mov},
  {0x6e00, 0xfe00, movp},

  // 7
  {0x7000, 0xfc00, addaxl},
  {0x7400, 0xfe00, incm},
  {0x7600, 0xfe00, inc},
  {0x7800, 0xfe00, decm},
  {0x7a00, 0xfe00, dec},
  {0x7c00, 0xfe00, neg},
  {0x7e00, 0xfe00, movnp},

  // 8
  {0x8000, 0xf700, nx},
  {0x8100, 0xf700, clr},
  {0x8200, 0xff00, cmp},
  {0x8300, 0xff00, mulaxh},
  {0x8400, 0xff00, clrp},
  {0x8500, 0xff00, tstprod},
  {0x8600, 0xfe00, tstaxh},
  {0x8a00, 0xff00, srbith},
  {0x8b00, 0xff00, srbith},
  {0x8c00, 0xff00, srbith},
  {0x8d00, 0xff00, srbith},
  {0x8e00, 0xff00, srbith},
  {0x8f00, 0xff00, srbith},

  // 9
  {0x9000, 0xf700, mul},
  {0x9100, 0xf700, asr16},
  {0x9200, 0xf600, mulmvz},
  {0x9400, 0xf600, mulac},
  {0x9600, 0xf600, mulmv},

  // A-B
  {0xa000, 0xe700, mulx},
  {0xa100, 0xf700, abs},
  {0xa200, 0xe600, mulxmvz},
  {0xa400, 0xe600, mulxac},
  {0xa600, 0xe600, mulxmv},
  {0xb100, 0xf700, tst},

  // C-D
  {0xc000, 0xe700, mulc},
  {0xc100, 0xe700, cmpar},
  {0xc200, 0xe600, mulcmvz},
  {0xc400, 0xe600, mulcac},
  {0xc600, 0xe600, mulcmv},

  // E
  {0xe000, 0xfc00, maddx},
  {0xe400, 0xfc00, msubx},
  {0xe800, 0xfc00, maddc},
  {0xec00, 0xfc00, msubc},

  // F
  {0xf000, 0xfe00, lsl16},
  {0xf200, 0xfe00, madd},
  {0xf400, 0xfe00, lsr16},
  {0xf600, 0xfe00, msub},
  {0xf800, 0xfc00, addpaxz},
  {0xfc00, 0xfe00, clrl},
  {0xfe00, 0xfe00, movpz},
}};

constexpr std::array<InterpreterOpInfo, 25> s_opcodes_ext
{{
  {0x0000, 0x00fc, Ext::nop},

  {0x0004, 0x00fc, Ext::dr},
  {0x0008, 0x00fc, Ext::ir},
  {0x000c, 0x00fc, Ext::nr},
  {0x0010, 0x00f0, Ext::mv},

  {0x0020, 0x00e4, Ext::s},
  {0x0024, 0x00e4, Ext::sn},

  {0x0040, 0x00c4, Ext::l},
  {0x0044, 0x00c4, Ext::ln},

  {0x0080, 0x00ce, Ext::ls},
  {0x0082, 0x00ce, Ext::sl},
  {0x0084, 0x00ce, Ext::lsn},
  {0x0086, 0x00ce, Ext::sln},
  {0x0088, 0x00ce, Ext::lsm},
  {0x008a, 0x00ce, Ext::slm},
  {0x008c, 0x00ce, Ext::lsnm},
  {0x008e, 0x00ce, Ext::slnm},

  {0x00c3, 0x00cf, Ext::ldax},
  {0x00c7, 0x00cf, Ext::ldaxn},
  {0x00cb, 0x00cf, Ext::ldaxm},
  {0x00cf, 0x00cf, Ext::ldaxnm},

  {0x00c0, 0x00cc, Ext::ld},
  {0x00c4, 0x00cc, Ext::ldn},
  {0x00c8, 0x00cc, Ext::ldm},
  {0x00cc, 0x00cc, Ext::ldnm},
}};
// clang-format on

namespace
{
std::array<InterpreterFunction, 65536> s_op_table;
std::array<InterpreterFunction, 256> s_ext_op_table;
bool s_tables_initialized = false;
}  // Anonymous namespace

InterpreterFunction GetOp(UDSPInstruction inst)
{
  return s_op_table[inst];
}

InterpreterFunction GetExtOp(UDSPInstruction inst)
{
  const bool has_seven_bit_extension = (inst >> 12) == 0x3;

  if (has_seven_bit_extension)
    return s_ext_op_table[inst & 0x7F];

  return s_ext_op_table[inst & 0xFF];
}

void InitInstructionTables()
{
  if (s_tables_initialized)
    return;

  // ext op table
  for (size_t i = 0; i < s_ext_op_table.size(); i++)
  {
    s_ext_op_table[i] = nop;

    const auto iter = FindByOpcode(static_cast<UDSPInstruction>(i), s_opcodes_ext);
    if (iter == s_opcodes_ext.cend())
      continue;

    s_ext_op_table[i] = iter->function;
  }

  // op table
  for (size_t i = 0; i < s_op_table.size(); i++)
  {
    s_op_table[i] = nop;

    const auto iter = FindByOpcode(static_cast<UDSPInstruction>(i), s_opcodes);
    if (iter == s_opcodes.cend())
      continue;

    s_op_table[i] = iter->function;
  }

  s_tables_initialized = true;
}
}  // namespace DSP::Interpreter
