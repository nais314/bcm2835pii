## for safety checks compile with -d:safetyOn or nim.cfg: -d:safetyOn
import posix # nanosleep, Timespec, Time

import bcm2835pii/rpi_info
if not (hardware_str in ["BCM2835","BCM2836", "BCM2837"]):
  quit("SOC is not compatible with BCM2835?", QuitFailure)

when not defined(DEPENDENCY_FREE):
  ## nim.cfg: -d:DEPENDENCY_FREE
  echo "importing bcm_host"
  import bcm_host

when defined(safetyOn):
  import tables
  import bcm2835pii/gpio_altnames

import strutils

# import END -------------------------------------------------------- import END


type 
  Gpio* = int
  Pull* {.pure.} = enum
    Unset = -1,
    None = 0,
    Down = 1,
    Up = 2


const
  v3_3 = 333
  v5 = 555
  gnd = 444
  reserved = 666
  HeaderPinsBPlus* = [v3_3, v5,
            2, v5,
            3, gnd,
            4, 14,
            gnd, 15,
            17, 18,
            27, gnd,
            22, 23,
            v3_3, 24,
            10, gnd,
            9, 25,
            11, 8,
            gnd, 7,
            reserved,reserved, #Gpio0&1 - EEPROM HAT connecton only
            5, gnd,
            6, 12,
            13, gnd,
            19, 16,
            26, 20,
            gnd, 21]
  ## Rpi B+ 40pin header pinout


let
  PullDefault* = [
    Pull.Up,Pull.Up,Pull.Up,Pull.Up, Pull.Up,Pull.Up,Pull.Up,Pull.Up, Pull.Up,#9
    Pull.Down,Pull.Down,Pull.Down,Pull.Down,Pull.Down,
    Pull.Down,Pull.Down,Pull.Down,Pull.Down,Pull.Down,
    Pull.Down,Pull.Down,Pull.Down,Pull.Down,Pull.Down,
    Pull.Down,Pull.Down,Pull.Down,Pull.Down, #27
    Pull.None,Pull.None,#29
    Pull.Down,Pull.Down,Pull.Down,Pull.Down,#33
    Pull.Up,Pull.Up,Pull.Up,#36
    Pull.Down,Pull.Down,Pull.Down, Pull.Down,Pull.Down,Pull.Down,Pull.Down,#43
    Pull.None,Pull.None,#45
    Pull.Up,Pull.Up,Pull.Up,Pull.Up, Pull.Up,Pull.Up,Pull.Up,Pull.Up#53
  ]
  ## BCM2835 default PUD values


type GpioMode* {.pure.} = enum
  Input = (0b000, "Input"), # = GPIO is an input
  Output = (0b001, "Output"), # GPIO is an output
  Alt5 = (0b010, "Alt5"), # GPIO takes alternate function 5
  Alt4 = (0b011, "Alt4"), # GPIO takes alternate function 4
  Alt0 = (0b100, "Alt0"), # GPIO takes alternate function 0
  Alt1 = (0b101, "Alt1"), # GPIO takes alternate function 1
  Alt2 = (0b110, "Alt2"), # GPIO takes alternate function 2
  Alt3 = (0b111, "Alt3") # GPIO takes alternate function 3
type FSEL* = GpioMode #? alias, bcm manual style, but ugly...
## cat /proc/cpuinfo
## FSEL = Function_Select 
## https://www.raspberrypi.org/app/uploads/2012/02/BCM2835-ARM-Peripherals.pdf - page 90


const
  GPIO_BASE_OFFSET = 0x00200000
  ## REGISTERS_SIZE = (0x7E2000B0-0x7E200000)
  ## the size of the peripheral's space, which is 0x01000000 for all models
  ## https://www.raspberrypi.org/documentation/hardware/raspberrypi/peripheral_addresses.md
  ## PERI_BASE = 0x20000000 # peripherals memory base addr old
  ## PERI_BASE = 0x3F000000 # new,  + 0x200000 = GPIO

var
  Gpio_MMAP_PTR*: pointer = nil #ptr int
  Gpio_MMAP*: ptr UncheckedArray[int] # for casting & reading Gpio_MMAP_PTR
const
  ## Gpio_MMAP[x]
  ## 0x 3F20 001C is the 7th 32bit int, etc...
  GPSET0 = 7 # 0..31
  GPSET1 = 8 # 32..53
  GPCLR0 = 10 # 0..31
  GPCLR1 = 11 # 32..53
  GPLEV0 = 13 # 0..31
  GPLEV1 = 14 # 32..53
  GPPUD = 37 # 0b00 Off, 01 Down, 10 Up, 11 Reserved
  GPPUDCLK0 = 38 # 0..31
  GPPUDCLK1 = 39 # 32..53

#type Mhz = int
let
  #CpuSpeed: Mhz = readFile("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq").strip.parseInt.Mhz
  CpuSpeed = readFile("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq").strip.parseInt
  ## removed type Mhz, as it is not used elsewhere
  NanosecondsPerCycles = 1_000_000 / CpuSpeed ## at 1Ghz 1 cycle == 1 nanosecond

#-------------------------------------------------------------------------------


###################     #### ##    ## #### ######## 
###################      ##  ###   ##  ##     ##    
###################      ##  ####  ##  ##     ##    
###################      ##  ## ## ##  ##     ##    
###################      ##  ##  ####  ##     ##    
###################      ##  ##   ###  ##     ##    
###################     #### ##    ## ####    ##   


proc init*(): int =
  when defined(DEPENDENCY_FREE):
    var
      ranges = readFile("/proc/device-tree/soc/ranges")
      ranges2 = cast[ptr UncheckedArray[int]](ranges)
    #echo "Ranges[3] ", toHex(ranges2[3].int), " ", ranges2[3]

    var GPIO_MEMORY_ADDR = (ranges2[3] shl 24) + GPIO_BASE_OFFSET #0x200000
    ## output: 0x0000003F - reverse it to 3F000000
    ## add offset to get GPIO range beginning

    var fd : cint

    try:
      fd = open("/dev/gpiomem", O_RDWR or O_SYNC)
      GPIO_MEMORY_ADDR = 0
    except:
      fd = open("/dev/mem", O_RDWR or O_SYNC)
      if (fd < 0): return -1
      
    Gpio_MMAP_PTR = mmap(
      nil,
      (0x7E2000B0-0x7E200000),# REGISTERS_SIZE, # BLOCK SIZE
      (PROT_READ or PROT_WRITE), # import posix
      MAP_SHARED, # import posix
      fd, # File descriptor to physical memory virtual file '/dev/mem'
      GPIO_MEMORY_ADDR.cint # GPIO_BASE # Address in physical map that we want this memory block to expose
    )

    discard close(fd)

    if not isNil(Gpio_MMAP_PTR):
      Gpio_MMAP = cast[ptr UncheckedArray[int]](Gpio_MMAP_PTR)
      return 0
    else:
      return -2




  when not defined(DEPENDENCY_FREE):
    ## use preferred bcm_host functions

    var GPIO_MEMORY_ADDR = (bcm_host_get_peripheral_address() + GPIO_BASE_OFFSET).Off

    var fd : cint

    try:
      fd = open("/dev/gpiomem", O_RDWR or O_SYNC)
      GPIO_MEMORY_ADDR = 0
    except:
      fd = open("/dev/mem", O_RDWR or O_SYNC)
      if (fd < 0): return -1
      
    Gpio_MMAP_PTR = mmap(
      nil,
      bcm_host_get_peripheral_size().int, # BLOCK SIZE # not valid for gpiomem (...)
      (PROT_READ or PROT_WRITE), # import posix
      MAP_SHARED, # import posix
      fd, # File descriptor to physical memory virtual file '/dev/mem'
      GPIO_MEMORY_ADDR #GPIO_BASE # Address in physical map that we want this memory block to expose
    )

    discard close(fd)

    if not isNil(Gpio_MMAP_PTR):
      Gpio_MMAP = cast[ptr UncheckedArray[int]](Gpio_MMAP_PTR)
      return 0
    else:
      return -2

# init() END--------------------------------------------------------- init() END


#####################    ######## ##     ## ##    ## 
#####################    ##       ##     ## ###   ## 
#####################    ##       ##     ## ####  ## 
#####################    ######   ##     ## ## ## ## 
#####################    ##       ##     ## ##  #### 
#####################    ##       ##     ## ##   ### 
#####################    ##        #######  ##    ## 


# MODE #-----------------------------------------
proc getMode*(gpio:Gpio):GpioMode=
  ## cast Gpio_MMAP_PTR as pointer to array of uin32
  ## read gpio mode bits 7 == 0b111, shl gpio*3(bits)
  ## shr back == mode!
  return GpioMode(
    (
      Gpio_MMAP[gpio div 10] and
      (7.int shl ((gpio mod 10) * 3))
    ) shr ((gpio mod 10) * 3)
    )
template mode*(gpio:Gpio):GpioMode=getMode(gpio)

proc setMode*(gpio:Gpio, mode:GpioMode)=
  ## get bank into buff, clear mode, set mode, write buff to bank
  #if gpio > 32: return # only 0..27 exposed on pin head
  when defined(safetyOn):
    if gpio > 27 or gpio < 2 or not (gpio in HeaderPinsBPlus):
      quit("safetOn: are you sure you want to touch GPIO-" & $gpio & " ?")
    if mode != GpioMode.Input and mode != GpioMode.Output and 
        AltNamesTbl[gpio.int][FselToAltnameTbl[mode.int]] in ["<reserved>", "☠"]:
          quit("safetOn: mode " & $AltNamesTbl[gpio.int][FselToAltnameTbl[mode.int]] & " on GPIO-" & $gpio & " can damage your board.")

  var
    bank = gpio div 10
    buff = Gpio_MMAP[bank]
  buff = buff and (not (7.int shl ((gpio mod 10) * 3)))
  buff = buff or (mode.int shl ((gpio mod 10) * 3))
  Gpio_MMAP[bank] = buff
template `mode=`*(gpio:Gpio, mode:GpioMode)=setMode(gpio,mode)

# LEVEL #-----------------------------------------
proc getLevel*(gpio:Gpio):int=
  ## read GPLEV register
  if gpio < 32: # only 0..27 exposed on pin head
    return (Gpio_MMAP[GPLEV0] shr gpio).int and 1
  else:
    return (Gpio_MMAP[GPLEV1] shr (gpio-32)).int and 1
template getVal*(gpio:Gpio):int=getLevel(gpio)
template level*(gpio:Gpio):int=getLevel(gpio)
template value*(gpio:Gpio):int=getLevel(gpio)

proc setLevel*(gpio:Gpio, level:int)=
  ## write GPSET or GPCLR registers
  #if gpio > 32: return
  when defined(safetyOn):
    if gpio > 27 or gpio < 2 or not (gpio in HeaderPinsBPlus):
      quit("safetOn: are you sure you want to touch GPIO-" & $gpio & " ?")

  if level > 0:
    if gpio < 32:
      Gpio_MMAP[GPSET0] = 1 shl gpio
    else:
      Gpio_MMAP[GPSET1] = 1 shl (gpio - 32)
  
  else:
    if gpio < 32:
      Gpio_MMAP[GPCLR0] = 1 shl gpio
    else:
      Gpio_MMAP[GPCLR1] = 1 shl (gpio - 32)
template setVal*(gpio:Gpio, val:int)=setLevel(gpio,val)
template `level=`*(gpio:Gpio, level:int):int=setLevel(gpio, level)
template `value=`*(gpio:Gpio, level:int):int=setLevel(gpio, level)

# PULL #-----------------------------------------
proc setPull*(gpio:Gpio, val:int)=
  #if gpio > 53: return  # only 0..27 exposed on pin head
  #[  The GPIO Pull-up/down Clock Registers control the actuation of internal Pull-downs on the respective GPIO pins. 
      These registers must be used in conjunction with the GPPUD register  to  effect  GPIO  Pull-up/down  changes.  
      The  following  sequence  of  events  is required: 
      1.  Write to GPPUD to set the required control signal (i.e. Pull-up or Pull-Down or neither to remove the current Pull-up/down) 
      2.  Wait 150 cycles – this provides the required set-up time for the control signal 
      3.  Write  to  GPPUDCLK0/1  to  clock  the  control  signal into  the  GPIO  pads  you  wish  to modify  –  NOTE  only the  pads  which  receive  a  clock will  be modified,  all  others  will retain their previous state. 
      4.  Wait 150 cycles – this provides the required hold time for the control signal 
      5.  Write to GPPUD to remove the control signal 
      6.  Write to GPPUDCLK0/1 to remove the clock 
      
      sudo cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
      1_000_000_000 Hz = 1 cycles / nanosecond?
      1Ghz = 1 cycles / nanosecond ?
      http://www.kylesconverter.com/frequency/gigahertz-to-cycles-per-nanosecond

      1 Gigahertz is exactly one billion Hertz. 1 GHz = 1 x 109 Hz. 1 GHz = 1_000_000_000 Hz.
      A period of 1 Nanosecond is equal to 1_000_000_000 Hertz frequency. 
      Period is the inverse of frequency: 1 Hz = 1 / 0.000 000 001 cpns.

      (1_000_000 / 900_000) * 150 = 166.666...
   ]#
  when defined(safetyOn):
    if gpio > 27 or gpio < 2 or not (gpio in HeaderPinsBPlus):
      quit("safetOn: are you sure you want to touch GPIO-" & $gpio & " ?")
  var
    ts1, ts2: Timespec
  ts1.tv_sec = 0.Time
  ts1.tv_nsec = ((NanosecondsPerCycles * 150) + 1).int # wait 150 cycles ???

  Gpio_MMAP[GPPUD] = val
  discard nanosleep(ts1, ts2)
  if gpio < 32:
    Gpio_MMAP[GPPUDCLK0] = (1 shl gpio)
  else:
    Gpio_MMAP[GPPUDCLK1] = (1 shl (gpio - 32))
  discard nanosleep(ts1, ts2)

  Gpio_MMAP[GPPUD] = 0
  discard nanosleep(ts1, ts2)
  if gpio < 32:
    Gpio_MMAP[GPPUDCLK0] = 0
  else:
    Gpio_MMAP[GPPUDCLK1] = 0
  discard nanosleep(ts1, ts2)

template setPull*(gpio:Gpio, val:Pull)=
  setPull(gpio, val.int)

#----#

template resetPull*(gpio:Gpio)=
  gpio.setPull(PullDefault[gpio])

# ----------------------------------------------------- #



####        ######## ########  ######  ######## 
####           ##    ##       ##    ##    ##    
####           ##    ##       ##          ##    
####           ##    ######    ######     ##    
####           ##    ##             ##    ##    
####           ##    ##       ##    ##    ##    
####           ##    ########  ######     ##    
    
when isMainModule:
  import strformat

  var errno = init()
  if errno < 0:
    echo "init failure ", errno
  else:
    echo "init success"
    let Gpio12: Gpio = 12
   
    for i in 0..15:
      var 
        g_mode = getMode(i)
        g_lvl = getLevel(i)

      echo &"GPIO {i:>2d}\t{g_mode}\t{g_lvl}"
    
    echo "gpio mode ", getMode(Gpio12)
    echo "getLevel ", getLevel(Gpio12)
    setPull(Gpio12, Pull.Up)
    echo "gpio mode ", Gpio12.mode
    echo "getLevel ", Gpio12.level
    setPull(Gpio12, Pull.Down)
    echo "gpio mode ", getMode(Gpio12)
    echo "getLevel ", getLevel(Gpio12)

    # set

    echo "gpio mode ", GpioMode(getMode(Gpio12))
    echo "gpio SET mode Alt0 "
    setMode(Gpio12,GpioMode.Alt0)
    echo "gpio mode ", GpioMode(getMode(Gpio12))

    echo "gpio SET mode Output "
    Gpio12.mode = GpioMode.Output
    echo "gpio mode ", GpioMode(Gpio12.mode)
    echo "getLevel ", Gpio12.level
    echo "  setLevel 1 "
    setLevel(Gpio12, 1)
    echo "getLevel ", getLevel(Gpio12)
    echo "gpio SET mode Input "
    setMode(Gpio12,GpioMode.Input)
    echo "gpio mode ", GpioMode(getMode(Gpio12))

    when defined(safetyOn):
      echo "#######################################"
      echo " safety check - should abort in 3..2.."
      setMode(Gpio(0),GpioMode.Input)

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