set_property PACKAGE_PIN E3 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

set_property PACKAGE_PIN C12 [get_ports nrst]
set_property IOSTANDARD LVCMOS33 [get_ports nrst]

set_property PACKAGE_PIN H17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN K15 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]


create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]
set_false_path -from clk_out1_clk_100_100_a7_1 -to clk_out2_clk_100_100_a7_1
#set_false_path -from clk_out1_clk_100_111_a7_1 -to clk_out2_clk_100_111_a7_1
#set_false_path -from clk_out1_clk_100_91_a7_1 -to clk_out2_clk_100_91_a7_1
                                                                     
#7 segment display
#Bank = 34, Pin name = IO_L2N_T0_34,						Sch name = CA
set_property PACKAGE_PIN T10 [get_ports {sevenseg[0]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sevenseg[0]}]
#Bank = 34, Pin name = IO_L3N_T0_DQS_34,					Sch name = CB
set_property PACKAGE_PIN R10 [get_ports {sevenseg[1]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sevenseg[1]}]
#Bank = 34, Pin name = IO_L6N_T0_VREF_34,					Sch name = CC
set_property PACKAGE_PIN K16 [get_ports {sevenseg[2]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sevenseg[2]}]
#Bank = 34, Pin name = IO_L5N_T0_34,						Sch name = CD
set_property PACKAGE_PIN K13 [get_ports {sevenseg[3]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sevenseg[3]}]
#Bank = 34, Pin name = IO_L2P_T0_34,						Sch name = CE
set_property PACKAGE_PIN P15 [get_ports {sevenseg[4]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sevenseg[4]}]
#Bank = 34, Pin name = IO_L4N_T0_34,						Sch name = CF
set_property PACKAGE_PIN T11 [get_ports {sevenseg[5]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sevenseg[5]}]
#Bank = 34, Pin name = IO_L6P_T0_34,						Sch name = CG
set_property PACKAGE_PIN L18 [get_ports {sevenseg[6]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {sevenseg[6]}]

##Bank = 34, Pin name = IO_L16P_T2_34,						Sch name = DP
#set_property PACKAGE_PIN M4 [get_ports dp]							
	#set_property IOSTANDARD LVCMOS33 [get_ports dp]

#Bank = 34, Pin name = IO_L18N_T2_34,						Sch name = AN0
set_property PACKAGE_PIN J17 [get_ports {anode[0]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {anode[0]}]
#Bank = 34, Pin name = IO_L18P_T2_34,						Sch name = AN1
set_property PACKAGE_PIN J18 [get_ports {anode[1]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {anode[1]}]
#Bank = 34, Pin name = IO_L4P_T0_34,						Sch name = AN2
set_property PACKAGE_PIN T9 [get_ports {anode[2]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {anode[2]}]
#Bank = 34, Pin name = IO_L13_T2_MRCC_34,					Sch name = AN3
set_property PACKAGE_PIN J14 [get_ports {anode[3]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {anode[3]}]
#Bank = 34, Pin name = IO_L3P_T0_DQS_34,					Sch name = AN4
set_property PACKAGE_PIN P14 [get_ports {anode[4]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {anode[4]}]
#Bank = 34, Pin name = IO_L16N_T2_34,						Sch name = AN5
set_property PACKAGE_PIN T14 [get_ports {anode[5]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {anode[5]}]
#Bank = 34, Pin name = IO_L1P_T0_34,						Sch name = AN6
set_property PACKAGE_PIN K2 [get_ports {anode[6]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {anode[6]}]
#Bank = 34, Pin name = IO_L1N_T034,							Sch name = AN7
set_property PACKAGE_PIN U13 [get_ports {anode[7]}]					
	set_property IOSTANDARD LVCMOS33 [get_ports {anode[7]}]

