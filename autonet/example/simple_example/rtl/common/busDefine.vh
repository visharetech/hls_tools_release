`ifndef BUS_DEFINE_VH
`define BUS_DEFINE_VH

//Bus
`define BUS_NUM            32
`define BUS_AXILITE        0
`define BUS_UART           1
`define BUS_XMII           2
`define BUS_I2C            3
`define BUS_VIN            4
`define BUS_GPIO           5
`define BUS_DBUF           6
`define BUS_SPI            7
`define BUS_IR             8   
`define BUS_MUTEX          9
`define BUS_CMDR           10
`define BUS_RESERVED_11    11   //reserve
`define BUS_RESERVED_12    12   //reserve
`define BUS_VESA 		   13   //previous: BUS_RESERVED_13
`define BUS_RESERVED_14    14   //reserve
`define BUS_VDMA           15
`define BUS_AUDIO          16
`define BUS_RESERVED_17    17   //reserve
`define BUS_I2C_1          18
`define BUS_VMUX           19
`define BUS_PROFILER       20
`define BUS_RESERVED_21    21   //reserve
`define BUS_RESERVED_22    22   //reserve
`define BUS_RESERVED_23    23   //reserve
`define BUS_MTDMA          24
`define BUS_LONGTAIL       25
`define BUS_CABAC_BIN      26
`define BUS_BSDMA          27
`define BUS_RESERVED_28    28   //reserve
`define BUS_RESERVED_29    29   //reserve
`define BUS_DATAFLOW       30
`define BUS_VERSION        31

//AXILITE
`define AXILITE_NUM        4
`define AXILITE_CLKMGT     0
`define AXILITE_MQSTAT     1
`define AXILITE_VESA2AXIS  2
`define AXILITE_AXIS2VESA  3

`endif
