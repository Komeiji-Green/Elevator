`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/11/23 20:09:50
// Design Name: 
// Module Name: elevator
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

module elevator(
    input           sys_clk,           // system clock 100Mhz on board
    input           rst_n,             // reset ,low active
    input           key_up,
    input           key_down,
    input           key_enter,
    input           key_back,
    output wire [3:0] wx,
    output wire [6:0] dx,
    output wire      run, open
    );
    
    wire    clk1, clk;
    wire    up, down, enter, back, key;
    wire [3:0] call, cur, tim, dcnt;

    fdivision fd(sys_clk, clk1, clk);
    debounce db(sys_clk, {key_up, key_down, key_enter, key_back}, {up, down, enter, back}, key);
    read rd(clk, rst_n, key, up, down, back, call);
    control ctrl(clk, rst_n, enter, call, cur, tim, dcnt, run, open);
    display ds(wx, dx, 4'b1111, dcnt, call, tim, cur, clk);
    
endmodule

module control(
    input           clk, rst_n, enter,
    input [3:0]     call,
    output reg [3:0] cur, tim, dcnt,
    output reg      run, open   
);
    reg [3:0] ucnt;
    reg [1:0] st; 
    reg [9:0] vis;
    
    initial begin
        vis = 0; st = 0;
        tim = 0; cur = 1;
        ucnt = 0; dcnt = 0;
        run = 0; open = 0;
    end
    
    wire [3:0] nex;
    wire [1:0] comp;
    wire run_back, open_back, vis_nex, vis_call;
    wire neg_run, neg_open, pos_enter;
    
    delay dl_run(clk, rst_n, run, run_back), dl_open(clk, rst_n, open, open_back);
    getedge eg(clk, rst_n, run_back, open_back, enter, neg_run, neg_open, pos_enter);
    
    assign nex = (st ? (st == 1 ? cur + 1 : cur - 1) : cur);
    assign vis_nex = vis[nex], vis_call = vis[call];
    assign comp = (call == cur ? 2'b00 : (call > cur ? 2'b01 : 2'b10));
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            vis <= 0; ucnt <= 0; dcnt <= 0;
        end else if(clk) begin
            if(neg_run) begin
                if(st == 1 && vis_nex) begin
                    vis[nex] <= 0;
                    ucnt <= ucnt - 1;
                end else if(st == 2 && vis_nex) begin
                    vis[nex] <= 0;
                    dcnt <= dcnt - 1;
                end
            end else if(pos_enter) begin
                if(!vis_call) begin
                    vis[call] <= 1;
                    if(!comp && st == 1 || comp == 2)
                        dcnt <= dcnt + 1;
                    else if(!comp && st == 2 || comp == 1)
                        ucnt <= ucnt + 1;
                end    
    end end end           
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            run <= 0; open <= 0; st <= 0;
        end else if(clk) begin
            if(neg_open) begin // back from opening
                open <= 0;
                run <= (st ? 1 : 0);
            end else if(neg_run) begin // back from running
                if(st == 1 && vis_nex) begin
                    run <= 0; open <= 1;
                    st <= ((ucnt - 1) ? 1 : (dcnt ? 2 : 0));
                end else if(st == 2 && vis_nex) begin
                    run <= 0; open <= 1;
                    st <= ((dcnt - 1) ? 2 : (ucnt ? 1 : 0)); 
                end
            end else if(st && !open && !run) begin
                run <= 1;
            end else if(pos_enter && !st) begin
            case(comp)
                0: open <= 1;
                1: st <= (vis_call ? 0 : 1);
                2: st <= (vis_call ? 0 : 2);
            endcase
    end end end
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tim <= 0; cur <= 1;
        end else if(clk) begin
            if(neg_open) tim <= 0;
            else if(neg_run) begin
                tim <= tim + 1;
                if(st == 1) cur <= cur + 1;
                else if(st == 2) cur <= cur - 1;
            end
    end end
     
endmodule

module getedge(
    input           clk, rst_n, run_back, open_back, enter,
    output          neg_run, neg_open, pos_enter   
);
    reg run_last, open_last, enter_last;
    initial begin
        run_last = 0; open_last = 0; enter_last = 0;
    end
    assign neg_run = run_last && !run_back;
    assign neg_open = open_last && !open_back;
    assign pos_enter = (!enter_last) && enter;
    
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            run_last <= 0; open_last <= 0; enter_last <= 0;
        end else if(clk) begin
            run_last <= run_back; open_last <= open_back; enter_last <= enter;
        end
    end
    
endmodule

module delay(   // delay for 1s
    input           clk190,
    input           rst_n,
    input           en,
    output reg      st
);
    parameter MOD = 190;   
    reg [7:0] timer;
    reg en_last;
    wire pos_en = !en_last && en;
    initial begin
        timer = 0; st = 0; en_last = 0;
    end
    always @(posedge clk190 or negedge rst_n) begin
        if(!rst_n) begin
            timer <= 0; st <= 0; en_last <= 0;
        end else if(clk190) begin
            en_last <= en;
            if(pos_en) begin
                timer <= 0; st <= 0;    // begin counting
            end else if(en) begin
                if(timer == MOD) begin
                    timer <= 0; st <= 0;
                end else begin 
                    timer <= timer + 1;
                    if(timer == MOD - 1) st <= 1;
                end
            end else begin
                st <= 0; timer <= 0;
            end
        end
    end
endmodule

module read(
    input           clk, rst_n, key, up, down, back,
    output reg [3:0] call
);
    reg key_last;
    wire pos_key;
    initial begin call = 1; key_last = 0; end
    assign pos_key = !key_last && key;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            call <= 4'b0001; key_last <= 0;
        end else if(clk) begin
            key_last <= key;
            if(pos_key) begin
                if(up) begin
                    if(call != 4'b1001) call <= call + 1;
                end else if(down) begin
                    if(call != 4'b0000) call <= call - 1;
                end else if(back)
                    call <= 4'b0001;
    end end end
endmodule

module display(
    output reg  [3:0] wx, // wei xuan
    output reg  [6:0] dx, // duan xuan
    input     [3:0] en, // enable
    input     [3:0] d3,
    input     [3:0] d2,
    input     [3:0] d1,
    input     [3:0] d0,
    input           clk190
);
    reg [1:0] s;
    reg [3:0] digit;
    
    initial s = 0;
    
    always@(posedge clk190) begin
        s <= s + 1;
    end
    
    always @(*) begin
        wx <= 4'b0000;
        if(en[s] == 1) wx[s] <= 1'b1;
    end
    
    always @(*)
	case(s)
		0:digit	<= d0[3:0];
		1:digit	<= d1[3:0];
		2:digit	<= d2[3:0];
		3:digit	<= d3[3:0];
		default:digit <= 4'b0000;
	endcase
    
    always @(*)
	case (digit)
		0:dx<=~7'b0000001;
		1:dx<=~7'b1001111;
		2:dx<=~7'b0010010;
		3:dx<=~7'b0000110;
		4:dx<=~7'b1001100;
		5:dx<=~7'b0100100;
		6:dx<=~7'b0100000;
		7:dx<=~7'b0001111;
		8:dx<=~7'b0000000;
		9:dx<=~7'b0000100;
		default:dx<=~7'b0000001;
	endcase
endmodule

module fdivision(
    input           sys_clk,       // system clock 100Mhz on board
    output reg      clk1,          // elevator_speed: 1Hz
    output reg      clk190         // fdisplay: 190Hz
    );
    
    // time counter
    reg [31:0] timer1, timer190;
    
    initial begin 
        timer1 = 0;
        clk1 = 0;
        timer190 = 0;
        clk190 = 0;
    end
    // fdivision for clk1
    always@(posedge sys_clk) begin
        if(timer1 == 32'd100_000_000) // 1Hz
            begin
            timer1 <= 32'd0; clk1 <= ~clk1;
            end
        else
            timer1 <= timer1 + 1'b1;
    end
    
    // fdivision for clk190
    always@(posedge sys_clk) begin
        if(timer190 == 32'd247_358) // 1Hz
            begin
            timer190 <= 32'd0; clk190 <= ~clk190;
            end
        else
            timer190 <= timer190 + 1'b1;
    end
endmodule


module debounce(
    input            clk,
    input [3:0]      key_in,
    output reg [3:0] key_out,
    output wire      signal
);
    parameter DURATION = 100_000;
    reg [19:0] cnt;
    reg st;
    
    initial begin
        st = 0;
        cnt = 0;
        key_out = 0;
    end
        
    // st
    always @(posedge clk) begin
        if(st == 0 && key_in != key_out)
            st <= 1;
        else if(cnt == DURATION)
            st <= 0;
        // else not change
    end
    
    // cnt
    always @(posedge clk) begin
        if(st)
            cnt <= cnt + 1'b1;
        else
            cnt <= 0;
    end
    
    // key_out
    always @(posedge clk) begin
        if(cnt == DURATION - 1)
            key_out <= key_in;
        // else not change
    end
    
    assign signal = (key_out[0] | key_out[1] | key_out[2] | key_out[3]);
    
endmodule