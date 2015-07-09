//
//  vp8.c
//  Avios
//
//  Created by Josh Baker on 7/8/15.
//  Copyright © 2015 ONcast, LLC. All rights reserved.
//

#include "vp8.h"
#include <time.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#define VPX_CODEC_DISABLE_COMPAT 1
#include <vpx/vpx_encoder.h>
#include <vpx/vpx_decoder.h>
#include <vpx/vp8dx.h>
#include <vpx/vp8cx.h>
#define dx_interface (vpx_codec_vp8_dx())
#define cx_interface (vpx_codec_vp8_cx())

struct _vp8_decoder {
    vpx_codec_ctx_t  codec;
    vpx_codec_iter_t iter;
    vp8_image        img;
};

static int vp8_decoder_init(vp8_decoder *vp8){
    int flags = 0;
    vpx_codec_err_t res = vpx_codec_dec_init(&vp8->codec, dx_interface, NULL, flags);
    if (res){
        return res;
    }
    return VPX_CODEC_OK;
}

bool vp8_decoder_decode(vp8_decoder *vp8, const uint8_t *data, size_t data_size){
    int res = vpx_codec_decode(&vp8->codec, data, data_size, NULL, 0);
    if (res) {
        return false;
    }
    vp8->iter = NULL;
    vpx_image_t *img = vpx_codec_get_frame(&vp8->codec, &vp8->iter);
    if (!img){
        return false;
    }
    if (img->fmt != VPX_IMG_FMT_I420) {
        return false;
    }
    vp8->img.y_width = img->d_w;
    vp8->img.y_height = img->d_h;
    vp8->img.y_stride = img->stride[0];
    vp8->img.uv_width = img->d_w/2;
    vp8->img.uv_height = img->d_h/2;
    vp8->img.uv_stride = img->stride[1];
    vp8->img.y = img->planes[0];
    vp8->img.u = img->planes[1];
    vp8->img.v = img->planes[2];
    return true;
}

vp8_decoder *vp8_decoder_new(){
    vp8_decoder *vp8 = (vp8_decoder *)malloc(sizeof(vp8_decoder));
    if (!vp8){
        return NULL;
    }
    memset(vp8, 0, sizeof(vp8_decoder));
    int flags = 0;
    vpx_codec_err_t res = vpx_codec_dec_init(&vp8->codec, dx_interface, NULL, flags);
    if (res){
        free(vp8);
        return false;
    }
    return vp8;
}
void vp8_decoder_delete(vp8_decoder *vp8){
    if (!vp8){
        return;
    }
    vpx_codec_destroy(&vp8->codec);
    free(vp8);
}
vp8_image *vp8_decoder_get_image(vp8_decoder *vp8){
    if (!vp8){
        return NULL;
    }
    return &vp8->img;
}
