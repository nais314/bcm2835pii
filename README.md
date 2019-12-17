# bcm2835pii - nim lang
bcm2835 basic gpio functions: i/o, pull-up/down  
for raspberry pi B+ boards until pi3  

created as a companion-lib for [nimgpiod](https://github.com/nais314/nimgpiod)  
  
**optionally depends on [bcm_host lib](https://github.com/nais314/bcm_host) - it is the new preferred way for hardware detection by raspberrypi.org**

### compiler definitions:
**-d:dependency_free** : do not import bcm_host  
**-d:safetyOn** : check for possibly harmful gpio mode operations (...)

```
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
    
    # set pull
    echo "gpio mode ", getMode(Gpio12)
    echo "getLevel ", getLevel(Gpio12)
    setPull(Gpio12, Pull.Up)
    echo "gpio mode ", Gpio12.mode
    echo "getLevel ", Gpio12.level
    setPull(Gpio12, Pull.Down)
    echo "gpio mode ", getMode(Gpio12)
    echo "getLevel ", getLevel(Gpio12)

    # set mode
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
```