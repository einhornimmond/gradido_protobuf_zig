#include "../include/grdu_memory.h"

/*
typedef struct grdu_memory {
    void* data;
    size_t last_index;
    size_t capacity;
} grdu_memory;


*/

int grdu_memory_init(grdu_memory* mem, size_t capacity) {
    mem->data = (uint8_t*)malloc(capacity);
    if (!mem->data) return -1;
    mem->last_index = 0;
    mem->capacity = capacity;
    return 0;
}

void grdu_memory_init_static(grdu_memory* mem, uint8_t* data, size_t capacity) {
    mem->data = data;
    mem->last_index = 0;
    mem->capacity = capacity;
}

void grdu_memory_free(grdu_memory* mem) {
    if (!mem) return;
    if (mem->data) {
        free(mem->data);
        mem->data = NULL;
    }
    mem->last_index = 0;
    mem->capacity = 0;
}

uint8_t *grdu_memory_alloc(grdu_memory* mem, size_t size) {
  if (!mem || !mem->data) return NULL;
  if (mem->last_index + size > mem->capacity) {
    return NULL;
  }
  mem->last_index += size;
  return mem->data + mem->last_index - size;
}

