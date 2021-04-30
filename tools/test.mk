TEST_UPDATE_VERSION?=2
WOLFBOOT_VERSION?=0
EXPVER=tools/test-expect-version/test-expect-version
BINASSEMBLE=tools/bin-assemble/bin-assemble

SPI_CHIP=SST25VF080B
SPI_OPTIONS=SPI_FLASH=1 WOLFBOOT_PARTITION_SIZE=0x80000 WOLFBOOT_PARTITION_UPDATE_ADDRESS=0x00000 WOLFBOOT_PARTITION_SWAP_ADDRESS=0x80000
SIGN_ARGS=
STFLASH:=st-flash

ifneq ("$(wildcard $(WOLFBOOT_ROOT)/tools/keytools/keygen)","")
	KEYGEN_TOOL=$(WOLFBOOT_ROOT)/tools/keytools/keygen
else
	ifneq ("$(wildcard $(WOLFBOOT_ROOT)/tools/keytools/keygen.exe)","")
		KEYGEN_TOOL=$(WOLFBOOT_ROOT)/tools/keytools/keygen.exe
	else
		KEYGEN_TOOL=python3 $(WOLFBOOT_ROOT)/tools/keytools/keygen.py
	endif
endif

ifneq ("$(wildcard $(WOLFBOOT_ROOT)/tools/keytools/sign)","")
	SIGN_TOOL=$(WOLFBOOT_ROOT)/tools/keytools/sign
else
	ifneq ("$(wildcard $(WOLFBOOT_ROOT)/tools/keytools/sign.exe)","")
		SIGN_TOOL=$(WOLFBOOT_ROOT)/tools/keytools/sign.exe
	else
		SIGN_TOOL=python3 $(WOLFBOOT_ROOT)/tools/keytools/sign.py
	endif
endif

ifeq ($(SIGN),ED25519)
  SIGN_ARGS+= --ed25519
endif

ifeq ($(SIGN),ECC256)
  SIGN_ARGS+= --ecc256
endif

ifeq ($(SIGN),RSA2048)
  SIGN_ARGS+= --rsa2048
endif

ifeq ($(SIGN),RSA4096)
  SIGN_ARGS+= --rsa4096
endif

ifeq ($(HASH),SHA256)
  SIGN_ARGS+= --sha256
endif
ifeq ($(HASH),SHA3)
  SIGN_ARGS+= --sha3
endif

$(EXPVER):
	$(MAKE) -C $(dir $@)

$(BINASSEMBLE):
	$(MAKE) -C $(dir $@)

# Testbed actions
#
#
# tpm-mute mode is the default
#
tpm-mute:
	$(Q)if ! (test -d /sys/class/gpio/gpio7); then echo "7" > /sys/class/gpio/export || true; fi
	$(Q)echo "out" >/sys/class/gpio/gpio7/direction
	$(Q)echo "1" >/sys/class/gpio/gpio7/value || true

tpm-unmute:
	$(Q)if ! (test -d /sys/class/gpio/gpio7); then echo "7" > /sys/class/gpio/export || true; fi
	$(Q)echo "in" >/sys/class/gpio/gpio7/direction

testbed-on: FORCE
	$(Q)if ! (test -d /sys/class/gpio/gpio4); then echo "4" > /sys/class/gpio/export || true; fi
	$(Q)echo "out" >/sys/class/gpio/gpio4/direction
	$(Q)echo "0" >/sys/class/gpio/gpio4/value || true
	$(Q)$(MAKE) tpm-mute
	$(Q)echo "Testbed on."

testbed-off: FORCE
	$(Q)$(MAKE) tpm-mute
	$(Q)if ! (test -d /sys/class/gpio/gpio4); then echo "4" > /sys/class/gpio/export || true; fi
	$(Q)echo "out" >/sys/class/gpio/gpio4/direction
	$(Q)echo "1" >/sys/class/gpio/gpio4/value || true
	$(Q)echo "Testbed off."

check-version: $(EXPVER)
	$(Q)echo "check"
	$(Q)if (test `$(EXPVER)` -ne $(EXPECTED_VERSION)); then echo "`$(EXPVER)` not equal to expected $(EXPECTED_VERSION)"; false; fi

test-reset: FORCE
	$(Q)(sleep 1 && $(STFLASH) reset && sleep 1)&

test-spi-on: FORCE
	$(Q)$(MAKE) testbed-off
	$(Q)echo "8" >/sys/class/gpio/unexport || true
	$(Q)echo "9" >/sys/class/gpio/unexport || true
	$(Q)echo "10" >/sys/class/gpio/unexport || true
	$(Q)echo "11" >/sys/class/gpio/unexport || true
	$(Q)modprobe spi_bcm2835
	$(Q)modprobe spidev

test-spi-off: FORCE
	$(Q)rmmod spi_bcm2835 || true
	$(Q)rmmod spidev || true
	$(Q)echo "8" >/sys/class/gpio/export || true
	$(Q)echo "9" >/sys/class/gpio/export || true
	$(Q)echo "10" >/sys/class/gpio/export || true
	$(Q)echo "11" >/sys/class/gpio/export || true
	$(Q)echo "in" >/sys/class/gpio/gpio8/direction
	$(Q)echo "in" >/sys/class/gpio/gpio9/direction
	$(Q)echo "in" >/sys/class/gpio/gpio10/direction
	$(Q)echo "in" >/sys/class/gpio/gpio11/direction
	$(Q)$(MAKE) testbed-on

test-update: test-app/image.bin FORCE
	$(Q)dd if=/dev/zero bs=131067 count=1 2>/dev/null | tr "\000" "\377" > test-update.bin
	$(Q)$(SIGN_TOOL) $(SIGN_ARGS) test-app/image.bin $(PRIVATE_KEY) $(TEST_UPDATE_VERSION)
	$(Q)dd if=test-app/image_v$(TEST_UPDATE_VERSION)_signed.bin of=test-update.bin bs=1 conv=notrunc
	$(Q)printf "pBOOT" | dd of=test-update.bin bs=1 seek=131067
	$(Q)$(MAKE) test-reset
	$(Q)sleep 2
	$(Q)$(STFLASH) --reset write test-update.bin 0x08040000 || \
		($(MAKE) test-reset && sleep 1 && $(STFLASH) --reset write test-update.bin 0x08040000) || \
		($(MAKE) test-reset && sleep 1 && $(STFLASH) --reset write test-update.bin 0x08040000)

test-self-update: wolfboot.bin test-app/image.bin FORCE
	$(Q)mv $(PRIVATE_KEY) private_key.old
	$(Q)$(MAKE) clean
	$(Q)rm src/*_pub_key.c
	$(Q)$(MAKE) wolfboot.bin
	$(Q)$(MAKE) factory.bin RAM_CODE=1 WOLFBOOT_VERSION=$(WOLFBOOT_VERSION) SIGN=$(SIGN)
	$(Q)$(SIGN_TOOL) $(SIGN_ARGS) test-app/image.bin $(PRIVATE_KEY) $(TEST_UPDATE_VERSION)
	$(Q)$(STFLASH) --reset write test-app/image_v2_signed.bin 0x08020000 || \
		($(MAKE) test-reset && sleep 1 && $(STFLASH) --reset write test-app/image_v2_signed.bin 0x08020000) || \
		($(MAKE) test-reset && sleep 1 && $(STFLASH) --reset write test-app/image_v2_signed.bin 0x08020000)
	$(Q)dd if=/dev/zero bs=131067 count=1 2>/dev/null | tr "\000" "\377" > test-self-update.bin
	$(Q)$(SIGN_TOOL) $(SIGN_ARGS) --wolfboot-update wolfboot.bin private_key.old $(WOLFBOOT_VERSION)
	$(Q)dd if=wolfboot_v$(WOLFBOOT_VERSION)_signed.bin of=test-self-update.bin bs=1 conv=notrunc
	$(Q)printf "pBOOT" | dd of=test-update.bin bs=1 seek=131067
	$(Q)$(STFLASH) --reset write test-self-update.bin 0x08040000 || \
		($(MAKE) test-reset && sleep 1 && $(STFLASH) --reset write test-self-update.bin 0x08040000) || \
		($(MAKE) test-reset && sleep 1 && $(STFLASH) --reset write test-self-update.bin 0x08040000)

test-update-ext: test-app/image.bin FORCE
	$(Q)$(SIGN_TOOL) $(SIGN_ARGS) test-app/image.bin $(PRIVATE_KEY) $(TEST_UPDATE_VERSION)
	$(Q)(dd if=/dev/zero bs=1M count=1 | tr '\000' '\377' > test-update.rom)
	$(Q)dd if=test-app/image_v$(TEST_UPDATE_VERSION)_signed.bin of=test-update.rom bs=1 count=524283 conv=notrunc
	$(Q)printf "pBOOT" | dd of=test-update.rom obs=1 seek=524283 count=5 conv=notrunc
	$(Q)$(MAKE) test-spi-on || true
	flashrom -c $(SPI_CHIP) -p linux_spi:dev=/dev/spidev0.0 -w test-update.rom
	$(Q)$(MAKE) test-spi-off
	$(Q)$(MAKE) test-reset
	$(Q)sleep 2
	$(Q)$(MAKE) clean

test-erase: FORCE
	$(Q)echo Mass-erasing the internal flash:
	$(Q)$(MAKE) test-reset
	$(Q)sleep 2
	$(Q)$(STFLASH) erase

test-erase-ext: FORCE
	$(Q)$(MAKE) test-spi-on || true
	$(Q)echo Mass-erasing the external SPI flash:
	flashrom -c $(SPI_CHIP) -p linux_spi:dev=/dev/spidev0.0 -E
	$(Q)$(MAKE) test-spi-off || true

test-factory: factory.bin
	$(Q)$(MAKE) test-reset
	$(Q)sleep 2
	$(Q)$(STFLASH) --reset write factory.bin 0x08000000 || \
		(($(MAKE) test-reset && sleep 1 && $(STFLASH) --reset write factory.bin 0x08000000) || \
		($(MAKE) test-reset && sleep 1 && $(STFLASH) --reset write factory.bin 0x08000000))&

test-resetold: FORCE
	$(Q)(sleep 1 && st-info --reset) &



## Test cases:

test-01-forward-update-no-downgrade: $(EXPVER) FORCE
	$(Q)$(MAKE) test-erase
	$(Q)echo Creating and uploading factory image...
	$(Q)$(MAKE) test-factory
	$(Q)echo Expecting version '1'
	$(MAKE) check-version EXPECTED_VERSION=1
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update TEST_UPDATE_VERSION=4
	$(Q)echo Expecting version '4'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update TEST_UPDATE_VERSION=1
	$(Q)echo Expecting version '4'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)$(MAKE) clean
	$(Q)echo TEST PASSED

test-02-forward-update-allow-downgrade: $(EXPVER) FORCE
	$(Q)$(MAKE) test-erase
	$(Q)echo Creating and uploading factory image...
	$(Q)$(MAKE) test-factory ALLOW_DOWNGRADE=1
	$(Q)echo Expecting version '1'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=1
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update TEST_UPDATE_VERSION=4
	$(Q)echo Expecting version '4'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update TEST_UPDATE_VERSION=2
	$(Q)echo Expecting version '4'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=2
	$(Q)$(MAKE) clean
	$(Q)echo TEST PASSED

test-03-rollback: $(EXPVER) FORCE
	$(Q)$(MAKE) test-erase
	$(Q)echo Creating and uploading factory image...
	$(Q)$(MAKE) test-factory
	$(Q)echo Expecting version '1'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=1
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update TEST_UPDATE_VERSION=4
	$(Q)echo Expecting version '4'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update TEST_UPDATE_VERSION=5
	$(Q)echo Expecting version '5'
	$(Q)(test `$(EXPVER)` -eq 5)
	$(Q)echo
	$(Q)echo Resetting to trigger rollback...
	$(Q)$(MAKE) test-reset
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)$(MAKE) clean
	$(Q)echo TEST PASSED

test-11-forward-update-no-downgrade-ECC: $(EXPVER) FORCE
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=ECC256

test-13-rollback-ECC: $(EXPVER) FORCE
	$(Q)$(MAKE) test-03-rollback SIGN=ECC256

test-21-forward-update-no-downgrade-SPI: $(EXPVER) FORCE
	$(Q)$(MAKE) test-erase-ext
	$(Q)echo Creating and uploading factory image...
	$(Q)$(MAKE) test-factory $(SPI_OPTIONS)
	$(Q)echo Expecting version '1'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=1
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update-ext TEST_UPDATE_VERSION=4 $(SPI_OPTIONS)
	$(Q)echo Expecting version '4'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update-ext TEST_UPDATE_VERSION=1 $(SPI_OPTIONS)
	$(Q)echo Expecting version '4'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)$(MAKE) clean
	$(Q)echo TEST PASSED

test-23-rollback-SPI: $(EXPVER) FORCE
	$(Q)$(MAKE) test-erase-ext
	$(Q)echo Creating and uploading factory image...
	$(Q)$(MAKE) test-factory $(SPI_OPTIONS)
	$(Q)echo Expecting version '1'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=1
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update-ext TEST_UPDATE_VERSION=4 $(SPI_OPTIONS)
	$(Q)echo Expecting version '4'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)echo
	$(Q)echo Creating and uploading update image...
	$(Q)$(MAKE) test-update-ext TEST_UPDATE_VERSION=5 $(SPI_OPTIONS)
	$(Q)echo Expecting version '5'
	$(Q)(test `$(EXPVER)` -eq 5)
	$(Q)echo
	$(Q)echo Resetting to trigger rollback...
	$(Q)$(MAKE) test-reset
	$(Q)sleep 2
	$(Q)$(MAKE) check-version EXPECTED_VERSION=4
	$(Q)$(MAKE) clean
	$(Q)echo TEST PASSED

test-34-forward-self-update: $(EXPVER) FORCE
	$(Q)echo Creating and uploading factory image...
	$(Q)$(MAKE) clean
	$(Q)$(MAKE) distclean
	$(Q)$(MAKE) test-factory RAM_CODE=1 SIGN=$(SIGN)
	$(Q)echo Expecting version '1'
	$(Q)$(MAKE) check-version EXPECTED_VERSION=1
	$(Q)echo
	$(Q)echo Updating keys, firmware, bootloader
	$(Q)$(MAKE) test-self-update WOLFBOOT_VERSION=4 RAM_CODE=1 SIGN=$(SIGN)
	$(Q)sleep 2
	$(Q)$(MAKE) check-version EXPECTED_VERSION=2
	$(Q)$(MAKE) clean
	$(Q)echo TEST PASSED

test-44-forward-self-update-ECC: $(EXPVER) FORCE
	$(Q)$(MAKE) test-34-forward-self-update SIGN=ECC256

test-51-forward-update-no-downgrade-RSA: $(EXPVER) FORCE
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=RSA2048

test-53-rollback-RSA: $(EXPVER) FORCE
	$(Q)$(MAKE) test-03-rollback SIGN=RSA2048

test-61-forward-update-no-downgrade-TPM: $(EXPVER) FORCE
	$(Q)$(MAKE) test-spi-off || true
	$(Q)$(MAKE) tpm-unmute
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=ECC256 WOLFTPM=1 TPM2=1
	$(Q)$(MAKE) tpm-mute

test-63-rollback-TPM: $(EXPVER) FORCE
	$(Q)$(MAKE) test-spi-off || true
	$(Q)$(MAKE) tpm-unmute
	$(Q)$(MAKE) test-03-rollback SIGN=ECC256 WOLFTPM=1
	$(Q)$(MAKE) tpm-mute

test-71-forward-update-no-downgrade-RSA-4096: $(EXPVER) FORCE
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=RSA4096

test-73-rollback-RSA-4096: $(EXPVER) FORCE
	$(Q)$(MAKE) test-03-rollback SIGN=RSA4096

test-81-forward-update-no-downgrade-ED25519-SHA3: $(EXPVER) FORCE
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=ED25519 HASH=SHA3

test-91-forward-update-no-downgrade-ECC256-SHA3: $(EXPVER) FORCE
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=ECC256 HASH=SHA3

test-101-forward-update-no-downgrade-RSA2048-SHA3: $(EXPVER) FORCE
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=RSA2048 HASH=SHA3

test-111-forward-update-no-downgrade-RSA4096-SHA3: $(EXPVER) FORCE
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=RSA4096 HASH=SHA3

test-161-forward-update-no-downgrade-TPM-RSA: $(EXPVER) FORCE
	$(Q)$(MAKE) test-spi-off || true
	$(Q)$(MAKE) tpm-unmute
	$(Q)$(MAKE) test-01-forward-update-no-downgrade SIGN=RSA2048 WOLFTPM=1
	$(Q)$(MAKE) tpm-mute

test-163-rollback-TPM-RSA: $(EXPVER) FORCE
	$(Q)$(MAKE) test-spi-off || true
	$(Q)$(MAKE) tpm-unmute
	$(Q)$(MAKE) test-03-rollback SIGN=RSA2048 WOLFTPM=1
	$(Q)$(MAKE) tpm-mute

test-all: clean test-01-forward-update-no-downgrade test-02-forward-update-allow-downgrade test-03-rollback \
	test-11-forward-update-no-downgrade-ECC test-13-rollback-ECC test-21-forward-update-no-downgrade-SPI test-23-rollback-SPI \
	test-34-forward-self-update \
	test-44-forward-self-update-ECC \
	test-51-forward-update-no-downgrade-RSA \
	test-53-rollback-RSA \
	test-61-forward-update-no-downgrade-TPM \
	test-63-rollback-TPM \
	test-71-forward-update-no-downgrade-RSA-4096 \
	test-73-rollback-RSA-4096 \
	test-81-forward-update-no-downgrade-ED25519-SHA3 \
	test-91-forward-update-no-downgrade-ECC256-SHA3 \
	test-101-forward-update-no-downgrade-RSA2048-SHA3 \
	test-111-forward-update-no-downgrade-RSA4096-SHA3 \
	test-161-forward-update-no-downgrade-TPM-RSA \
	test-163-rollback-TPM-RSA
