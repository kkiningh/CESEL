module Frontend_test #(
    parameter INSTRUCTION_MEMORY_SIZE = 2 ** 10,
    parameter DATA_BUS_DATA_BITS = 32,
    parameter DATA_BUS_ADDR_BITS = 32,

    parameter INSTRUCTION_BITS = 32,
    parameter REGFILE_ADDR_BITS = 4,
    parameter IMMEDIATE_BITS = 8,
    parameter ALU_OP_BITS = 6
);

    /* Setup clock and reset */
    logic clock;
    logic reset;

    initial begin
        clock = '0;
        reset = '1;

        /* Clock */
        forever begin
            #10 clock = ~clock;
        end
    end

    initial begin
        /* Deassert reset after 100 ticks */
        #100 reset = ~reset;
    end

    /* Cycle counter */
    logic [31:0] cycle_count = '0;
    logic [31:0] cycle_count_since_reset = '0;

    always @(posedge clock) begin
        cycle_count <= cycle_count + 1'b1;
    end

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            cycle_count_since_reset <= '0;
        end else begin
            cycle_count_since_reset <= cycle_count_since_reset + 1'b1;
        end
    end

    /* Load the instruction memory */
    logic [INSTRUCTION_BITS-1:0] instruction_memory [INSTRUCTION_MEMORY_SIZE-1:0];
    initial begin
        $readmemh("instruction_memory.hex", instruction_memory);
    end

    /* Interface between memory and data bus */
    logic [DATA_BUS_DATA_BITS-1:0] data_bus_data;
    logic [DATA_BUS_ADDR_BITS-1:0] data_bus_addr;
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            data_bus_data <= '0;
        end else begin
            data_bus_data <= instruction_memory[data_bus_addr]; 
        end
    end

    /* DUT */
    logic [REGFILE_ADDR_BITS-1:0] read1_addr;
    logic [REGFILE_ADDR_BITS-1:0] read2_addr;
    logic [REGFILE_ADDR_BITS-1:0] write_addr;
    logic                         write_addr_en;
    logic [IMMEDIATE_BITS-1:0]    immediate;
    logic                         use_immediate;
    logic                         use_accumulate;
    logic [ALU_OP_BITS-1:0]       alu_op;
    logic                         halt;
    Controlpath #(
        .INSTRUCTION_BITS(INSTRUCTION_BITS),
        .REGFILE_ADDR_BITS(REGFILE_ADDR_BITS),
        .IMMEDIATE_BITS(IMMEDIATE_BITS),
        .ALU_OP_BITS(ALU_OP_BITS)
    ) dut (
        .clock,
        .reset,

        .data_bus_data(data_bus_data),
        .data_bus_addr(data_bus_addr),

        .alu_op(alu_op),
        .use_immediate(use_immediate),
        .use_accumulate(use_accumulate),

        .read1_addr(read1_addr),
        .read2_addr(read2_addr),
        .immediate(immediate),
        .write_addr(write_addr),
        .write_addr_en(write_addr_en),
        
        .halt(halt)
    );

    always @(posedge clock) begin
        if (cycle_count == 0) begin
            $display("          | Fetch    | Decode                                        |   ");
            $display("R | Cycle | InstAddr | Instr    | OP | A | R1 | R2 | Im | ? | Wr | ? | H ");
        end else begin
            $display("%c | %5d | %8H | %8H | %2H | %1b |  %1H |  %1H | %2H | %1b |  %1H | %1b | %1b ", 
                reset ? "R" : " ",
                cycle_count, 
                dut.if_.pc_ff,
                dut.decode.instruction,
                alu_op, use_accumulate, 
                read1_addr, read2_addr, 
                immediate, use_immediate,
                write_addr, write_addr_en,
                halt);
        end
    end

    initial begin
        #1000 $finish();
    end
endmodule
