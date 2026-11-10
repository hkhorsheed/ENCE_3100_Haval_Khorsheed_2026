# 50 MHz board clock
create_clock -name clk50 -period 20.000 [get_ports MAX10_CLK1_50]
derive_clock_uncertainty

# Keys and the UART input are asynchronous (synchronized in the design).
# LEDs, 7-segment displays and the UART output have no timing requirement.
set_false_path -from [get_ports {KEY[*] UART_RXD}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*] UART_TXD}]
