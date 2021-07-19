`include "define_Cache.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/04/24 18:01:22
// Design Name: 
// Module Name: test
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


module DCache(
     // 
    input  wire              clk_g,
    input  wire              resetn,
    // Cache与CPU流水线的交互接口
    input  wire              D_UnCache,  
    input  wire              valid,
    input  wire              op,    //op=1,Write
    input  wire [`IndexBus]  index,
    input  wire [`TagBus]    tag,
    input  wire [`OffsetBus] offset,
    input  wire [`WstrbBus]  wstrb,
    input  wire [`DataBus]   wdata,
    
    output wire              addr_ok,
    output wire              data_ok,
    output wire [`DataBus]   rdata,
    // Cache与AXI总线接口的交互接口
    
    output wire              rd_req,//zhe san ge tong shi
    output wire [`TypeBus]   rd_type,
    output wire [`AddrBus]   rd_addr,
    input  wire              rd_finish,
    input  wire [`LineBus]   rd_data,
    
    output wire              wr_req,//tong shi
    output wire [`TypeBus]   wr_type,
    output wire [`AddrBus]   wr_addr,
    output wire [`WstrbBus]  wr_wstrb,
    output wire [`LineBus]   wr_data,
    input  wire              wr_finish
    
);
    parameter DLY = 0;
   
    // Dirty Table
    reg [255:0]       dirty_table [3:0];
    reg               dirty_way0;
    reg               dirty_way1;
    reg               dirty_way2;
    reg               dirty_way3;
    reg               write_back;
    
    // Requset Buffer
    reg               buffer_op0;
    reg  [`IndexBus]  buffer_index0;
    reg  [`TagBus]    buffer_tag0;
    reg  [`OffsetBus] buffer_offset0;
    reg  [`WstrbBus]  buffer_wstrb0;
    reg  [`DataBus]   buffer_data0;
    reg               buffer_op1;
    reg  [`IndexBus]  buffer_index1;
    reg  [`TagBus]    buffer_tag1;
    reg  [`OffsetBus] buffer_offset1;
    
    // PLRU
    reg [255:0] PLRU_0; // 寄存器的个数即为bram中数据块的个数
    reg [255:0] PLRU_1_0;
    reg [255:0] PLRU_1_1;
    
    // Write Buffer
    reg              Write_Way0;
    reg              Write_Way1;
    reg              Write_Way2;
    reg              Write_Way3;
    reg [`IndexBus]  Write_Index;
    reg [`DataBus]   Write_Data;
    reg [`WstrbBus]  Write_Wstrb;
    reg [`OffsetBus] Write_Offset;
    reg [`TagBus]    Write_Tag;
    
    // Miss Buffer 
    reg [`DataBus]   rdata_way0_bank0_buffer;
    reg [`DataBus]   rdata_way0_bank1_buffer;
    reg [`DataBus]   rdata_way0_bank2_buffer;
    reg [`DataBus]   rdata_way0_bank3_buffer;
    reg [`DataBus]   rdata_way1_bank0_buffer;
    reg [`DataBus]   rdata_way1_bank1_buffer;
    reg [`DataBus]   rdata_way1_bank2_buffer;
    reg [`DataBus]   rdata_way1_bank3_buffer;
    reg [`DataBus]   rdata_way2_bank0_buffer;
    reg [`DataBus]   rdata_way2_bank1_buffer;
    reg [`DataBus]   rdata_way2_bank2_buffer;
    reg [`DataBus]   rdata_way2_bank3_buffer;
    reg [`DataBus]   rdata_way3_bank0_buffer;
    reg [`DataBus]   rdata_way3_bank1_buffer;
    reg [`DataBus]   rdata_way3_bank2_buffer;
    reg [`DataBus]   rdata_way3_bank3_buffer;
    reg [`TagBus]    rtag_way0_buffer ;
    reg [`TagBus]    rtag_way1_buffer ;
    reg [`TagBus]    rtag_way2_buffer ;
    reg [`TagBus]    rtag_way3_buffer ;
    reg [`LineBus]   miss_data0;
    reg [`LineBus]   miss_data1;
    reg [`LineBus]   miss_data2;
    reg [`LineBus]   miss_data3;
    reg [`TagBus]    miss_tag0;
    reg [`TagBus]    miss_tag1;
    reg [`TagBus]    miss_tag2;
    reg [`TagBus]    miss_tag3;
    
    // rd_finish buffer
    reg              miss_rd_finish;
    
    // Tag Compare
    wire             way0_hit;
    wire             way1_hit;
    wire             way2_hit;
    wire             way3_hit;
    wire             cache_hit;
    
    // Hit Write 读写地址冲突
    wire             hit_write0; // 主状态机处于LOOKUP，且有Store指令命中，而此时流水线发来一个与该Store指令地址相同的Load指令
    wire             hit_write1; // Write Buffer处于WRITE，此时流水线发来一个Load指令且Load指令地址与Store地址重叠 
    reg              buffer_hit_write; // 
    wire [`DataBus]  wsel_expand0;      // hit_write0数据前推时的拼接信号
    wire [`DataBus]  wsel_expand1;      // hit_write1数据前推时的拼接信号
    
    // Read from Data_ram and Tagv_ram
    wire             enb;
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
    wire [`TagvBus]  rtagv_way0;
    wire [`TagvBus]  rtagv_way1;
    wire [`TagvBus]  rtagv_way2;
    wire [`TagvBus]  rtagv_way3;
    
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
    wire [`TagvBus]  wtagv;
    wire [`IndexBus] waddr;
    wire [`WstrbBus] dwea;
    wire             wea; // tagv的字节选择信号
    
    // Select Data and Judge Data
    
    wire [`DataBus]  way0_data;
    wire [`DataBus]  way1_data;
    wire [`DataBus]  way2_data;
    wire [`DataBus]  way3_data;
    reg  [`DataBus]  rddata_buffer;
    reg  [`DataBus]  way0_data_buffer;
    reg  [`DataBus]  way1_data_buffer;
    reg  [`DataBus]  way2_data_buffer;
    reg  [`DataBus]  way3_data_buffer;
    
    // Variable of StateMachine
    
    reg [`DMStateBus] current_mstate;
    reg [`DMStateBus] next_mstate;
    reg [`WStateBus] current_wstate;
    reg [`WStateBus] next_wstate;
    localparam MIDLE   = 7'b0000001;
    localparam LOOKUP  = 7'b0000010;
    localparam MISS    = 7'b0000100;
    localparam REPLACE = 7'b0001000;
    localparam REFILL  = 7'b0010000;
    localparam UNREAD  = 7'b0100000;
    localparam UNWRITE = 7'b1000000;
    localparam WIDLE   = 2'b01;
    localparam WRITE   = 2'b10;
    
    
    
    // Cache Memory
    Data_RAM data_ram_way0_bank0 (
        .clka(clk_g),    // input wire clka
        .ena(dena00),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data0),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way0_bank0)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way0_bank1 (
        .clka(clk_g),    // input wire clka
        .ena(dena01),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data1),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way0_bank1)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way0_bank2 (
        .clka(clk_g),    // input wire clka
        .ena(dena02),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data2),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way0_bank2)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way0_bank3 (
        .clka(clk_g),    // input wire clka
        .ena(dena03),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data3),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way0_bank3)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way1_bank0 (
        .clka(clk_g),    // input wire clka
        .ena(dena10),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data0),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way1_bank0)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way1_bank1 (
        .clka(clk_g),    // input wire clka
        .ena(dena11),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data1),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way1_bank1)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way1_bank2 (
        .clka(clk_g),    // input wire clka
        .ena(dena12),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data2),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way1_bank2)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way1_bank3 (
        .clka(clk_g),    // input wire clka
        .ena(dena13),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data3),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way1_bank3)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way2_bank0 (
        .clka(clk_g),    // input wire clka
        .ena(dena20),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data0),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way2_bank0)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way2_bank1 (
        .clka(clk_g),    // input wire clka
        .ena(dena21),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data1),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way2_bank1)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way2_bank2 (
        .clka(clk_g),    // input wire clka
        .ena(dena22),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data2),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way2_bank2)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way2_bank3 (
        .clka(clk_g),    // input wire clka
        .ena(dena23),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data3),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way2_bank3)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way3_bank0 (
        .clka(clk_g),    // input wire clka
        .ena(dena30),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data0),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way3_bank0)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way3_bank1 (
        .clka(clk_g),    // input wire clka
        .ena(dena31),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data1),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way3_bank1)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way3_bank2 (
        .clka(clk_g),    // input wire clka
        .ena(dena32),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data2),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way3_bank2)  // output wire [31 : 0] doutb
    );
    Data_RAM data_ram_way3_bank3 (
        .clka(clk_g),    // input wire clka
        .ena(dena33),      // input wire ena
        .wea(dwea),      // input wire [3 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(write_data3),    // input wire [31 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rdata_way3_bank3)  // output wire [31 : 0] doutb
    );
    Tagv_RAM tagv_ram_way0 (
        .clka(clk_g),    // input wire clka
        .ena(ena0),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(wtagv),    // input wire [20 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rtagv_way0)  // output wire [20 : 0] doutb
    );
    Tagv_RAM tagv_ram_way1 (
        .clka(clk_g),    // input wire clka
        .ena(ena1),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(wtagv),    // input wire [20 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rtagv_way1)  // output wire [20 : 0] doutb
    );
    Tagv_RAM tagv_ram_way02(
        .clka(clk_g),    // input wire clka
        .ena(ena2),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(wtagv),    // input wire [20 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rtagv_way2)  // output wire [20 : 0] doutb
    );
    Tagv_RAM tagv_ram_way3 (
        .clka(clk_g),    // input wire clka
        .ena(ena3),      // input wire ena
        .wea(wea),      // input wire [0 : 0] wea
        .addra(waddr),  // input wire [3 : 0] addra
        .dina(wtagv),    // input wire [20 : 0] dina
        .clkb(clk_g),    // input wire clkb
        .enb(enb),      // input wire enb
        .addrb(index),  // input wire [3 : 0] addrb
        .doutb(rtagv_way3)  // output wire [20 : 0] doutb
    );
    
    // Register
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        buffer_op0     <= #DLY 1'b0 ;
        buffer_index0  <= #DLY 8'b0 ;
        buffer_tag0    <= #DLY 20'b0;
        buffer_offset0 <= #DLY 4'b0 ;
        buffer_op1     <= #DLY 1'b0 ;
        buffer_index1  <= #DLY 8'b0 ;
        buffer_tag1    <= #DLY 20'b0;
        buffer_offset1 <= #DLY 4'b0 ;
      //end else if(next_mstate[1] || current_mstate[0]) begin 
      end else if(current_mstate[1] || current_mstate[0] || D_UnCache) begin 
      // 包含两种情况，主状态机处于MIDLE状态以及主状态机处于LOOKUP状态且下一周期的主状态机仍处于LOOKUP状态
        buffer_op0     <= #DLY op    ;
        buffer_index0  <= #DLY index ;
        buffer_tag0    <= #DLY tag   ;
        buffer_offset0 <= #DLY offset;
        buffer_op1     <= #DLY buffer_op0    ;
        buffer_index1  <= #DLY buffer_index0 ;
        buffer_tag1    <= #DLY buffer_tag0   ;
        buffer_offset1 <= #DLY buffer_offset0;
      end else begin
        buffer_op0     <= #DLY buffer_op0    ;
        buffer_index0  <= #DLY buffer_index0 ;
        buffer_tag0    <= #DLY buffer_tag0   ;
        buffer_offset0 <= #DLY buffer_offset0;
        buffer_op1     <= #DLY buffer_op1    ;
        buffer_index1  <= #DLY buffer_index1 ;
        buffer_tag1    <= #DLY buffer_tag1   ;
        buffer_offset1 <= #DLY buffer_offset1;
      end
    end

    
    
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        buffer_wstrb0  <= #DLY 4'b0;
        buffer_data0   <= #DLY 32'b0;
      end else if(op && (next_mstate[1] || current_mstate[0] || D_UnCache)) begin 
      //end else if(op && (current_mstate[1] || current_mstate[0])) begin 
      // 包含两种情况，主状态机处于MIDLE状态以及主状态机处于LOOKUP状态且下一周期的主状态机仍处于LOOKUP状态
        buffer_wstrb0  <= #DLY wstrb ;
        buffer_data0   <= #DLY wdata ;
      end else begin
        buffer_wstrb0  <= #DLY buffer_wstrb0 ;
        buffer_data0   <= #DLY buffer_data0  ;
      end
    end
    // PLRU   
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        PLRU_0     <= #DLY 256'b0;
        PLRU_1_0   <= #DLY 256'b0;
        PLRU_1_1   <= #DLY 256'b0;
        dirty_way0 <= #DLY 1'b0  ;
        dirty_way1 <= #DLY 1'b0  ;
        dirty_way2 <= #DLY 1'b0  ;
        dirty_way3 <= #DLY 1'b0  ;
      end else if(cache_hit) begin
        PLRU_0[buffer_index0]    <= #DLY way0_hit || way1_hit; // 第一路的命中结果决定哪一路命中，例如way0_hit=1,way1_hit=0，则表示第0路命中,PLRU中记录的是最近没有使用的块
        PLRU_1_0[buffer_index0]  <= #DLY way0_hit || way2_hit;
        PLRU_1_1[buffer_index0]  <= #DLY way1_hit || way2_hit;
        dirty_way0 <= #DLY 1'b0  ;
        dirty_way1 <= #DLY 1'b0  ;
        dirty_way2 <= #DLY 1'b0  ;
        dirty_way3 <= #DLY 1'b0  ;
      end else if(current_mstate[1] && !cache_hit) begin // 在将缺失的数据写入cache后将新写入的块标记为最近使用过
        PLRU_0[buffer_index0]    <= #DLY ~PLRU_0[buffer_index0]  ;                                                
        PLRU_1_0[buffer_index0]  <= #DLY PLRU_0[buffer_index0] ? PLRU_1_0[buffer_index0] : ~PLRU_1_0[buffer_index0];
        PLRU_1_1[buffer_index0]  <= #DLY PLRU_0[buffer_index0] ? ~PLRU_1_1[buffer_index0] : PLRU_1_1[buffer_index0]; 
        dirty_way0 <= #DLY !PLRU_0[buffer_index0] && !PLRU_1_0[buffer_index0];
        dirty_way1 <= #DLY !PLRU_0[buffer_index0] &&  PLRU_1_0[buffer_index0];
        dirty_way2 <= #DLY PLRU_0[buffer_index0]  && !PLRU_1_1[buffer_index0];
        dirty_way3 <= #DLY PLRU_0[buffer_index0]  &&  PLRU_1_1[buffer_index0];
      end else begin
        PLRU_0   <= #DLY PLRU_0  ;
        PLRU_1_0 <= #DLY PLRU_1_0;
        PLRU_1_1 <= #DLY PLRU_1_1;
        dirty_way0 <= #DLY dirty_way0;
        dirty_way1 <= #DLY dirty_way1;
        dirty_way2 <= #DLY dirty_way2;
        dirty_way3 <= #DLY dirty_way3;
      end
    end
    /*
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        PLRU_0_buffer   <= #DLY 1'b0; 
        PLRU_1_0_buffer <= #DLY 1'b0;
        PLRU_1_1_buffer <= #DLY 1'b0;
      end else if(current_mstate[1] && !cache_hit) begin
        PLRU_0_buffer   <= #DLY ~PLRU_0[buffer_index0]  ;                                                  
        PLRU_1_0_buffer <= #DLY PLRU_0[buffer_index0] ? PLRU_1_0[buffer_index0] : ~PLRU_1_0[buffer_index0];
        PLRU_1_1_buffer <= #DLY PLRU_0[buffer_index0] ? ~PLRU_1_1[buffer_index0] : PLRU_1_1[buffer_index0];
      end else begin
        PLRU_0_buffer   <= #DLY PLRU_0_buffer  ;
        PLRU_1_0_buffer <= #DLY PLRU_1_0_buffer;
        PLRU_1_1_buffer <= #DLY PLRU_1_1_buffer;
      end
    end
    */
    // Write Buffer
    always@(posedge clk_g) begin
      if(resetn == `RstEnable || !buffer_op0) begin
        Write_Way0  <= #DLY 1'b0;
        Write_Way1  <= #DLY 1'b0;
        Write_Way2  <= #DLY 1'b0;
        Write_Way3  <= #DLY 1'b0;
        Write_Index <= #DLY 8'b0;
        Write_Data  <= #DLY 32'b0;
        Write_Wstrb <= #DLY 4'b0;
        Write_Tag   <= #DLY 20'b0;
        Write_Offset<= #DLY 4'b0;
      //end else if((next_wstate[1] || current_wstate[0]) && buffer_op0) begin
      end else if(buffer_op0) begin
        Write_Way0  <= #DLY way0_hit;
        Write_Way1  <= #DLY way1_hit;
        Write_Way2  <= #DLY way2_hit;
        Write_Way3  <= #DLY way3_hit;
        Write_Index <= #DLY buffer_index0;
        Write_Data  <= #DLY buffer_data0;
        Write_Wstrb <= #DLY buffer_wstrb0;
        Write_Tag   <= #DLY buffer_tag0;
        Write_Offset<= #DLY buffer_offset0;
      end else begin
        Write_Way0  <= #DLY Write_Way0  ;
        Write_Way1  <= #DLY Write_Way1  ;
        Write_Way2  <= #DLY Write_Way2  ;
        Write_Way3  <= #DLY Write_Way3  ;
        Write_Index <= #DLY Write_Index ;
        Write_Data  <= #DLY Write_Data  ;
        Write_Wstrb <= #DLY Write_Wstrb ;
        Write_Tag   <= #DLY Write_Tag   ;
        Write_Offset<= #DLY Write_Offset;
      end
    end
    
    // Miss Buffer // Icache用不上
    
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        rdata_way0_bank0_buffer <= #DLY 32'b0;
        rdata_way0_bank1_buffer <= #DLY 32'b0;
        rdata_way0_bank2_buffer <= #DLY 32'b0;
        rdata_way0_bank3_buffer <= #DLY 32'b0;
        rdata_way1_bank0_buffer <= #DLY 32'b0;
        rdata_way1_bank1_buffer <= #DLY 32'b0;
        rdata_way1_bank2_buffer <= #DLY 32'b0;
        rdata_way1_bank3_buffer <= #DLY 32'b0;
        rdata_way2_bank0_buffer <= #DLY 32'b0;
        rdata_way2_bank1_buffer <= #DLY 32'b0;
        rdata_way2_bank2_buffer <= #DLY 32'b0;
        rdata_way2_bank3_buffer <= #DLY 32'b0;
        rdata_way3_bank0_buffer <= #DLY 32'b0;
        rdata_way3_bank1_buffer <= #DLY 32'b0;
        rdata_way3_bank2_buffer <= #DLY 32'b0;
        rdata_way3_bank3_buffer <= #DLY 32'b0;
        rtag_way0_buffer        <= #DLY 20'b0;
        rtag_way1_buffer        <= #DLY 20'b0;
        rtag_way2_buffer        <= #DLY 20'b0;
        rtag_way3_buffer        <= #DLY 20'b0;
      end else if(current_mstate[0] || current_mstate[1]) begin
        rdata_way0_bank0_buffer <= #DLY rdata_way0_bank0;
        rdata_way0_bank1_buffer <= #DLY rdata_way0_bank1;
        rdata_way0_bank2_buffer <= #DLY rdata_way0_bank2;
        rdata_way0_bank3_buffer <= #DLY rdata_way0_bank3;
        rdata_way1_bank0_buffer <= #DLY rdata_way1_bank0;
        rdata_way1_bank1_buffer <= #DLY rdata_way1_bank1;
        rdata_way1_bank2_buffer <= #DLY rdata_way1_bank2;
        rdata_way1_bank3_buffer <= #DLY rdata_way1_bank3;
        rdata_way2_bank0_buffer <= #DLY rdata_way2_bank0;
        rdata_way2_bank1_buffer <= #DLY rdata_way2_bank1;
        rdata_way2_bank2_buffer <= #DLY rdata_way2_bank2;
        rdata_way2_bank3_buffer <= #DLY rdata_way2_bank3;
        rdata_way3_bank0_buffer <= #DLY rdata_way3_bank0;
        rdata_way3_bank1_buffer <= #DLY rdata_way3_bank1;
        rdata_way3_bank2_buffer <= #DLY rdata_way3_bank2;
        rdata_way3_bank3_buffer <= #DLY rdata_way3_bank3;
        rtag_way0_buffer        <= #DLY rtagv_way0[19:0];      
        rtag_way1_buffer        <= #DLY rtagv_way1[19:0]; 
        rtag_way2_buffer        <= #DLY rtagv_way2[19:0];      
        rtag_way3_buffer        <= #DLY rtagv_way3[19:0];      
      end else begin
        rdata_way0_bank0_buffer <= #DLY rdata_way0_bank0_buffer;
        rdata_way0_bank1_buffer <= #DLY rdata_way0_bank1_buffer;
        rdata_way0_bank2_buffer <= #DLY rdata_way0_bank2_buffer;
        rdata_way0_bank3_buffer <= #DLY rdata_way0_bank3_buffer;
        rdata_way1_bank0_buffer <= #DLY rdata_way1_bank0_buffer;
        rdata_way1_bank1_buffer <= #DLY rdata_way1_bank1_buffer;
        rdata_way1_bank2_buffer <= #DLY rdata_way1_bank2_buffer;
        rdata_way1_bank3_buffer <= #DLY rdata_way1_bank3_buffer;
        rdata_way2_bank0_buffer <= #DLY rdata_way2_bank0_buffer;
        rdata_way2_bank1_buffer <= #DLY rdata_way2_bank1_buffer;
        rdata_way2_bank2_buffer <= #DLY rdata_way2_bank2_buffer;
        rdata_way2_bank3_buffer <= #DLY rdata_way2_bank3_buffer;
        rdata_way3_bank0_buffer <= #DLY rdata_way3_bank0_buffer;
        rdata_way3_bank1_buffer <= #DLY rdata_way3_bank1_buffer;
        rdata_way3_bank2_buffer <= #DLY rdata_way3_bank2_buffer;
        rdata_way3_bank3_buffer <= #DLY rdata_way3_bank3_buffer;
        rtag_way0_buffer        <= #DLY rtag_way0_buffer       ;
        rtag_way1_buffer        <= #DLY rtag_way1_buffer       ;
        rtag_way2_buffer        <= #DLY rtag_way2_buffer       ;
        rtag_way3_buffer        <= #DLY rtag_way3_buffer       ;
      end
    end
    
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        miss_data0 <= #DLY 128'b0;
        miss_data1 <= #DLY 128'b0;
        miss_data2 <= #DLY 128'b0;
        miss_data3 <= #DLY 128'b0;
        miss_tag0  <= #DLY 20'b0;
        miss_tag1  <= #DLY 20'b0;
        miss_tag2  <= #DLY 20'b0;
        miss_tag3  <= #DLY 20'b0;
      end else if(current_mstate[2])begin//可能会有问题
        miss_data0 <= #DLY {rdata_way0_bank3_buffer,rdata_way0_bank2_buffer,rdata_way0_bank1_buffer,rdata_way0_bank0_buffer};
        miss_data1 <= #DLY {rdata_way1_bank3_buffer,rdata_way1_bank2_buffer,rdata_way1_bank1_buffer,rdata_way1_bank0_buffer};
        miss_data2 <= #DLY {rdata_way2_bank3_buffer,rdata_way2_bank2_buffer,rdata_way2_bank1_buffer,rdata_way2_bank0_buffer};
        miss_data3 <= #DLY {rdata_way3_bank3_buffer,rdata_way3_bank2_buffer,rdata_way3_bank1_buffer,rdata_way3_bank0_buffer};
        miss_tag0  <= #DLY rtag_way0_buffer;
        miss_tag1  <= #DLY rtag_way1_buffer;
        miss_tag2  <= #DLY rtag_way0_buffer;
        miss_tag3  <= #DLY rtag_way1_buffer;
      end else begin
        miss_data0 <= #DLY miss_data0;
        miss_data1 <= #DLY miss_data1;
        miss_data2 <= #DLY miss_data2;
        miss_data3 <= #DLY miss_data3;
        miss_tag0  <= #DLY miss_tag0;
        miss_tag1  <= #DLY miss_tag1;
        miss_tag2  <= #DLY miss_tag2;
        miss_tag3  <= #DLY miss_tag3;
      end
    end
    
    // Dirty Table
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        dirty_table[0] <= #DLY 256'b0;
        dirty_table[1] <= #DLY 256'b0;
        dirty_table[2] <= #DLY 256'b0;
        dirty_table[3] <= #DLY 256'b0;
      end else if(cache_hit && buffer_op0) begin
        dirty_table[0][buffer_index0] <= #DLY dirty_table[0][buffer_index0] || way0_hit;
        dirty_table[1][buffer_index0] <= #DLY dirty_table[1][buffer_index0] || way1_hit;
        dirty_table[2][buffer_index0] <= #DLY dirty_table[2][buffer_index0] || way2_hit;
        dirty_table[3][buffer_index0] <= #DLY dirty_table[3][buffer_index0] || way3_hit;
      end else if(rd_finish) begin
        dirty_table[0][buffer_index1] <= #DLY dirty_way0 ? buffer_op1 : dirty_table[0][buffer_index1];
        dirty_table[1][buffer_index1] <= #DLY dirty_way1 ? buffer_op1 : dirty_table[1][buffer_index1];
        dirty_table[2][buffer_index1] <= #DLY dirty_way2 ? buffer_op1 : dirty_table[2][buffer_index1];
        dirty_table[3][buffer_index1] <= #DLY dirty_way3 ? buffer_op1 : dirty_table[3][buffer_index1];
      end else begin
        dirty_table[0] <= #DLY dirty_table[0];
        dirty_table[1] <= #DLY dirty_table[1]; 
        dirty_table[2] <= #DLY dirty_table[2];
        dirty_table[3] <= #DLY dirty_table[3];
      end
    end
    
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        write_back <= #DLY 1'b0;
      end else if(current_mstate[2]) begin
        write_back <= #DLY dirty_way0 ? dirty_table[0][buffer_index1] :
                           dirty_way1 ? dirty_table[1][buffer_index1] :
                           dirty_way2 ? dirty_table[2][buffer_index1] :
                           dirty_way3 ? dirty_table[3][buffer_index1] :
                           1'b0;
      end else begin
        write_back <= #DLY write_back;
      end
    end
    
    // Main State Machine
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        current_mstate <= #DLY MIDLE;
      end else if(op && D_UnCache) begin
        current_mstate <= #DLY UNWRITE;
      end else if(!op && D_UnCache) begin
        current_mstate <= #DLY UNREAD;
      end else begin
        current_mstate <= #DLY next_mstate;
      end
    end
    
    always@(*) begin
      case(current_mstate)
        MIDLE : begin
          if(valid)
            next_mstate <= #DLY LOOKUP;
          else
            next_mstate <= #DLY MIDLE;
        end
        LOOKUP : begin
          if(cache_hit) begin
            if(valid) begin
              next_mstate <= #DLY LOOKUP;
            end else begin
              next_mstate <= #DLY MIDLE;
            end
          end else
            next_mstate <= #DLY MISS;
        end
        MISS : begin
          next_mstate <= #DLY REPLACE;
        end
        REPLACE : begin
          if(wr_finish || !write_back)
            next_mstate <= #DLY REFILL;
          else
            next_mstate <= #DLY REPLACE;
        end
        REFILL : begin
          if(!rd_finish)
            next_mstate <= #DLY REFILL;
          else
            next_mstate <= #DLY MIDLE;
        end
        UNREAD : begin
          if(!rd_finish)
            next_mstate <= #DLY UNREAD;
          else
            next_mstate <= #DLY MIDLE;
        end
        UNWRITE : begin
          if(!wr_finish)
            next_mstate <= #DLY UNWRITE;
          else
            next_mstate <= #DLY MIDLE;
        end
        default : begin
          next_mstate <= #DLY MIDLE;
        end
      endcase
    end
    
    // Write State Machine
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        current_wstate <= #DLY WIDLE;
      end else begin
        current_wstate <= #DLY next_wstate;
      end
    end
    
    always@(*) begin
      case(current_wstate)
        WIDLE : begin
          if(cache_hit && buffer_op0) begin
            next_wstate <= #DLY WRITE;
          end else begin
            next_wstate <= #DLY WIDLE;
          end
        end
        WRITE : begin
          if(cache_hit && buffer_op0) begin
            next_wstate <= #DLY WRITE;
          end else begin
            next_wstate <= #DLY WIDLE;
          end
        end
        default : begin
          next_wstate <= #DLY WIDLE;
        end
      endcase
    end

    assign way0_hit  = (current_mstate[1]) ? (rtagv_way0[19:0] == buffer_tag0 && rtagv_way0[20]) : `HitFail;
    assign way1_hit  = (current_mstate[1]) ? (rtagv_way1[19:0] == buffer_tag0 && rtagv_way1[20]) : `HitFail;
    assign way2_hit  = (current_mstate[1]) ? (rtagv_way2[19:0] == buffer_tag0 && rtagv_way2[20]) : `HitFail;
    assign way3_hit  = (current_mstate[1]) ? (rtagv_way3[19:0] == buffer_tag0 && rtagv_way3[20]) : `HitFail;
    assign cache_hit = way0_hit || way1_hit || way2_hit || way3_hit;
    
    
    // Hit Write 读写地址冲突 // 该处的buffer应该用哪一个尚不清楚  
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        buffer_hit_write <= #DLY 1'b0;
      end else begin                    
        buffer_hit_write <= #DLY hit_write0 || hit_write1;
      end
    end
    
    assign hit_write0 = (cache_hit && buffer_op0 && !op && valid && buffer_tag0 == tag && 
                         buffer_index0 == index && buffer_offset0[3:2] == offset[3:2]);
    assign hit_write1 = (current_wstate == WRITE && !op && valid &&
                         offset[3:2] == Write_Offset[3:2] && 
                         tag == Write_Tag);
    assign wsel_expand0 = {{8{buffer_wstrb0[3]}} , {8{buffer_wstrb0[2]}} , {8{buffer_wstrb0[1]}} , {8{buffer_wstrb0[0]}}};
    assign wsel_expand1 = {{8{Write_Wstrb[3]}} , {8{Write_Wstrb[2]}} , {8{Write_Wstrb[1]}} , {8{Write_Wstrb[0]}}};
    
    // READ
    
    // Rdata Bufferrd_addr
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        way0_data_buffer <= #DLY 32'h00000000;
        way1_data_buffer <= #DLY 32'h00000000;
        way2_data_buffer <= #DLY 32'h00000000;
        way3_data_buffer <= #DLY 32'h00000000;
      end else if(hit_write0) begin
        if(!hit_write0) begin //没有发生"写写读"的情况
          way0_data_buffer <= #DLY (buffer_data0 & wsel_expand0) | (way0_data & (~wsel_expand0));
          way1_data_buffer <= #DLY (buffer_data0 & wsel_expand0) | (way1_data & (~wsel_expand0));
          way2_data_buffer <= #DLY (buffer_data0 & wsel_expand0) | (way2_data & (~wsel_expand0));
          way3_data_buffer <= #DLY (buffer_data0 & wsel_expand0) | (way3_data & (~wsel_expand0));
        end else begin // 发生"写写读"的情况
          way0_data_buffer <= #DLY (buffer_data0 & wsel_expand0) | (Write_Data & ((~wsel_expand0) & wsel_expand1)) | (way0_data & (~(wsel_expand0 | wsel_expand1)));
          way1_data_buffer <= #DLY (buffer_data0 & wsel_expand0) | (Write_Data & ((~wsel_expand0) & wsel_expand1)) | (way1_data & (~(wsel_expand0 | wsel_expand1)));
          way2_data_buffer <= #DLY (buffer_data0 & wsel_expand0) | (Write_Data & ((~wsel_expand0) & wsel_expand1)) | (way2_data & (~(wsel_expand0 | wsel_expand1)));
          way3_data_buffer <= #DLY (buffer_data0 & wsel_expand0) | (Write_Data & ((~wsel_expand0) & wsel_expand1)) | (way3_data & (~(wsel_expand0 | wsel_expand1)));
        end
      end else if(hit_write1) begin
        way0_data_buffer <= #DLY (Write_Data & wsel_expand1) | (way0_data & (~wsel_expand1));
        way1_data_buffer <= #DLY (Write_Data & wsel_expand1) | (way1_data & (~wsel_expand1));
        way2_data_buffer <= #DLY (Write_Data & wsel_expand1) | (way2_data & (~wsel_expand1));
        way3_data_buffer <= #DLY (Write_Data & wsel_expand1) | (way3_data & (~wsel_expand1));
      end else begin
        way0_data_buffer <= #DLY way0_data_buffer;
        way1_data_buffer <= #DLY way1_data_buffer;
        way2_data_buffer <= #DLY way2_data_buffer;
        way3_data_buffer <= #DLY way3_data_buffer;
      end
    end
    
    assign enb = 1'b1 ;

    assign way0_data = buffer_hit_write             ? way0_data_buffer :
                       buffer_offset0[3:2] == 2'b00 ? rdata_way0_bank0 :
                       buffer_offset0[3:2] == 2'b01 ? rdata_way0_bank1 :
                       buffer_offset0[3:2] == 2'b10 ? rdata_way0_bank2 :
                       buffer_offset0[3:2] == 2'b11 ? rdata_way0_bank3 :
                       32'b0;
    assign way1_data = buffer_hit_write             ? way1_data_buffer :
                       buffer_offset0[3:2] == 2'b00 ? rdata_way1_bank0 :
                       buffer_offset0[3:2] == 2'b01 ? rdata_way1_bank1 :
                       buffer_offset0[3:2] == 2'b10 ? rdata_way1_bank2 :
                       buffer_offset0[3:2] == 2'b11 ? rdata_way1_bank3 :
                       32'b0;
    assign way2_data = buffer_hit_write             ? way2_data_buffer :
                       buffer_offset0[3:2] == 2'b00 ? rdata_way2_bank0 :
                       buffer_offset0[3:2] == 2'b01 ? rdata_way2_bank1 :
                       buffer_offset0[3:2] == 2'b10 ? rdata_way2_bank2 :
                       buffer_offset0[3:2] == 2'b11 ? rdata_way2_bank3 :
                       32'b0;
    assign way3_data = buffer_hit_write             ? way3_data_buffer :
                       buffer_offset0[3:2] == 2'b00 ? rdata_way3_bank0 :
                       buffer_offset0[3:2] == 2'b01 ? rdata_way3_bank1 :
                       buffer_offset0[3:2] == 2'b10 ? rdata_way3_bank2 :
                       buffer_offset0[3:2] == 2'b11 ? rdata_way3_bank3 :
                       32'b0;
    assign rdata = //miss_rd_finish ? rd_data[31:0] :
                   //miss_rd_finish && (!buffer_op1) ? rddata_buffer :
                   miss_rd_finish ? rddata_buffer :
                   way0_hit ? way0_data :
                   way1_hit ? way1_data :
                   way2_hit ? way2_data :
                   way3_hit ? way3_data :
                   32'b0;
    
    always@(posedge clk_g) begin
      if(resetn == `RstEnable) begin
        miss_rd_finish <= #DLY 1'b0;
        rddata_buffer  <= #DLY 32'b0;
      end else begin
        miss_rd_finish <= #DLY rd_finish;
        rddata_buffer  <= current_mstate[5]              ? rd_data[31:0]  :
                          (buffer_offset1[3:2] == 2'b00) ? rd_data[31:0]  :
                          (buffer_offset1[3:2] == 2'b01) ? rd_data[63:32] :
                          (buffer_offset1[3:2] == 2'b10) ? rd_data[95:64] :
                          (buffer_offset1[3:2] == 2'b11) ? rd_data[127:96]:
                          32'b0;
      end
    end
    
    // WRITE
    assign dena00 = (rd_finish && dirty_way0 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way0 &&
                     Write_Offset[3:2] == 2'b00) ? `WriteEnable :`WriteDisable;
    assign dena01 = (rd_finish && dirty_way0 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way0 &&
                     Write_Offset[3:2] == 2'b01) ? `WriteEnable :`WriteDisable;
    assign dena02 = (rd_finish && dirty_way0 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way0 &&
                     Write_Offset[3:2] == 2'b10) ? `WriteEnable :`WriteDisable;
    assign dena03 = (rd_finish && dirty_way0 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way0 &&
                     Write_Offset[3:2] == 2'b11) ? `WriteEnable :`WriteDisable;
    assign dena10 = (rd_finish && dirty_way1 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way1 &&
                     Write_Offset[3:2] == 2'b00) ? `WriteEnable :`WriteDisable;
    assign dena11 = (rd_finish && dirty_way1 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way1 &&
                     Write_Offset[3:2] == 2'b01) ? `WriteEnable :`WriteDisable;
    assign dena12 = (rd_finish && dirty_way1 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way1 &&
                     Write_Offset[3:2] == 2'b10) ? `WriteEnable :`WriteDisable;
    assign dena13 = (rd_finish && dirty_way1 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way1 &&
                     Write_Offset[3:2] == 2'b11) ? `WriteEnable :`WriteDisable;
    assign dena20 = (rd_finish && dirty_way2 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way2 &&
                     Write_Offset[3:2] == 2'b00) ? `WriteEnable :`WriteDisable;
    assign dena21 = (rd_finish && dirty_way2 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way2 &&
                     Write_Offset[3:2] == 2'b01) ? `WriteEnable :`WriteDisable;
    assign dena22 = (rd_finish && dirty_way2 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way2 &&
                     Write_Offset[3:2] == 2'b10) ? `WriteEnable :`WriteDisable;
    assign dena23 = (rd_finish && dirty_way2 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way2 &&
                     Write_Offset[3:2] == 2'b11) ? `WriteEnable :`WriteDisable;
    assign dena30 = (rd_finish && dirty_way3 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way3 &&
                     Write_Offset[3:2] == 2'b00) ? `WriteEnable :`WriteDisable;
    assign dena31 = (rd_finish && dirty_way3 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way3 &&
                     Write_Offset[3:2] == 2'b01) ? `WriteEnable :`WriteDisable;
    assign dena32 = (rd_finish && dirty_way3 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way3 &&
                     Write_Offset[3:2] == 2'b10) ? `WriteEnable :`WriteDisable;
    assign dena33 = (rd_finish && dirty_way3 && current_mstate[4]) ? `WriteEnable :
                    (current_wstate == WRITE && Write_Way3 &&
                     Write_Offset[3:2] == 2'b11) ? `WriteEnable :`WriteDisable;
                     
    assign ena0   = (rd_finish && dirty_way0 && current_mstate[4]);
    assign ena1   = (rd_finish && dirty_way1 && current_mstate[4]);
    assign ena2   = (rd_finish && dirty_way2 && current_mstate[4]);
    assign ena3   = (rd_finish && dirty_way3 && current_mstate[4]);
    
    assign write_data0 =  (rd_finish && buffer_op1 && (buffer_offset1[3:2] == 2'b00)) ? (buffer_data0 & wsel_expand0) | (rd_data[31:0] & (~wsel_expand0)):
                          rd_finish ? rd_data[31:0]   :
                          (current_wstate == WRITE) ? Write_Data : 32'b0;
    assign write_data1 =  (rd_finish && buffer_op1 && (buffer_offset1[3:2] == 2'b01)) ? (buffer_data0 & wsel_expand0) | (rd_data[63:32] & (~wsel_expand0)):
                          rd_finish ? rd_data[63:32]  :
                          (current_wstate == WRITE) ? Write_Data : 32'b0;
    assign write_data2 =  (rd_finish && buffer_op1 && (buffer_offset1[3:2] == 2'b10)) ? (buffer_data0 & wsel_expand0) | (rd_data[95:64] & (~wsel_expand0)):
                          rd_finish ? rd_data[95:64]  :
                          (current_wstate == WRITE) ? Write_Data : 32'b0;
    assign write_data3 =  (rd_finish && buffer_op1 && (buffer_offset1[3:2] == 2'b11)) ? (buffer_data0 & wsel_expand0) | (rd_data[127:96] & (~wsel_expand0)):
                          rd_finish ? rd_data[127:96] :
                          (current_wstate == WRITE) ? Write_Data : 32'b0;
    assign wtagv = rd_finish ? {1'b1,buffer_tag1} : 21'b0;
    assign waddr = rd_finish ? buffer_index1 :
                   (current_wstate == WRITE) ? Write_Index : 4'b0;
    assign dwea = rd_finish ? 4'b1111 :
                  (current_wstate == WRITE) ? Write_Wstrb : 4'b0;
    assign wea  = rd_finish;
    
    // Signal to CPU

    
    assign data_ok = ((cache_hit && !buffer_op0) || (miss_rd_finish && !buffer_op1) || wr_finish);//可能有问题
    //assign addr_ok = ~((current_mstate[0] || current_mstate[1]) && !wr_finish && !miss_rd_finish && !next_mstate[2]) && !miss_rd_finish && !wr_finish;
    assign addr_ok = (current_mstate[1] && !cache_hit)|| current_mstate[2] || current_mstate[3] || current_mstate[4] || current_mstate[5] || current_mstate[6] ;
    // 将miss_rd_finish去除，改为rd_finish
    // Signal to AXI
    
    assign wr_addr  = current_mstate[6] ? {buffer_tag0,buffer_index0,buffer_offset0} :
                      dirty_way0 ? {miss_tag0,buffer_index1,buffer_offset1} : 
                      dirty_way1 ? {miss_tag1,buffer_index1,buffer_offset1} :
                      dirty_way2 ? {miss_tag2,buffer_index1,buffer_offset1} : 
                      dirty_way3 ? {miss_tag3,buffer_index1,buffer_offset1} :
                      32'b0;
    assign wr_data  = current_mstate[6] ? {buffer_data0,96'b0} :
                      dirty_way0 ? miss_data0 : 
                      dirty_way1 ? miss_data1 :
                      dirty_way2 ? miss_data2 : 
                      dirty_way3 ? miss_data3 :
                      128'b0;
    assign wr_req   = ((current_mstate[3]) && (!wr_finish) && write_back) || (current_mstate[6] && (!wr_finish));
    assign wr_wstrb = current_mstate[4] ? 4'b1111 : buffer_wstrb0;
    assign wr_type  = current_mstate[4] ? 3'b100 : 3'b010; 
    assign rd_addr  = current_mstate[4] ? {buffer_tag1,buffer_index1,4'b0} :
                      current_mstate[5] ? {buffer_tag0,buffer_index0,buffer_offset0} :
                      32'b0;
    assign rd_req   = (current_mstate[4] || current_mstate[5]) && (~rd_finish)/* ? 1'b1 : 1'b0*/;
    assign rd_type  = current_mstate[4] ? 3'b100 : 3'b010; 
endmodule