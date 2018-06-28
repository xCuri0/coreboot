include ../../.config

ARCHDIR-$(CONFIG_ARCH_ARMV7) := armv7
ARCHDIR-$(CONFIG_ARCH_X86)	 := x86

OBJ-$(CONFIG_SOUTHBRIDGE_INTEL_COMMON)	+= ../../src/southbridge/intel/common/usb_debug.o
OBJ-$(CONFIG_SOUTHBRIDGE_AMD_AGESA_HUDSON) += ../../src/southbridge/amd/agesa/hudson/enable_usbdebug.o
OBJ-$(CONFIG_SOUTHBRIDGE_AMD_SB700) += ../../src/southbridge/amd/sb700/enable_usbdebug.o
OBJ-$(CONFIG_SOUTHBRIDGE_AMD_SB800) += ../../src/southbridge/amd/sb800/enable_usbdebug.o

PROGRAM	:= uio_usbdebug

SRC := $(OBJ-y) ./uio_usbdebug.o ../../src/drivers/usb/ehci_debug.o ../../src/drivers/usb/pci_ehci.o ../../src/drivers/usb/gadget.o

INCLUDE := \
	../../src/drivers/usb/ehci.h \
	../../src/drivers/usb/ehci_debug.h \
	../../src/drivers/usb/usb_ch9.h \

KCONFIG_H := ../../src/include/kconfig.h

LIBS := -lpci -lz

CFLAGS := \
	-I ../../src/include/ \
	-I ../../src/commonlib/include/ \
	-I ../../build/ \
	-I ../../src/arch/$(ARCHDIR-y)/include/ \
	-include$(KCONFIG_H)

all: $(PROGRAM)

$(PROGRAM): $(SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(LIBS)