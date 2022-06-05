HDL = $(wildcard src/*.v)

# Bitstream Generation
build/top.bin: build/top.asc
	icepack $< $@

# Place 'n route
build/top.asc: build/top.json upduino.pcf
	nextpnr-ice40 --up5k --package sg48 --no-promote-globals --json build/top.json --pcf upduino.pcf --asc $@

# Synthesis
build/top.json: top.v $(HDL)
	@mkdir -p $(@D)
	cd $(@D) && yosys -q -p 'synth_ice40 -flatten -top top -json $(realpath $@)' $(realpath top.v $(HDL))


build/report.txt: top.v $(HDL)
	@mkdir -p $(@D)
	cd $(@D) && yosys -p 'synth_ice40 -noflatten' $(realpath top.v $(HDL)) > $(realpath $@)

# Compile testbench
build/%.vvp: test/%.v $(HDL)
	@mkdir -p $(@D)
	cd $(@D) && iverilog -o $(realpath $@) -s tb $(realpath $< $(HDL))

# Simulate for waveform
build/%.vcd: build/%.vvp
	cd $(@D) && vvp $(realpath $<) # vcd path is specified in testbench

# Display waveform
.PHONY: sim
sim: build/test_bench.vcd
	gtkwave build/test_bench.vcd env/scope.gtkw


# Program FPGA
.PHONY: run
run: build/top.bin
	iceprog -S -d i:0x0403:0x6014 $<
# 	iceprog -S -d i:0x0403:0xE014 $<

.PHONY: flash
flash: build/top.bin
	iceprog -S -d i:0x0403:0x6014 $<
# 	iceprog -d i:0x0403:0xE014 $<

.PHONY: clean
clean:
	$(RM) -rf build

.PHONY: report
report: build/report.txt
	grep -A 10000 'Printing statistics' $(realpath $<)
