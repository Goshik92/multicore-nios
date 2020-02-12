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

#include "io.h"
#include "nios2.h"
#include "stddef.h"
#include "stdint.h"
#include "stdio.h"
#include "sys/alt_cache.h"
#include "altera_avalon_mailbox_simple.h"

// Register access for custom hardware clock counter
#define CCOUNTER_BASE (CLOCK_COUNTER_0_BASE)
#define CCOUNTER_RESET() IOWR(CCOUNTER_BASE, 0, 0)
#define CCOUNTER_GETL() IORD(CCOUNTER_BASE, 0)
#define CCOUNTER_GETH() IORD(CCOUNTER_BASE, 4)
#define CCOUNTER_CAPTURE() (CCOUNTER_GETL() | ((uint64_t)(CCOUNTER_GETH()) << 32))

// CORE_ID is passed through compiler parameters.
// This number is unique for each project and
// as a result for each processor in the system

// Id of the main core
#define MAIN_CORE 0

// Size of the square matrices being multiplied
// Must be divisible by CORE_COUNT to get correct results
#define MAT_SIZE (104)

// Number of rows for each processor to process
#define LENGTH (MAT_SIZE / CORE_COUNT)

// Defines where the rows for the current processor start
#define OFFSET (CORE_ID * LENGTH)

// Type representing a square matrix
typedef int mat_t[MAT_SIZE][MAT_SIZE];

// Matrix operands (a and b) and product (c).
// They all are located in the shared region
// that all processors have access to.
__attribute__((section(".shared")))
mat_t a, b, c;

// Opens a mailbox device of processor <id>
// for direction <dir> ("in" for sending messages 
// to core <id>, "out" for receiving them)
altera_avalon_mailbox_dev* mbox_open(int id, char* dir)
{
    char name[20];
    sprintf(name, "/dev/c%d_mbox_%s", id, dir);
    return altera_avalon_mailbox_open(name, NULL, NULL);
}

int main()
{  
    // Timeout for mailbox operations
    // 0 means that is infinite
    alt_u32 t = 0;
    
    // The message passed through mailboxes
    // The content of this message is not used
    // in this program: only the fact of receiving matters
    alt_u32 m[2];

// Code for the main core only        
#if (CORE_ID == MAIN_CORE)
    
    // Init matrix a with increasing values mod 16
    for(int i = 0; i < MAT_SIZE; i++)
        for (int j = 0; j < MAT_SIZE; j++)
            a[i][j] = (i * MAT_SIZE + j) % 0x10;
    
    // Matrix b is an identity matrix
    for(int i = 0; i < MAT_SIZE; i++)
        for (int j = 0; j < MAT_SIZE; j++)
            b[i][j] = (i == j ? 1 : 0);
    
    // Since Nios does not have hardware coherency
    // mechanisms, we need to explicitly flush
    // the data cache, so that other cores have
    // access to the most recent data
    alt_dcache_flush_all(); 
    
    // Mailboxes for communicating to the secondary cores
    altera_avalon_mailbox_dev* mbox_in_list[CORE_COUNT];
    altera_avalon_mailbox_dev* mbox_out_list[CORE_COUNT];

    // For each core
    for(int i = 0; i < CORE_COUNT; i++)
    {
        // Skip the main core
        if (i == MAIN_CORE) continue;
        
        // Init mailboxes for sending signals to secondary cores
        mbox_in_list[i] = mbox_open(i, "in");
        
        // Init mailboxes for receiving signals from secondary cores
        mbox_out_list[i] = mbox_open(i, "out");
    }
    
    // Start measuring execution time
    CCOUNTER_RESET();

    // For each core
    for(int i = 0; i < CORE_COUNT; i++)
    { 
        // Tell secondary cores to start processing their rows
        altera_avalon_mailbox_send(mbox_in_list[i], m, t, POLL);
    }
#endif

// Code for all but the main core   
#if (CORE_ID != MAIN_CORE)
    // Open input and output mailboxes that belong
    // to the current core
    altera_avalon_mailbox_dev* mbox_out = mbox_open(CORE_ID, "out"); 
    altera_avalon_mailbox_dev* mbox_in = mbox_open(CORE_ID, "in");
    
    // Wait until the main core signal to the current one
    altera_avalon_mailbox_retrieve_poll(mbox_in, m, t); 
#endif

    // Code for all cores

    // Do partial matrix multiplication.
    // Each core does a different part because of
    // different values of <OFFSET>
    for (int i = OFFSET; i < OFFSET + LENGTH; i++)
    {
        for (int j = 0; j < MAT_SIZE; j++)
        {
            c[i][j] = 0;
            for (int k = 0; k < MAT_SIZE; k++)
                c[i][j] += a[i][k] * b[k][j];
        }
    }

// Code for all but the main core
#if (CORE_ID != MAIN_CORE) 
    // Each secondary core must flush its cache, so that
    // the main core can see correct results
    alt_dcache_flush_all();
    
    // After the job is done, each core sends
    // a notification to the main core
    altera_avalon_mailbox_send(mbox_out, m, t, POLL);
#endif
  
// Code for the main core only  
#if (CORE_ID == MAIN_CORE)
    // For each core
    for(int i = 0; i < CORE_COUNT; i++)
    {   
        // Skip the main core
        if (i == MAIN_CORE) continue;

        // Wait till the secondary cores
        // signalize about completion
        altera_avalon_mailbox_retrieve_poll(mbox_out_list[i], m, t); 
    }
    
    // Record execution time
    const uint64_t execTime = CCOUNTER_CAPTURE();
    
    // Print the resulting matrix
    for(int i = 0; i < MAT_SIZE; i++)
    {
        for (int j = 0; j < MAT_SIZE; j++)
           printf("%x", c[i][j]);
        
        printf("\n");
    }
    
    // Print execution time
    printf("\nExecution time for %d cores is %llu clock cycles\n", CORE_COUNT, execTime);
#endif
    
    // Do nothing
    while(1);
}
