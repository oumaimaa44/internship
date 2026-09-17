// CVA6 staging-only implementation for Vivado/Odatix
// Upstream source is intentionally left untouched.

module unread (
    input logic d_i
);

    (* KEEP = "TRUE", DONT_TOUCH = "TRUE" *)
    logic d_sink;

    assign d_sink = ~d_i;

endmodule
