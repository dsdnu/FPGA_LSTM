`timescale 1ns / 1ps

module lstm_cell #
(
    parameter integer DATA_WIDTH	    = 32,
    parameter integer UNITS             = 4,
    parameter integer ACTIV_MEM_DEPTH   = 2048,
    parameter integer W_LENGTH          = 16,
    parameter integer U_LENGTH          = 64,
    parameter integer B_LENGTH          = 16,
    parameter SIG_FILE                  = "sigmoid_lut_13.mem",
    parameter TANH_FILE                 = "tanh_lut_13.mem",
    parameter W_FILE                    = "w_lstm.mem",
    parameter U_FILE                    = "u_lstm.mem",
    parameter B_FILE                    = "b_lstm.mem",
    parameter integer ACTIV_ADDR_WIDTH  = $clog2(ACTIV_MEM_DEPTH),  //11, 2**11 = 2048
    parameter integer W_ADDR_WIDTH      = $clog2(W_LENGTH),         //4, 2**4 = 16
    parameter integer U_ADDR_WIDTH      = $clog2(U_LENGTH),         //6, 2**6 = 64
    parameter integer B_ADDR_WIDTH      = $clog2(B_LENGTH),          //4, 2**4 = 16
    parameter integer A_ROWS = 1,
    parameter integer A_COLS = 4,
    parameter integer B_COLS = 16
)
(
    input       clock,
    input       reset,
    input       [DATA_WIDTH-1:0] xt,                                        //input X = 0.0157
    input       [DATA_WIDTH-1:0] ht_prev0, ht_prev1, ht_prev2, ht_prev3,    //ht-1 = [0 0 0 0]
    input       [DATA_WIDTH-1:0] ct_prev0, ct_prev1, ct_prev2, ct_prev3,    //Ct-1 = [0 0 0 0]
    //input       [DATA_WIDTH-1:0] b,                                         //bias = 1
    output reg  [DATA_WIDTH-1:0] ht0, ht1, ht2, ht3,                        //ht = [_ _ _ _]
    output reg  [DATA_WIDTH-1:0] ct0, ct1, ct2, ct3,                        //Ct = [_ _ _ _]
    output reg  done
);

    //Making array for ht and ct
    reg [DATA_WIDTH-1:0] ht_prev[0:UNITS-1], ct_prev[0:UNITS-1];
    reg [DATA_WIDTH-1:0] ht[0:UNITS-1], ct[0:UNITS-1];
    
    //Memory initialisations
    ////////////////////////////////////////////////////////////////////////////////////////
    //activation functions
    reg [ACTIV_ADDR_WIDTH-1:0] sig_in, tanh_in;
    wire [DATA_WIDTH-1:0] sig_out, tanh_out;
    rom #(DATA_WIDTH, ACTIV_ADDR_WIDTH, SIG_FILE) sig(clock, sig_in, sig_out);
    rom #(DATA_WIDTH, ACTIV_ADDR_WIDTH, TANH_FILE) tanh(clock, tanh_in, tanh_out);
    //weights, biases and hidden state
    reg [$clog2(UNITS)-1:0] h_in;    
    reg [W_ADDR_WIDTH-1:0] w_in;
    reg [U_ADDR_WIDTH-1:0] u_in; 
    reg [B_ADDR_WIDTH-1:0] b_in;
    reg [DATA_WIDTH-1:0] h_out;
    wire [DATA_WIDTH-1:0] w_out, u_out, b_out;
    rom #(DATA_WIDTH, W_ADDR_WIDTH, W_FILE) wlstm(clock, w_in, w_out);
    rom #(DATA_WIDTH, U_ADDR_WIDTH, U_FILE) ulstm(clock, u_in, u_out);
    rom #(DATA_WIDTH, B_ADDR_WIDTH, B_FILE) blstm(clock, b_in, b_out);
    ////////////////////////////////////////////////////////////////////////////////////////
    
    //activation = Wx + Uh + b
    ////////////////////////////////////////////////////////////////////////////////////////
    reg [DATA_WIDTH-1:0] activation[0:W_LENGTH-1], uh_product[0:W_LENGTH-1];
    reg uh_done, activ_done;
    reg [DATA_WIDTH-1:0] addall_ina, addall_inb;
    wire [DATA_WIDTH-1:0] addall_out;
    adder #(DATA_WIDTH) addall(clock, addall_ina, addall_inb, addall_out);
    //A
    reg maddw_enable, maddu_enable;
    wire maddw_ready, maddw_valid, maddu_ready, maddu_valid;
    reg [DATA_WIDTH-1:0] maddw_ina, maddw_inb, maddw_inc, maddu_ina, maddu_inb, maddu_inc;
    wire [DATA_WIDTH-1:0] maddw_out, maddu_out;
    multipadd #(DATA_WIDTH) maddw(clock, reset, maddw_enable, maddw_ina, maddw_inb, maddw_inc, maddw_out, maddw_ready, maddw_valid);
    multipadd #(DATA_WIDTH) maddu(clock, reset, maddu_enable, maddu_ina, maddu_inb, maddu_inc, maddu_out, maddu_ready, maddu_valid);
    ////////////////////////////////////////////////////////////////////////////////////////
    
    //Registers for storing gate variables
    reg [DATA_WIDTH-1:0] it[0:UNITS-1], ft[0:UNITS-1], gt[0:UNITS-1], ot[0:UNITS-1]; 
    
    //Calculating ct
    ////////////////////////////////////////////////////////////////////////////////////////
    reg [DATA_WIDTH-1:0] multc0_ina, multc0_inb, multc1_ina, multc1_inb, addc_ina, addc_inb;
    wire [DATA_WIDTH-1:0] multc0_out, multc1_out, addc_out;
    multiplier #(DATA_WIDTH) multc0(clock, multc0_ina, multc0_inb, multc0_out);
    multiplier #(DATA_WIDTH) multc1(clock, multc1_ina, multc1_inb, multc1_out);
    adder #(DATA_WIDTH) addc(clock, addc_ina, addc_inb, addc_out);
    ////////////////////////////////////////////////////////////////////////////////////////
    
    //Calculating ht
    ////////////////////////////////////////////////////////////////////////////////////////
    reg [DATA_WIDTH-1:0] multh_ina, multh_inb;
    wire [DATA_WIDTH-1:0] multh_out;
    multiplier #(DATA_WIDTH) multh(clock, multh_ina, multh_inb, multh_out);
    ////////////////////////////////////////////////////////////////////////////////////////
    
    integer i, j, k, u, w, z, r, p, c, d, g,  ct_index, ct_delaya, ct_delayb, ht_delay, counterh, ht_index, ht_tan_index;
    
    always @(posedge clock) begin
        if(reset) begin
            for(z=0; z<= UNITS-1; z=z+1) begin
                ht_prev[z] <= 0;
                ct_prev[z] <= 0;
            end
        end else begin
            {ht_prev[0], ht_prev[1], ht_prev[2], ht_prev[3]} <= {ht_prev0, ht_prev1, ht_prev2, ht_prev3};
            {ct_prev[0], ct_prev[1], ct_prev[2], ct_prev[3]} <= {ct_prev0, ct_prev1, ct_prev2, ct_prev3};
            {ht0, ht1, ht2, ht3} <= {ht[0], ht[1], ht[2], ht[3]};
            {ct0, ct1, ct2, ct3} <= {ct[0], ct[1], ct[2], ct[3]};
        end
    end
    
    always @(*) begin
        maddw_ina <= w_out;
        maddw_inb <= xt;
        maddw_inc <= b_out;
    end
    
    always @(posedge clock) begin
        if(reset) begin
            w <= 0;
            w_in <= 0;
            b_in <= 0;
            maddw_enable <= 0;
            r <= 0;
            activ_done <= 0;
            for(z=0; z<=W_LENGTH-1; z=z+1)
                activation[z] <= 0;
        end else if(w < W_LENGTH) begin
            if(maddw_ready)
                maddw_enable <= 1;
            if(maddw_valid)
                maddw_enable <= 0;
            if(maddw_valid & !maddw_enable) begin
                activation[w] <= maddw_out;
                w_in <= w_in + 1; 
                b_in <= b_in + 1;
                w <= w + 1;
            end
        end else if(uh_done) begin 
            if(r < W_LENGTH + 1) begin
                activation[p] <= addall_out;  //activation = activation + Uh
                p <= r;
                r <= r + 1;
            end else
                activ_done <= 1;
        end
    end
    
    always @(*) begin
        h_in <= i*A_COLS + k;
        u_in <= k*B_COLS + j;
        h_out <= ht_prev[h_in];
        maddu_ina <= u_out;
        maddu_inb <= h_out;
        maddu_inc <= uh_product[u];
    end
    
    always @(posedge clock) begin
        if(reset) begin
            i <= 0;
            j <= 0;
            k <= 0;
            u <= 0;
            uh_done <= 0;
            maddu_enable <= 0;
            for(z=0; z<=W_LENGTH-1; z=z+1)
                uh_product[z] <= 0;
        end else if(u < W_LENGTH) begin
            if(maddu_ready)
                maddu_enable <= 1;
            if(maddu_valid)
                maddu_enable <= 0;
            u <= i*B_COLS + j;  //index of the result register
            if(maddu_valid & !maddu_enable) begin
               if(i < A_ROWS) begin    //goes row by row in matrix A, A_ROWS
                   if(j < B_COLS) begin    //goes column by column in matrix B, B_COLS
                       if(k < A_COLS - 1) begin    //goes through addition elements, A_COLS
                           k <= k + 1;
                       end else if(k == A_COLS - 1) begin
                           k <= 0;
                           j <= j + 1;
                       end
                   end
                   if(j == B_COLS - 1 && k == A_COLS - 1) begin    //go to the next row of matrix A
                       j <= 0;     //start from the zeroth column of matrix B
                       i <= i + 1;
                   end
                   uh_product[u] <= maddu_out;
               end
            end
        end else
           uh_done <= 1;
    end
    
    always @(posedge clock) begin
        if(uh_done & !activ_done) begin
            addall_ina <= activation[r];
            addall_inb <= uh_product[r];
        end else begin
            addall_ina <= 0;
            addall_inb <= 0;
        end
    end
    
    always @(posedge clock) begin
        if(reset) begin
            c <= 0;
            d <= 0;
            g <= 0;
            for(z=0; z<=UNITS-1; z=z+1) begin
                it[z] <= 0;
                ft[z] <= 0;
                gt[z] <= 0;
                ot[z] <= 0;
            end
        end else if(activ_done) begin
            if(c < W_LENGTH+1) begin
                g <= d;
                if(g < 4)
                    it[g] <= sig_out;
                else if(g < 8)
                    ft[g-4] <= sig_out;
                else if(g < 12)
                    gt[g-8] <= tanh_out;
                else if(g < 16)
                    ot[g-12] <= sig_out;
                if(d < W_LENGTH-1)
                    d <= d + 1;
                c <= c + 1;
            end
        end 
    end
    
    always @(*) begin
        if(activ_done & c < W_LENGTH+1) begin
            sig_in <= activation[d][DATA_WIDTH-1:DATA_WIDTH-ACTIV_ADDR_WIDTH];
            tanh_in <= activation[d][DATA_WIDTH-1:DATA_WIDTH-ACTIV_ADDR_WIDTH];
        end else begin
            sig_in <= 0;
            tanh_in <= ct[ht_tan_index][DATA_WIDTH-1:DATA_WIDTH-ACTIV_ADDR_WIDTH];
        end
    end
    
    always @(posedge clock) begin
        if(ct_index < UNITS) begin
            multc0_ina <= ft[ct_index];       //ft
            multc0_inb <= ct_prev[ct_index];  //ct_prev    
            multc1_ina <= it[ct_index];       //it
            multc1_inb <= gt[ct_index];       //gt
            addc_ina <= multc0_out;           //ft*ct_prev
            addc_inb <= multc1_out;           //it*gt
        end
        else begin
            multc0_ina <= 0;        //ft
            multc0_inb <= 0;        //ct_prev    
            multc1_ina <= 0;        //it
            multc1_inb <= 0;        //gt
            addc_ina <= 0;          //ft*ct_prev
            addc_inb <= 0;          //it*gt
        end
        
    end

    
    always @(posedge clock) begin
        if(reset) begin
            ct_index <= 0;
            ct_delaya <= 0;
            ct_delayb <= 0;
            for(z=0; z<= UNITS-1; z=z+1) begin
                ct[z] <= 0;
            end
        end else if((c >= W_LENGTH+1) & ct_index < UNITS) begin
            ct_delaya <= ct_index;
            ct_delayb <= ct_delaya;
            ct[ct_delayb] <= addc_out;
            if(ct_index < UNITS-1)
                ct_index <= ct_index + 1;
            else 
                ct_index <= ct_index;
        end
    end
    
    always @(posedge clock) begin
        if(ht_index < UNITS) begin
            multh_ina <= tanh_out;          //tanh(ct)
            multh_inb <= ot[ht_index];      //ct_prev
        end else begin
            multh_ina <= 0;
            multh_inb <= 0;
        end
    end
    
    always @(posedge clock) begin
        if(reset) begin
            counterh <= 0;
            ht_tan_index <= 0;
            ht_index <= 0;
            ht_delay <= 0;
            for(z=0; z<= UNITS-1; z=z+1) begin
                ht[z] <= 0;
            end
        end else if((ct_delayb >= UNITS-1) & counterh < UNITS+2) begin
            ht_index <= ht_tan_index;
            ht_delay <= ht_index;
            ht[ht_delay] <= multh_out;
            if(ht_tan_index < UNITS-1)
                ht_tan_index <= ht_tan_index + 1;
            counterh <= counterh + 1;
        end
    end
    
    always @(posedge clock) begin
        if(reset)
            done <= 0;
        else if (counterh == UNITS+1)
            done <= 1;
    end
    
endmodule
