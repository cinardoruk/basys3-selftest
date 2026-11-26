`timescale 1ns/1ps
module tb;
    reg clk = 0; always #5 clk = ~clk;
    reg [15:0] sw = 0;
    reg btnC=0, btnU=0, btnL=0, btnR=0, btnD=0;
    wire [15:0] led; wire [6:0] seg; wire dp; wire [3:0] an;
    wire [3:0] r, g, b; wire hs, vs, tx;
    top dut(.clk(clk), .sw(sw), .btnC(btnC), .btnU(btnU), .btnL(btnL), .btnR(btnR), .btnD(btnD),
            .led(led), .seg(seg), .dp(dp), .an(an), .vgaRed(r), .vgaGreen(g), .vgaBlue(b),
            .Hsync(hs), .Vsync(vs), .RsTx(tx));

    integer errors = 0;
    task check(input cond, input [511:0] msg); begin
        if (!cond) begin errors = errors + 1; $display("FAIL: %0s", msg); end
        else $display("ok:   %0s", msg);
    end endtask

    // ---- UART receiver ----
    reg [8*40-1:0] line = 0; integer k;
    reg [7:0] c;
    initial begin
        // listen from t=0
        forever begin
            @(negedge tx);
            #(10417*10*1.5);
            for (k = 0; k < 8; k = k + 1) begin c[k] = tx; #(10417*10); end
            line = {line[8*39-1:0], c};
        end
    end

    // which digit is lit & with what pattern, sampled when 'an' selects digit d
    function [7:0] segs_of(input integer d); begin segs_of = 0; end endfunction
    reg [7:0] cap [0:3];
    task capture; integer i, n; begin
        for (i = 0; i < 4; i = i + 1) cap[i] = 8'hEE;
        for (n = 0; n < 4; n = n + 0) begin
            @(posedge clk); #1;
            for (i = 0; i < 4; i = i + 1)
                if (an == ~(4'b1 << i) && cap[i] == 8'hEE) begin cap[i] = {~dp, ~seg}; n = n + 1; end
        end
    end endtask

    integer t0, t1, t2;
    initial begin
        // ---- idle at power-up: st=0 -> LED0 on, leftmost digit shows segment a only
        repeat (300000) @(posedge clk);
        check(led == 16'h0001, "idle: chase starts at LED0");
        capture;
        check(cap[3] == 8'h01 && cap[2] == 0 && cap[1] == 0 && cap[0] == 0,
              "idle: segment walk starts with digit 3 seg a");

        // ---- VGA timing
        @(negedge hs); t0 = $time; @(negedge hs); t1 = $time;
        check(t1 - t0 == 32000, "VGA hsync period 32 us (800 px @ 25 MHz)");
        @(negedge vs); t0 = $time; @(negedge vs); t1 = $time;
        check(t1 - t0 == 32000*525, "VGA vsync period 16.8 ms (525 lines)");

        // ---- switches
        sw = 16'hA5C3; repeat (10) @(posedge clk);
        check(led == 16'hA5C3, "switches mirrored on LEDs");
        capture;
        check(cap[3] == 8'h77 && cap[2] == 8'h6D && cap[1] == 8'h39 && cap[0] == 8'h4F,
              "7-seg shows A5C3");

        // ---- buttons
        btnU = 1; repeat (10) @(posedge clk); capture;
        check(cap[0] == 8'h3E && cap[3] == 8'h3E, "btnU shows U on all digits");
        btnU = 0; btnR = 1; repeat (10) @(posedge clk); capture;
        check(cap[1] == 8'h50, "btnR shows r");
        btnR = 0; btnD = 1;

        // ---- UART: first message started at t=0 with sw=0; wait for the 2nd one (cnt wrap 1.34 s)
        //      too long to sim; just check the first message which is already fully sent by now
        if ($time < 10417*10*35*10 + 1000) #(10417*10*35*10 + 1000 - $time);
        $display("uart: \"%0s\"", line);
        check(line[8*35-1:0] == {"BASYS3 SELFTEST SW=0000 BTN=-----", 8'h0D, 8'h0A},
              "UART banner at power-up");
        if (errors) $display("\n%0d FAILURES", errors); else $display("\nALL PASS");
        $finish;
    end
endmodule
