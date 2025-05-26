VASM = vasmm68k_mot
VASMFLAGS = -Fhunkexe -o

all: demo

demo: src/demo.s
	$(VASM) $(VASMFLAGS) $@ $<

clean:
	rm -f demo 