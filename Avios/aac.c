//
//  aac.c
//  Avios
//
//  Created by Josh Baker on 4/13/15.
//  Copyright (c) 2015 ONCast, LLC. All rights reserved.
//

#include <stdbool.h>
#include <pthread.h>

#include "aac.h"
#include "libavformat/avformat.h"

struct _aac_decoder {
    bool torndown;
    AVCodec *codec;
    AVPacket packet;
    AVCodecContext *codec_ctx;
    AVFrame *frame;
    AVCodecParserContext *parser;
    int rate;
    int channels;
    int              pcm_float_size;
    size_t           pcm_size;
    float*           pcm;
    int              pcm_count;
    int              pcm_channels;
};

static void avlog_cb(void *av, int level, const char * szFmt, va_list varg) {
    char str[1000];
    vsnprintf(str, sizeof(str)-1, szFmt, varg);
    fprintf(stderr, "libav: %s\n", str);
}

static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static bool is_av_setup = false;
static void av_setup(){
    pthread_mutex_lock(&lock);
    if (!is_av_setup){
        av_log_set_callback(avlog_cb);
        av_register_all();
        is_av_setup = true;
    }
    pthread_mutex_unlock(&lock);
}

static int aac_decoder_init(aac_decoder *aac, int rate, int channels){
    if (aac->torndown){
        return false;
    }
    av_setup();
    aac->pcm_float_size = sizeof(float);
    aac->codec = avcodec_find_decoder(AV_CODEC_ID_AAC);
    if (!aac->codec){
        fprintf(stderr, "aac: avcodec_find_decoder failed\n");
        return false;
    }
    av_init_packet(&aac->packet);
    aac->codec_ctx = avcodec_alloc_context3(aac->codec);
    if (!aac->codec_ctx){
        fprintf(stderr, "aac: avcodec_alloc_context3 failed\n");
        return false;
    }
    aac->rate = rate;
    aac->channels = channels;
    aac->codec_ctx->channels = channels;
    aac->codec_ctx->sample_rate = rate;
    aac->codec_ctx->bit_rate = 0;
    aac->frame = av_frame_alloc();
    if (!aac->frame){
        fprintf(stderr, "aac: av_frame_alloc failed\n");
        av_free(aac->codec_ctx);
        return false;
    }
    int ret = avcodec_open2(aac->codec_ctx, aac->codec, NULL);
    if (ret){
        fprintf(stderr, "aac: avcodec_open2 failed\n");
        av_free(aac->frame);
        av_free(aac->codec_ctx);
        return false;
    }
    aac->parser = av_parser_init(aac->codec_ctx->codec_id);
    if (!aac->parser){
        fprintf(stderr, "aac: av_parser_init failed\n");
        avcodec_close(aac->codec_ctx);
        av_free(aac->frame);
        av_free(aac->codec_ctx);
        return false;
    }
    return true;
}


bool aac_decoder_teardown(aac_decoder *aac){
    if (aac->torndown){
        return false;
    }
    aac->torndown = true;
    if (aac->pcm){
        free(aac->pcm);
    }
    av_parser_close(aac->parser);
    avcodec_close(aac->codec_ctx);
    av_free(aac->frame);
    av_free(aac->codec_ctx);
    return true;
}


bool aac_decoder_decode(aac_decoder *aac, uint8_t *data, size_t data_size){
    if (aac->torndown){
        return false;
    }
    int got_frame = 0;
    int pi=0;
    uint8_t *in_bytes = data;
    size_t in_len = data_size;
    while (in_len > 0){
        aac->packet.data = in_bytes;
        aac->packet.size = (int)in_len;
        int len = avcodec_decode_audio4(aac->codec_ctx, aac->frame, &got_frame, &aac->packet);
        if (len < 0) {
            fprintf(stderr, "aac: avcodec_decode_audio4 failed\n");
            return false;
        }
        if (got_frame) {
            /*int data_size = */ av_samples_get_buffer_size(NULL, aac->codec_ctx->channels,aac->frame->nb_samples,aac->codec_ctx->sample_fmt,1);
            if (aac->frame->format != AV_SAMPLE_FMT_FLTP){
                fprintf(stderr, "aac: invalid format: expecting AV_SAMPLE_FMT_FLTP\n");
                return false;
            }
            int expected_size = aac->frame->nb_samples*aac->codec_ctx->channels*sizeof(float);
            if (aac->pcm_size < expected_size){
                if (aac->pcm){
                    free(aac->pcm);
                }
                aac->pcm_size = 0;
                aac->pcm = malloc(expected_size);
                if (!aac->pcm){
                    fprintf(stderr, "aac: out of memory\n");
                    return false;
                }
                aac->pcm_size = expected_size;
            }
            for (int i=0,k=0;i<aac->frame->nb_samples;i++){
                for (int j=0;j<aac->codec_ctx->channels;j++,k++){
                    float sample = ((float*)(aac->frame->data[j]))[i];
                    aac->pcm[k] = sample;
                }
            }
            aac->pcm_count = aac->frame->nb_samples * aac->codec_ctx->channels;
        }
        in_bytes += len;
        in_len -= len;
        pi++;
    }
    return true;
}

aac_decoder *aac_decoder_new(int rate, int channels){
    aac_decoder *aac = malloc(sizeof(aac_decoder));
    if (!aac){
        return NULL;
    }
    memset(aac, 0, sizeof(aac_decoder));
    if (!aac_decoder_init(aac, rate, channels)){
        free(aac);
        return NULL;
    }
    return aac;
}
void aac_decoder_delete(aac_decoder *aac){
    if (aac){
        aac_decoder_teardown(aac);
        free(aac);
    }
}
int aac_decoder_get_rate(aac_decoder *aac){
    if (!aac){
        return -1;
    }
    return aac->rate;
}
int aac_decoder_get_channels(aac_decoder *aac){
    if (!aac){
        return -1;
    }
    return aac->channels;
}
int aac_decoder_get_pcm_count(aac_decoder *aac){
    if (!aac){
        return -1;
    }
    return aac->pcm_count;
}
float *aac_decoder_get_pcm(aac_decoder *aac){
    if (!aac){
        return 0;
    }
    return aac->pcm;
}


