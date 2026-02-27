ASM=wla-z80
LINK=wlalink

all: demo.sms

demo.o: demo.asm
	$(ASM) -o $@ $<

demo.sms: demo.o linkfile
	$(LINK) -S -d linkfile $@

clean:
	rm -f demo.o demo.sms
