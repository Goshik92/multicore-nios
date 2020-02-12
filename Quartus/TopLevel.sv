/*******************************************************************************
 * Copyright 2020 Igor Semenov and LaCASA@UAH
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

module TopLevel (
    // Clock pins
    input logic CLOCK_50,
    input logic KEY
);

    nios_multicore nios_multicore_0 (
        .clock_clk(CLOCK_50),
        .reset_reset_n(KEY)
    );

endmodule

