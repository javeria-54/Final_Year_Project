// Author        : Zawaher Bin Asim , UET Lahore
// Description   : This is the testbench for the register file of the vector processor
// Date         : 13 Sep, 2024.

`timescale 1ns / 1ps


module vec_regfile_tb(

    `ifdef Verilator
        input logic clk
    `endif

);
    `define VLEN 512

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter MAX_VLEN = 4096;
    parameter MAX_VEC_REGISTERS = 32;
    parameter DATA_WIDTH = MAX_VLEN;
    parameter VECTOR_LENGTH = $clog2(MAX_VLEN);

    // Inputs
    `ifndef Verilator
    logic clk;
    `endif

    logic reset;
    logic [ADDR_WIDTH-1:0] raddr_1, raddr_2;
    logic [DATA_WIDTH-1:0] wdata;
    logic [ADDR_WIDTH-1:0] waddr;
    logic wr_en;
    logic [3:0] lmul;
    logic [`VLEN -1 : 0]v0_mask_data;
    logic mask_operation;
    logic mask_wr_en;

    // Outputs
    logic [DATA_WIDTH-1:0] rdata_1;
    logic [DATA_WIDTH-1:0] rdata_2;
    logic [DATA_WIDTH-1:0] dst_data;
    logic [VECTOR_LENGTH-1:0] vector_length;
    logic wrong_addr;
    logic data_written;

    // Vector Register File instantiation
    vec_regfile uut (
        .clk(clk),
        .reset(reset),
        .raddr_1(raddr_1),
        .raddr_2(raddr_2),
        .wdata(wdata),
        .waddr(waddr),
        .wr_en(wr_en),
        .lmul(lmul),
        .rdata_1(rdata_1),
        .rdata_2(rdata_2),
        .dst_data(dst_data),
        .vector_length(vector_length),
        .wrong_addr(wrong_addr),
        .mask_operation(mask_operation),
        .v0_mask_data(v0_mask_data),
        .mask_wr_en(mask_wr_en),
        .data_written(data_written)
    );

    // Testbench Variables
    integer i;
    logic [`VLEN-1:0] expected_data [MAX_VEC_REGISTERS-1:0];
    logic [DATA_WIDTH-1:0] read_data_1, read_data_2 , read_dst_data;
    logic operation;

    `ifndef Verilator
    initial begin
        // Clock generation
        clk <= 0;
        forever #5 clk <= ~clk;
    end
    `endif

    // Main Testbench
    initial begin
        init_signals();

        // Resetting the unit
        reset_sequence();

        // Resetting the dummy register file
        for (i = 0; i < MAX_VEC_REGISTERS; i++) begin
            expected_data[i] <= 'h0;
        end

        // Run the directed test
       // directed_test();

       masking_operands_test();
       @(negedge clk);

        $display("======= Starting Random Tests =======");

        repeat(15) begin
            // Ensure LMUL selection happens first
            lmul_selection();

            // Fork the driver, monitor, and dummy register write to run in parallel
            
            
            fork
                driver();
                dummy_regfile_write();
                monitor();   
            join 
            
            
            
        end

        $finish;
    end

    // Initialize signals
    task init_signals();
        raddr_1 <= 'h0;
        raddr_2 <= 'h0;
        wr_en   <= 'h0;
        waddr   <= 'h0;
        lmul    <= 'h1;
        wdata   <= 'h0;
        @(posedge clk);
    endtask

    // Reset task
    task reset_sequence();
        begin
            reset <= 1;
            @(posedge clk);
            reset <= 0;
            @(posedge clk);
            reset <= 1;
            @(posedge clk);
        end
    endtask

    // LMUL selection task
    task lmul_selection();
        logic [1:0] random_lmul;
        @(negedge clk);  // Pick LMUL on negative clock edge
        random_lmul <= $urandom_range(0, 3);
        case (random_lmul)
            2'b00 : lmul = 1;
            2'b01 : lmul = 2;
            2'b10 : lmul = 4;
            2'b11 : lmul = 8;
        endcase
        $display("LMUL value at the start = %0d", lmul);
        @(negedge clk);
    endtask

    // Driver task (synchronous writes, asynchronous reads)
    task driver();
        operation = $urandom_range(0, 1);  // Randomly select read or write operation
        if (operation == 0) begin
            // Asynchronous reads
            raddr_1 <= $urandom_range(0, 31);
            raddr_2 <= $urandom_range(0, 31);
            waddr   <= $urandom_range(0, 31);
        
            
        end else begin
            // Synchronous writes at negedge
            waddr <= $urandom_range(0, 31);
            wdata <= $random;
            wr_en <= 1'b1;
            @(negedge clk);  // De-assert after write
            wr_en <= 1'b0;
        

        end
    endtask

    // Monitor task
    task monitor();
        @(negedge clk);
        @(negedge clk);
        if (wrong_addr) begin
            $display("======= Invalid Address Detected =======");
            $display("raddr_1 = %0d, raddr_2 = %0d, waddr = %0d", raddr_1, raddr_2, waddr);
            $display("LMUL = %0d", lmul);
            $display("operation = %s", operation ? "write" : "read");
        end else begin
            while (!data_written)begin
                @(negedge clk);
            end
            // Check the result
            read_data_1     <= rdata_1;
            read_data_2     <= rdata_2;
            read_dst_data   <= dst_data;


            if (operation == 0) begin
                compare_read_data();
            end else begin
                check_write_data();
            end
        end
    endtask

    // Compare read data (asynchronous reads)
    task compare_read_data();
        logic [DATA_WIDTH-1:0] expected_data_1, expected_data_2,expected_data_3;

        case (lmul)
            1: begin
                expected_data_1 = expected_data[raddr_1];
                expected_data_2 = expected_data[raddr_2];
                expected_data_3 = expected_data[waddr];
            end
            2: begin
                expected_data_1 = {expected_data[raddr_1 + 1], expected_data[raddr_1]};
                expected_data_2 = {expected_data[raddr_2 + 1], expected_data[raddr_2]};
                expected_data_3 = {expected_data[waddr + 1], expected_data[waddr]};
            end
            4: begin
                expected_data_1 = {expected_data[raddr_1 + 3], expected_data[raddr_1 + 2], expected_data[raddr_1 + 1], expected_data[raddr_1]};
                expected_data_2 = {expected_data[raddr_2 + 3], expected_data[raddr_2 + 2], expected_data[raddr_2 + 1], expected_data[raddr_2]};
                expected_data_3 = {expected_data[waddr + 3], expected_data[waddr + 2], expected_data[waddr + 1], expected_data[waddr]};
            end
            8: begin
                expected_data_1 = {expected_data[raddr_1 + 7], expected_data[raddr_1 + 6], expected_data[raddr_1 + 5], expected_data[raddr_1 + 4],
                                   expected_data[raddr_1 + 3], expected_data[raddr_1 + 2], expected_data[raddr_1 + 1], expected_data[raddr_1]};
                expected_data_2 = {expected_data[raddr_2 + 7], expected_data[raddr_2 + 6], expected_data[raddr_2 + 5], expected_data[raddr_2 + 4],
                                   expected_data[raddr_2 + 3], expected_data[raddr_2 + 2], expected_data[raddr_2 + 1], expected_data[raddr_2]};
                expected_data_3 = {expected_data[waddr + 7], expected_data[waddr + 6], expected_data[waddr + 5], expected_data[waddr + 4],
                                   expected_data[waddr + 3], expected_data[waddr + 2], expected_data[waddr + 1], expected_data[waddr]};
            end
        endcase

        @(negedge clk);

        if ((expected_data_1 == read_data_1) && (expected_data_2 == read_data_2) && (expected_data_3 == read_dst_data)) begin
            $display("================== Read Test Passed ==================");
            $display("raddr_1 = %0d, raddr_2 = %0d", raddr_1, raddr_2);
            $display("read_data_1 = %0d", $signed(read_data_1));
            $display("read_data_2 = %0d", $signed(read_data_2));
            $display("read_dst_data = %0d", $signed(read_dst_data));
            $display("LMUL = %d ", lmul);
        end else begin
            $display("================== Read Test Failed ==================");
            $display("raddr_1 = %0d, raddr_2 = %0d , waddr = %d", raddr_1, raddr_2 ,waddr);
            $display("read_data_1 = %0h, expected_data_1 = %0h", read_data_1, expected_data_1);
            $display("read_data_2 = %0h, expected_data_2 = %0h", read_data_2, expected_data_2);
            $display("read_dst_data = %0h, expected_data_3 = %0h", read_dst_data, expected_data_3);
        end
    endtask

    // Check write data task
    task check_write_data();
        logic [DATA_WIDTH-1:0] expected_wdata;
        @(negedge clk);
        case (lmul)
            1: expected_wdata = expected_data[waddr];
            
            2: begin
                expected_wdata = {expected_data[waddr + 1], expected_data[waddr]};
            end
            4: begin
                expected_wdata = {expected_data[waddr + 3], expected_data[waddr + 2], expected_data[waddr + 1], expected_data[waddr]};
            end
            8: begin
                expected_wdata = {expected_data[waddr + 7], expected_data[waddr + 6], expected_data[waddr + 5], expected_data[waddr + 4],
                                  expected_data[waddr + 3], expected_data[waddr + 2], expected_data[waddr + 1], expected_data[waddr]};
            end
        endcase

        // Reading the data from the write address
        raddr_1 <= 'h0;
        raddr_2 <= 'h0;
        waddr   <= waddr;
        @(negedge clk);
        read_dst_data <=  dst_data;
        @(negedge clk);

        if (expected_wdata == read_dst_data) begin
            $display("================== Write Test Passed ==================");
            $display("wdata = %0d, waddr = %0d", wdata, waddr);
        end else begin
            $display("================== Write Test Failed ==================");
            $display("actual_data = %0d, expected_wdata = %0d", read_dst_data, expected_wdata);
            $display("wdata = %0d, waddr = %0d", wdata, waddr);
        end
    endtask

    task dummy_regfile_write();
        @(negedge clk);
        @(negedge clk);
        if (operation == 1 &  !wrong_addr) begin
            case(lmul)
                1: expected_data[waddr] = wdata[`VLEN-1:0];
                2: begin
                    expected_data[waddr]     = wdata[`VLEN-1:0];
                    expected_data[waddr + 1] = wdata[2*`VLEN-1:`VLEN];
                end
                4: begin
                    expected_data[waddr]     = wdata[`VLEN-1:0];
                    expected_data[waddr + 1] = wdata[2*`VLEN-1:`VLEN];
                    expected_data[waddr + 2] = wdata[3*`VLEN-1:2*`VLEN];
                    expected_data[waddr + 3] = wdata[4*`VLEN-1:3*`VLEN];
                end
                8: begin
                    expected_data[waddr]     = wdata[`VLEN-1:0];
                    expected_data[waddr + 1] = wdata[2*`VLEN-1:`VLEN];
                    expected_data[waddr + 2] = wdata[3*`VLEN-1:2*`VLEN];
                    expected_data[waddr + 3] = wdata[4*`VLEN-1:3*`VLEN];
                    expected_data[waddr + 4] = wdata[5*`VLEN-1:4*`VLEN];
                    expected_data[waddr + 5] = wdata[6*`VLEN-1:5*`VLEN];
                    expected_data[waddr + 6] = wdata[7*`VLEN-1:6*`VLEN];
                    expected_data[waddr + 7] = wdata[8*`VLEN-1:7*`VLEN];
                end
            endcase
        end else begin
            if (operation == 1 ) begin 
                $display("Skipping the write in dummy regfile due to invalid address");
            end
        end

    endtask

    task masking_operands_test();
        
        logic expected_mask_reg_data_1 , expected_mask_reg_data_2 , expected_mask_reg_write_data;
        logic mask_op;
        
        mask_op <= $urandom_range(0,1);
        if (mask_op == 0)begin
            raddr_1 <= $urandom_range(0,31);
            raddr_2 <= $urandom_range(0,31);
            @(negedge clk);
            read_data_1 <= rdata_1;
            read_data_2 <= rdata_2;

            expected_mask_reg_data_1 <= expected_data[raddr_1];
            expected_mask_reg_data_2 <= expected_data[raddr_2];

            @(negedge clk);

            if((expected_mask_reg_data_1 == read_data_1) && (expected_mask_reg_data_2 == read_data_2))begin
                $display("=================== Masking Operand Test Passed =========================");
                $display("read_data_1 =  %d  |  read_data_2 = %d ", read_data_1 , read_data_2 );

            end
            else begin
                $display("=================== Masking Operand Test Failed =========================");
                $display("read_data_1 =  %d  |  expected_read_data_1 = %d ", read_data_1 , expected_mask_reg_data_1 );
                $display("read_data_2 =  %d  |  expected_read_data_2 = %d ", read_data_2 , expected_mask_reg_data_2 );
            end
        end

        else begin

            $display("THE DATA OF MASK REG BEFORE WRITE is : %d" , v0_mask_data);
            waddr <= 'h0;
            wdata <= 'hDEADBEEF;
            mask_wr_en <= 1'b1;
            @(negedge clk);
            mask_wr_en <= 1'b0;


            // write the data to the v0 register  of the expected data
            expected_data[waddr] = 'hDEADBEEF;

            @(negedge clk);
            
            if (expected_data[waddr] == v0_mask_data)begin
                $display("=================== MASKING WRITE TEST PASSED ==================");
                $display("THE DATA OF MASK REG AFTER WRITE is : %d" , v0_mask_data);  
            end
            else begin
                $display("=================== MASKING WRITE TEST FAILED ==================");
                $display("THE DATA OF MASK REG AFTER WRITE is : %d" , v0_mask_data);
                $display("THE EXPECTED MASK REG DATA : %d ", 'hDEADBEEF);
            end
        end

    endtask

    task directed_test();
        $display("======= Starting Directed Test =======");
        
        @(posedge clk);
        // Initialize with a known value
        waddr <= 5;
        wdata <= 32'hDEADBEEF;
        @(negedge clk);
        wr_en <= 1'b1;
        @(negedge clk);

        dummy_regfile_write();

        wr_en <= 1'b0;
        
        operation = 1;
        
        monitor();
    endtask

endmodule
