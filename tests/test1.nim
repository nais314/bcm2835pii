# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import strformat, strutils
import bcm2835pii

test "proof of concept":
  var errno = init()
  if errno < 0:
    echo "init failure ", errno
  else:
    echo "init success"

    for bank in 0..3:
      echo cast[ptr UncheckedArray[int]](Gpio_MMAP_PTR)[bank]

      var regBank: int = cast[ptr UncheckedArray[int]](Gpio_MMAP_PTR)[bank]
      var regBuf: int
      for i in countup(0,29,3):
        regBuf = regBank
        regBuf = (regBuf and (7.int shl i)) shr i

        echo "GPIO ", ((i div 3) + (bank * 10) + 1), ": ", GpioMode(regBuf.int), " ", toBin(regBuf.int, 3)



test "fun test":

  var errno = init()
  if errno < 0:
    echo "init failure ", errno
  else:
    echo "init success"
    let Gpio12:Gpio = 12
   
    for i in 0..15:
      var 
        g_mode = getMode(i)
        g_lvl = getLevel(i)

      echo &"GPIO {i:>2d}\t{g_mode}\t{g_lvl}"
    
    echo "gpio mode ", getMode(Gpio12)
    echo "getLevel ", getLevel(Gpio12)
    setPull(Gpio12, Pull.UP)
    echo "gpio mode ", Gpio12.getMode
    echo "getLevel ", Gpio12.getLevel
    setPull(Gpio12, Pull.DOWN)
    echo "gpio mode ", getMode(Gpio12)
    echo "getLevel ", getLevel(Gpio12)

    # set

    echo "gpio mode ", GpioMode(getMode(Gpio12))
    echo "gpio SET mode Alt0 "
    setMode(Gpio12,GpioMode.Alt0)
    echo "gpio mode ", GpioMode(getMode(Gpio12))

    echo "gpio SET mode Output "
    #setMode(Gpio12,GpioMode.Output)
    Gpio12.mode = GpioMode.Output
    echo "gpio mode ", GpioMode(getMode(Gpio12))
    echo "getLevel ", getLevel(Gpio12)
    echo "  setLevel 1 "
    #setLevel(Gpio12, 1)
    Gpio12.level = 1
    echo "getLevel ", getLevel(Gpio12)
    echo "gpio SET mode Input "
    setMode(Gpio12,GpioMode.Input)
    echo "gpio mode ", GpioMode(getMode(Gpio12))

