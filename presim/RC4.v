`timescale 1ns/10ps
module RC4(clk,rst,key_valid,key_in,plain_read,plain_in_valid,plain_in,plain_write,plain_out,cipher_write,cipher_out,cipher_read,cipher_in,cipher_in_valid,done);

input clk,rst;
input key_valid,plain_in_valid,cipher_in_valid;
input [7:0] key_in,cipher_in,plain_in;
output done;
output plain_write,cipher_write,plain_read,cipher_read;
output [7:0] cipher_out,plain_out;

reg  [ 5:0] sbox  [0:63];
reg  [ 7:0] key   [0:31];

reg  [ 5:0] sbox_cnt;
reg  [ 5:0] sbox_idx;
wire [ 5:0] sbox_idx_cb;

reg  [ 5:0] idx_i;
reg  [ 5:0] idx_j;

wire [ 5:0] sel_i;
wire [ 5:0] sel_j;

wire [ 5:0] idx_i_cb;
wire [ 5:0] idx_j_cb;

wire [ 5:0] CONST_63;

wire key_done;
reg  plain_done;
reg  cipher_done;

reg  [ 1:0] cs;
reg  [ 1:0] ns;

reg  [ 1:0] encrypt_ctrl;

parameter get_key   = 2'b00,
					init_sbox = 2'b01,
					encrypt   = 2'b10,
					decrypt   = 2'b11;

parameter index_i		= 2'b00,
					index_j   = 2'b01,
					swap_ij   = 2'b10,
					cal_out   = 2'b11;

integer i;
integer j;

assign CONST_63 = 63;

always @(posedge clk) begin
	if(key_valid) begin
		cs <= get_key;
	end
	else begin
		cs <= ns;
	end
end

assign done = plain_done && cipher_done ? 1 : 0;

always @(posedge clk) begin
	if(rst) begin
		cipher_done <= 0;
	end
	else begin
		if(cipher_read && !cipher_in_valid)
			cipher_done <= 1;
	end
end

always @(posedge clk) begin
	if(rst) begin
		plain_done <= 0;
	end
	else begin
		if(plain_read && !plain_in_valid)
			plain_done <= 1;
	end
end

//assign cipher_done = !cipher_in_valid ? 1 : 0;
//assign plain_done  = !plain_in_valid  ? 1 : 0;

/* Next state */
always @(*) begin
	case(cs)
		get_key: begin
			ns = key_valid ? get_key : init_sbox;
		end
		init_sbox: begin
			if(sbox_cnt != CONST_63) begin
				ns = init_sbox;
			end
			else begin
				if(plain_done) begin
						ns = decrypt;
				end
				else begin
						ns = encrypt;
				end
			end
		end
		encrypt: begin
			ns = !plain_done ? encrypt : get_key;	
		end
		decrypt: begin
			ns = decrypt;
		end
	endcase
end

assign key_done = key_valid ? 0 : 1;

/* Counter for initing sbox */
always @(posedge clk) begin
	if(cs == get_key) begin
		sbox_cnt <= 0;
	end
	else begin
		if(cs == init_sbox) begin	
			if(sbox_cnt < 63)
				sbox_cnt <= sbox_cnt +1;
			else
				sbox_cnt <= sbox_cnt;
		end
	end
end

/* Get key */
always @(posedge clk) begin
	if(rst) begin
		for(i=0; i<32; i=i+1) begin
			key[i] <= 0;
		end
	end
	else begin
		if(key_valid) begin
			key[31] <= key_in;
			for(j=0; j<31; j=j+1) begin
				key[j] <= key[j+1];
			end
		end
	end
end

assign sbox_idx_cb = (sbox_idx + sbox[sbox_cnt] + key[sbox_cnt[4:0]]) & CONST_63;

always @(posedge clk) begin
	if(cs == get_key) begin
		sbox_idx <= 0;
	end
	else begin 
		if(cs == init_sbox) begin
			sbox_idx <= sbox_idx_cb;
		end
	end
end

/* Sbox */
always @(posedge clk) begin
	if(cs == get_key) begin
		for(i=0; i<64; i = i+1) begin
			sbox[i] <= i;
		end
	end
	else begin
		if(cs == init_sbox) begin
			sbox[sbox_idx_cb] <= sbox[sbox_cnt[5:0]];
		  sbox[sbox_cnt[5:0]] <= sbox[sbox_idx_cb];
		end
		else if(cs == encrypt && encrypt_ctrl == 2) begin
			sbox[idx_i] <= sbox[idx_j];
			sbox[idx_j] <= sbox[idx_i];
		end
		else if(cs == decrypt && encrypt_ctrl == 2) begin
			sbox[idx_i] <= sbox[idx_j];
			sbox[idx_j] <= sbox[idx_i];
		end
	end
end

assign plain_read   = cs == encrypt && encrypt_ctrl == 0 ? 1 : 0;
assign plain_write  = cs == decrypt && encrypt_ctrl == 3 ? 1 : 0;
assign cipher_read  = cs == decrypt && encrypt_ctrl == 0 ? 1 : 0;
assign cipher_write = cs == encrypt && encrypt_ctrl == 3 ? 1 : 0; 

/* ?_? */
wire [ 7:0] sel_in;
wire [ 7:0] sel_out;
assign sel_in  = cs == encrypt ? plain_in   : cipher_in;
assign sel_out = sel_in ^ sbox[sbox[idx_i] + sbox[idx_j] & CONST_63];

assign plain_out  = sel_out;
assign cipher_out = sel_out; 

//assign plain_out  = cipher_in ^ sbox[sbox[idx_i] + sbox[idx_j] & CONST_63];
//assign cipher_out = plain_in  ^ sbox[sbox[idx_i] + sbox[idx_j] & CONST_63];

always @(posedge clk) begin
	if(cs == get_key) begin
		encrypt_ctrl <= 0;
	end
	else begin
		if(cs == encrypt || cs == decrypt) begin
				encrypt_ctrl <= encrypt_ctrl + 1;
		end
	end
end

/* ?_? */
assign idx_i_cb = (idx_i+1) & CONST_63;
assign idx_j_cb = (idx_j + sbox[idx_i]) & CONST_63;

/* Index of encrypt/decrypt */
always @(posedge clk) begin
	if(cs == get_key) begin
		idx_i <= 0;
	end
	else begin
		if(cs == encrypt || cs == decrypt) begin
			if(encrypt_ctrl == 0) begin
				idx_i <= idx_i_cb;
			end
		end
	end
end

always @(posedge clk) begin
	if(cs == get_key) begin
		idx_j <= 0;
	end
	else begin
		if(cs == encrypt || cs == decrypt) begin
			if(encrypt_ctrl == 1) begin
				idx_j <= idx_j_cb;
			end
		end
	end
end

endmodule
