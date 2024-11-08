.PHONY: \
	vars \
	help \
	clean \
	compile \
	dump \
	upload \
	simul \
	fuses \
	check-fuses

# Hack to get the directory this makefile is in:
MKFILE_PATH	:= $(lastword $(MAKEFILE_LIST))
MKFILE_DIR	:= $(notdir $(patsubst %/,%,$(dir $(MKFILE_PATH))))
MKFILE_ABSDIR	:= $(abspath $(MKFILE_DIR))
AVR_PATH	:= /snap/arduino/85/hardware/tools/avr
AVR_BIN_PATH	:= $(AVR_PATH)/bin

# Hack to get all *.h files into compile dependencies:
HEADERS		= $(shell find $(MKFILE_DIR) -name "*.h")

BUILDTMP	?= $(MKFILE_DIR)/build-tmp
OPTIMIZATION	?= -Os
AVRAS		?= $(AVR_BIN_PATH)/avr-as -Wall -al -v --listing-rhs-width=80 -mmcu=$(DEVICE) -I$(MKFILE_DIR)
AVRGCC		?= $(AVR_BIN_PATH)/avr-gcc -Wall -nostartfiles -mmcu=$(DEVICE) -I$(MKFILE_DIR)
AVRCC		?= $(AVRGCC)
AVRDUDE		?= $(AVR_BIN_PATH)/avrdude
LD		?= ld
#---------------------------------------------------------
# AVRDUDE_FLASHARG:
# This preserves the chip memory when updating the fuses.
# To erase the chip when setting fuses, do:
#
#     make AVRDUDE_FLASHARG=-e fuses
#
AVRDUDE_FLASHARG ?= -D
#---------------------------------------------------------
AVR_SIZE	?= $(AVR_BIN_PATH)/avr-size
AVR_OBJCOPY	?= $(AVR_BIN_PATH)/avr-objcopy
AVR_OBJDUMP	?= $(AVR_BIN_PATH)/avr-objdump
DEVICE		:= attiny4313
ARCHITECTURE	:= "avr:25"
CLOCK		:= 8000000L
PROGRAMMER	:= stk500v1
BAUD		:= 19200
#SRC		:= blink+midi3.S simulmo4.S
SRC		:= simulmo4.S
#SRC		:= blink+midi2.S
OBJ		:= $(BUILDTMP)/$(SRC:S=o)
ELF		:= $(BUILDTMP)/$(SRC:S=elf)
HEX		:= $(BUILDTMP)/$(SRC:S=hex)
EEP		:= $(BUILDTMP)/$(SRC:S=eep)
FUSE_EXT	:= 0xff
FUSE_HIGH	:= 0x9f
FUSE_LOW	:= 0xcf
AVRDUDE_CONF    := $(AVR_PATH)/etc/avrdude.conf
USBDEVICE	:= $(shell dmesg | awk '/tty/ && /USB/ {gsub(/:/,"",$$4);A=$$4} END{print "/dev/"A}')
AVRDUDE_OPTS    := -C $(AVRDUDE_CONF) -p$(DEVICE) -c$(PROGRAMMER) -P$(USBDEVICE) -b$(BAUD) 

# Misc target info:
help_spacing  := 12

.DEFAULT_GOAL := compile

#---------------------------------------------------------
# Ensure temp directories.
#
# In order to ensure temp dirs exit, we include a file
# that doesn't exist, with a target declared as PHONY
# (above), and then have the target create our tmp dirs.
#---------------------------------------
-include ensure-tmp
ensure-tmp:
	@mkdir -p $(BUILDTMP)

vars: ## Print relevant environment vars
	@printf  "%-20.20s%s\n"  "MKFILE_PATH:"		"$(MKFILE_PATH)"
	@printf  "%-20.20s%s\n"  "MKFILE_DIR:"		"$(MKFILE_DIR)"
	@printf  "%-20.20s%s\n"  "MKFILE_ABSDIR:"	"$(MKFILE_ABSDIR)"
	@printf  "%-20.20s%s\n"  "BUILDTMP:"		"$(BUILDTMP)"
	@printf  "%-20.20s%s\n"  "OPTIMIZATION:"	"$(OPTIMIZATION)"
	@printf  "%-20.20s%s\n"  "AVRAS:"		"$(AVRAS)"
	@printf  "%-20.20s%s\n"  "AVRGCC:"		"$(AVRGCC)"
	@printf  "%-20.20s%s\n"  "AVRCC:"		"$(AVRCC)"
	@printf  "%-20.20s%s\n"  "AVRDUDE:"		"$(AVRDUDE)"
	@printf  "%-20.20s%s\n"  "AVRDUDE_OPTS:"	"$(AVRDUDE_OPTS)"
	@printf  "%-20.20s%s\n"  "AVR_SIZE:"		"$(AVR_SIZE)"
	@printf  "%-20.20s%s\n"  "AVR_OBJCOPY:"		"$(AVR_OBJCOPY)"
	@printf  "%-20.20s%s\n"  "AVR_OBJDUMP:"		"$(AVR_OBJDUMP)"
	@printf  "%-20.20s%s\n"  "DEVICE:"		"$(DEVICE)"
	@printf  "%-20.20s%s\n"  "CLOCK:"		"$(CLOCK)"
	@printf  "%-20.20s%s\n"  "PROGRAMMER:"		"$(PROGRAMMER)"
	@printf  "%-20.20s%s\n"  "USBDEVICE:"		"$(USBDEVICE)"
	@printf  "%-20.20s%s\n"  "BAUD:"		"$(BAUD)"
	@printf  "%-20.20s%s\n"  "SRC:"			"$(SRC)"
	@printf  "%-20.20s%s\n"  "ELF:"			"$(ELF)"
	@printf  "%-20.20s%s\n"  "EEP:"			"$(EEP)"
	@printf  "%-20.20s%s\n"  "HEX:"			"$(HEX)"

help: ## Print this makefile help menu
	@echo "TARGETS:"
	@grep '^[a-z_\-]\{1,\}:.*##' $(MAKEFILE_LIST) \
		| sed 's/^\([a-z_\-]\{1,\}\): *\(.*[^ ]\) *## *\(.*\)/\1:\t\3 (\2)/g' \
		| sed 's/^\([a-z_\-]\{1,\}\): *## *\(.*\)/\1:\t\2/g' \
		| awk '{$$1 = sprintf("%-$(help_spacing)s", $$1)} 1' \
		| sed 's/^/  /'
	@printf "\nUsage:\n    make \\ \n    %s \\ \n    %s \\ \n    %s \\ \n    %s\n" \
		"USBDEVICE=/dev/cu.usbserial-1234" \
		"SRC=my_source.c" \
		"DEVICE=<mcu>" \
		"<make target>"

vpath %.o $(BUILDTMP)
vpath %.eep $(BUILDTMP)
vpath %.elf $(BUILDTMP)
vpath %.hex $(BUILDTMP)

$(OBJ): $(SRC)
	$(AVRAS) -mmcu=$(DEVICE) -o $@ $<
$(ELF): $(OBJ)
	$(AVRGCC) -mmcu=$(DEVICE) -L$(BUILDTMP) $(LDFLAGS) -o $@ $<
$(HEX): $(ELF)
	$(AVR_OBJCOPY) -O ihex -R .eeprom --preserve-dates $< $@
	$(AVR_OBJDUMP) --architecture=$(ARCHITECTURE) -D $@
$(EEP): $(ELF)
	$(AVR_OBJCOPY) -O ihex -j .eeprom --set-section-flags=.eeprom=alloc,load --no-change-warnings --change-section-lma=.eeprom=0 --preserve-dates $< $@

clean: ## Clean build artifacts
	rm -rf $(BUILDTMP)/*
	rm -vf *.s

compile: $(EEP) $(HEX)
	$(AVR_SIZE) -A $(ELF)

link: compile ## Link compilation artifacts and package for upload
#	$(AVR_OBJCOPY) \
#	    -O ihex \
#	    -j .eeprom \
#		    --set-section-flags=.eeprom=alloc,load \
#		    --no-change-warnings \
#		    --change-section-lma .eeprom=0 \
#		    $(ELF) \
#		    $(BUILDTMP)/$(SRC).eep
#		$(AVR_OBJCOPY) -O ihex -R .eeprom $(ELF) $(HEX)
#		$(AVR_SIZE) -A $(ELF)

upload: $(HEX)	 ## Upload (NOTE: USBDEVICE must be set)
ifndef USBDEVICE
	$(error 'USBDEVICE not defined! Please set USBDEVICE env var!')
endif # USBDEVICE
	$(AVRDUDE) -v $(AVRDUDE_OPTS) -Uflash:w:$(HEX):i

fuses: ## Flash the fuses
ifndef USBDEVICE
	$(error 'USBDEVICE not defined! Please set USBDEVICE env var!')
endif # USBDEVICE
	$(AVRDUDE) -v $(AVRDUDE_OPTS) -D \
	    -Uefuse:w:$(FUSE_EXT):m \
	    -Uhfuse:w:$(FUSE_HIGH):m \
	    -Ulfuse:w:$(FUSE_LOW):m

check-fuses: ## Verify device signature and check fuse values
	$(AVRDUDE) $(AVRDUDE_OPTS)

simul: $(ELF)
	simulavr -d attiny2313 -t attiny2313 -f $(ELF)

mo4: mo4.S  tn4313def.h attiny4313_registers.h
	avr-gcc -mmcu=attiny4313 $^

dump:
	@echo "Dump of Flash"
	$(AVRDUDE) $(AVRDUDE_OPTS) -U flash:r:$(MKFILE_DIR)/flash.bin:r
	$(AVR_OBJCOPY) -O ihex $(MKFILE_DIR)/flash.bin $(MKFILE_DIR)/flash.hex
	@$(AVR_OBJDUMP) --architecture=$(ARCHITECTURE) --demangle --disassemble --source --wide $(MKFILE_DIR)/flash.hex
