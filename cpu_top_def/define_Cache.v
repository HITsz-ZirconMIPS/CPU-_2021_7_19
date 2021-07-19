//////////////////////////////////////////////////////////////////////////////////
// Company: ZirconMIPS
// Engineer: QiZhu
// 
// Create Date: 2021/04/22 17:26:16
// Design Name: 
// Module Name: define
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A header file for ICache
// 
// Dependencies: 
// 
// Revision:0.1
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// Reset Singal
`define RstEnable             1'b1
`define RstDisable            1'b0

// Signals of Interface between Cache and CPU
//`define CPUValid              1'b1
//`define CPUInValid            1'b0
`define AddrSuccess           1'b1
`define AddrFail              1'b0
`define DataSuccess           1'b1
`define DataFail              1'b0
`define HitSuccess            1'b1
`define HitFail               1'b0

// Signals of Interface between Cache and AXI
`define ReadEnable            1'b1
`define ReadDisable           1'b0
`define RdType_Byte           3'b000
`define RdType_HalfWord       3'b001
`define RdType_Word           3'b010
`define RdType_CacheLine      3'b100
`define RdRdyEnable           1'b1
`define RdRdyDisable          1'b0
`define RetVaild              1'b1
`define RetInValid            1'b0
`define WriteEnable           1'b1
`define WriteDisable          1'b0
`define WrReqEnable           1'b1
`define WrReqDisable          1'b0
`define WrType_Byte           3'b000
`define WrType_HalfWord       3'b001
`define WrType_Word           3'b010
`define WrType_CacheLine      3'b100

// Singals of BitWidth
`define WstrbBus              3:0
`define OffsetBus             3:0
`define TypeBus               2:0
`define IndexBus              7:0
`define TagBus                19:0
`define TagvBus               20:0
`define DataBus               31:0
`define AddrBus               31:0
`define InstBus               31:0
`define DoubleInstBus         63:0
`define LineBus               127:0
`define IMStateBus            8:0
`define DMStateBus            6:0
`define WStateBus             1:0