`include "define_Cache.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/05 08:27:42
// Design Name: 
// Module Name: ICache
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module ICache(
     // 
    input  wire              clk_g,
    input  wire              resetn,
    // Cache与CPU流水线的交互接口
    input  wire              flush,
    input  wire              I_UnCache,
    input  wire              cpu_req,
    input  wire [`IndexBus]  index,
    input  wire [`TagBus]    ptag,
    input  wire [`TagBus]    vtag,
    input  wire [`OffsetBus] offset,
    
    output wire              stallreq,
    output wire              inst0_valid,
    output wire              inst1_valid,
    output wire [`InstBus]   inst0,
    output wire [`InstBus]   inst1,
    output wire [`AddrBus]   inst0_addr,
    output wire [`AddrBus]   inst1_addr,

    // Cache与AXI总线接口的交互接口
    
    output wire              rd_req,
    output wire [`TypeBus]   rd_type,
    output wire [`AddrBus]   rd_addr,
    input  wire              rd_finish,
    input  wire [`LineBus]   rd_data
    
);
    parameter DLY = 0;
    
    // Requset Buffer
    
    reg  [`IndexBus]  buffer_index0;
    reg  [`TagBus]    buffer_ptag0;
    reg  [`TagBus]    buffer_vtag0;
    reg  [`OffsetBus] buffer_offset0;
    reg  [`IndexBus]  inst1_index_buffer0;
    reg  [`OffsetBus] inst1_offset_buffer0;
    reg  [`TagBus]    inst1_vtag_buffer0;
    reg  [`TagBus]    inst1_ptag_buffer0;
    
    reg  [`IndexBus]  buffer_index1;
    reg  [`TagBus]    buffer_ptag1;
    reg  [`TagBus]    buffer_vtag1;
    reg  [`OffsetBus] buffer_offset1;
    reg  [`IndexBus]  inst1_index_buffer1;
    reg  [`OffsetBus] inst1_offset_buffer1;
    reg  [`TagBus]    inst1_vtag_buffer1;
    reg  [`TagBus]    inst1_ptag_buffer1;
    
    wire [`IndexBus]  buffer_index;
    wire [`TagBus]    buffer_ptag;
    wire [`TagBus]    buffer_vtag;
    wire [`OffsetBus] buffer_offset;
    wire [`IndexBus]  inst1_index_buffer;
    wire [`OffsetBus] inst1_offset_buffer;
    wire [`TagBus]    inst1_vtag_buffer;
    
    reg  [`InstBus]  inst0_buffer;
    
    // rd_finish buffer
    reg              miss_rd_finish;
    
    // PLRU
    reg [255:0] PLRU_0 ; // 寄存器的个数即为bram中数据块的个数
    reg [255:0] PLRU_1_0;
    reg [255:0] PLRU_1_1;
    reg         PLRU_0_buffer;
    reg         PLRU_1_0_buffer;
    reg         PLRU_1_1_buffer;
    
    // Tag Compare
    wire             way0_hit0;
    wire             way1_hit0;
    wire             way2_hit0;
    wire             way3_hit0;
    wire             cache_hit0;
    
    
    wire             way0_hit1;
    wire             way1_hit1;
    wire             way2_hit1;
    wire             way3_hit1;
    wire             cache_hit1;
    
    // Read from Data_ram and Tagv_ram
    wire             enb;
    wire [`IndexBus] addrb;
    wire [`DataBus]  rdata_way0_bank0;
    wire [`DataBus]  rdata_way0_bank1;
    wire [`DataBus]  rdata_way0_bank2;
    wire [`DataBus]  rdata_way0_bank3;
    wire [`DataBus]  rdata_way1_bank0;
    wire [`DataBus]  rdata_way1_bank1;
    wire [`DataBus]  rdata_way1_bank2;
    wire [`DataBus]  rdata_way1_bank3;
    wire [`DataBus]  rdata_way2_bank0;
    wire [`DataBus]  rdata_way2_bank1;
    wire [`DataBus]  rdata_way2_bank2;
    wire [`DataBus]  rdata_way2_bank3;
    wire [`DataBus]  rdata_way3_bank0;
    wire [`DataBus]  rdata_way3_bank1;
    wire [`DataBus]  rdata_way3_bank2;
    wire [`DataBus]  rdata_way3_bank3;
    wire [`TagBus]   rtag_way0;
    wire [`TagBus]   rtag_way1;
    wire [`TagBus]   rtag_way2;
    wire [`TagBus]   rtag_way3;
    
    // Write to Data_ram and Tagv_ram
    wire             dena00;
    wire             dena01;
    wire             dena02;
    wire             dena03;
    wire             dena10;
    wire             dena11;
    wire             dena12;
    wire             dena13;
    wire             dena20;
    wire             dena21;
    wire             dena22;
    wire             dena23;
    wire             dena30;
    wire             dena31;
    wire             dena32;
    wire             dena33;
    wire             ena0;
    wire             ena1;
    wire             ena2;
    wire             ena3;
    wire [`DataBus]  write_data0;
    wire [`DataBus]  write_data1;
    wire [`DataBus]  write_data2;
    wire [`DataBus]  write_data3;
    wire [`TagBus]   wtag;
    wire [`IndexBus] waddr;
    wire             dwea;
    wire             wea; // tagv的字节选择信号
    
    // Select Data and Judge Data
    
    wire [`InstBus]  inst0_way0_data;
    wire [`InstBus]  inst0_way1_data;
    wire [`InstBus]  inst0_way2_data;
    wire [`InstBus]  inst0_way3_data;
    wire [`InstBus]  inst1_way0_data;
    wire [`InstBus]  inst1_way1_data;
    wire [`InstBus]  inst1_way2_data;
    wire [`InstBus]  inst1_way3_data;
    wire [`InstBus]  inst0_data;
    wire [`InstBus]  inst1_data;
    
    // Variable of StateMachine
    
    reg [`IMStateBus] current_mstate;
    reg [`IMStateBus] next_mstate;
    localparam MIDLE    = 9'b000000001;
    localparam LOOKUP   = 9'b000000010;
    localparam REFILL   = 9'b000000100;
    localparam WIDLE    = 9'b000001000;
    localparam SEARCH   = 9'b000010000;
    localparam MISS     = 9'b000100000;
    localparam BUFFER   = 9'b001000000;
    localparam CONFLICT = 9'b010000000;
    localparam UNCACHE  = 9'b100000000;
    
    // Cache Memory
    Instructions_RAM data_ram_way0_bank0 (
        .clka(clk_g),    // input wire clka
        .ena(dena00),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data0),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way0_bank0)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way0_bank1 (
        .clka(clk_g),    // input wire clka
        .ena(dena01),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data1),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way0_bank1)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way0_bank2 (
        .clka(clk_g),    // input wire clka
        .ena(dena02),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data2),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way0_bank2)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way0_bank3 (
        .clka(clk_g),    // input wire clka
        .ena(dena03),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data3),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way0_bank3)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way1_bank0 (
        .clka(clk_g),    // input wire clka
        .ena(dena10),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data0),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way1_bank0)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way1_bank1 (
        .clka(clk_g),    // input wire clka
        .ena(dena11),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data1),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way1_bank1)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way1_bank2 (
        .clka(clk_g),    // input wire clka
        .ena(dena12),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data2),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way1_bank2)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way1_bank3 (
        .clka(clk_g),    // input wire clka
        .ena(dena13),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data3),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way1_bank3)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way2_bank0 (
        .clka(clk_g),    // input wire clka
        .ena(dena20),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data0),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way2_bank0)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way2_bank1 (
        .clka(clk_g),    // input wire clka
        .ena(dena21),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data1),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way2_bank1)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way2_bank2 (
        .clka(clk_g),    // input wire clka
        .ena(dena22),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data2),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way2_bank2)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way2_bank3 (
        .clka(clk_g),    // input wire clka
        .ena(dena23),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data3),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way2_bank3)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way3_bank0 (
        .clka(clk_g),    // input wire clka
        .ena(dena30),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data0),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way3_bank0)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way3_bank1 (
        .clka(clk_g),    // input wire clka
        .ena(dena31),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data1),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way3_bank1)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way3_bank2 (
        .clka(clk_g),    // input wire clka
        .ena(dena32),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data2),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way3_bank2)  // output wire [31 : 0] doutb
    );
    Instructions_RAM data_ram_way3_bank3 (
        .clka(clk_g),    // input wire clka
        .ena(dena33),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data3),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rdata_way3_bank3)  // output wire [31 : 0] doutb
    );
    Tag_RAM tag_ram_way0 (
        .clka(clk_g),    // input wire clka
        .ena(ena0),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(wtag),    // input wire [20 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rtag_way0)  // output wire [20 : 0] doutb
    );
    Tag_RAM tag_ram_way1 (
        .clka(clk_g),    // input wire clka
        .ena(ena1),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(wtag),    // input wire [20 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rtag_way1)  // output wire [20 : 0] doutb
    );
    Tag_RAM tag_ram_way2 (
        .clka(clk_g),    // input wire clka
        .ena(ena2),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(wtag),    // input wire [20 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rtag_way2)  // output wire [20 : 0] doutb
    );
    Tag_RAM tag_ram_way3 (
        .clka(clk_g),    // input wire clka
        .ena(ena3),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(wtag),    // input wire [20 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(addrb),  // input wire [3 : 0] addrb
        .doutb(rtag_way3)  // output wire [20 : 0] doutb
    );
    
    // Register
    always@(posedge clk_g) begin
      if(resetn == `RstEnable || flush == `RstEnable) begin
        
        buffer_index0        <= #DLY 8'b0 ;
        buffer_ptag0         <= #DLY 20'b0;
        buffer_vtag0         <= #DLY 20'b0;
        buffer_offset0       <= #DLY 4'b0 ;
        inst1_index_buffer0  <= #DLY 8'b0;
        inst1_offset_buffer0 <= #DLY 4'b0;
        inst1_vtag_buffer0   <= #DLY 20'b0;
        inst1_ptag_buffer0   <= #DLY 20'h0;
        
        buffer_index1        <= #DLY 8'b0 ;
        buffer_ptag1         <= #DLY 20'b0;
        buffer_vtag1         <= #DLY 20'b0;
        buffer_offset1       <= #DLY 4'b0 ;
        inst1_index_buffer1  <= #DLY 8'b0;
        inst1_offset_buffer1 <= #DLY 4'b0;
        inst1_vtag_buffer1   <= #DLY 20'b0;
        inst1_ptag_buffer1   <= #DLY 20'h0;
      end else if(current_mstate[6] || current_mstate[1] || current_mstate[0] || I_UnCache) begin 
      // 包含两种情况，主状态机处于MIDLE状态以及主状态机处于LOOKUP状态且下一周期的主状态机仍处于LOOKUP状态
        
        buffer_index0        <= #DLY index ;
        buffer_ptag0         <= #DLY ptag  ;
        buffer_vtag0         <= #DLY vtag  ;
        buffer_offset0       <= #DLY offset;
        inst1_index_buffer0  <= #DLY index+1;
        inst1_offset_buffer0 <= #DLY offset+4;
        inst1_vtag_buffer0   <= #DLY vtag+1;
        inst1_ptag_buffer0   <= #DLY ptag+1;
        
        buffer_index1        <= #DLY buffer_index0       ;
        buffer_ptag1         <= #DLY buffer_ptag0        ;
        buffer_vtag1         <= #DLY buffer_vtag0        ;
        buffer_offset1       <= #DLY buffer_offset0      ;
        inst1_index_buffer1  <= #DLY inst1_index_buffer0 ;
        inst1_offset_buffer1 <= #DLY inst1_offset_buffer0;
        inst1_vtag_buffer1   <= #DLY inst1_vtag_buffer0;
        inst1_ptag_buffer1   <= #DLY inst1_ptag_buffer0;
      end else begin
        
        buffer_index0        <= #DLY buffer_index0 ;
        buffer_ptag0         <= #DLY buffer_ptag0  ;
        buffer_vtag0         <= #DLY buffer_vtag0  ;
        buffer_offset0       <= #DLY buffer_offset0;
        inst1_index_buffer0  <= #DLY inst1_index_buffer0 ;
        inst1_offset_buffer0 <= #DLY inst1_offset_buffer0;
        inst1_vtag_buffer0   <= #DLY inst1_vtag_buffer0;
        inst1_ptag_buffer0   <= #DLY inst1_ptag_buffer0;
        
        buffer_index1        <= #DLY buffer_index1       ;
        buffer_ptag1         <= #DLY buffer_ptag1        ;
        buffer_vtag1         <= #DLY buffer_vtag1        ;
        buffer_offset1       <= #DLY buffer_offset1      ;
        inst1_index_buffer1  <= #DLY inst1_index_buffer1 ;
        inst1_offset_buffer1 <= #DLY inst1_offset_buffer1;
        inst1_vtag_buffer1   <= #DLY inst1_vtag_buffer1  ;
        inst1_ptag_buffer1   <= #DLY inst1_ptag_buffer1  ;
      end
    end
    
    assign buffer_index        = (current_mstate[0] || current_mstate[1] || current_mstate[8]) ? buffer_index0        : buffer_index1       ;
    assign buffer_ptag         = (current_mstate[0] || current_mstate[1] || current_mstate[8]) ? buffer_ptag0         : buffer_ptag1        ;
    assign buffer_vtag         = (current_mstate[0] || current_mstate[1] || current_mstate[8]) ? buffer_vtag0         : buffer_vtag1        ;
    assign buffer_offset       = (current_mstate[0] || current_mstate[1] || current_mstate[8]) ? buffer_offset0       : buffer_offset1      ;
    assign inst1_index_buffer  = (current_mstate[0] || current_mstate[1] || current_mstate[8]) ? inst1_index_buffer0  : inst1_index_buffer1 ;
    assign inst1_offset_buffer = (current_mstate[0] || current_mstate[1] || current_mstate[8]) ? inst1_offset_buffer0 : inst1_offset_buffer1;
    assign inst1_vtag_buffer   = (current_mstate[0] || current_mstate[1] || current_mstate[8]) ? inst1_vtag_buffer0   : inst1_vtag_buffer1  ;
    
    // PLRU   
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        PLRU_0    <= #DLY 256'b0;
        PLRU_1_0  <= #DLY 256'b0;
        PLRU_1_1  <= #DLY 256'b0;
      end else if(cache_hit0) begin
        PLRU_0[buffer_index]    <= #DLY way0_hit0 || way1_hit0;
        PLRU_1_0[buffer_index]  <= #DLY way0_hit0 || way2_hit0;
        PLRU_1_1[buffer_index]  <= #DLY way1_hit0 || way2_hit0;
      end else if(current_mstate[1] && !cache_hit0) begin
        PLRU_0[buffer_index]    <= #DLY ~PLRU_0[buffer_index]  ;
        PLRU_1_0[buffer_index]  <= #DLY PLRU_0[buffer_index] ? PLRU_1_0[buffer_index] : ~PLRU_1_0[buffer_index];
        PLRU_1_1[buffer_index]  <= #DLY PLRU_0[buffer_index] ? ~PLRU_1_1[buffer_index] : PLRU_1_1[buffer_index];
      end else if(cache_hit1) begin
        PLRU_0[buffer_index]    <= #DLY way0_hit1 || way1_hit1;
        PLRU_1_0[buffer_index]  <= #DLY way0_hit1 || way2_hit1;
        PLRU_1_1[buffer_index]  <= #DLY way1_hit1 || way2_hit1;
      end else if(current_mstate[4] && !cache_hit1) begin
        PLRU_0[buffer_index]    <= #DLY ~PLRU_0[buffer_index]  ;
        PLRU_1_0[buffer_index]  <= #DLY PLRU_0[buffer_index] ? PLRU_1_0[buffer_index] : ~PLRU_1_0[buffer_index];
        PLRU_1_1[buffer_index]  <= #DLY PLRU_0[buffer_index] ? ~PLRU_1_1[buffer_index] : PLRU_1_1[buffer_index];
      end  else begin
        PLRU_0    <= #DLY PLRU_0  ;
        PLRU_1_0  <= #DLY PLRU_1_0;
        PLRU_1_1  <= #DLY PLRU_1_1;
      end
    end
    
    always@(posedge clk_g) begin
      if(resetn == `RstEnable || flush == `RstEnable) begin
        PLRU_0_buffer   <= #DLY 1'b0;
        PLRU_1_0_buffer <= #DLY 1'b0;
        PLRU_1_1_buffer <= #DLY 1'b0;
      end else if(current_mstate[1] && !cache_hit0) begin
        PLRU_0_buffer   <= #DLY ~PLRU_0[buffer_index]  ;                                                
        PLRU_1_0_buffer <= #DLY PLRU_0[buffer_index] ? PLRU_1_0[buffer_index] : ~PLRU_1_0[buffer_index];
        PLRU_1_1_buffer <= #DLY PLRU_0[buffer_index] ? ~PLRU_1_1[buffer_index] : PLRU_1_1[buffer_index];
      end else if(current_mstate[4] && !cache_hit1) begin
        PLRU_0_buffer   <= #DLY ~PLRU_0[buffer_index]  ;                                                
        PLRU_1_0_buffer <= #DLY PLRU_0[buffer_index] ? PLRU_1_0[buffer_index] : ~PLRU_1_0[buffer_index];
        PLRU_1_1_buffer <= #DLY PLRU_0[buffer_index] ? ~PLRU_1_1[buffer_index] : PLRU_1_1[buffer_index];
      end else begin
        PLRU_0_buffer   <= #DLY PLRU_0_buffer  ;
        PLRU_1_0_buffer <= #DLY PLRU_1_0_buffer;
        PLRU_1_1_buffer <= #DLY PLRU_1_1_buffer;
      end
    end
    
    // Main State Machine
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        current_mstate <= #DLY MIDLE;
      end else if(flush == `RstEnable && rd_req) begin
        current_mstate <= #DLY CONFLICT;
      end else if(flush == `RstEnable && !current_mstate[7]) begin
        current_mstate <= #DLY BUFFER;
      end else if(I_UnCache == `RstEnable) begin
        current_mstate <= #DLY UNCACHE;
      end else begin
        current_mstate <= #DLY next_mstate;
      end
    end
    
    always@(*) begin
      case(current_mstate)
        MIDLE : begin
          if(cpu_req)
            next_mstate <= #DLY LOOKUP;
          else
            next_mstate <= #DLY MIDLE;
        end
        LOOKUP : begin
          if(cache_hit0) begin
            //if(buffer_offset[3:2] == 2'b11) begin
            //if(buffer_offset0[3] && buffer_offset0[2]) begin
            if(buffer_offset0[3:2] == 2'b11) begin
              next_mstate <= #DLY WIDLE;
            end else if(cpu_req) begin
              next_mstate <= #DLY LOOKUP;
            end else begin
              next_mstate <= #DLY MIDLE;
            end
          end else
            next_mstate <= #DLY REFILL;
        end
        REFILL : begin
          if(!rd_finish) begin
            next_mstate <= #DLY REFILL;
          //end else if(buffer_offset[3:2] == 2'b11) begin
          //end else if(buffer_offset1[3] && buffer_offset1[2]) begin
          end else if(buffer_offset1[3:2] == 2'b11) begin
            next_mstate <= #DLY WIDLE;
          end else begin
            next_mstate <= #DLY BUFFER;
          end
        end
        WIDLE : begin
          next_mstate <= #DLY SEARCH;
        end
        SEARCH : begin
          if(cache_hit1)
            next_mstate <= #DLY MIDLE;
          else
            next_mstate <= #DLY MISS;
        end
        MISS : begin
          if(!rd_finish) begin
            next_mstate <= #DLY MISS;
          end else begin
            next_mstate <= #DLY BUFFER;
          end
        end
        BUFFER : begin
          next_mstate <= #DLY MIDLE;
        end
        CONFLICT : begin
          if(rd_finish) begin
            next_mstate <= #DLY MIDLE;
          end else begin
            next_mstate <= #DLY CONFLICT;
          end
        end
        UNCACHE : begin
          if(rd_finish) begin
            next_mstate <= #DLY MIDLE;
          end else begin
            next_mstate <= #DLY UNCACHE;
          end
        end
        default : begin
          next_mstate <= #DLY MIDLE;
        end
      endcase
    end
    
    // Cache_Hit
    
    assign way0_hit0  = current_mstate[1] ? rtag_way0[19:0] == buffer_ptag0 : `HitFail;
    assign way1_hit0  = current_mstate[1] ? rtag_way1[19:0] == buffer_ptag0 : `HitFail;
    assign way2_hit0  = current_mstate[1] ? rtag_way2[19:0] == buffer_ptag0 : `HitFail;
    assign way3_hit0  = current_mstate[1] ? rtag_way3[19:0] == buffer_ptag0 : `HitFail;
    assign cache_hit0 = way0_hit0 || way1_hit0 || way2_hit0 || way3_hit0;
    assign way0_hit1  = (buffer_index != 8'hff) && current_mstate[4] ? rtag_way0[19:0] == buffer_ptag1 : 
                        (buffer_index == 8'hff) && current_mstate[4] ? rtag_way0[19:0] == inst1_ptag_buffer1 :`HitFail;
    assign way1_hit1  = (buffer_index != 8'hff) && current_mstate[4] ? rtag_way1[19:0] == buffer_ptag1 : 
                        (buffer_index == 8'hff) && current_mstate[4] ? rtag_way1[19:0] == inst1_ptag_buffer1 :`HitFail;
    assign way2_hit1  = (buffer_index != 8'hff) && current_mstate[4] ? rtag_way2[19:0] == buffer_ptag1 : 
                        (buffer_index == 8'hff) && current_mstate[4] ? rtag_way2[19:0] == inst1_ptag_buffer1 :`HitFail;
    assign way3_hit1  = (buffer_index != 8'hff) && current_mstate[4] ? rtag_way3[19:0] == buffer_ptag1 : 
                        (buffer_index == 8'hff) && current_mstate[4] ? rtag_way3[19:0] == inst1_ptag_buffer1 :`HitFail;
    assign cache_hit1 = way0_hit1 || way1_hit1 || way2_hit1 || way3_hit1;
    
    // READ
    
    // Rdata Bufferrd_addr
    
    assign enb = 1'b1 ;
    //assign addrb = (next_mstate[3] || next_mstate[4]) ? inst1_index_buffer : index;
    assign addrb = current_mstate[3] ? inst1_index_buffer1 : index;
//    assign addrb = current_mstate[3] && miss_rd_finish ? inst1_index_buffer1 : 
//                   current_mstate[3] ? inst1_index_buffer0 : index;
    
    assign inst0_way0_data = buffer_offset[3:2] == 2'b00 ? rdata_way0_bank0 :
                             buffer_offset[3:2] == 2'b01 ? rdata_way0_bank1 :
                             buffer_offset[3:2] == 2'b10 ? rdata_way0_bank2 :
                             buffer_offset[3:2] == 2'b11 ? rdata_way0_bank3 :
                             32'b0;
    assign inst0_way1_data = buffer_offset[3:2] == 2'b00 ? rdata_way1_bank0 :
                             buffer_offset[3:2] == 2'b01 ? rdata_way1_bank1 :
                             buffer_offset[3:2] == 2'b10 ? rdata_way1_bank2 :
                             buffer_offset[3:2] == 2'b11 ? rdata_way1_bank3 :
                             32'b0;
    assign inst0_way2_data = buffer_offset[3:2] == 2'b00 ? rdata_way2_bank0 :
                             buffer_offset[3:2] == 2'b01 ? rdata_way2_bank1 :
                             buffer_offset[3:2] == 2'b10 ? rdata_way2_bank2 :
                             buffer_offset[3:2] == 2'b11 ? rdata_way2_bank3 :
                             32'b0;
    assign inst0_way3_data = buffer_offset[3:2] == 2'b00 ? rdata_way3_bank0 :
                             buffer_offset[3:2] == 2'b01 ? rdata_way3_bank1 :
                             buffer_offset[3:2] == 2'b10 ? rdata_way3_bank2 :
                             buffer_offset[3:2] == 2'b11 ? rdata_way3_bank3 :
                             32'b0;
    assign inst1_way0_data = (buffer_offset[3:2] == 2'b11 && current_mstate[4]) ? rdata_way0_bank0 :
                             buffer_offset[3:2] == 2'b00 ? rdata_way0_bank1 :
                             buffer_offset[3:2] == 2'b01 ? rdata_way0_bank2 :
                             buffer_offset[3:2] == 2'b10 ? rdata_way0_bank3 :
                             32'b0;
    assign inst1_way1_data = (buffer_offset[3:2] == 2'b11 && current_mstate[4]) ? rdata_way1_bank0 :
                             buffer_offset[3:2] == 2'b00 ? rdata_way1_bank1 :
                             buffer_offset[3:2] == 2'b01 ? rdata_way1_bank2 :
                             buffer_offset[3:2] == 2'b10 ? rdata_way1_bank3 :
                             32'b0;
    assign inst1_way2_data = (buffer_offset[3:2] == 2'b11 && current_mstate[4]) ? rdata_way2_bank0 :
                             buffer_offset[3:2] == 2'b00 ? rdata_way2_bank1 :
                             buffer_offset[3:2] == 2'b01 ? rdata_way2_bank2 :
                             buffer_offset[3:2] == 2'b10 ? rdata_way2_bank3 :
                             32'b0;
    assign inst1_way3_data = (buffer_offset[3:2] == 2'b11 && current_mstate[4]) ? rdata_way3_bank0 :
                             buffer_offset[3:2] == 2'b00 ? rdata_way3_bank1 :
                             buffer_offset[3:2] == 2'b01 ? rdata_way3_bank2 :
                             buffer_offset[3:2] == 2'b10 ? rdata_way3_bank3 :
                             32'b0;
    // UNCache改了这里
    assign inst0_data = current_mstate[8]             ? rd_data[31:0]  :
                        (buffer_offset[3:2] == 2'b00) ? rd_data[31:0]  :
                        (buffer_offset[3:2] == 2'b01) ? rd_data[63:32] :
                        (buffer_offset[3:2] == 2'b10) ? rd_data[95:64] :
                        (buffer_offset[3:2] == 2'b11) ? rd_data[127:96]:
                        32'b0;
    assign inst1_data = current_mstate[8]             ? rd_data[63:32] :
                        (buffer_offset[3:2] == 2'b00) ? rd_data[63:32] :
                        (buffer_offset[3:2] == 2'b01) ? rd_data[95:64] :
                        (buffer_offset[3:2] == 2'b10) ? rd_data[127:96]:
                        (buffer_offset[3:2] == 2'b11) ? rd_data[31:0]:
                        32'b0;
    
    
    // WRITE
    assign dena00 = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && PLRU_1_0_buffer) ? `WriteEnable :
                    `WriteDisable;
    assign dena01 = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && PLRU_1_0_buffer) ? `WriteEnable :
                    `WriteDisable;
    assign dena02 = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && PLRU_1_0_buffer) ? `WriteEnable :
                    `WriteDisable;
    assign dena03 = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && PLRU_1_0_buffer) ? `WriteEnable :
                    `WriteDisable;
    assign dena10 = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && ~PLRU_1_0_buffer) ? `WriteEnable :
                    `WriteDisable;
    assign dena11 = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && ~PLRU_1_0_buffer) ? `WriteEnable :
                    `WriteDisable;
    assign dena12 = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && ~PLRU_1_0_buffer) ? `WriteEnable :
                    `WriteDisable;
    assign dena13 = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && ~PLRU_1_0_buffer) ? `WriteEnable :
                    `WriteDisable;
    assign dena20 = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && PLRU_1_1_buffer) ? `WriteEnable :
                    `WriteDisable;                          
    assign dena21 = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && PLRU_1_1_buffer) ? `WriteEnable :
                    `WriteDisable;                          
    assign dena22 = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && PLRU_1_1_buffer) ? `WriteEnable :
                    `WriteDisable;                          
    assign dena23 = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && PLRU_1_1_buffer) ? `WriteEnable :
                    `WriteDisable;        
    assign dena30 = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && ~PLRU_1_1_buffer) ? `WriteEnable :
                    `WriteDisable;                           
    assign dena31 = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && ~PLRU_1_1_buffer) ? `WriteEnable :
                    `WriteDisable;                           
    assign dena32 = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && ~PLRU_1_1_buffer) ? `WriteEnable :
                    `WriteDisable;                           
    assign dena33 = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && ~PLRU_1_1_buffer) ? `WriteEnable :
                    `WriteDisable;
                     
    assign ena0   = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && PLRU_1_0_buffer)    ;
    assign ena1   = (rd_finish && (current_mstate[2] || current_mstate[5]) && PLRU_0_buffer && ~PLRU_1_0_buffer)   ;
    assign ena2   = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && PLRU_1_1_buffer)   ;
    assign ena3   = (rd_finish && (current_mstate[2] || current_mstate[5]) && ~PLRU_0_buffer && ~PLRU_1_1_buffer)  ;
    
    assign write_data0 =  rd_finish ? rd_data[31:0]   : 32'b0;
    assign write_data1 =  rd_finish ? rd_data[63:32]  : 32'b0;
    assign write_data2 =  rd_finish ? rd_data[95:64]  : 32'b0;                  
    assign write_data3 =  rd_finish ? rd_data[127:96] : 32'b0;
    
    assign wtag  = rd_finish ? buffer_ptag : 21'b0;
    assign waddr = (rd_finish && current_mstate[2]) ? buffer_index : 
                   (rd_finish && current_mstate[5]) ? inst1_index_buffer : 4'b0;
    assign dwea = rd_finish ? 1'b1 : 1'b0;
    assign wea  = rd_finish;
    
    // Signal to CPU
    
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        miss_rd_finish <= #DLY 1'b0;
      end else begin
        miss_rd_finish <= #DLY rd_finish;
      end
    end
    
    always@(posedge clk_g) begin
      if(resetn == `RstEnable || flush == `RstEnable) begin
        inst0_buffer <= 32'b0;
      end else if(cache_hit0 && buffer_offset0[3] && buffer_offset[2]) begin
        inst0_buffer <= way0_hit0 ? inst0_way0_data :
                        way1_hit0 ? inst0_way1_data :
                        way2_hit0 ? inst0_way2_data :
                        way3_hit0 ? inst0_way3_data : 
                        32'b0;
      end else if(current_mstate[2] && rd_finish && buffer_offset1[3] && buffer_offset1[2]) begin
        inst0_buffer <= inst0_data;
      end else begin
        inst0_buffer <= inst0_buffer;
      end
    end
    
    assign inst0 = current_mstate[5] && rd_finish  ? inst0_buffer :
                   current_mstate[4] && cache_hit1 ? inst0_buffer :
                   rd_finish && !current_mstate[7] ? inst0_data :
                   (way0_hit0 || way0_hit1) ? inst0_way0_data :
                   (way1_hit0 || way1_hit1) ? inst0_way1_data :
                   (way2_hit0 || way2_hit1) ? inst0_way2_data :
                   (way3_hit0 || way3_hit1) ? inst0_way3_data : 
                   32'b0;
    assign inst1 = rd_finish && !current_mstate[7] ? inst1_data :
                   (way0_hit0 || way0_hit1) ? inst1_way0_data :
                   (way1_hit0 || way1_hit1) ? inst1_way1_data :
                   (way2_hit0 || way2_hit1) ? inst1_way2_data :
                   (way3_hit0 || way3_hit1) ? inst1_way3_data :
                   32'b0;           
    assign inst0_valid = (buffer_offset[3:2]  != 2'b11) && (cache_hit0 || (current_mstate[2] && rd_finish) || 
                         (current_mstate[8] && rd_finish));
    assign inst1_valid = (buffer_offset[3:2] == 2'b11)  && (cache_hit1 || (current_mstate[5] && rd_finish) ||
                         (current_mstate[8] && rd_finish));
    assign inst0_addr  = {buffer_vtag,buffer_index,buffer_offset};
    assign inst1_addr  = (buffer_offset[3:2] == 2'b11 && inst1_index_buffer == 8'b0) ? {inst1_vtag_buffer,inst1_index_buffer,4'b0000} :
                         (buffer_offset[3:2] == 2'b11) ? {buffer_vtag,inst1_index_buffer,4'b0000} : 
                         {buffer_vtag,buffer_index,inst1_offset_buffer};
    //assign stallreq = ~((current_mstate[0]) || (next_mstate[1]) || (current_mstate[1] && next_mstate[0]));
    assign stallreq = current_mstate[2] || current_mstate[3] || current_mstate[4] || current_mstate[5] || 
                      current_mstate[6] || current_mstate[7] || current_mstate[8] ||
                      (current_mstate[1] && !cache_hit0) || (current_mstate[1] && buffer_offset[3] && buffer_offset[2]);
    // Signal to AXI
    
    assign rd_addr  = (current_mstate[5] && buffer_index != 8'hff) ? {buffer_ptag,inst1_index_buffer,4'b0000} : 
                      (current_mstate[5] && buffer_index == 8'hff) ? {inst1_ptag_buffer1,inst1_index_buffer,4'b0000} :
                      (current_mstate[8]) ? {buffer_ptag0,buffer_index0,buffer_offset0} :
                      {buffer_ptag,buffer_index,4'b0000};
    assign rd_req   = (current_mstate[2] || current_mstate[5] || current_mstate[8]) && (~rd_finish)/* ? 1'b1 : 1'b0*/;
    assign rd_type  = 3'b100;
endmodule