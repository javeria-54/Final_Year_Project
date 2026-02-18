//Author        : Zawaher Bin Asim , UET Lahore       <zawaherbinasim.333@gmail.com>
//            
//Description   : This is the load store unit of the vector processor containing the 
//                Addess Generation Unit , Load Store Controller , Memory DATA Management for Load and Store

// Date         : 15 JUNE , 2025.



`include "vec_regfile_defs.svh"
`include "axi_4_defs.svh"

module vec_lsu (
    input   logic                               clk,
    input   logic                               n_rst,

    // Scalar Processor -> vec_lsu
    input   logic   [`XLEN-1:0]                 rs1_data,       // Base address
    input   logic   [`XLEN-1:0]                 rs2_data,       // Stride

    // CSR Register File -> vec_lsu
    input   logic   [9:0]                       vlmax,          // Max number of elements in a vector
    input   logic   [6:0]                       sew,            // Element width

    // Vector Processor Controller -> vec_lsu
    input   logic                               stride_sel,     // Unit stride select
    input   logic                               ld_inst,        // Load instruction
    input   logic                               st_inst,        // Store instruction
    input   logic                               index_str,      // tells about index stride
    input   logic                               index_unordered,// tells about index unordered stride
 
    // vec_register_file -> vec_lsu
    input   logic   [`MAX_VLEN-1:0]             vs2_data,       // vector register that tell the offset 
    input   logic   [`MAX_VLEN-1:0]             vs3_data,       // vector register that tells that data to be stored
    
    // vec_decode -> vec_lsu
    input   logic                               mew,            // Not used in this context
    input   logic   [2:0]                       width,          // Memory access width

    // datapath ---> vec_lsu
    input   logic                               inst_done,      // tells  load inst or the store inst completed

    // vec_lsu -> AXI 4 MASTER
    output  logic   [`XLEN-1:0]                 lsu2mem_addr,   // Memory address
    output  logic   [`DATA_BUS*`BURST_MAX-1:0]  lsu2mem_data,   // Stored Data
    output  logic                               ld_req,         // Load request
    output  logic                               st_req,         // Store request
    output  logic   [WR_STROB*`BURST_MAX-1:0]   wr_strobe,      // THE bytes of the DATA_BUS that contains the actual data 
    output  logic   [7:0]                       burst_len,      // TElls the length of the burst
    output  logic   [2:0]                       burst_size,     // Size of data in each burst
    output  logic   [1:0]                       burst_type,     // Type of burst

    // AXI 4 MASTER -> vec_lsu
    input   logic   [`DATA_BUS*`BURST_MAX-1:0]  mem2lsu_data,   // LOADED DATA
    input   logic                               burst_valid_data,// Tells that loaded data is valid and loaded from memory for whole  burst
    input   logic                               burst_wr_valid,  // Tells that store burst is completed and data is stored 

    // vec_lsu -> Vector Register File
    output  logic   [`MAX_VLEN-1:0]             vd_data,        // Destination vector data
    output  logic                               is_loaded,      // Load data complete signal
    output  logic                               is_stored,      // Store data complete signal
    output  logic                               error_flag      // Gives on invalid configuration

);
    logic                           new_inst;       // tells the initiation of new instruction
    logic                           unit_stride;    // Tells that the instruction is unit stride
    logic                           const_stride;   // TElls that this is constant stride 

 // ADDRESS GENERATION  Signals                  
    logic [`XLEN-1:0]               stride_value;
    logic [`XLEN-1:0]               unit_const_element_strt;
    logic [`XLEN-1:0]               selected_stride;
    logic                           start_unit_cont;
    logic                           index_str_en;

    // UORDERED ADDRESS GENERATION
    logic [$clog2(`VLEN)-1:0]       random_index, unorder_idx_counter;
    logic [`XLEN-1:0] random_str_array [`VLEN-1:0];
    logic [`XLEN-1:0]               random_stride;
    logic [`VLEN-1:0]               index_used;
    logic                           valid_entry;
    logic [$clog2(`VLEN):0]         lfsr_seed;
    logic [$clog2(`VLEN):0]         scan_index;
    logic                           all_indices_used;

    // COUNTER SIGNALS
    logic [$clog2(`VLEN)-1:0]       count_el;        // Current element count
    logic                           count_en;
    logic                           is_loaded_reg;
    logic                           ld_req_reg;     // to give ld_req a delay of one cycle so that address became ready
    logic                           st_req_reg;     // to give st_req a delay of one cycle so that address became ready
    logic                           load_complete;
    logic                           store_complete;

    
    // DATA MANAGEMENT SIGNALS
    logic [2*`XLEN-1:0]             loaded_data [0:`VLEN-1];
    logic                           data_en;         // Data write enable
    logic                           st_data_en;

/*

            ===========================================================
                        VECTOR LOAD/STORE UNIT (vLSU)
            ===========================================================

                            +-------------------------+
                            |   Vector Instruction    |
                            |   Decode Signals        |
                            |   (ld_inst/st_inst,     |
                            |   stride_sel, etc.)     |
                            +------------+------------+
                                        |
                                        v
                                +--------+---------+
                                |     FSM CONTROLLER|
                                |   (IDLE, LOAD,    |
                                |    STORE states)  |
                                +--------+---------+
                                        |
                                        v
                            +----------+-----------+
                            |   Address Generator  |
                            |                      |
                            |  +----------------+  |
                            |  | Stride Select  |<--------+
                            |  +----------------+         |
                            |    |                       |
                            |    |   +----------------+  | Index-based
                            |    +-->| Index Stride   |--+-----> LFSR / Random
                            |    |   | (vs2_data)     |        Stride Gen
                            |    |   +----------------+             |
                            |    |                                 v
                            |    |     +-----------------+   +--------------+
                            |    +---->| Constant Stride |   |  Unit Stride |
                            |          | (rs2_data)      |   |  (seq addr)  |
                            |          +-----------------+   +--------------+
                            |                      |
                            +----------+-----------+
                                        |
                                        v
                                +--------+---------+
                                | AXI Address/     |
                                | Burst Setup      |
                                +--------+---------+
                                        |
                        +----------------+----------------+
                        |                                 |
                        v                                 v
            +----------------------------+     +--------------------------+
            | AXI READ CHANNEL           |     |  AXI WRITE CHANNEL       |
            | - lsu2mem_addr             |     | - lsu2mem_data           |
            | - burst_len, burst_size    |     | - wr_strobe              |
            |                            |     | - st_data_en             |
            +------------+---------------+     +-------------+------------+
                        |                                   |
                        v                                   v
                +-------+---------+               +---------+--------+
                |  Data Receive   |               |  Data Formatter  |
                | (mem2lsu_data)  |               |  (vs3_data ->     |
                |  - Extracts     |               |   AXI format)     |
                |    based on SEW |               |                  |
                +-------+---------+               +---------+--------+
                        |                                   |
                        v                                   v
            +-----------------------------+      +------------------------------+
            |    Vector Register Update   |      |    AXI Write Data Dispatch   |
            | - loaded_data[i] <= mem     |      | - wr_strobe per element      |
            | - vd_data <= packed vec     |      |                              |
            +-----------------------------+      +------------------------------+

            ===========================================================

            Modes:
            ------
            [1] Unit Stride:
                - Address increments sequentially
                - Bulk transfer via burst

            [2] Constant Stride:
                - First element = base
                - Subsequent elements offset by rs2_data

            [3] Index Stride:
                - Ordered   : vs2_data[index]
                - Unordered : Random LFSR-indexed vs2_data

            ===========================================================
 */


/******************************************* ADDRESS GENERATION ******************************************************/

/******************************************************************************
 /*
 * Address Generation Logic Description:
 * 
 * This module implements the address generation for a vector load/store unit (VLSU). It supports
 * three types of address generation modes: 
 * 1. **Unit Constant Address Generation**: 
 *    - The base address is directly taken from the input `rs1_data`, and a constant stride is applied to it. 
 *    - The stride can either be selected based on a predefined width (`stride_sel`) or set through an explicit 
 *      value in `rs2_data[7:0]`. This mode is useful when each element has a fixed address offset.
 * 
 * 2. **Index-Ordered Address Generation**:
 *    - This mode generates addresses based on a simple sequential pattern of indices.
 *    - The `count_el` value is incremented by a fixed stride width (`add_el`) to generate the address 
 *      of the next element in a sequential fashion.
 *    - The stride used is either derived from `vs2_data` or a fixed value depending on the width configuration.
 *    - The `count_el` value is incremented in steps based on the element size (8, 16, 32, or 64 bits), 
 *      with different `add_el` values for each stride width.
 * 
 * 3. **Index-Unordered Address Generation**:
 *    - This mode generates addresses by randomly selecting an index from a pool of available indices.
 *    - A Linear Feedback Shift Register (LFSR) is used to generate random numbers. 
 *    - If the generated index has already been used, the next index in sequence is checked until an unused index 
 *      is found.
 *    - Once a valid index is found, the corresponding data for the generated index is extracted from `vs2_data` 
 *      and used as the stride for address computation.
 *    - The `index_used` array tracks which indices have been used to prevent repetition.
 *    - The `unorder_idx_counter` ensures that the stride for each element is placed in the correct location.
 * 
 * Address Calculation:
 * 1. For **Unit Constant Mode**, the address is computed using:
 *    `address = rs1_data + stride_value`
 *    Where `stride_value` is either constant or derived from `rs2_data` depending on the configuration.
 * 2. For **Index-Ordered Mode**, the address is computed using:
 *    `address = rs1_data +  stride_value`
 * 3. For **Index-Unordered Mode**, the address is computed using:
 *    `address = rs1_data + random_stride`
 *    Where `random_stride` is selected from the array `random_str_array`, based on a random index and the stride 
 *    value corresponding to the selected element.
 
 ******************************************************************************/



// IN Case of UNIT STRIDE  , We will load the data in one burst operation such that :
// burst len = (vlmax*sew)/DATABUS_Width
// burst type = BURST_INCR
// burst_size =  number of bytes in each beat (DATA_BUS/8)=> 512/8 = 64 bytes => 3b'110 
// IN case of the Unit Constant Stride since we are loading the continuous memory and 
// in one burst so we dont need the counter for the indexings and counting of the data 
// as we are always using the full data bus width for each beat so we don't need to count
// data and therefore we are not using the counter for unit const stride 


// In case of the UNIT-CONSTANT-STRIDE :
// sew = eew
// vlmax = evlmax
// In case of INDEX STRIDE : 
// sew = sew (data part)
// vlamx = vlmax (data part)
// width = eew (inndex part)

    

    // Generate a unique random index in a single cycle (Index Unordered Stride)
    always_comb begin
        valid_entry   = 0;
        random_stride = 0;
        lfsr_seed     = 'h1;
        scan_index    = 0;

        all_indices_used = &vlmax; // If all bits are set, all indices are used

        if (index_unordered && !all_indices_used) begin
            // LFSR-based pseudo-random number generation
            lfsr_seed = {lfsr_seed[$clog2(`VLEN)-2:0], 
                        lfsr_seed[$clog2(`VLEN)-1] ^ 
                        lfsr_seed[$clog2(`VLEN)-3] ^ 
                        lfsr_seed[$clog2(`VLEN)-2] ^ 1'b1};
            
            random_index = lfsr_seed % vlmax;  // Ensure within range

            // If the generated index is used, scan sequentially to find the next available index
            for (int i = 0; i < vlmax; i++) begin
                if (!index_used[random_index]) begin
                    valid_entry = 1;
                end else begin
                    random_index = (random_index + 1) % vlmax;
                end
            end

            // Extract stride data based on unique random index
            if (valid_entry) begin
                case (width)
                    3'b000: random_stride = vs2_data[(random_index * 8) +: 8];
                    3'b101: random_stride = vs2_data[(random_index * 16) +: 16];
                    3'b110: random_stride = vs2_data[(random_index * 32) +: 32];
                    3'b111: begin 
                        if (index_str)begin 
                            $error("SEW = 64 is not supported for XLEN = 32 ");
                        end
                        random_stride = 0;
                    end
                    default:begin
                        random_stride = 0;
                    end
                endcase
            end
        end
    end

    // Store the unique random index on clock edge
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            unorder_idx_counter <= 0; 
            index_used          <= 0;  // Reset tracking array
            for (int i = 0; i < `VLEN; i++) begin
                random_str_array[i] <= 0;
            end
        end else begin
            if (is_loaded) begin
                index_used <= '0;
                for (int i = 0; i < `VLEN; i++) begin
                    random_str_array[i] <= 0;
                end
            end
            else if (index_unordered && valid_entry) begin
                random_str_array[unorder_idx_counter] <= random_stride;
                index_used[random_index]              <= 1'b1;  // Mark index as used
                unorder_idx_counter                   <= (unorder_idx_counter == vlmax-1) ? 0 : unorder_idx_counter + 1;
            end
        end
    end

    // CONFIGURATION CHECKING BLOCK
    always_comb begin 
        error_flag = 0;

        if (index_str &&  (width == 3'b111))begin
            error_flag = 1;
        end
        else begin
            error_flag = 0;
        end
    end

    // Index Orderded Stride Computation
    always_comb begin
        case (width)
            3'b000: begin
                selected_stride = vs2_data[(count_el * 8) +: 8];
            end
            3'b101: begin 
                selected_stride = vs2_data[(count_el * 16) +: 16];
            end
            3'b110: begin
                selected_stride = vs2_data[(count_el * 32) +: 32];
            end
            3'b111: begin 
                if (index_str)begin 
                    $error("SEW = 64 is not supported for XLEN = 32 ");
                end
            end
            default: begin
                selected_stride = 0;
            end
        endcase
    end


        /* Unit and Constant Stride */

    // In case if stride sel is one or rs2_data that is the constant stride offset is 1
    // then treat the instruction as the unit stride  
    assign unit_stride = stride_sel || ($unsigned(rs2_data[7:0]) == 1);

    // If the stride sel is 0 and the rs2_data is not 1 then it is constant stride 
    assign const_stride = !stride_sel && !($unsigned(rs2_data[7:0]) == 1);
    
    assign unit_const_element_strt = rs1_data;  // Base address


  // STRIDE VALUE CALCULATION
    always_comb begin
        stride_value = '0; // default value to avoid latches

        if (index_str_en) begin
            if (index_unordered) begin
                if (count_el == 0)begin
                    stride_value = random_stride;
                end
                else 
                    stride_value = random_str_array[count_el];
            end else begin
                stride_value = selected_stride;
            end
        end else if (const_stride) begin
            if (count_el == 0) begin
                stride_value = unit_const_element_strt;
            end else begin
                stride_value = $unsigned(rs2_data[7:0]);
            end
        end
    end

    // LSU2MEM ADDRESS GENERATION
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            lsu2mem_addr <= 0;
            burst_type   <= `BURST_INCR;
            burst_len    <= 0;
            burst_size   <= 3'b110;
        end
        else if (inst_done)begin
            lsu2mem_addr <= 0;
            burst_type   <= `BURST_INCR;
            burst_len    <= 0;
            burst_size   <= 3'b110;
        end
        else if ((st_inst ||ld_inst) && index_str)begin
            if (count_en) begin
                lsu2mem_addr <= rs1_data + stride_value;
                burst_len    <= 0; // 0 means one beat in the burst
                burst_type   <= `BURST_INCR;
                case (sew)
                    8:   burst_size = 0;
                    16:  burst_size = 1;
                    32:  burst_size = 2;
                    64:  burst_size = 3;
                    default: burst_size = 0;  
                endcase   
            end                
        end
        else if ((st_inst ||ld_inst) && const_stride)begin
            if (count_en) begin
                lsu2mem_addr <= lsu2mem_addr + stride_value;
                burst_len    <= 0; // 0 means one beat in the burst
                burst_type   <= `BURST_INCR;
                case (sew)
                    8:   burst_size = 0;
                    16:  burst_size = 1;
                    32:  burst_size = 2;
                    64:  burst_size = 3;
                    default: burst_size = 0;  
                endcase   
            end                
        end
        else if ((st_inst ||ld_inst) && unit_stride)begin
            lsu2mem_addr <= unit_const_element_strt;
            burst_size   <= 3'b110;  // 64 bytes in each beat
            burst_type   <= `BURST_INCR;
            case (sew)
                8: begin
                    case (vlmax)
                        64  : burst_len = ((64  * 8 ) / `DATA_BUS_WIDTH) -1; 
                        128 : burst_len = ((128 * 8 ) / `DATA_BUS_WIDTH) -1; 
                        256 : burst_len = ((256 * 8 ) / `DATA_BUS_WIDTH) -1; 
                        512 : burst_len = ((512 * 8 ) / `DATA_BUS_WIDTH) -1; 
                        default: burst_len = 0;
                    endcase
                end

                16: begin
                    case (vlmax)
                        32  : burst_len = ((32  * 16) / `DATA_BUS_WIDTH) -1;
                        64  : burst_len = ((64  * 16) / `DATA_BUS_WIDTH) -1;
                        128 : burst_len = ((128 * 16) / `DATA_BUS_WIDTH) -1;
                        256 : burst_len = ((256 * 16) / `DATA_BUS_WIDTH) -1;
                        default: burst_len = 0;
                    endcase
                end

                32: begin
                    case (vlmax)
                        16  : burst_len = ((16  * 32) / `DATA_BUS_WIDTH) -1;
                        32  : burst_len = ((32  * 32) / `DATA_BUS_WIDTH) -1;
                        64  : burst_len = ((64  * 32) / `DATA_BUS_WIDTH) -1;
                        128 : burst_len = ((128 * 32) / `DATA_BUS_WIDTH) -1;
                        default: burst_len = 0;
                    endcase
                end

                64: begin
                    case (vlmax)
                        8   : burst_len = ((8  * 64) / `DATA_BUS_WIDTH) -1;
                        16  : burst_len = ((16 * 64) / `DATA_BUS_WIDTH) -1;
                        32  : burst_len = ((32 * 64) / `DATA_BUS_WIDTH) -1;
                        64  : burst_len = ((64 * 64) / `DATA_BUS_WIDTH) -1;
                        default: burst_len = 0;
                    endcase
                end

                default: burst_len = 0;
            endcase
        end           
    end 

  
    /* Element Counter */
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            count_el <= 0;
        else if (is_loaded_reg || is_stored || error_flag)begin
            count_el <= 0;
        end
        else if (count_en) begin           
            count_el <= count_el + 1;
        end
        else begin
            count_el <= count_el;
        end
    end

    always_ff @( posedge clk or negedge n_rst ) begin 
        if (!n_rst)begin
            new_inst <= 1;
        end
        else if ((is_loaded_reg || is_stored) && !inst_done)begin
            new_inst <= 0;
        end
        else if (inst_done)begin
            new_inst <= 1;
        end
    end


    // Register is_loaded and data_en to introduce a one-cycle delay

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            is_loaded     <= 0;
            ld_req        <= 0;
        end
        else begin
            is_loaded     <= is_loaded_reg;
            ld_req        <= ld_req_reg;
            st_req        <= st_req_reg;
        end    
    end


    always_comb begin
        if (ld_inst)begin
            load_complete = (count_el == vlmax);
        end
        else if (st_inst)begin
            store_complete = (count_el == vlmax);
        end
        else begin
            store_complete = 1'b0;
            load_complete  = 1'b0;
        end 
    end


    

/****************************************** DATA MANGEMENT **********************************************************/

    /* -------------------------------------------------------
     * LOAD DATA BLOCK
     * -------------------------------------------------------
     * - Handles loading memory data (`mem2lsu_data`) into 
     *   the temporary buffer `loaded_data[]` based on stride mode.
     * 
     * - In unit stride mode:
     *     * The whole burst is transferred together.
     *     * Data is split and stored element-wise in parallel.
     * 
     * - In constant or index stride:
     *     * Only one element is transferred per cycle.
     *     * Data is stored sequentially using `count_el`.
     * 
     * - `vd_data` packs the loaded elements into a contiguous
     *   vector register writeback format depending on SEW.
     * ------------------------------------------------------- */

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            for (int i = 0; i < `MAX_VLEN; i++) 
                loaded_data[i] <= 0;
        end
        else if (data_en) begin
            if (unit_stride)begin
                for (int i = 0; i < `MAX_VLEN; i++) begin
                    if (i < vlmax) begin
                        case (sew)
                            8:  loaded_data[i] = mem2lsu_data[i*8   +: 8];
                            16: loaded_data[i] = mem2lsu_data[i*16  +: 16];
                            32: loaded_data[i] = mem2lsu_data[i*32  +: 32];
                            64: loaded_data[i] = mem2lsu_data[i*64  +: 64];
                            default: loaded_data[i] = '0;
                        endcase
                    end
                end          
            end
            else begin     
                case (sew)
                    7'd8:  loaded_data[count_el-1] <= mem2lsu_data[7:0];
                    7'd16: loaded_data[count_el-1] <= mem2lsu_data[15:0];
                    7'd32: loaded_data[count_el-1] <= mem2lsu_data[31:0];
                    7'd64: loaded_data[count_el-1] <= mem2lsu_data[63:0];
                    default: loaded_data[count_el-1] <= mem2lsu_data;
            endcase
            end
        end
    end

    /* -------------------------------------------------------
     * VECTOR REGISTER WRITEBACK (vd_data)
     * -------------------------------------------------------
     * - Converts the internal `loaded_data[]` into a packed
     *   vector (`vd_data`) based on `sew` (Standard Element Width).
     * 
     * - This is used to write back to the vector register file.
     * - The logic ensures proper alignment of the data lanes.
     * ------------------------------------------------------- */


    always_comb begin
        vd_data = '0;
        for (int i = 0; i < `MAX_VLEN; i++) begin
            if (i < vlmax) begin
                case (sew)
                    8:   vd_data[i*8   +: 8]  = loaded_data[i][7:0];
                    16:  vd_data[i*16  +: 16] = loaded_data[i][15:0];
                    32:  vd_data[i*32  +: 32] = loaded_data[i][31:0];
                    64:  vd_data[i*64  +: 64] = loaded_data[i][63:0];
                    default: ;/* leave as zero */
                endcase
            end
        end
    end


    /* -------------------------------------------------------
     * STORE DATA BLOCK
     * -------------------------------------------------------
     * - Handles formatting and preparing `vs3_data` into 
     *   `lsu2mem_data` for AXI write transactions.
     *
     * - Supports three modes:
     *     [1] Unit stride:
     *         - Data is burst written together.
     *         - Each element's size is selected by SEW.
     *         - Write strobes (`wr_strobe`) are generated 
     *           per element size.
     *
     *     [2] Index stride unordered:
     *         - Random index selected from `random_str_array`.
     *         - Only one element is written per cycle.
     *
     *     [3] Index stride ordered / constant stride:
     *         - Uses `count_el` to select the correct word.
     *         - One element is written per cycle.
     * 
     * - `wr_strobe` ensures only valid bytes are enabled 
     *   during AXI write.
     * ------------------------------------------------------- */
   
    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst) begin
            lsu2mem_data <= 'h0;
            wr_strobe    <= 'h0;
        end
        else if (st_data_en)begin
            if (unit_stride)begin
                for (int i = 0; i < `MAX_VLEN; i++) begin
                    if (i < vlmax) begin
                        case (sew)
                            7'd8: begin 
                                lsu2mem_data[(8 * i) +: 8] = vs3_data[(i*8) +: 8];
                                wr_strobe[i] = 1;
                            end
                            7'd16: begin 
                                lsu2mem_data[(16 * i) +: 16] = vs3_data[(i*16) +: 15];
                                wr_strobe[2*i +: 2] = 'b11;
                            end
                            7'd32: begin 
                                lsu2mem_data[(32 * i) +: 32] = vs3_data[(i*32) +: 32];
                                wr_strobe[4*i +: 4] = 'b1111;
                            end
                            7'd64: begin 
                                lsu2mem_data[(64 * i) +: 64] = vs3_data[(i*64) +: 64];
                                wr_strobe[8*i +: 8] = 'b11111111;
                            end    
                            default: begin 
                                lsu2mem_data = 0;
                                wr_strobe = 0;
                            end 
                        endcase
                    end
                end
            end
            else begin
                if (index_str && index_unordered)begin
                    case (sew)
                        7'd8: begin
                            lsu2mem_data[7:0]  <= vs3_data[random_str_array[count_el] +: 8];
                            wr_strobe <= 'b1;
                        end 
                        7'd16: begin
                            lsu2mem_data[15:0] <= vs3_data[random_str_array[count_el] +: 16];
                            wr_strobe <= 'b11;
                        end
                        7'd32: begin
                            lsu2mem_data[31:0] <= vs3_data[random_str_array[count_el] +: 32];
                            wr_strobe <= 'b1111;
                        end
                        7'd64: begin
                            lsu2mem_data[63:0] <= vs3_data[random_str_array[count_el] +: 64];
                            wr_strobe <= 'b11111111;
                        end
                        default: begin 
                                lsu2mem_data = 0;
                                wr_strobe = 0;
                        end
                    endcase
                end
                else begin     
                    case (sew)
                        7'd8: begin
                            lsu2mem_data[7:0]  <= vs3_data[(count_el) * 8 +: 8];
                            wr_strobe <= 'b1;
                        end 
                        7'd16: begin
                            lsu2mem_data[15:0] <= vs3_data[(count_el) * 16 +: 16];
                            wr_strobe <= 'b11;
                        end
                        7'd32: begin
                            lsu2mem_data[31:0] <= vs3_data[(count_el) * 32 +: 32];
                            wr_strobe <= 'b1111;
                        end
                        7'd64: begin
                            lsu2mem_data[63:0] <= vs3_data[(count_el) * 64 +: 64];
                            wr_strobe <= 'b11111111;
                        end
                        default: begin 
                                lsu2mem_data = 0;
                                wr_strobe = 0;
                        end
                    endcase
                end   
            end
        end
    end


/****************************************************** CONTROLLER *****************************************************/

    typedef enum logic [3:0]{IDLE, 
                            LOAD_UNIT_STR,
                            LOAD_CONST_STR,
                            LOAD_INDEX_STR, 
                            STORE_UNIT_STR, 
                            STORE_CONST_STR,
                            STORE_INDEX_STR
                            } lsu_state_e;
    
    lsu_state_e c_state, n_state;

    always_ff @(posedge clk or negedge n_rst) begin
        if (!n_rst)
            c_state <= IDLE;
        else
            c_state <= n_state;
    end


    always_comb begin
        n_state             = c_state;
        count_en            = 0;
        ld_req_reg          = 0;
        st_req_reg          = 0;
        index_str_en        = 0;
        st_data_en          = 0;
        data_en             = 0;
        is_stored           = 0;
        is_loaded_reg       = 0;

        if (error_flag) begin
            n_state     = IDLE;
            count_en    = 0;
            data_en     = 0;
            st_data_en  = 0;
            ld_req_reg  = 0;
            st_req_reg  = 0;
        end else begin
            case (c_state)
                IDLE: begin
                
                    if (ld_inst && new_inst) begin
                        if (index_str)begin
                            n_state             = LOAD_INDEX_STR;
                            index_str_en        = 1'b1;
                            count_en            = 1;
                            ld_req_reg          = 1;
                        end
                        else if (const_stride)begin
                            n_state             = LOAD_CONST_STR;
                            count_en            = 1;
                            ld_req_reg          = 1;
                        end
                        else if (unit_stride)begin
                            n_state             = LOAD_UNIT_STR;
                            ld_req_reg          = 1;                        
                        end
                        else begin
                            n_state             = IDLE;
                            count_en            = 0;
                            ld_req_reg          = 0;
                            index_str_en        = 0; 
                        end 
                    end
                
                    else if (st_inst && new_inst) begin
                        if (index_str)begin
                            n_state             = STORE_INDEX_STR;
                            index_str_en        = 1'b1;
                            count_en            = 1;
                            st_req_reg          = 1;
                            st_data_en          = 1;  
                        end
                        else if (const_stride)begin
                            n_state             = STORE_CONST_STR;
                            count_en            = 1;
                            st_req_reg          = 1;
                            st_data_en          = 1;
                        end
                        else if (unit_stride)begin
                            n_state             = STORE_UNIT_STR;
                            st_req_reg          = 1;
                            st_data_en          = 1;                        
                        end
                        else begin
                            n_state             = IDLE;
                            count_en            = 0;
                            st_req_reg          = 0;
                            index_str_en        = 0;
                            st_data_en          = 0; 
                        end
                    end
                end
                LOAD_UNIT_STR: begin
                    if (burst_valid_data)begin
                        n_state       = IDLE;
                        data_en       = 1;
                        is_loaded_reg = 1;
                    end
                    else begin
                        n_state       = LOAD_UNIT_STR;
                        data_en       = 0;
                        is_loaded_reg = 0;                        
                    end    
                end

                LOAD_CONST_STR : begin
                    if (burst_valid_data)begin
                        if (load_complete)begin
                            n_state       = IDLE;
                            data_en       = 1;
                            is_loaded_reg = 1;
                        end
                        else begin
                            n_state       = LOAD_CONST_STR;
                            data_en       = 1;
                            count_en      = 1;
                            ld_req_reg    = 1;
                            is_loaded_reg = 0;
                        end
                    end
                    else begin
                        n_state       = LOAD_CONST_STR;
                        data_en       = 0;
                        count_en      = 0;
                        ld_req_reg    = 0;
                        is_loaded_reg = 0;
                    end
                end
                
                LOAD_INDEX_STR : begin
                    if (burst_valid_data)begin
                        if (load_complete)begin
                            n_state       = IDLE;
                            data_en       = 1;
                            index_str_en  = 0;
                            is_loaded_reg = 1;
                        end
                        else begin
                            n_state       = LOAD_INDEX_STR;
                            data_en       = 1;
                            count_en      = 1;
                            index_str_en  = 1;
                            ld_req_reg    = 1;
                            is_loaded_reg = 0;
                        end
                    end
                    else begin
                        n_state       = LOAD_INDEX_STR;
                        data_en       = 0;
                        count_en      = 0;
                        index_str_en  = 0;
                        ld_req_reg    = 0;
                        is_loaded_reg = 0;
                    end
                end

                STORE_UNIT_STR: begin
                    if (burst_wr_valid)begin
                        n_state   = IDLE;
                        is_stored = 1;
                    end
                    else begin
                        n_state   = STORE_UNIT_STR;
                        is_stored = 0;
                    end    
                end

                STORE_CONST_STR : begin
                    if (burst_wr_valid)begin
                        if (store_complete)begin
                            n_state   = IDLE;
                            is_stored = 1;
                        end
                        else begin
                            n_state       = STORE_CONST_STR;
                            st_data_en    = 1;
                            count_en      = 1;
                            st_req_reg    = 1;
                        end
                    end
                    else begin
                        n_state       = STORE_CONST_STR;
                        st_data_en    = 0;
                        count_en      = 0;
                        st_req_reg    = 0;
                    end
                end

                STORE_INDEX_STR : begin
                    if (burst_wr_valid)begin
                        if (store_complete)begin
                            n_state   = IDLE;
                            is_stored = 1; 
                        end
                        else begin
                            n_state       = STORE_INDEX_STR;
                            st_data_en    = 1;
                            count_en      = 1;
                            index_str_en  = 1;
                            st_req_reg    = 1;
                        end
                    end
                    else begin
                        n_state       = STORE_INDEX_STR;
                        st_data_en    = 0;
                        count_en      = 0;
                        index_str_en  = 0;
                        st_req_reg    = 0;
                    end
                end
                default : begin
                    n_state             = IDLE;
                    count_en            = 0;
                    ld_req_reg          = 0;
                    st_req_reg          = 0;
                    index_str_en        = 0;
                    st_data_en          = 0;
                    data_en             = 0;
                    is_stored           = 0;
                    is_loaded_reg       = 0;
                end
                
            endcase
        end
    end

endmodule

