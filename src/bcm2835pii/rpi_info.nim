import strutils
import parseutils

import tables
## https://www.raspberrypi-spy.co.uk/2012/09/checking-your-raspberry-pi-board-version/
## cat /proc/cpuinfo
## cat /proc/device-tree/model

let RpiRevisions* = {
  0x0002:"Model B Rev 1 256MB",
  0x0003:"Model B Rev 1 ECN0001 (no fuses, D14 removed) 256MB",
  0x0004:"Model B Rev 2 256MB",
  0x0005:"Model B Rev 2 256MB",
  0x0006:"Model B Rev 2 256MB",
  0x0007:"Model A 256MB",
  0x0008:"Model A 256MB",
  0x0009:"Model A 256MB",
  0x000d:"Model B Rev 2 512MB",
  0x000e:"Model B Rev 2 512MB",
  0x000f:"Model B Rev 2 512MB",
  0x0010:"Model B+ 512MB",
  0x0013:"Model B+ 512MB",
  0x900032:"Model B+ 512MB",
  0x0011:"Compute Module 512MB",
  0x0014:"Compute Module 512MB (Embest, China)",
  0x0012:"Model A+ 256MB",
  0x0015:"Model A+ 256MB (Embest, China)",
  #"0015":"Model A+ 512MB (Embest, China)",
  0xa01041:"Pi 2 Model B v1.1 1GB (Sony, UK)",
  0xa21041:"Pi 2 Model B v1.1 1GB (Embest, China)",
  0xa22042:"Pi 2 Model B v1.2 1GB",
  0x900092:"Pi Zero v1.2 512MB",
  0x900093:"Pi Zero v1.3 512MB",
  0x9000C1:"Pi Zero W 512MB ",
  0xa02082:"Pi 3 Model B 1GB  (Sony, UK)",
  0xa22082:"Pi 3 Model B 1GB  (Embest, China)",
  0xa020d3:"Pi 3 Model B+ 1GB  (Sony, UK)",
  0xa03111:"Pi 4 1GB  (Sony, UK)",
  0xb03111:"Pi 4 2GB  (Sony, UK)",
  0xc03111:"Pi 4 4GB  (Sony, UK)" }.newTable #.newStringTable

var cpuinfo_str = readFile("/proc/cpuinfo")

#echo cpuinfo_str, "\n------------------------\n"

var
  numParsed: int
  parsed: string

  hardware_str*: string
  revision_str*: string
  revision_num*: int
  model_str*: string

try:
  numParsed = parseUntil(cpuinfo_str, parsed, "Hardware")
  numParsed += parseUntil(cpuinfo_str, parsed, ":", numParsed) + 2
  numParsed += parseUntil(cpuinfo_str, hardware_str, "\n", numParsed)
  #echo "hardware_str: ", hardware_str, "\n"

  numParsed += parseUntil(cpuinfo_str, parsed, "Revision", numParsed)
  numParsed += parseUntil(cpuinfo_str, parsed, ":", numParsed) + 2
  numParsed += parseUntil(cpuinfo_str, revision_str, "\n", numParsed)
  revision_num = parseHexInt(strip(revision_str))
  #echo "revision_str: ", revision_str, "\n"

  numParsed += parseUntil(cpuinfo_str, parsed, "Model", numParsed)
  numParsed += parseUntil(cpuinfo_str, parsed, ":", numParsed) + 2
  numParsed += parseUntil(cpuinfo_str, model_str, "\n", numParsed)
  #echo "model_str: ", model_str, "\n"

except:
  discard


when isMainModule:

  if hardware_str in ["BCM2835","BCM2836", "BCM2837"] :
    echo "B+"

  echo "revision_num: ", toHex(revision_num)," : ", RpiRevisions[revision_num]

  echo "cpuinfo parsed"
  echo hardware_str
  echo revision_str
  echo model_str


#[ 
type Mhz = int
let
  cpu_speed: Mhz = readFile("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq").strip.parseInt.Mhz

  nanoseconds_per_cycles = 1_000_000 / cpu_speed

echo cpu_speed
echo nanoseconds_per_cycles
 ]#
#[ var q_string = readFile("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
q_string = strip(q_string)
echo parseInt(q_string)

cpu_speed = readFile("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq").strip.parseInt.Mhz
echo cpu_speed
 ]#


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