//
//  vp8.h
//  Avios
//
//  Created by Josh Baker on 7/8/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//

#ifndef __VP8_H__
#define __VP8_H__

#include <stdbool.h>
#include <stdint.h>

typedef struct  {
    int   y_width;
    int   y_height;
    int   y_stride;
    int   uv_width;
    int   uv_height;
    int   uv_stride;
    const uint8_t *y;
    const uint8_t *u;
    const uint8_t *v;
} vp8_image;

struct _vp8_decoder;
typedef struct _vp8_decoder vp8_decoder;

vp8_decoder *vp8_decoder_new();
void vp8_decoder_delete(vp8_decoder *vp8);
bool vp8_decoder_decode(vp8_decoder *vp8, const uint8_t *data, size_t data_size);
vp8_image *vp8_decoder_get_image(vp8_decoder *vp8);


#endif /* __VP8_H__ */
