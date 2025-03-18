# Serial port for communication with the AVR microcontroller
PORT=COM4

# Path to the AVRDUDE configuration file
AVRDUDE_CONF_PATH = "./config/avrdude.conf"

# Microcontroller type (ATmega2560)
MCU=m2560

# Absolute path to the Assembler executable for the AVR architecture
ASSEMBLER="/mnt/c/Program Files (x86)/Atmel/Studio/7.0/toolchain/avr8/avrassembler/avrasm2.exe"

# Path to the directory containing header files (relative to the Makefile)
INCLUDE_PATH = "./inc"

# Absolute path to the AVRDUDE executable for flashing the microcontroller
AVRDUDE = "/mnt/c/Program Files (x86)/Arduino/hardware/tools/avr/bin/avrdude.exe"

# Name of the target file (without extension)
TARGET=main

# Path to the source directory containing assembly files (relative to the Makefile)
SRC_DIR=./src

# Name of the output hex file
HEX_FILES=$(TARGET).hex

# Rule to build all hex files
all: $(HEX_FILES)

# Clean command to remove generated files
# This will delete all object files, hex files, and other generated files
clean:
	rm -f *.o *.hex *.obj *.elf *.cof *.eep.hex *.map

# Rule to assemble .asm files into .hex files
# This rule assembles the target .asm file into a .hex file using the assembler
$(TARGET).hex: $(SRC_DIR)/$(TARGET).asm
	$(ASSEMBLER) -fI -I $(INCLUDE_PATH) $< -o $@

# Rule to program the hex file onto the microcontroller
# This rule uses AVRDUDE to flash the .hex file onto the MCU
program: $(HEX_FILES)
	$(AVRDUDE) -C $(AVRDUDE_CONF_PATH) -c wiring -p $(MCU) -P $(PORT) -U flash:w:$(HEX_FILES):i -D
