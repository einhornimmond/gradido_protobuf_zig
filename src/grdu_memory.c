#include "../include/grdu_memory.h"

int grdu_memory_init(grdu_memory* mem, size_t capacity) {
    mem->data = (uint8_t*)malloc(capacity);
    if (!mem->data) return -1;
    mem->last_index = 0;
    mem->capacity = capacity;
    mem->out_of_memory_capacity = 0;
    return 0;
}

void grdu_memory_init_static(grdu_memory* mem, uint8_t* data, size_t capacity) {
    mem->data = data;
    mem->last_index = 0;
    mem->capacity = capacity;
    mem->out_of_memory_capacity = 0;
}

void grdu_memory_free(grdu_memory* mem) {
    if (!mem) return;
    if (mem->data) {
        free(mem->data);
        mem->data = NULL;
    }
    mem->last_index = 0;
    mem->capacity = 0;
    mem->out_of_memory_capacity = 0;
}

uint8_t *grdu_memory_alloc(grdu_memory* mem, size_t size) {
  if (!mem || !mem->data) return NULL;
  if (mem->last_index + size > mem->capacity) {
    mem->out_of_memory_capacity += size;
    return NULL;
  }
  mem->last_index += size;
  return mem->data + mem->last_index - size;
}

