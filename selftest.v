// Basys 3 standalone self-test.
// Load from a USB stick (JP1 = USB) or over JTAG. No PC interaction needed.
//
//  Idle (all switches off, no button):
//    LEDs  : chase right->left, bar fill, chase back, all-on blink
//    7-seg : lights every segment (a..g, dp) of every digit one at a time,
//            then all four "8." fully lit
//  Any switch on : LEDs mirror the switches, 7-seg shows them as hex
//  Any button    : 7-seg shows C / U / L / r / d on all four digits
//  VGA (640x480) : top = 10 colour bars, bottom = 16-step R, G, B, grey ramps
//  UART 9600 8N1 : "BASYS3 SELFTEST SW=xxxx BTN=CULRD" about once a second

module top (
    input             clk,          // 100 MHz
    input      [15:0] sw,
    input             btnC, btnU, btnL, btnR, btnD,
    output reg [15:0] led,
    output reg [6:0]  seg,          // a..g, active low
    output reg        dp,           // active low
    output reg [3:0]  an,           // active low, an[3] = leftmost digit
    output reg [3:0]  vgaRed, vgaGreen, vgaBlue,
    output reg        Hsync, Vsync,
    output reg        RsTx
);

    // ---------------- input synchronisers ----------------
    reg [15:0] sw_a, sw_s;
    reg [4:0]  bt_a, bt_s;          // {C,U,L,R,D}
    always @(posedge clk) begin
        sw_a <= sw;  sw_s <= sw_a;
        bt_a <= {btnC, btnU, btnL, btnR, btnD};
        bt_s <= bt_a;
    end
    wire any_sw = |sw_s;
    wire any_bt = |bt_s;

    // ---------------- timebase ----------------
    reg [26:0] cnt = 0;
    always @(posedge clk) cnt <= cnt + 1'b1;
    reg  [5:0] st = 0;                     // pattern step, ~84 ms each
    always @(posedge clk) if (&cnt[22:0]) st <= st + 1'b1;

    // ---------------- LEDs ----------------
    reg [15:0] chase;
    always @(*) begin
        case (st[5:4])
            2'd0: chase = 16'h0001 << st[3:0];                // single LED up
            2'd1: chase = 16'hFFFF >> (4'd15 - st[3:0]);      // bar fill
            2'd2: chase = 16'h8000 >> st[3:0];                // single LED down
            default: chase = st[1] ? 16'hFFFF : 16'h0000;     // blink all
        endcase
    end
    always @(posedge clk) led <= any_sw ? sw_s : chase;

    // ---------------- 7-segment ----------------
    function [6:0] hex7;            // bit0 = a ... bit6 = g, 1 = lit
        input [3:0] h;
        case (h)
            4'h0: hex7 = 7'h3F; 4'h1: hex7 = 7'h06; 4'h2: hex7 = 7'h5B; 4'h3: hex7 = 7'h4F;
            4'h4: hex7 = 7'h66; 4'h5: hex7 = 7'h6D; 4'h6: hex7 = 7'h7D; 4'h7: hex7 = 7'h07;
            4'h8: hex7 = 7'h7F; 4'h9: hex7 = 7'h6F; 4'hA: hex7 = 7'h77; 4'hB: hex7 = 7'h7C;
            4'hC: hex7 = 7'h39; 4'hD: hex7 = 7'h5E; 4'hE: hex7 = 7'h79; default: hex7 = 7'h71;
        endcase
    endfunction

    wire [1:0] md = cnt[17:16];     // digit being driven, ~380 Hz refresh
    reg  [6:0] p;                   // lit segments for current digit
    reg        pdp;
    reg  [3:0] nib;
    always @(*) begin
        p = 7'h00; pdp = 1'b0;
        case (md)
            2'd0: nib = sw_s[3:0];  2'd1: nib = sw_s[7:4];
            2'd2: nib = sw_s[11:8]; default: nib = sw_s[15:12];
        endcase
        if (any_bt) begin
            if      (bt_s[4]) p = 7'h39;   // C
            else if (bt_s[3]) p = 7'h3E;   // U
            else if (bt_s[2]) p = 7'h38;   // L
            else if (bt_s[1]) p = 7'h50;   // r
            else              p = 7'h5E;   // d
        end else if (any_sw) begin
            p = hex7(nib);
        end else if (!st[5]) begin
            // walk: digit st[4:3] (3 = leftmost first), segment st[2:0]
            if (md == ~st[4:3]) begin
                if (st[2:0] == 3'd7) pdp = 1'b1;
                else                 p   = 7'h01 << st[2:0];
            end
        end else begin
            p = 7'h7F; pdp = 1'b1;          // 8.8.8.8.
        end
    end
    always @(posedge clk) begin
        seg <= ~p;
        dp  <= ~pdp;
        an  <= ~(4'b0001 << md);
    end

    // ---------------- VGA 640x480 @ 60 Hz (25 MHz pixel enable) ----------------
    reg [1:0] pdiv = 0;
    always @(posedge clk) pdiv <= pdiv + 1'b1;
    wire pe = (pdiv == 2'd3);

    reg [9:0] hc = 0, vc = 0;
    always @(posedge clk) if (pe) begin
        if (hc == 10'd799) begin
            hc <= 0;
            vc <= (vc == 10'd524) ? 10'd0 : vc + 1'b1;
        end else hc <= hc + 1'b1;
    end

    wire       vis   = (hc < 10'd640) && (vc < 10'd480);
    wire [9:0] hr    = hc - 10'd64;                  // ramp area 64..575
    wire       inrmp = (hc >= 10'd64) && (hc < 10'd576);
    wire [3:0] lvl   = inrmp ? hr[8:5] : 4'd0;

    reg [11:0] rgb;
    always @(*) begin
        rgb = 12'h000;
        if (vis) begin
            if (vc < 10'd240) begin
                case (hc[9:6])
                    4'd0: rgb = 12'hFFF; 4'd1: rgb = 12'hFF0; 4'd2: rgb = 12'h0FF;
                    4'd3: rgb = 12'h0F0; 4'd4: rgb = 12'hF0F; 4'd5: rgb = 12'hF00;
                    4'd6: rgb = 12'h00F; 4'd7: rgb = 12'h000; 4'd8: rgb = 12'h888;
                    default: rgb = 12'hFFF;
                endcase
            end else if (vc < 10'd300) rgb = {lvl, 4'h0, 4'h0};
            else if   (vc < 10'd360) rgb = {4'h0, lvl, 4'h0};
            else if   (vc < 10'd420) rgb = {4'h0, 4'h0, lvl};
            else                     rgb = {lvl, lvl, lvl};
        end
    end
    always @(posedge clk) if (pe) begin
        {vgaRed, vgaGreen, vgaBlue} <= rgb;
        Hsync <= ~((hc >= 10'd656) && (hc < 10'd752));
        Vsync <= ~((vc >= 10'd490) && (vc < 10'd492));
    end

    // ---------------- UART TX 9600 8N1 ----------------
    function [7:0] hexc;
        input [3:0] h;
        hexc = (h < 4'd10) ? (8'h30 + h) : (8'h37 + h);
    endfunction

    reg [5:0] ci;                   // character index in message
    reg [7:0] ch;
    always @(*) begin
        case (ci)
            6'd0: ch = "B";  6'd1: ch = "A";  6'd2: ch = "S";  6'd3: ch = "Y";
            6'd4: ch = "S";  6'd5: ch = "3";  6'd6: ch = " ";  6'd7: ch = "S";
            6'd8: ch = "E";  6'd9: ch = "L";  6'd10: ch = "F"; 6'd11: ch = "T";
            6'd12: ch = "E"; 6'd13: ch = "S"; 6'd14: ch = "T"; 6'd15: ch = " ";
            6'd16: ch = "S"; 6'd17: ch = "W"; 6'd18: ch = "=";
            6'd19: ch = hexc(sw_s[15:12]); 6'd20: ch = hexc(sw_s[11:8]);
            6'd21: ch = hexc(sw_s[7:4]);   6'd22: ch = hexc(sw_s[3:0]);
            6'd23: ch = " "; 6'd24: ch = "B"; 6'd25: ch = "T"; 6'd26: ch = "N";
            6'd27: ch = "=";
            6'd28: ch = bt_s[4] ? "C" : "-";
            6'd29: ch = bt_s[3] ? "U" : "-";
            6'd30: ch = bt_s[2] ? "L" : "-";
            6'd31: ch = bt_s[1] ? "R" : "-";
            6'd32: ch = bt_s[0] ? "D" : "-";
            6'd33: ch = 8'h0D;
            default: ch = 8'h0A;
        endcase
    end

    localparam BAUD_DIV = 14'd10417;   // 100 MHz / 9600
    reg [13:0] bd = 0;
    reg [3:0]  bit_n = 0;              // 0 = idle
    reg [9:0]  sh = 10'h3FF;
    reg        sending = 0;
    initial RsTx = 1'b1;

    always @(posedge clk) begin
        if (!sending) begin
            RsTx <= 1'b1;
            if (cnt == 27'd0) begin sending <= 1'b1; ci <= 6'd0; bit_n <= 4'd0; end
        end else if (bit_n == 4'd0) begin
            sh    <= {1'b1, ch, 1'b0};     // stop, data (LSB first), start
            bit_n <= 4'd10;
            bd    <= 0;
        end else begin
            RsTx <= sh[0];
            if (bd == BAUD_DIV - 1'b1) begin
                bd    <= 0;
                sh    <= {1'b1, sh[9:1]};
                bit_n <= bit_n - 1'b1;
                if (bit_n == 4'd1) begin
                    if (ci == 6'd34) sending <= 1'b0;
                    else             ci <= ci + 1'b1;
                end
            end else bd <= bd + 1'b1;
        end
    end

endmodule
