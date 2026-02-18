package axi_4_pkg;

    parameter XLEN = 32;
    parameter DATA_BUS_WIDTH = 512;
    parameter STROBE_WIDTH  = DATA_BUS_WIDTH/8;
    
    typedef enum logic [2:0]{  
        MASTER_IDLE,
        WAIT_ARREADY,
        WAIT_RVALID,
        WAIT_AWREADY_WREADY,
        WAIT_AWREADY,
        WAIT_WREADY,
        WAIT_WLAST,
        WAIT_BVALID
    } axi_4_master_states_e;

    typedef enum logic [3:0]{  
        SLAVE_IDLE,
        WAIT_ARVALID,
        DATA_FETCH,
        WAIT_RREADY,
        WAIT_AWVALID_WVALID,
        WAIT_AWVALID,
        WAIT_WVALID,
        DATA_STORE,
        WAIT_BREADY
    } axi_4_slave_states_e;

typedef struct packed {
    logic   [XLEN-1:0] arid;       // read address transaction id
    logic   [XLEN-1:0] awid;       // write address transction id
    logic   [XLEN-1:0] axaddr;     // Read Address
    logic   [7:0]      axlen;      // Burst Length
    logic   [2:0]      axsize;     // Burst Size
    logic   [1:0]      axburst;    // Burst type
    logic              axlock;     // Atomic Access
    logic   [3:0]      axcache;    // memory type
    logic   [2:0]      axprot;     // Protection Type
    logic   [3:0]      axqos;      // Quality of Service

} read_write_address_channel_t;

typedef struct packed {
    logic   [XLEN-1:0]           rid;       // read data transaction id
    logic   [DATA_BUS_WIDTH-1:0] rdata;      // READ DATA 
    logic   [1:0]                rresp;      // Read Response
    logic                        rlast;      // Signal to tell the last transaction    
} read_data_channel_t;

typedef struct packed {
    logic   [XLEN-1:0]           wid;       // write data transaction id
    logic   [DATA_BUS_WIDTH-1:0] wdata;     // write DATA 
    logic   [STROBE_WIDTH-1:0]   wstrb;     // Write strobe
    logic                        wlast;     // Signal to tell the last transaction    
} write_data_channel_t;

typedef struct packed {
    logic   [XLEN-1:0] bid;        // write response transaction id
    logic   [1:0]      bresp;      // Write Response
} write_response_channel_t;

    
endpackage