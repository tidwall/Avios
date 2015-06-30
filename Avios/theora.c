//
//  theora.c
//  Avios
//
//  Created by Josh Baker on 6/24/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//


#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "libtheora/theora.h"
#include "libtheora/theoraenc.h"

#define TH_SUCCESS 0

#include "theora.h"

struct _theora_decoder {
    bool           torndown;
    ogg_packet     ogg;
    theora_info    info;
    theora_comment comment;
    theora_state   state;
    yuv_buffer     yuv;
};

static bool theora_decoder_init(theora_decoder *theora, uint8_t *headers, size_t headers_size){
    
    // we need to seperate the info, comments, and codeblock
    // headers from the single headers block
    uint8_t *info_hdr = NULL, *comm_hdr = NULL, *code_hdr = NULL;
    for (int i=0;i<headers_size;i++){
        if        ((headers[i+0]==128&&headers[i+1]=='t') && (memcmp(headers+i+1, "theora", 6)==0)){
            info_hdr = headers+i;
        } else if ((headers[i+0]==129&&headers[i+1]=='t') && (memcmp(headers+i+1, "theora", 6)==0)){
            comm_hdr = headers+i;
        } else if ((headers[i+0]==130&&headers[i+1]=='t') && (memcmp(headers+i+1, "theora", 6)==0)){
            code_hdr = headers+i;
        }
    }
    if ((!info_hdr||!comm_hdr||!code_hdr)||(info_hdr>comm_hdr||info_hdr>code_hdr||comm_hdr>code_hdr)){
        fprintf(stderr, "theora_decoder_init: bad header\n");
        return false;
    }
    
    int info_hdr_len = comm_hdr-info_hdr;
    int comm_hdr_len = code_hdr-comm_hdr;
    int code_hdr_len = headers_size-comm_hdr_len-info_hdr_len;
    
    theora_info_init(&theora->info);
    theora_comment_init(&theora->comment);
    
    // decode headers
    theora->ogg.b_o_s = 1;
    theora->ogg.packet = info_hdr;
    theora->ogg.bytes = info_hdr_len;
    int ret = theora_decode_header(&theora->info, &theora->comment, &theora->ogg);
    if (ret){
        theora_info_clear(&theora->info);
        theora_comment_clear(&theora->comment);
        fprintf(stderr, "theora_decoder_init: theora_decode_header (1) failed: %d\n", ret);
        return false;
    }
    theora->ogg.packet = comm_hdr;
    theora->ogg.bytes = comm_hdr_len;
    ret = theora_decode_header(&theora->info, &theora->comment, &theora->ogg);
    if (ret){
        theora_info_clear(&theora->info);
        theora_comment_clear(&theora->comment);
        fprintf(stderr, "theora_decoder_init: theora_decode_header (2) failed: %d\n", ret);
        return false;
    }
    theora->ogg.packet = code_hdr;
    theora->ogg.bytes = code_hdr_len;
    ret = theora_decode_header(&theora->info, &theora->comment, &theora->ogg);
    if (ret){
        theora_info_clear(&theora->info);
        theora_comment_clear(&theora->comment);
        fprintf(stderr, "theora_decoder_init: theora_decode_header (3) failed: %d\n", ret);
        return false;
    }
    theora->ogg.b_o_s = 0;
    ret = theora_decode_init(&theora->state, &theora->info);
    if (ret){
        theora_info_clear(&theora->info);
        theora_comment_clear(&theora->comment);
        fprintf(stderr, "theora_decoder_init: theora_decode_init failed: %d\n", ret);
        return false;
    }
    return true;
}

bool theora_decoder_decode(theora_decoder *theora, const uint8_t *data, size_t data_size){
    if (theora->torndown){
        return false;
    }
    theora->ogg.packet = data;
    theora->ogg.bytes = data_size;
    theora->ogg.packetno++;
    int ret = theora_decode_packetin(&theora->state, &theora->ogg);
    if (ret){
        fprintf(stderr, "theora_decoder_decode: theora_decode_packetin failed: %d\n", ret);
        return false;
    }
    ret = theora_decode_YUVout(&theora->state, &theora->yuv);
    if (ret){
        fprintf(stderr, "theora_decoder_decode: theora_decode_YUVout failed: %d\n", ret);
        return false;
    }
    return true;
}



static void theora_decoder_teardown(theora_decoder *theora){
    if (theora->torndown){
        return;
    }
    theora->torndown = true;
    theora_info_clear(&theora->info);
    theora_comment_clear(&theora->comment);
    theora_clear(&theora->state);
}

theora_decoder *theora_decoder_new(const uint8_t *headers, size_t headers_size){
    theora_decoder *theora = malloc(sizeof(theora_decoder));
    if (!theora){
        return NULL;
    }
    memset(theora, 0, sizeof(theora_decoder));
    bool res = theora_decoder_init(theora, headers, headers_size);
    if (!res){
        free(theora);
        return NULL;
    }
    return theora;
}

void theora_decoder_delete(theora_decoder *theora){
    if (!theora){
        return;
    }
    theora_decoder_teardown(theora);
}

theora_image *theora_decoder_get_image(theora_decoder *theora){
    if (!theora){
        return NULL;
    }
    return (theora_image*)(&theora->yuv);
}

