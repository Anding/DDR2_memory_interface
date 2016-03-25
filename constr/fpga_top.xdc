set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property PACKAGE_PIN C12 [get_ports nrst]
set_property IOSTANDARD LVCMOS33 [get_ports nrst]

set_property PACKAGE_PIN H17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN K15 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]


create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]
                                                                     


