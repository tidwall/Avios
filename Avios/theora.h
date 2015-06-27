//
//  theora.h
//  Avios
//
//  Created by Josh Baker on 6/24/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//

#ifndef __THEORA_H__
#define __THEORA_H__

typedef struct  {
    int   y_width;
    int   y_height;
    int   y_stride;
    int   uv_width;
    int   uv_height;
    int   uv_stride;
    unsigned char *y;
    unsigned char *u;
    unsigned char *v;
} theora_image;

struct _theora_decoder;
typedef struct _theora_decoder theora_decoder;

theora_decoder *theora_decoder_new(uint8_t *headers, size_t headers_size);
void theora_decoder_delete(theora_decoder *theora);
bool theora_decoder_decode(theora_decoder *theora, uint8_t *data, size_t data_size);
theora_image *theora_decoder_get_image(theora_decoder *theora);

#endif /* __THEORA_H__ */
