#ifndef __GRDU_MEMORY_H
#define __GRDU_MEMORY_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct grdu_memory {
    uint8_t* data;
    size_t last_index;
    size_t capacity;
    size_t out_of_memory_capacity; // how many bytes were needed to allocate on top of last_index, outside of capacity
} grdu_memory;

void grdu_memory_free(grdu_memory* mem);
// return 0 on success, -1 on error
int grdu_memory_init(grdu_memory* mem, size_t capacity);
void grdu_memory_init_static(grdu_memory* mem, uint8_t* data, size_t capacity);
uint8_t * grdu_memory_alloc(grdu_memory* mem, size_t size);

#ifdef __cplusplus
}
#endif

#endif //__GRDU_MEMORY_H