import tables

let
  ## https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf page 102
  AltNamesTbl* = {
    2:["SDA1", "SA3", "<reserved>", "☠", "☠", "☠" ], # 2
    3:["SCL1", "SA2", "<reserved>", "☠", "☠", "☠" ], # 3
    4:["1WIRE/GPCLK0", "SA1", "<reserved>", "☠", "☠", "ARM_TDI" ], # 4
    14:["TXD0", "SD6", "<reserved>", "☠", "☠", "TXD1" ], # 14
    15:["RXD0", "SD7", "<reserved>", "☠", "☠", "RXD1" ], # 15
    17:["<reserved>", "SD9", "<reserved>", "RTS0", "SPI1_CE1_N", "RTS1"], # 17
    18:["PCM_CLK", "SD10", "<reserved>", "BSCSLSDA / MOSI", "SPI1_CE0_N", "PWM0"], # 18
    27:["<reserved>", "<reserved>", "<reserved>", "SD1_DAT3", "ARM_TMS", "☠" ], # 27
    22:["<reserved>", "SD14", "<reserved>", "SD1_CLK", "ARM_TRST", "☠" ], # 22
    23:["<reserved>", "SD15", "<reserved>", "SD1_CMD", "ARM_RTCK", "☠" ], # 23
    24:["<reserved>", "SD16", "<reserved>", "SD1_DAT0", "ARM_TDO", "☠" ], # 24
    10:["SPI0_MOSI", "SD2", "<reserved>", "☠", "☠", "☠" ], # 10
    9:["SPI0_MISO", "SD1", "<reserved>", "☠", "☠", "☠"], # 9
    25:["<reserved>", "SD17", "<reserved>", "SD1_DAT1", "ARM_TCK", "☠"], # 25
    11:["SPI0_SCLK", "SD3", "<reserved>", "☠", "☠", "☠"], # 11
    8:["SPI0_CE0_N", "SD0", "<reserved>" , "☠", "☠", "☠"], # 8
    7:["SPI0_CE1_N", "SWE_N / SRW_N", "<reserved>", "☠", "☠", "☠" ], # 7
    5:["GPCLK1", "SA0", "<reserved>", "☠", "☠", "ARM_TDO" ], # 5
    6:["GPCLK2", "SOE_N / SE", "<reserved>", "☠", "☠", "ARM_RTCK" ], # 6
    12:["PWM0", "SD4", "<reserved>", "☠", "☠", "ARM_TMS" ], #12
    13:["PWM1", "SD5", "<reserved>", "☠", "☠", "ARM_TCK" ], # 13
    19:["PCM_FS", "SD11", "<reserved>", "BSCSL SCL / SCLK", "SPI1_MISO", "PWM1"], #19
    16:["<reserved>", "SD8", "<reserved>", "CTS0", "SPI1_CE2_N", "CTS1"], #16
    26:["<reserved>", "<reserved>", "<reserved>", "SD1_DAT2", "ARM_TDI", "☠"], #26
    20:["<reserved>", "SD14", "<reserved>", "SD1_CLK", "ARM_TRST", "☠"], #20
    21:["PCM_DOUT", "SD13", "<reserved>", "BSCSL / CE_N", "SPI1_SCLK", "GPCLK1"],
    
    0:["SDA0", "SA5", "<reserved>", "☠", "☠", "☠" ], #0 EEPROM CONNECT FOR HATs
    1:["SCL0", "SA4", "<reserved>", "☠", "☠", "☠" ] #1 EEPROM CONNECT FOR HATs

  }.newTable

  FselToAltnameTbl* = {
    0b100:0,
    0b101:1,
    0b110:2,
    0b111:3,
    0b011:4,
    0b010:5
  }.newTable


when isMainModule:
  import bcm2835pii
  const
    v3_3 = 333
    v5 = 555
    gnd = 444
    reserved = 666

  var errno = init()
  if errno < 0:
    quit("BCM2835 init failure: " & $errno)
  else:
    echo "[init success]"

  import strformat
  let 
    q_space = 30
    
  var 
    row:int
    algn = 'r'

  for boardpin in countup(0,HeaderPinsBPlus.high,2):
    row += 1
    for i in 0..1:
      if i == 1: 
        stdout.write "\e[0m\e[36m", " ⋅ ⋅ ", "\e[0m"
        algn = '<'
      else:
        stdout.write "\e[0m\e[36m", &"{row:>2d}", "\e[0m", &" ({boardpin+1:>2d})({boardpin+2:>2d})"
        algn = '>'

      case HeaderPinsBPlus[boardpin + i]:
        of v3_3: stdout.write "\e[33m", alignString("3v3",q_space,algn)
        of v5: stdout.write "\e[31m", alignString("5v",q_space,algn)
        of gnd: stdout.write "\e[32m", alignString("GND",q_space,algn)
        of reserved: stdout.write "\e[35m", alignString("RESV",q_space,algn)
        else:
          var
            g_mode = $Gpio(HeaderPinsBPlus[boardpin + i]).mode
            g_lvl = Gpio(HeaderPinsBPlus[boardpin + i]).level

          if g_mode != "Input" and  g_mode != "Output":# GpioMode.Input and mode != GpioMode.Output
            g_mode = AltNamesTbl[HeaderPinsBPlus[boardpin + i]][FselToAltnameTbl[Gpio(HeaderPinsBPlus[boardpin + i]).mode.int]]

          if i == 1: 
            stdout.write "\e[0m", alignString(&"GPIO {HeaderPinsBPlus[boardpin + i]:>2d} ({g_lvl}:{g_mode})", q_space,algn)
          else:
            stdout.write "\e[0m", alignString(&"({g_mode}:{g_lvl}) GPIO {HeaderPinsBPlus[boardpin + i]:>2d}", q_space,algn)
    echo ""


#[ 
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
 ]#