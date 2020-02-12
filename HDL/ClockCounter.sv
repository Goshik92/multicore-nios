/*******************************************************************************
 * Copyright 2019 Igor Semenov and LaCASA@UAH
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *******************************************************************************/

/***********************************************
* Platform: Terasic DE2-115
* Date: 10/14/2019
* Description:
*     The module implements a simple 64-bit clock counter
*     connected to the Avalon-MM interface as a slave 
*     (see its full description in the report)
***********************************************/
module ClockCounter(
    input logic clock,
    input logic reset,
    
    // Avalon-MM slave interface for accessing control-status registers
    input logic csr_read,
    input logic csr_write,
    input logic csr_address,
    output logic [31:0] csr_readdata,
    input logic [31:0] csr_writedata
);

    // A 16-bit clock counter
    logic [63:0] counter;
    
    // A snapshot of the higher 32-bits of the clock counter
    logic [31:0] hSnapshot;

    always_ff @(posedge clock)
    begin
        if (reset) counter <= 1'b0;

        else begin
            // No matter what software writes to any of the registers,
            // we set the value of clock counter to 0, allowing to reset the counting
            if (csr_write) counter <= 1'b0;
            
            // If no writes are needed we update the counter. This process
            // cannot be stopped
            else counter <= counter + 1'b1;
            
            if (csr_read) begin
                case(csr_address)
                    // When software reads the lower part of the counter
                    // we take a snapshot of its higher part, to provide
                    // clock counter integrity
                    1'b0: begin
                        hSnapshot <= counter[63:32];
                        csr_readdata <= counter[31:0];
                    end
                    
                    // The higher part of the clock counter is taken from the
                    // snapshot register. To update it, software needs to read
                    // the lower part of the counter first
                    1'b1: csr_readdata <= hSnapshot;
                endcase
            end
        end
    end
    
endmodule