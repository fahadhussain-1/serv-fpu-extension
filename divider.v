`timescale 1ns / 1ps

module divider (
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] out
);
    // Extract components
    wire a_sign = a[31];
    wire [7:0] a_exp = a[30:23];
    wire [23:0] a_mant = (|a_exp) ? {1'b1, a[22:0]} : {1'b0, a[22:0]};
    
    wire b_sign = b[31];
    wire [7:0] b_exp = b[30:23];
    wire [23:0] b_mant = (|b_exp) ? {1'b1, b[22:0]} : {1'b0, b[22:0]};
    
    // Special cases
    wire a_zero = (a_exp == 0) && (a[22:0] == 0);
    wire b_zero = (b_exp == 0) && (b[22:0] == 0);
    wire a_inf = (a_exp == 8'hFF) && (a[22:0] == 0);
    wire b_inf = (b_exp == 8'hFF) && (b[22:0] == 0);
    wire a_nan = (a_exp == 8'hFF) && (|a[22:0]);
    wire b_nan = (b_exp == 8'hFF) && (|b[22:0]);
    
    // Reciprocal approximation (Goldschmidt algorithm)
    wire [31:0] b_reciprocal;
    fp_reciprocal recip(.a(b), .r(b_reciprocal));
    
    // Multiply a × (1/b)
    wire [31:0] product;
    multiplier mult(.a(a), .b(b_reciprocal), .out(product));
    
    always @(*) begin
        if (a_nan || b_nan) begin
            out = 32'h7FC00000; // NaN
        end
        else if (a_inf && b_inf) begin
            out = 32'h7FC00000; // ?/? = NaN
        end
        else if (a_zero && b_zero) begin
            out = 32'h7FC00000; // 0/0 = NaN
        end
        else if (b_zero) begin
            out = {a_sign ^ b_sign, 8'hFF, 23'h0}; // x/0 = ±?
        end
        else if (a_inf) begin
            out = {a_sign ^ b_sign, 8'hFF, 23'h0}; // ?/x = ±?
        end
        else if (b_inf) begin
            out = {a_sign ^ b_sign, 8'h0, 23'h0}; // x/? = 0
        end
        else if (a_zero) begin
            out = {a_sign ^ b_sign, 8'h0, 23'h0}; // 0/x = 0
        end
        else begin
            out = product;
        end
    end
endmodule

//RECIPROCAL MODULE
module fp_reciprocal (
    input  wire [31:0] a,    // IEEE-754 single-precision input
    output wire [31:0] r     // Reciprocal result
);

    wire sign;
    wire [7:0] exponent;
    wire [22:0] mantissa;
    wire [31:0] norm_mant;
    wire [31:0] x0, x1;
    wire [31:0] one = 32'h3F800000; // 1.0 in IEEE-754

    // Extract sign, exponent and mantissa
    assign sign     = a[31];
    assign exponent = a[30:23];
    assign mantissa = a[22:0];

    // Normalize mantissa (add implicit 1 at MSB)
    assign norm_mant = {1'b0, 8'd127, 1'b1, mantissa}; // Normalize to 1.M

    // Lookup Table for initial guess of reciprocal
    // For simplicity, using upper 8 bits of mantissa as index
    //wire [31:0] x0;
lut_rom my_lut (
    .addr(mantissa[22:15]),
    .data(x0)
);



    // Newton-Raphson Iteration: x1 = x0 * (2 - a * x0)
    wire [31:0] ax0, two_minus_ax0;

    multiplier mul1 (.a(a),    .b(x0), .out(ax0));
    adder sub1 (.a(one << 1), .b(ax0), .out(two_minus_ax0)); // 2.0 - a*x0
    multiplier mul2 (.a(x0),   .b(two_minus_ax0), .out(x1));       // x1 = x0 * (2 - ax0)
    
    
    
    //SECOND ITERATION
    

    assign r = {sign, (8'd253 - exponent), x1[22:0]}; // Adjust exponent for reciprocal

endmodule

//lut ROM
module lut_rom (
    input  wire [7:0] addr,
    output reg  [31:0] data
);

    always @(*) begin
        case (addr)
            8'd0  : data = 32'h3F800000;
            8'd1  : data = 32'h3F7F00FF;
            8'd2  : data = 32'h3F7E03F8;
            8'd3  : data = 32'h3F7D08E5;
            8'd4  : data = 32'h3F7C0FC1;
            8'd5  : data = 32'h3F7B1885;
            8'd6  : data = 32'h3F7A232D;
            8'd7  : data = 32'h3F792FB2;
            8'd8  : data = 32'h3F783E10;
            8'd9  : data = 32'h3F774E40;
            8'd10 : data = 32'h3F76603E;
            8'd11 : data = 32'h3F757404;
            8'd12 : data = 32'h3F74898D;
            8'd13 : data = 32'h3F73A0D5;
            8'd14 : data = 32'h3F72B9D6;
            8'd15 : data = 32'h3F71D48C;
            8'd16 : data = 32'h3F70F0F1;
            8'd17 : data = 32'h3F700F01;
            8'd18 : data = 32'h3F6F2EB7;
            8'd19 : data = 32'h3F6E500F;
            8'd20 : data = 32'h3F6D7304;
            8'd21 : data = 32'h3F6C9791;
            8'd22 : data = 32'h3F6BBDB3;
            8'd23 : data = 32'h3F6AE564;
            8'd24 : data = 32'h3F6A0EA1;
            8'd25 : data = 32'h3F693965;
            8'd26 : data = 32'h3F6865AC;
            8'd27 : data = 32'h3F679373;
            8'd28 : data = 32'h3F66C2B4;
            8'd29 : data = 32'h3F65F36D;
            8'd30 : data = 32'h3F652598;
            8'd31 : data = 32'h3F645933;
            8'd32 : data = 32'h3F638E39;
            8'd33 : data = 32'h3F62C4A7;
            8'd34 : data = 32'h3F61FC78;
            8'd35 : data = 32'h3F6135AA;
            8'd36 : data = 32'h3F607038;
            8'd37 : data = 32'h3F5FAC1F;
            8'd38 : data = 32'h3F5EE95C;
            8'd39 : data = 32'h3F5E27EB;
            8'd40 : data = 32'h3F5D67C9;
            8'd41 : data = 32'h3F5CA8F1;
            8'd42 : data = 32'h3F5BEB62;
            8'd43 : data = 32'h3F5B2F17;
            8'd44 : data = 32'h3F5A740E;
            8'd45 : data = 32'h3F59BA42;
            8'd46 : data = 32'h3F5901B2;
            8'd47 : data = 32'h3F584A5A;
            8'd48 : data = 32'h3F579436;
            8'd49 : data = 32'h3F56DF44;
            8'd50 : data = 32'h3F562B81;
            8'd51 : data = 32'h3F5578E9;
            8'd52 : data = 32'h3F54C77B;
            8'd53 : data = 32'h3F541733;
            8'd54 : data = 32'h3F53680D;
            8'd55 : data = 32'h3F52BA08;
            8'd56 : data = 32'h3F520D21;
            8'd57 : data = 32'h3F516154;
            8'd58 : data = 32'h3F50B6A0;
            8'd59 : data = 32'h3F500D01;
            8'd60 : data = 32'h3F4F6475;
            8'd61 : data = 32'h3F4EBCF9;
            8'd62 : data = 32'h3F4E168A;
            8'd63 : data = 32'h3F4D7127;
            8'd64 : data = 32'h3F4CCCCD;
            8'd65 : data = 32'h3F4C2978;
            8'd66 : data = 32'h3F4B8728;
            8'd67 : data = 32'h3F4AE5D8;
            8'd68 : data = 32'h3F4A4588;
            8'd69 : data = 32'h3F49A634;
            8'd70 : data = 32'h3F4907DA;
            8'd71 : data = 32'h3F486A79;
            8'd72 : data = 32'h3F47CE0C;
            8'd73 : data = 32'h3F473294;
            8'd74 : data = 32'h3F46980C;
            8'd75 : data = 32'h3F45FE74;
            8'd76 : data = 32'h3F4565C8;
            8'd77 : data = 32'h3F44CE08;
            8'd78 : data = 32'h3F443730;
            8'd79 : data = 32'h3F43A13E;
            8'd80 : data = 32'h3F430C31;
            8'd81 : data = 32'h3F427806;
            8'd82 : data = 32'h3F41E4BC;
            8'd83 : data = 32'h3F415250;
            8'd84 : data = 32'h3F40C0C1;
            8'd85 : data = 32'h3F40300C;
            8'd86 : data = 32'h3F3FA030;
            8'd87 : data = 32'h3F3F112B;
            8'd88 : data = 32'h3F3E82FA;
            8'd89 : data = 32'h3F3DF59D;
            8'd90 : data = 32'h3F3D6910;
            8'd91 : data = 32'h3F3CDD53;
            8'd92 : data = 32'h3F3C5264;
            8'd93 : data = 32'h3F3BC841;
            8'd94 : data = 32'h3F3B3EE7;
            8'd95 : data = 32'h3F3AB656;
            8'd96 : data = 32'h3F3A2E8C;
            8'd97 : data = 32'h3F39A786;
            8'd98 : data = 32'h3F392144;
            8'd99 : data = 32'h3F389BC3;
            8'd100: data = 32'h3F381703;
            8'd101: data = 32'h3F379301;
            8'd102: data = 32'h3F370FBB;
            8'd103: data = 32'h3F368D31;
            8'd104: data = 32'h3F360B61;
            8'd105: data = 32'h3F358A48;
            8'd106: data = 32'h3F3509E7;
            8'd107: data = 32'h3F348A3A;
            8'd108: data = 32'h3F340B41;
            8'd109: data = 32'h3F338CFA;
            8'd110: data = 32'h3F330F63;
            8'd111: data = 32'h3F32927C;
            8'd112: data = 32'h3F321643;
            8'd113: data = 32'h3F319AB6;
            8'd114: data = 32'h3F311FD4;
            8'd115: data = 32'h3F30A59B;
            8'd116: data = 32'h3F302C0B;
            8'd117: data = 32'h3F2FB322;
            8'd118: data = 32'h3F2F3ADE;
            8'd119: data = 32'h3F2EC33E;
            8'd120: data = 32'h3F2E4C41;
            8'd121: data = 32'h3F2DD5E6;
            8'd122: data = 32'h3F2D602B;
            8'd123: data = 32'h3F2CEB10;
            8'd124: data = 32'h3F2C7692;
            8'd125: data = 32'h3F2C02B0;
            8'd126: data = 32'h3F2B8F6A;
            8'd127: data = 32'h3F2B1CBE;
            8'd128: data = 32'h3F2AAAAB;
            8'd129: data = 32'h3F2A392F;
            8'd130: data = 32'h3F29C84A;
            8'd131: data = 32'h3F2957FB;
            8'd132: data = 32'h3F28E83F;
            8'd133: data = 32'h3F287917;
            8'd134: data = 32'h3F280A81;
            8'd135: data = 32'h3F279C7B;
            8'd136: data = 32'h3F272F05;
            8'd137: data = 32'h3F26C21E;
            8'd138: data = 32'h3F2655C4;
            8'd139: data = 32'h3F25E9F7;
            8'd140: data = 32'h3F257EB5;
            8'd141: data = 32'h3F2513FD;
            8'd142: data = 32'h3F24A9CF;
            8'd143: data = 32'h3F244029;
            8'd144: data = 32'h3F23D70A;
            8'd145: data = 32'h3F236E72;
            8'd146: data = 32'h3F23065E;
            8'd147: data = 32'h3F229ECF;
            8'd148: data = 32'h3F2237C3;
            8'd149: data = 32'h3F21D13A;
            8'd150: data = 32'h3F216B31;
            8'd151: data = 32'h3F2105A9;
            8'd152: data = 32'h3F20A0A1;
            8'd153: data = 32'h3F203C17;
            8'd154: data = 32'h3F1FD80A;
            8'd155: data = 32'h3F1F747A;
            8'd156: data = 32'h3F1F1166;
            8'd157: data = 32'h3F1EAECD;
            8'd158: data = 32'h3F1E4CAD;
            8'd159: data = 32'h3F1DEB07;
            8'd160: data = 32'h3F1D89D9;
            8'd161: data = 32'h3F1D2922;
            8'd162: data = 32'h3F1CC8E1;
            8'd163: data = 32'h3F1C6917;
            8'd164: data = 32'h3F1C09C1;
            8'd165: data = 32'h3F1BAADF;
            8'd166: data = 32'h3F1B4C70;
            8'd167: data = 32'h3F1AEE73;
            8'd168: data = 32'h3F1A90E8;
            8'd169: data = 32'h3F1A33CD;
            8'd170: data = 32'h3F19D723;
            8'd171: data = 32'h3F197AE7;
            8'd172: data = 32'h3F191F1A;
            8'd173: data = 32'h3F18C3BB;
            8'd174: data = 32'h3F1868C8;
            8'd175: data = 32'h3F180E41;
            8'd176: data = 32'h3F17B426;
            8'd177: data = 32'h3F175A75;
            8'd178: data = 32'h3F17012E;
            8'd179: data = 32'h3F16A850;
            8'd180: data = 32'h3F164FDA;
            8'd181: data = 32'h3F15F7CC;
            8'd182: data = 32'h3F15A025;
            8'd183: data = 32'h3F1548E5;
            8'd184: data = 32'h3F14F209;
            8'd185: data = 32'h3F149B93;
            8'd186: data = 32'h3F144581;
            8'd187: data = 32'h3F13EFD2;
            8'd188: data = 32'h3F139A86;
            8'd189: data = 32'h3F13459C;
            8'd190: data = 32'h3F12F114;
            8'd191: data = 32'h3F129CEC;
            8'd192: data = 32'h3F124925;
            8'd193: data = 32'h3F11F5BD;
            8'd194: data = 32'h3F11A2B4;
            8'd195: data = 32'h3F115009;
            8'd196: data = 32'h3F10FDBC;
            8'd197: data = 32'h3F10ABCC;
            8'd198: data = 32'h3F105A38;
            8'd199: data = 32'h3F100901;
            8'd200: data = 32'h3F0FB824;
            8'd201: data = 32'h3F0F67A2;
            8'd202: data = 32'h3F0F177A;
            8'd203: data = 32'h3F0EC7AB;
            8'd204: data = 32'h3F0E7835;
            8'd205: data = 32'h3F0E2918;
            8'd206: data = 32'h3F0DDA52;
            8'd207: data = 32'h3F0D8BE3;
            8'd208: data = 32'h3F0D3DCB;
            8'd209: data = 32'h3F0CF009;
            8'd210: data = 32'h3F0CA29C;
            8'd211: data = 32'h3F0C5584;
            8'd212: data = 32'h3F0C08C1;
            8'd213: data = 32'h3F0BBC51;
            8'd214: data = 32'h3F0B7034;
            8'd215: data = 32'h3F0B246B;
            8'd216: data = 32'h3F0AD8F3;
            8'd217: data = 32'h3F0A8DCD;
            8'd218: data = 32'h3F0A42F8;
            8'd219: data = 32'h3F09F874;
            8'd220: data = 32'h3F09AE41;
            8'd221: data = 32'h3F09645C;
            8'd222: data = 32'h3F091AC7;
            8'd223: data = 32'h3F08D181;
            8'd224: data = 32'h3F088889;
            8'd225: data = 32'h3F083FDE;
            8'd226: data = 32'h3F07F781;
            8'd227: data = 32'h3F07AF70;
            8'd228: data = 32'h3F0767AB;
            8'd229: data = 32'h3F072033;
            8'd230: data = 32'h3F06D905;
            8'd231: data = 32'h3F069223;
            8'd232: data = 32'h3F064B8A;
            8'd233: data = 32'h3F06053C;
            8'd234: data = 32'h3F05BF37;
            8'd235: data = 32'h3F05797C;
            8'd236: data = 32'h3F053408;
            8'd237: data = 32'h3F04EEDD;
            8'd238: data = 32'h3F04A9FA;
            8'd239: data = 32'h3F04655E;
            8'd240: data = 32'h3F042108;
            8'd241: data = 32'h3F03DCF9;
            8'd242: data = 32'h3F039930;
            8'd243: data = 32'h3F0355AD;
            8'd244: data = 32'h3F03126F;
            8'd245: data = 32'h3F02CF75;
            8'd246: data = 32'h3F028CC0;
            8'd247: data = 32'h3F024A4E;
            8'd248: data = 32'h3F020821;
            8'd249: data = 32'h3F01C636;
            8'd250: data = 32'h3F01848E;
            8'd251: data = 32'h3F014328;
            8'd252: data = 32'h3F010204;
            8'd253: data = 32'h3F00C122;
            8'd254: data = 32'h3F008081;
            8'd255: data = 32'h3F004020;
            default: data = 32'h00000000;
        endcase
    end

endmodule



