# IBM Research - Zurich
# Zurich CAPI Streaming Layer
# Raphael Polig <pol@zurich.ibm.com>
# Heiner Giefers <hgi@zurich.ibm.com>

# Setting false path from port B write enable reg in zcsl_ram_1r1w instances as the port is disconnected
#set_false_path -from [get_registers *zcsl_ram_1r1w*PORT_B_WRITE_ENABLE_REG] -to [get_registers *]

# Remove internal reset path from timing.
# TODO: More accurate this is a multi-cycle path
set_false_path -from [get_registers {*zcsl_ctrl*IRST*}] -to [get_registers *]
#set_multicycle_path -from [get_registers {*zcsl_ctrl*IRST*}] -to [get_registers *] -setup -end 2


# Remove path from CROOM register. Never changes during operation, only at start of AFU
set_false_path -from [get_registers {*zcsl_cmd*IROOM*}] -to [get_registers *]

