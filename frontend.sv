module InstructionFetch #(
    parameter DATA_BUS_DATA_BITS = 32,
    parameter DATA_BUS_ADDR_BITS = 32,
    parameter INSTRUCTION_BITS   = 32
) (
    input clock,
    input reset,

    /* Memory interface */
    input logic [DATA_BUS_DATA_BITS-1:0] data_bus_data,
    output logic [DATA_BUS_ADDR_BITS-1:0] data_bus_addr,

    output logic [INSTRUCTION_BITS-1:0] next_instruction
);
    logic [DATA_BUS_ADDR_BITS-1:0] pc;
    logic [DATA_BUS_ADDR_BITS-1:0] pc_ff;
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            pc_ff <= '0; 
        end else begin
            pc_ff <= pc;
        end
    end

    /* Always just fetch the next instruction */
    assign pc = pc_ff + 1;

    assign data_bus_addr = pc_ff;
    assign next_instruction = data_bus_data;
endmodule


module Decode #(
    parameter INSTRUCTION_BITS  = 32,
    parameter REGFILE_ADDR_BITS = 4,
    parameter IMMEDIATE_BITS    = 8,
    parameter ALU_OP_BITS       = 6
) (
    input clock,
    input reset,

    input logic [INSTRUCTION_BITS-1:0]   instruction,
    
    output logic [REGFILE_ADDR_BITS-1:0] read1_addr,
    output logic [REGFILE_ADDR_BITS-1:0] read2_addr,
    output logic [REGFILE_ADDR_BITS-1:0] write_addr,
    output logic                         write_addr_en,
    output logic [IMMEDIATE_BITS-1:0]    immediate,
    output logic                         use_immediate,
    output logic                         use_accumulate,
    output logic [ALU_OP_BITS-1:0]       alu_op,
    output logic                         halt
);
    /*  31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 09 08 07 06 05 04 03 02 01 00
     * | ALU OP          | 0| A|                                   | Read R1   | Read R2   | Write R   | R type instruction
     * | ALU OP          | 1| A|                                   |  Imm8                 | Write R   | I type instruction
     *
     * A = Use Accumulate
     */

    always_comb begin
        alu_op         = instruction[31:26];
        use_immediate  = instruction[25];
        use_accumulate = instruction[24];
       
        if (use_immediate) begin
            read1_addr = '0;
            read2_addr = '0;
            immediate  = instruction[11:4];
        end else begin
            read1_addr = instruction[11:8];
            read2_addr = instruction[ 7:4];
            immediate  = '0;
        end

        write_addr    = instruction[3:0];
        write_addr_en = '1;

        /* Halt is true if we get all zeros */
        halt = (instruction == '0);
    end
endmodule


module Controlpath #(
    parameter DATA_BUS_DATA_BITS = 32,
    parameter DATA_BUS_ADDR_BITS = 32,
    parameter INSTRUCTION_BITS   = 32,
    parameter REGFILE_ADDR_BITS  = 4,
    parameter IMMEDIATE_BITS     = 8,
    parameter ALU_OP_BITS        = 6
) (
    input clock,
    input reset,

    /* Memory interface */
    input logic [DATA_BUS_DATA_BITS-1:0] data_bus_data,
    output logic [DATA_BUS_ADDR_BITS-1:0] data_bus_addr,

    /* Datapath interface */
    output logic [REGFILE_ADDR_BITS-1:0] read1_addr,
    output logic [REGFILE_ADDR_BITS-1:0] read2_addr,
    output logic [REGFILE_ADDR_BITS-1:0] write_addr,
    output logic                         write_addr_en,
    output logic [IMMEDIATE_BITS-1:0]    immediate,
    output logic                         use_immediate,
    output logic                         use_accumulate,
    output logic [ALU_OP_BITS-1:0]       alu_op,
    output logic                         halt
);
    /* Instruction Fetch Stage */
    logic [INSTRUCTION_BITS-1:0] if_instruction;
    InstructionFetch #(
        .DATA_BUS_DATA_BITS(DATA_BUS_DATA_BITS),
        .DATA_BUS_ADDR_BITS(DATA_BUS_DATA_BITS),
        .INSTRUCTION_BITS(INSTRUCTION_BITS)
    ) if_ (
        .clock,
        .reset,

        .data_bus_data(data_bus_data),
        .data_bus_addr(data_bus_addr),

        .next_instruction(if_instruction)
    );

    logic [INSTRUCTION_BITS-1:0] if_instruction_ff;
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            if_instruction_ff <= '0;
        end else begin
            if_instruction_ff <= if_instruction;
        end
    end

    /* Decode Stage */
    logic [INSTRUCTION_BITS-1:0]  de_instruction;
    assign de_instruction = if_instruction_ff;

    logic [REGFILE_ADDR_BITS-1:0] de_read1_addr;
    logic [REGFILE_ADDR_BITS-1:0] de_read2_addr;
    logic [REGFILE_ADDR_BITS-1:0] de_write_addr;
    logic                         de_write_addr_en;
    logic [IMMEDIATE_BITS-1:0]    de_immediate;
    logic                         de_use_immediate;
    logic                         de_use_accumulate;
    logic [ALU_OP_BITS-1:0]       de_alu_op;
    logic                         de_halt;
    Decode #(
        .INSTRUCTION_BITS(INSTRUCTION_BITS),
        .REGFILE_ADDR_BITS(REGFILE_ADDR_BITS),
        .IMMEDIATE_BITS(IMMEDIATE_BITS),
        .ALU_OP_BITS(ALU_OP_BITS)
    ) decode (
        .clock,
        .reset,
        .instruction(de_instruction),

        .alu_op(de_alu_op),
        .use_immediate(de_use_immediate),
        .use_accumulate(de_use_accumulate),

        .read1_addr(de_read1_addr),
        .read2_addr(de_read2_addr),
        .immediate(de_immediate),
        .write_addr(de_write_addr),
        .write_addr_en(de_write_addr_en),

        .halt(de_halt)
    );

    logic [REGFILE_ADDR_BITS-1:0] de_read1_addr_ff;
    logic [REGFILE_ADDR_BITS-1:0] de_read2_addr_ff;
    logic [REGFILE_ADDR_BITS-1:0] de_write_addr_ff;
    logic                         de_write_addr_en_ff;
    logic [IMMEDIATE_BITS-1:0]    de_immediate_ff;
    logic                         de_use_immediate_ff;
    logic                         de_use_accumulate_ff;
    logic [ALU_OP_BITS-1:0]       de_alu_op_ff;
    logic                         de_halt_ff;
    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            de_read1_addr_ff     <= '0;
            de_read2_addr_ff     <= '0;
            de_write_addr_ff     <= '0;
            de_write_addr_en_ff  <= '0;
            de_immediate_ff      <= '0;
            de_use_immediate_ff  <= '0; 
            de_use_accumulate_ff <= '0;
            de_alu_op_ff         <= '0;
            de_halt_ff           <= '0;
        end else begin
            de_read1_addr_ff     <= de_read1_addr;
            de_read2_addr_ff     <= de_read2_addr;
            de_write_addr_ff     <= de_write_addr;
            de_write_addr_en_ff  <= de_write_addr_en;
            de_immediate_ff      <= de_immediate;
            de_use_immediate_ff  <= de_use_immediate;
            de_use_accumulate_ff <= de_use_accumulate;
            de_alu_op_ff         <= de_alu_op;
            de_halt_ff           <= de_halt;
        end
    end

    /* Outputs */
    assign read1_addr     = de_read1_addr_ff;
    assign read2_addr     = de_read2_addr_ff;
    assign write_addr     = de_write_addr_ff;
    assign write_addr_en  = de_write_addr_en_ff;
    assign immediate      = de_immediate_ff;
    assign use_immediate  = de_use_immediate_ff;
    assign use_accumulate = de_use_accumulate_ff;
    assign alu_op         = de_alu_op_ff;
    assign halt           = de_halt;
endmodule
