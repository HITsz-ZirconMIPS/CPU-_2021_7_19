/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

//*************************************************************************
//   > File Name   : 
//   > Description : SoC, included cpu, 2 x 3 bridge,
//                   inst ram, confreg, data ram
// 
//           -------------------------
//           |           cpu         |
//           -------------------------
//         inst|                  | data
//             |                  | 
//             |        ---------------------
//             |        |    1 x 2 bridge   |
//             |        ---------------------
//             |             |            |           
//             |             |            |           
//      -------------   -----------   -----------
//      | inst ram  |   | data ram|   | confreg |
//      -------------   -----------   -----------
//
//   > Author      : LOONGSON
//   > Date        : 2017-08-04
//*************************************************************************

//for simulation:
//1. if define SIMU_USE_PLL = 1, will use clk_pll to generate cpu_clk/timer_clk,
//   and simulation will be very slow.
//2. usually, please define SIMU_USE_PLL=0 to speed up simulation by assign
//   cpu_clk/timer_clk = clk.
//   at this time, cpu_clk/timer_clk frequency are both 100MHz, same as clk.
`define SIMU_USE_PLL 0 //set 0 to speed up simulation

module CPU_TOP #(parameter SIMULATION=1'b0)
(
    //todo port
    input [ 5: 0]           ext_int   ,
    output[ 1: 0]           arlock    ,//defualt:00
    output[ 3: 0]           arcache   ,//defualt:0000
    output[ 2: 0]           arprot    ,//defualt:000
    output[ 1: 0]           awlock    ,//defualt:00
    output[ 3: 0]           awcache   ,//defualt:0000
    output[ 2: 0]           awprot    ,//defualt:000
    output[ 3: 0]           wid       ,//defualt:0001


    input         cpu_resetn, 
    input         cpu_clk,

    output                   rlast    ,
    input             [31:0]rdata     ,

    input                   wready    ,
    output                   rready   ,
    output                  awready   ,
    input                   arready   ,
    output                  bready    ,

    input                   bvalid    ,
    output                   arvalid  ,
    output                   awvalid  ,
    input                   rvalid    ,
    output                   wvalid   ,

    output             [31:0]araddr   ,
    output             [ 2:0]arsize   ,

    output             [ 2:0]awsize   ,
    output             [31:0]awaddr   ,

    output                   wlast    ,
    output             [31:0]wdata    ,
    output             [ 3:0]wstrb    ,
    //!
    output             [ 3:0]awid     ,
    output             [ 7:0]awlen    ,
    output             [ 1:0]awburst  ,

    input             [ 3:0]bid       ,
    input            [ 1:0]bresp      ,
    
    output             [ 3:0]arid     ,
    output             [ 7:0]arlen    ,
    output             [ 1:0]arburst  ,                         

    input             [ 3:0]rid       ,
    input             [ 1:0]rresp     ,//ignore

    (*debug_mark = "true"*)output [31:0] debug_wb_pc1        ,
    (*debug_mark = "true"*)output [3 :0] debug_wb_rf_wen1    ,
    (*debug_mark = "true"*)output [4 :0] debug_wb_rf_wnum1   ,
    (*debug_mark = "true"*)output [31:0] debug_wb_rf_wdata1  ,
    output [31:0] debug_wb_pc2        ,
    output [3 :0] debug_wb_rf_wen2    ,
    output [4 :0] debug_wb_rf_wnum2   ,
    output [31:0] debug_wb_rf_wdata2   

    /*
    //------gpio-------
    output [15:0] led,
    output [1 :0] led_rg0,
    output [1 :0] led_rg1,
    output [7 :0] num_csn,
    output [6 :0] num_a_g,
    input  [7 :0] switch, 
    output [3 :0] btn_key_col,
    input  [3 :0] btn_key_row,
    input  [1 :0] btn_step
    */
);

assign arlock   = 2'b00     ;
assign arcache  = 4'b0000   ;
assign arprot   = 3'b000    ;
assign awlock   = 2'b00     ;
assign awcache  = 4'b0000   ;
assign awprot   = 3'b000    ;
assign wid      = 4'b0001   ;

wire[5:0] int;
wire timer_int;
    
 assign int = {5'b00000,timer_int}; //时钟中断输出作为一个中断输入   

//    wire [`InstAddrBus] inst_addr;  //虚地址
    wire [`InstBus] inst1 ;
    wire [`InstBus] inst2 ;
    wire            inst1_valid;
    wire            inst2_valid;
    wire [`InstAddrBus] inst1_addr; //怎么接？
    wire [`InstAddrBus] inst2_addr;
    wire icache_stall;
    wire flush_to_icache;
    wire cpu_inst_uncache;
    (*mark_debug = "true"*)wire cpu_data_uncache;
    

//cpu inst sram
wire        cpu_inst_en;
wire  [31:0] cpu_inst_paddr;
wire  [31:0] cpu_inst_vaddr;
/*
//cpu data ram
    wire [`DataAddrBus] mem_to_ram_raddr;
    wire [`DataAddrBus] mem_to_ram_waddr;
    wire [`DataBus] mem_to_ram_data;
    wire [3:0] mem_to_ram_sel;
    wire mem_to_ram_we;
    wire mem_to_ram_ce;
*/

//cpu data sram
wire        cpu_data_re;
wire        cpu_data_we;
wire [3 :0] cpu_data_wsel;
wire [31:0] cpu_data_raddr;
wire [31:0] cpu_data_waddr;
wire [31:0] cpu_data_wdata;
wire [31:0] cpu_data_rdata;
wire [31:0] cpu_data_addr;
wire        data_valid;
wire        dcache_stall;

//cpu
mycpu mycpu0(
        .clk(cpu_clk),  //
        .rst(~cpu_resetn),
        
        .int_i(int),
        
        .inst1_from_icache(inst1),
        .inst2_from_icache(inst2),
        .inst1_addr_from_icache(inst1_addr),
        .inst2_addr_from_icache(inst2_addr),
        
        .inst1_valid_from_icache(inst1_valid),
        .inst2_valid_from_icache(inst2_valid),
       
        . stallreq_from_icache(icache_stall),   
         
         .praddr_to_icache_o(cpu_inst_paddr),
         .vraddr_to_icache_o(cpu_inst_vaddr),
        .rreq_to_icache(cpu_inst_en)    ,
        
        //input
        .rdata_from_dcache(cpu_data_rdata), //cpu_data_rdata
        .stallreq_from_dcache(dcache_stall),
        .rdata_valid_from_dcache(data_valid), 
        //output
        .rreq_to_dcache(cpu_data_re), //cpu_data_re
        .raddr_to_dcache_o(cpu_data_raddr), //cpu_data_raddr
        .wreq_to_dcache(cpu_data_we),     //cpu_data_we
        .waddr_to_dcache_o(cpu_data_waddr),//cpu_data_waddr
        .wdata_to_dcache(cpu_data_wdata), //cpu_data_wdata
        .wsel_to_dcache(cpu_data_wsel) ,  //cpu_data_wsel
        .flush(flush_to_icache),
        
        .timer_int_o(timer_int),
          
        .inst_uncache(cpu_inst_uncache),
        .data_uncache(cpu_data_uncache),  
        
        .commit_pc1(debug_wb_pc1),   
        .commit_rf_wen1(debug_wb_rf_wen1),  
        .commit_rf_waddr1(debug_wb_rf_wnum1),
        .commit_rf_wdata1(debug_wb_rf_wdata1),
        
        .commit_pc2(debug_wb_pc2),      
        .commit_rf_wen2(debug_wb_rf_wen2),  
        .commit_rf_waddr2(debug_wb_rf_wnum2),
        .commit_rf_wdata2 (debug_wb_rf_wdata2)
      
        
        
        
    );
assign cpu_data_addr = cpu_data_we ? cpu_data_waddr :
                       cpu_data_re ? cpu_data_raddr : 
                       32'b0;

    wire               i_rd_req_i     ;
    wire  [ 2:0]       i_rd_type_i    ;
    wire  [31:0]       i_rd_addr_i    ;
    wire               i_rd_finish_o  ;

    wire               d_rd_req_i     ;
    wire  [ 2:0]       d_rd_type_i    ;
    wire  [31:0]       d_rd_addr_i    ;
    wire               d_rd_finish_o  ; 
    wire               d_wr_req_i     ;
    wire  [ 2:0]       d_wr_type_i    ;
    wire  [31:0]       d_wr_addr_i    ;
    wire  [ 3:0]       d_wr_wstrb_i   ;
    wire  [127:0]      d_wr_data_i    ;
    wire               d_wr_finish_o  ;
    wire  [127:0]      read_data      ;

// ICache
    ICache ICache(
        .clk_g(cpu_clk),
        .resetn(~cpu_resetn),
        .flush(flush_to_icache),
        .I_UnCache(cpu_inst_uncache),
        .cpu_req(cpu_inst_en),
        .index(cpu_inst_vaddr[11:4]),
        .ptag(cpu_inst_paddr[31:12]),
        .vtag(cpu_inst_vaddr[31:12]),
        .offset(cpu_inst_vaddr[3:0]),
        .stallreq(icache_stall),
        .inst0_valid(inst1_valid),
        .inst1_valid(inst2_valid),
        .inst0(inst1),
        .inst1(inst2),
        .inst0_addr(inst1_addr),
        .inst1_addr(inst2_addr),
        // Cache_AXI
        .rd_req(i_rd_req_i),  
        .rd_type(i_rd_type_i), 
        .rd_addr(i_rd_addr_i), 
        .rd_finish(i_rd_finish_o),
        .rd_data(read_data)
    ); 
    
    DCache DCache(
        .clk_g(cpu_clk),
        .resetn(~cpu_resetn),
        .D_UnCache(cpu_data_uncache),
        .valid(cpu_data_re || cpu_data_we),
        .op(cpu_data_we),
        .index(cpu_data_addr[11:4]),
        .tag(cpu_data_addr[31:12]),
        .offset(cpu_data_addr[3:0]),
        .wstrb(cpu_data_wsel),
        .wdata(cpu_data_wdata),
        .addr_ok(dcache_stall),
        .data_ok(data_valid),
        .rdata(cpu_data_rdata),
        // Cache_AXI
        .rd_req(d_rd_req_i),
        .rd_type(d_rd_type_i),
        .rd_addr(d_rd_addr_i),
        .rd_finish(d_rd_finish_o),
        .rd_data(read_data),
        .wr_req(d_wr_req_i),
        .wr_type(d_wr_type_i),
        .wr_addr(d_wr_addr_i),
        .wr_wstrb(d_wr_wstrb_i),
        .wr_data(d_wr_data_i),
        .wr_finish(d_wr_finish_o)
    );

wire flush_to_axi;
assign flush_to_axi = flush_to_icache;
    test_top AXI(.clk(cpu_clk),
                 .resetn(cpu_resetn),
                 .flush(1'b0),
                 .stall(6'b000000),
                 .i_rd_req_i(i_rd_req_i),
                 .i_rd_type_i(i_rd_type_i),
                 .i_rd_addr_i(i_rd_addr_i),
                 .i_rd_finish_o(i_rd_finish_o),

                 .d_rd_req_i(d_rd_req_i),
                 .d_rd_type_i(d_rd_type_i),
                 .d_rd_addr_i(d_rd_addr_i),
                 .d_rd_finish_o(d_rd_finish_o),

                 .d_wr_req_i(d_wr_req_i),
                 .d_wr_type_i(d_wr_type_i),
                 .d_wr_addr_i(d_wr_addr_i),
                 .d_wr_wstrb_i(d_wr_wstrb_i),
                 .d_wr_data_i(d_wr_data_i),
                 .d_wr_finish_o(d_wr_finish_o),
                 .read_data(read_data),

                 .rlast(rlast),
                 .rdata(rdata),
                 .wready(wready),
                 .rready(rready),
                 .awready(awready),
                 .arready(arready),
                 .bready(bready),
                 .bvalid(bvalid),
                 .arvalid(arvalid),
                 .awvalid(awvalid),
                 .rvalid(rvalid),
                 .wvalid(wvalid),

                 .araddr(araddr),
                 .arsize(arsize),
                 .awsize(awsize),
                 .awaddr(awaddr),
                 .wlast(wlast),
                 .wdata(wdata),
                 .wstrb(wstrb),
                 .awid(awid),
                 .awlen(awlen),
                 .awburst(awburst),

                 .bid(bid),   
                 .bresp(bresp),
                 .arid(arid),
                 .arlen(arlen),
                 .arburst(arburst),
                 .rid(rid),
                 .rresp(rresp)   
                );

endmodule

