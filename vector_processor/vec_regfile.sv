//Author        : Zawaher Bin Asim , UET Lahore
//Description   : This the   register file of the vector processor
// Date         : 20 Sep, 2024.




`include "vec_regfile_defs.svh"

module vec_regfile (
    // Inputs
    input   logic                           clk, reset,
    input   logic   [ADDR_WIDTH-1:0]        raddr_1, raddr_2,  // The address of the vector registers to be read
    input   logic   [DATA_WIDTH-1:0]        wdata,             // The vector that is to be written in the vector register
    input   logic   [ADDR_WIDTH-1:0]        waddr,             // The address of the vector register where the vector is written
    input   logic                           wr_en,             // The enable signal to write in the vector register 
    input   logic   [3:0]                   lmul,              // LMUL value (controls register granularity)
    input   logic   [3:0]                   emul,              // EMUL value (controls register granularity)
    input   logic                           offset_vec_en,     // Tells the rdata2 vector is offset vector and will be chosen on base of emul
    input   logic                           mask_operation,    // This signal tell this instruction is going to perform mask register update 
    input   logic                           mask_wr_en,        // This the enable signal for updating the mask value                                                
    // Outputs 
    output  logic   [DATA_WIDTH-1:0]        rdata_1, rdata_2,  // The read data from the vector register file
    output  logic   [DATA_WIDTH-1:0]        dst_data,          // The data of the destination register that is to be replaced with the data after the opertaion and masking
    output  logic   [VECTOR_LENGTH-1:0]     vector_length,     // Width of the vector depending on LMUL
    output  logic                           wrong_addr,        // Signal to indicate an invalid address
    output  logic   [`VLEN-1:0]             v0_mask_data,      // The data of the mask register that is v0 in register file 
    output  logic                           data_written       // tells that data is written to the register file
);

    logic temp_wrong_addr ;                                    // Temporary variable to hold error state
    logic addr_error , addr_error_emul;                        // Temporary signal for address error checking
    logic   [DATA_WIDTH-1:0]  rdata_2_lmul,rdata_2_emul;       // Temporary rdata_2 across emul and lmul
    
    // Fixed-size Vector Register File (VLEN and MAX_VEC_REGISTERS)
    logic [`VLEN-1:0] vec_regfile [`MAX_VEC_REGISTERS-1:0];

    // Dynamically calculate vector length and number of registers based on LMUL
    always_comb begin
        
        vector_length = `VLEN;

        case (lmul)
            4'b0001: vector_length = `VLEN;        // LMUL = 1
            4'b0010: vector_length = 2 * `VLEN;    // LMUL = 2
            4'b0100: vector_length = 4 * `VLEN;    // LMUL = 4
            4'b1000: vector_length = 8 * `VLEN;    // LMUL = 8
            default: vector_length = `VLEN;
        endcase
    end

    // assigning the data of v0 to mask_data
    assign v0_mask_data = vec_regfile[0];

    
    // Address validation and read operation
    always_comb begin
        rdata_1          = 'h0;
        rdata_2_emul     = 'h0;
        rdata_2_lmul     = 'h0;
        rdata_2          = 'h0;
        dst_data         = 'h0;
        addr_error       =   0;
        addr_error_emul  =   0;
        // If the mask logical operations is to perform then the rdata should 
        // get the vector register at the addr regarless of the lmul value

        if (mask_operation)begin

            rdata_1 = vec_regfile[raddr_1];
            rdata_2 = vec_regfile[raddr_2];
        end
        // Read operation for rdata_1, rdata_2, and dst_data based on lmul
        else begin
            
            case (emul)
                4'b0001: begin // EMUL = 1
                    if (raddr_2 >= `MAX_VEC_REGISTERS) begin
                        addr_error_emul = 1;
                    end else begin
                    rdata_2_emul = vec_regfile[raddr_2];                        
                    end
                end
                4'b0010: begin // EMUL = 2
                    if ( raddr_2 >= `MAX_VEC_REGISTERS - 1 ||  raddr_2 % 2 != 0 ) begin
                        addr_error_emul = 1;
                    end else begin
                        rdata_2_emul = {vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                    end
                end
                4'b0100: begin // LMUL = 4
                    if (raddr_2 >= `MAX_VEC_REGISTERS - 3 || raddr_2 % 4 != 0 ) begin
                        addr_error_emul = 1;
                    end else begin
                        rdata_2_emul = {vec_regfile[raddr_2 + 3], vec_regfile[raddr_2 + 2], vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                    end
                end
                4'b1000: begin // LMUL = 8
                    if (raddr_2 >= `MAX_VEC_REGISTERS - 7 || raddr_2 % 8 != 0 ) begin
                        addr_error_emul = 1;
                    end else begin
                        rdata_2_emul = {vec_regfile[raddr_2 + 7], vec_regfile[raddr_2 + 6], vec_regfile[raddr_2 + 5], vec_regfile[raddr_2 + 4],
                                vec_regfile[raddr_2 + 3], vec_regfile[raddr_2 + 2], vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                    end
                end
                default: begin 
                    rdata_2_emul = 'h0;
                    addr_error_emul = 1;  // Flag an error for invalid EMUL
                end
            endcase

            case (lmul)
                4'b0001: begin // LMUL = 1
                    if (raddr_1 >= `MAX_VEC_REGISTERS || raddr_2 >= `MAX_VEC_REGISTERS || waddr >= `MAX_VEC_REGISTERS) begin
                        addr_error = 1;
                    end else begin
                        rdata_1      = vec_regfile[raddr_1];
                        rdata_2_lmul = vec_regfile[raddr_2];
                        dst_data     = vec_regfile[waddr]; // Read data at waddr
                    end
                end
                4'b0010: begin // LMUL = 2
                    if (raddr_1 >= `MAX_VEC_REGISTERS - 1 || raddr_2 >= `MAX_VEC_REGISTERS - 1 || waddr >= `MAX_VEC_REGISTERS -1 ||
                        raddr_1 % 2 != 0 || raddr_2 % 2 != 0 || waddr % 2 != 0) begin
                        addr_error = 1;
                    end else begin
                        rdata_1      = {vec_regfile[raddr_1 + 1], vec_regfile[raddr_1]};
                        rdata_2_lmul = {vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                        dst_data     = {vec_regfile[waddr + 1], vec_regfile[waddr]}; // Read data at waddr
                    end
                end
                4'b0100: begin // LMUL = 4
                    if (raddr_1 >= `MAX_VEC_REGISTERS - 3 || raddr_2 >= `MAX_VEC_REGISTERS - 3 || waddr >= `MAX_VEC_REGISTERS -3 ||
                        raddr_1 % 4 != 0 || raddr_2 % 4 != 0 || waddr % 4 != 0) begin
                        addr_error = 1;
                    end else begin
                        rdata_1      = {vec_regfile[raddr_1 + 3], vec_regfile[raddr_1 + 2], vec_regfile[raddr_1 + 1], vec_regfile[raddr_1]};
                        rdata_2_lmul = {vec_regfile[raddr_2 + 3], vec_regfile[raddr_2 + 2], vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                        dst_data     = {vec_regfile[waddr + 3], vec_regfile[waddr + 2], vec_regfile[waddr + 1], vec_regfile[waddr]}; // Read data at waddr
                    end
                end
                4'b1000: begin // LMUL = 8
                    if (raddr_1 >= `MAX_VEC_REGISTERS - 7 || raddr_2 >= `MAX_VEC_REGISTERS - 7 || waddr >= `MAX_VEC_REGISTERS -7 ||
                        raddr_1 % 8 != 0 || raddr_2 % 8 != 0 || waddr % 8 != 0) begin
                        addr_error = 1;
                    end else begin
                        rdata_1      = {vec_regfile[raddr_1 + 7], vec_regfile[raddr_1 + 6], vec_regfile[raddr_1 + 5], vec_regfile[raddr_1 + 4],
                                        vec_regfile[raddr_1 + 3], vec_regfile[raddr_1 + 2], vec_regfile[raddr_1 + 1], vec_regfile[raddr_1]};
                        rdata_2_lmul = {vec_regfile[raddr_2 + 7], vec_regfile[raddr_2 + 6], vec_regfile[raddr_2 + 5], vec_regfile[raddr_2 + 4],
                                        vec_regfile[raddr_2 + 3], vec_regfile[raddr_2 + 2], vec_regfile[raddr_2 + 1], vec_regfile[raddr_2]};
                        dst_data     = {vec_regfile[waddr + 7], vec_regfile[waddr + 6], vec_regfile[waddr + 5], vec_regfile[waddr + 4],
                                        vec_regfile[waddr + 3], vec_regfile[waddr + 2], vec_regfile[waddr + 1], vec_regfile[waddr]}; // Read data at waddr
                    end
                end
                default: begin 
                    
                    rdata_1      = 'h0;
                    rdata_2_lmul = 'h0;
                    rdata_2_emul = 'h0;
                    dst_data     = 'h0;
                    addr_error   = 1;  // Flag an error for invalid LMUL
                end

            endcase
        end
        // RDATA2 MUX for selection b/w data based on lmul and emul
        rdata_2 = (offset_vec_en) ? rdata_2_emul : rdata_2_lmul;  
    end
     
    
    // Write operation and error handling for both read and write addresses
    always_ff @(negedge clk or negedge reset) begin
        if (!reset) begin
            // Reset all registers
            for (int i = 0; i < `MAX_VEC_REGISTERS; i++) begin
                vec_regfile[i] <= 'h0;
            end
            wrong_addr <= 0;
            data_written <= 0;
        end else begin
            data_written <= 0;
            
            // Writing to  the v0 register to update the mask value          
            if (mask_wr_en)begin
                vec_regfile[0] <= wdata[`VLEN-1:0];
                data_written   <= 1'b1;
            end

            // If The write addr is 0 then the bits  for the v0 register will retain their value and others will bw updated    

            else if (wr_en) begin
                wrong_addr   <= 0;
                data_written <= 0;
                // Check for valid write addresses
                case (lmul)
                    4'b0001: begin
                        if (waddr >= `MAX_VEC_REGISTERS) begin
                            wrong_addr <= 1;
                        end else begin
                            if (waddr == 0)begin
                                vec_regfile[waddr] <= vec_regfile[0];
                            end
                            vec_regfile[waddr] <= wdata[`VLEN-1:0];
                            data_written       <= 1'b1;
                        end
                    end
                    4'b0010: begin
                        if (waddr >= `MAX_VEC_REGISTERS - 1 || waddr % 2 != 0) begin
                            wrong_addr <= 1;
                        end else begin
                            if (waddr == 0)begin
                                vec_regfile[waddr] <= vec_regfile[0];
                            end
                            else begin
                                vec_regfile[waddr]     <= wdata[`VLEN-1:0];    
                            end

                            vec_regfile[waddr + 1] <= wdata[2*`VLEN-1:`VLEN];
                            data_written           <= 1'b1;
                        end
                    end
                    4'b0100: begin
                        if (waddr >= `MAX_VEC_REGISTERS - 3 || waddr % 4 != 0) begin
                            wrong_addr <= 1;
                        end else begin
                            if (waddr == 0)begin
                                vec_regfile[waddr] <= vec_regfile[0];
                            end
                            else begin
                                vec_regfile[waddr]     <= wdata[`VLEN-1:0];    
                            end
                            
                            vec_regfile[waddr + 1] <= wdata[2*`VLEN-1:`VLEN];
                            vec_regfile[waddr + 2] <= wdata[3*`VLEN-1:2*`VLEN];
                            vec_regfile[waddr + 3] <= wdata[4*`VLEN-1:3*`VLEN];
                            data_written           <= 1'b1;
                        end
                    end
                    4'b1000: begin
                        if (waddr >= `MAX_VEC_REGISTERS - 7 || waddr % 8 != 0) begin
                            wrong_addr <= 1;
                        end else begin
                            if (waddr == 0)begin
                                vec_regfile[waddr] <= vec_regfile[0];
                            end
                            else begin
                                vec_regfile[waddr]     <= wdata[`VLEN-1:0];    
                            end
                            
                            vec_regfile[waddr + 1] <= wdata[2*`VLEN-1:`VLEN];
                            vec_regfile[waddr + 2] <= wdata[3*`VLEN-1:2*`VLEN];
                            vec_regfile[waddr + 3] <= wdata[4*`VLEN-1:3*`VLEN];
                            vec_regfile[waddr + 4] <= wdata[5*`VLEN-1:4*`VLEN];
                            vec_regfile[waddr + 5] <= wdata[6*`VLEN-1:5*`VLEN];
                            vec_regfile[waddr + 6] <= wdata[7*`VLEN-1:6*`VLEN];
                            vec_regfile[waddr + 7] <= wdata[8*`VLEN-1:7*`VLEN];
                            data_written           <= 1'b1;
                        end
                    end
                    default: begin 
                        wrong_addr <= 0;
                        data_written <= 0;
                    end
                endcase
            end else begin
                wrong_addr <= addr_error | addr_error_emul;  // Capture address error during read
                data_written <= 0;
            end
        end
    end


endmodule
