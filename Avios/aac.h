//
//  aac.h
//  Avios
//
//  Created by Josh Baker on 4/13/15.
//  Copyright (c) 2015 ONCast, LLC. All rights reserved.
//

#ifndef __AAC_H__
#define __AAC_H__

#include <stdio.h>
#include <stdbool.h>

#define FLOAT_SIZE sizeof(float)

struct _aac_decoder;
typedef struct _aac_decoder aac_decoder;

aac_decoder *aac_decoder_new(int rate, int channels);
void aac_decoder_delete(aac_decoder *aac);
bool aac_decoder_decode(aac_decoder *aac, uint8_t *data, size_t data_size);


#endif /* defined(__AAC_H__) */
