VCS := vcs -full64 +lint=all -sverilog -timescale=1ns/1ps

all: Frontend_test

Frontend_test: frontend.sv frontend_test.sv
	$(VCS) $^ -top $@

Backend_test: backend.sv backend_test.sv
	$(VCS) $^ -top $@
