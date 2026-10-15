/**
 * This file is part of the Coyote <https://github.com/fpgasystems/Coyote>
 *
 * MIT Licence
 * Copyright (c) 2025, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

`ifndef SIM_PARAMS_SVH
`define SIM_PARAMS_SVH

`include "log.svh"

// dpi/file_io.c
import "DPI-C" function real coyote_sim_env_real(input string name, input real dflt);

/**
 * Rate limit of one direction of a mock: a token bucket in bytes that gains
 * bytes_per_cycle every clock and holds at most two beats.
 */
class token_bucket;
    localparam int BEAT_BYTES = AXI_DATA_BITS / 8;
    localparam real BUCKET_BYTES = 2.0 * BEAT_BYTES;

    real     bytes_per_cycle; // 0 is no limit
    real     tokens = BUCKET_BYTES;
    realtime filled_at = 0;

    function new(input real bytes_per_cycle);
        this.bytes_per_cycle = bytes_per_cycle;
    endfunction

    // One beat from the bucket; 0 when the bucket is short.
    // Refills from the time since the last call, so one bucket serves all streams of the mock.
    function bit take();
        if (bytes_per_cycle == 0) return 1;

        tokens += ($realtime - filled_at) / CLK_PERIOD * bytes_per_cycle;
        filled_at = $realtime;
        if (tokens > BUCKET_BYTES) tokens = BUCKET_BYTES;

        if (tokens < BEAT_BYTES) return 0;
        tokens -= BEAT_BYTES;
        return 1;
    endfunction
endclass

/**
 * Timing parameters of one memory mock, read once from the environment:
 * COYOTE_SIM_<KEY>_LATENCY_NS and COYOTE_SIM_<KEY>_GBPS, KEY = HOST, CARD or RDMA.
 * Variables, defaults and the token bucket: sim/README.md, "Timing parameters".
 * Mocks that share a port (the two RDMA mocks) share one object, so they share the buckets.
 */
class mock_params;
    realtime     latency;
    token_bucket rd; // data out of the mock (read responses)
    token_bucket wr; // data into the mock (writes)

    function new(input string key);
        real gbps = coyote_sim_env_real({"COYOTE_SIM_", key, "_GBPS"}, 0.0);
        real bytes_per_cycle;

        latency = coyote_sim_env_real({"COYOTE_SIM_", key, "_LATENCY_NS"}, 50.0) * 1ns;
        // At least one clock: a stream that drives in the time step of its request wake
        // hits the lost-drive bug of Verilator 5.052 (see c_meta.svh, last_send).
        if (latency < CLK_PERIOD) latency = CLK_PERIOD;
        if (gbps < 0) gbps = 0;
        bytes_per_cycle = gbps / 8.0 * (CLK_PERIOD / 1ns);

        rd = new(bytes_per_cycle);
        wr = new(bytes_per_cycle);

        `DEBUG(("%s: latency %0.0f ns, bandwidth %s", key, latency / 1ns, (gbps == 0) ? "unlimited"
            : $sformatf("%0g Gbit/s (%0.2f B/cycle)", gbps, bytes_per_cycle)))
    endfunction
endclass

`endif // SIM_PARAMS_SVH
