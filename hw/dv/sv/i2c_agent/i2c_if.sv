// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

import i2c_agent_pkg::*;

interface i2c_if;
  logic clk_i;
  logic rst_ni;

  // standard i2c interface pins
  logic scl_i;
  logic scl_o;
  logic sda_i;
  logic sda_o;

  //---------------------------------
  // common tasks
  //---------------------------------
  task automatic wait_for_dly(int dly);
    repeat (dly) @(posedge clk_i);
  endtask : wait_for_dly

  task automatic wait_for_host_start(ref timing_cfg_t tc);
    forever begin
      @(negedge sda_i);
      wait_for_dly(tc.tHoldStart);
      @(negedge scl_i);
      wait_for_dly(tc.tClockStart);
      break;
    end
  endtask: wait_for_host_start

  task automatic wait_for_host_rstart(ref timing_cfg_t tc,
                                      output bit rstart);
    rstart = 1'b0;
    forever begin
      @(posedge scl_i && sda_i);
      wait_for_dly(tc.tSetupStart);
      @(negedge sda_i);
      if (scl_i) begin
        wait_for_dly(tc.tHoldStart);
        @(negedge scl_i) begin
          rstart = 1'b1;
          break;
        end
      end
    end
  endtask: wait_for_host_rstart

  task automatic wait_for_host_stop(ref timing_cfg_t tc,
                                    output bit stop);
    stop = 1'b0;
    forever begin
      @(posedge scl_i);
      @(posedge sda_i);
      if (scl_i) begin
        stop = 1'b1;
        break;
      end
    end
    wait_for_dly(tc.tHoldStop);
  endtask: wait_for_host_stop

  task automatic wait_for_host_stop_or_rstart(timing_cfg_t tc,
                                              output bit   rstart,
                                              output bit   stop);
    fork
      begin : iso_fork
        fork
          wait_for_host_stop(tc, stop);
          wait_for_host_rstart(tc, rstart);
        join_any
        disable fork;
      end : iso_fork
    join
  endtask: wait_for_host_stop_or_rstart

  task automatic wait_for_host_ack(ref timing_cfg_t tc);
    @(negedge sda_i);
    wait_for_dly(tc.tClockLow + tc.tSetupBit);
    forever begin
      @(posedge scl_i);
      if (!sda_i) begin
        wait_for_dly(tc.tClockPulse);
        break;
      end
    end
    wait_for_dly(tc.tHoldBit);
  endtask: wait_for_host_ack

  task automatic wait_for_host_nack(ref timing_cfg_t tc);
    @(negedge sda_i);
    wait_for_dly(tc.tClockLow + tc.tSetupBit);
    forever begin
      @(posedge scl_i);
      if (sda_i) begin
        wait_for_dly(tc.tClockPulse);
        break;
      end
    end
    wait_for_dly(tc.tHoldBit);
  endtask: wait_for_host_nack

  task automatic wait_for_host_ack_or_nack(timing_cfg_t tc,
                                           output bit   ack,
                                           output bit   nack);
    ack = 1'b0;
    nack = 1'b0;
    fork
      begin : iso_fork
        fork
          begin
            wait_for_host_ack(tc);
            ack = 1'b1;
          end
          begin
            wait_for_host_nack(tc);
            nack = 1'b1;
          end
        join_any
        disable fork;
      end : iso_fork
    join
  endtask: wait_for_host_ack_or_nack

  task automatic wait_for_device_ack(ref timing_cfg_t tc);
    @(negedge sda_o && scl_o);
    wait_for_dly(tc.tSetupBit);
    forever begin
      @(posedge scl_i);
      if (!sda_o) begin
        wait_for_dly(tc.tClockPulse);
        break;
      end
    end
    wait_for_dly(tc.tHoldBit);
  endtask: wait_for_device_ack

  task automatic device_send_ack(ref timing_cfg_t tc);
    sda_o = 1'b1;
    wait_for_dly(tc.tClockLow);
    sda_o = 1'b0;
    wait_for_dly(tc.tSetupBit);
    @(posedge scl_i);
    wait_for_dly(tc.tClockPulse + tc.tHoldBit);
    if (tc.enbTimeOut) begin
      wait_for_dly(tc.tStretchHostClock);
    end
    sda_o = 1'b1;
  endtask: device_send_ack

  task automatic device_send_bit(ref timing_cfg_t tc,
                                 input bit bit_i);
    sda_o = 1'b1;
    wait_for_dly(tc.tClockLow);
    sda_o = bit_i;
    wait_for_dly(tc.tSetupBit);
    @(posedge scl_i);
    wait_for_dly(tc.tClockPulse + tc.tHoldBit);
    sda_o = 1'b1;
  endtask: device_send_bit

  task automatic device_stretch_host_clk(ref timing_cfg_t tc);
    if (tc.enbTimeOut) begin
      wait_for_dly(tc.tClockLow + tc.tSetupBit);
      scl_o = 1'b0;
      wait_for_dly(tc.tStretchHostClock);
      scl_o = 1'b1;
    end
  endtask : device_stretch_host_clk

  task automatic get_bit_data(string src = "host",
                              ref timing_cfg_t tc,
                              output bit bit_o);
    wait_for_dly(tc.tClockLow + tc.tSetupBit);
    @(posedge scl_i);
    bit_o = (src == "host") ? sda_i : sda_o;
    wait_for_dly(tc.tClockPulse + tc.tHoldBit);
  endtask: get_bit_data


endinterface : i2c_if
