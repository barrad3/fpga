## Basys 3 constraints for PmodBLE UART echo project
## Top-level ports expected:
## clk, btnC, ble_rx, ble_tx, ble_cts, led[7:0]

## Clock signal - 100 MHz
set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]


## Reset button - BTNC
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports btnC]


## LEDs 0-7
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN E19 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN V19 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {led[4]}]
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports {led[5]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led[6]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led[7]}]


## Pmod Header JB - UART to PmodBLE
##
## PmodBLE pinout (top row of JB):
##   JB1 (pin 1) = CTS  - Clear To Send input (active low)
##   JB2 (pin 2) = RXD  - receive data input of PmodBLE (FPGA sends TO this)
##   JB3 (pin 3) = TXD  - transmit data output of PmodBLE (FPGA receives FROM this)
##   JB4 (pin 4) = RTS  - Ready To Send output
##
## UART connection is crossed:
##   FPGA ble_tx  -> PmodBLE RXD (pin 2)
##   FPGA ble_rx  <- PmodBLE TXD (pin 3)
##   FPGA ble_cts -> PmodBLE CTS (pin 1) - drive low to allow BLE to transmit

## JB1 - CTS to PmodBLE (active low = allow transmit)
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports ble_cts]

## JB2 - FPGA TX to PmodBLE RXD
set_property -dict { PACKAGE_PIN A16 IOSTANDARD LVCMOS33 } [get_ports ble_tx]

## JB3 - PmodBLE TXD to FPGA RX
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 } [get_ports ble_rx]

## JB4 - RTS from PmodBLE (active low, directly active, directly active, directly active - not used, directly active)
#set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports ble_rts]

## JB8 - PmodBLE Reset (active low)
set_property -dict { PACKAGE_PIN A17 IOSTANDARD LVCMOS33 } [get_ports ble_rst]
## JB9 - PmodBLE Mode (high = app mode)
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 } [get_ports ble_mode]



## Configuration options, can be used for all designs
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## SPI configuration mode options for QSPI boot, can be used for all designs
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
