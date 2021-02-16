qemu-system-ppc -m 200 -nographic -M ppce500  -kernel wolfboot.elf -s -d in_asm,cpu --singlestep -D /dev/pts/6 -S

qemu-system-ppc -m 200 -nographic -M ppce500  -kernel wolfboot.elf -s -d in_asm,cpu --singlestep -S

gdb-multiarch wolfboot.elf -ex "target remote :1234"

# Refs
CRM - e6500 Core Reference Manual, Rev 0
EREF - EREF: A Programmer’s Reference Manual for Freescale Power Architecture Processors, Rev. 1 (EIS 2.1)
T2080RM - QorIQ T2080 Reference Manual, Rev. 3, 11/2016
MPC8544ERM - https://www.nxp.com/docs/en/reference-manual/MPC8544ERM.pdf
 
7.5.2.1 Address Space (AS) Value


## Early boot

CRM chapter 11



 * Save DBSR reset reason - probably not worth it. MRR in CRM 2.14.9
 * Print CIR for info (alias to SVR)
 * L1, LRAT, MMU capabilities?
 * display PIR and PVR for as cores start?
 * Registers to set
   * BUCSR - branch control
   * L1CSR0, L1CSR1, L1CSR2 - L1 Cache
   * PWRMGTCR0 - power management
   * HID0 - error management

 * Timer state - Not required
 * L2 - "Note that enabling either L1 cache without first enabling the L2 cache is not supported."
     * flash invalidate
     * enable
 * L1
   * flash clear
   * enable


* Set up CCSR TLB
* Set up L1 TLB and stack


T2080RM - -CCSR needs to not be overlapped with flash space
4.3.1.1 Updating CCSRBARs

Also MPC8544ERM 

