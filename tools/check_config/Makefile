# Configuration values: see tools/config.mk
-include ../../.config
include ../config.mk
include ../../options.mk

CFLAGS+=-I. -I../../ -I../../include

check_config: check_config.o
	$(Q)gcc -o $@ $^ $(CFLAGS)
	$(Q)./check_config

%.o:%.c
	$(Q)gcc -c -o $@ $^ $(CFLAGS)

clean:
	$(Q)rm -f check_config *.o
