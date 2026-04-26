module fir_filter_shift/add
    #(  parameter ORDER           = 50 ,
        parameter DATA_IN_WIDTH  = 16 ,
        parameter DATA_OUT_WIDTH = 32 ,
        parameter TAP_DATA_WIDTH = 16 ,
        parameter TAP_ADDR_WIDTH = 6  )
    (
        input  wire  signed [DATA_IN_WIDTH-1 : 0]   i_fir_data_in  ,
        input  wire                                 i_fir_en       ,
        input  wire                                 i_tap_wr_en    ,
        input  wire        [TAP_ADDR_WIDTH-1 : 0]   i_tap_wr_addr  , 
        input  wire        [TAP_DATA_WIDTH-1 : 0]   i_tap_wr_data  , 
        input  wire                                 i_clk          ,
        input  wire                                 i_rst_n        ,
        output reg   signed [DATA_OUT_WIDTH-1 : 0]  o_fir_data_out      
    );

    // Internal tap (coefficients)
    reg signed [TAP_DATA_WIDTH-1 : 0] tap [0:ORDER];
    reg signed [DATA_IN_WIDTH-1  : 0] buffer [0:ORDER];

    integer i, j;

    //--- Tap coefficient load/reset logic
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            tap[0]  <= 16'sb1111_1111_1111_1101;
            tap[1]  <= 16'sb1111_1111_1110_1011;
            tap[2]  <= 16'sb1111_1111_1101_1010;
            tap[3]  <= 16'sb1111_1111_1100_1011;
            tap[4]  <= 16'sb1111_1111_1100_0101;
            tap[5]  <= 16'sb1111_1111_1101_0010;
            tap[6]  <= 16'sb1111_1111_1111_1010;
            tap[7]  <= 16'sb0000_0000_0011_1110;
            tap[8]  <= 16'sb0000_0000_1001_0011;
            tap[9]  <= 16'sb0000_0000_1101_1111;
            tap[10] <= 16'sb0000_0001_0000_0010;
            tap[11] <= 16'sb0000_0000_1101_1010;
            tap[12] <= 16'sb0000_0000_0101_0001;
            tap[13] <= 16'sb1111_1111_0110_1110;
            tap[14] <= 16'sb1111_1110_0101_0110;
            tap[15] <= 16'sb1111_1101_0101_0001;
            tap[16] <= 16'sb1111_1100_1011_1110;
            tap[17] <= 16'sb1111_1100_1111_1101;
            tap[18] <= 16'sb1111_1110_0101_0110;
            tap[19] <= 16'sb0000_0000_1110_0011;
            tap[20] <= 16'sb0000_0100_1000_0000;
            tap[21] <= 16'sb0000_1000_1100_0111;
            tap[22] <= 16'sb0000_1101_0010_0100;
            tap[23] <= 16'sb0001_0000_1110_1001;
            tap[24] <= 16'sb0001_0011_0111_0111;
            tap[25] <= 16'sb0001_0100_0101_1111;
            tap[26] <= 16'sb0001_0011_0111_0111;
            tap[27] <= 16'sb0001_0000_1110_1001;
            tap[28] <= 16'sb0000_1101_0010_0100;
            tap[29] <= 16'sb0000_1000_1100_0111;
            tap[30] <= 16'sb0000_0100_1000_0000;
            tap[31] <= 16'sb0000_0000_1110_0011;
            tap[32] <= 16'sb1111_1110_0101_0110;
            tap[33] <= 16'sb1111_1100_1111_1101;
            tap[34] <= 16'sb1111_1100_1011_1110;
            tap[35] <= 16'sb1111_1101_0101_0001;
            tap[36] <= 16'sb1111_1110_0101_0110;
            tap[37] <= 16'sb1111_1111_0110_1110;
            tap[38] <= 16'sb0000_0000_0101_0001;
            tap[39] <= 16'sb0000_0000_1101_1010;
            tap[40] <= 16'sb0000_0001_0000_0010;
            tap[41] <= 16'sb0000_0000_1101_1111;
            tap[42] <= 16'sb0000_0000_1001_0011;
            tap[43] <= 16'sb0000_0000_0011_1110;
            tap[44] <= 16'sb1111_1111_1111_1010;
            tap[45] <= 16'sb1111_1111_1101_0010;
            tap[46] <= 16'sb1111_1111_1100_0101;
            tap[47] <= 16'sb1111_1111_1100_1011;
            tap[48] <= 16'sb1111_1111_1101_1010;
            tap[49] <= 16'sb1111_1111_1110_1011;
            tap[50] <= 16'sb1111_1111_1111_1101;
        end else if(i_tap_wr_en && !i_fir_en) begin
            tap[i_tap_wr_addr] <= i_tap_wr_data;
        end
    end

    //--- Shift Register (Delay Line)
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (i = 0; i <= ORDER; i = i + 1)
                buffer[i] <= 0;
        end else if (i_fir_en) begin
            buffer[0] <= i_fir_data_in;
            for (i = 0; i < ORDER; i = i + 1)
                buffer[i+1] <= buffer[i];
        end
    end

    //--- Shift-and-Add Multiply-Accumulate
    reg signed [DATA_OUT_WIDTH-1:0] acc;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            acc <= 0;
            o_fir_data_out <= 0;
        end else if (i_fir_en) begin
            acc = 0;

            for (i = 0; i <= ORDER; i = i + 1) begin
                reg signed [TAP_DATA_WIDTH-1:0] coeff;
                reg signed [DATA_IN_WIDTH-1:0] sample;
                reg signed [DATA_OUT_WIDTH-1:0] product;

                coeff = tap[i];
                sample = buffer[i];
                product = 0;

                if (coeff[TAP_DATA_WIDTH-1]) begin
                    // Negative coeff → negate before shift-add
                    coeff = -coeff;
                    for (j = 0; j < TAP_DATA_WIDTH-1; j = j + 1)
                        if (coeff[j]) product = product - (sample <<< j);
                end else begin
                    for (j = 0; j < TAP_DATA_WIDTH; j = j + 1)
                        if (coeff[j]) product = product + (sample <<< j);
                end

                acc = acc + product;
            end

            o_fir_data_out <= acc;
        end
    end

endmodule